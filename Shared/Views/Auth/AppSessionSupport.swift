import Combine
import Foundation
import OSLog

extension Logger {
    static let session = Logger(subsystem: "com.RheirHome.RHEIR", category: "session")
}

enum AppSessionState: Equatable {
    case launching
    case signedOut
    case processingInvite
    case selectingOrganization
    case adminOnboarding
    case ready
}

struct SelectionState: Codable, Equatable {
    var organizationID: String?
    var projectID: String?
}

final class LocalCacheStore {
    static let shared = LocalCacheStore()

    private enum Key {
        static let selectionState = "selection_state_v1"
        static let pendingInvite = "pending_invite_v1"
        static let currentOrganizationID = "currentOrganizationID"
        static let previousOrganizationID = "previousOrganizationID"
        static let pendingInviteOrgID = "pending_invite_orgID"
        static let pendingInviteOrgName = "pending_invite_orgName"
        static let pendingInviteToken = "pending_invite_token"
        static let pendingInviteRole = "pending_invite_role"
        static let lastProjectPrefix = "selected_project_for_org_"
        static let appleEmailPrefix = "stored_apple_email_"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        migrateLegacyStateIfNeeded()
    }

    var selectionState: SelectionState {
        get {
            guard let data = userDefaults.data(forKey: Key.selectionState),
                  let state = try? JSONDecoder().decode(SelectionState.self, from: data) else {
                return SelectionState(
                    organizationID: userDefaults.string(forKey: Key.currentOrganizationID),
                    projectID: nil
                )
            }

            return state
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            userDefaults.set(data, forKey: Key.selectionState)
            if let organizationID = newValue.organizationID {
                userDefaults.set(organizationID, forKey: Key.currentOrganizationID)
            } else {
                userDefaults.removeObject(forKey: Key.currentOrganizationID)
            }
        }
    }

    var previousOrganizationID: String? {
        get { userDefaults.string(forKey: Key.previousOrganizationID) }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: Key.previousOrganizationID)
            } else {
                userDefaults.removeObject(forKey: Key.previousOrganizationID)
            }
        }
    }

    var pendingInvite: PendingInvite? {
        get {
            guard let data = userDefaults.data(forKey: Key.pendingInvite),
                  let invite = try? JSONDecoder().decode(PendingInvite.self, from: data) else {
                return nil
            }

            return invite
        }
        set {
            guard let newValue else {
                clearPendingInvite()
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            userDefaults.set(data, forKey: Key.pendingInvite)
            if let organizationID = newValue.organizationId {
                userDefaults.set(organizationID, forKey: Key.pendingInviteOrgID)
            }
            userDefaults.set(newValue.organizationName, forKey: Key.pendingInviteOrgName)
            userDefaults.set(newValue.inviteToken, forKey: Key.pendingInviteToken)
            userDefaults.set(newValue.role.rawValue, forKey: Key.pendingInviteRole)
        }
    }

    func storeAppleEmail(_ email: String, for userID: String) {
        userDefaults.set(email, forKey: Key.appleEmailPrefix + userID)
    }

    func appleEmail(for userID: String) -> String? {
        userDefaults.string(forKey: Key.appleEmailPrefix + userID)
    }

    func clearSessionState() {
        selectionState = SelectionState(organizationID: nil, projectID: nil)
        previousOrganizationID = nil
        clearPendingInvite()
    }

    func clearAllKnownSessionKeys() {
        clearSessionState()
        userDefaults.removeObject(forKey: Key.selectionState)

        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(Key.lastProjectPrefix) || key.hasPrefix(Key.appleEmailPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    func storeLastSelectedProjectID(_ projectID: String?, for organizationID: String) {
        let key = Key.lastProjectPrefix + organizationID
        if let projectID {
            userDefaults.set(projectID, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    func lastSelectedProjectID(for organizationID: String) -> String? {
        userDefaults.string(forKey: Key.lastProjectPrefix + organizationID)
    }

    func clearPendingInvite() {
        userDefaults.removeObject(forKey: Key.pendingInvite)
        userDefaults.removeObject(forKey: Key.pendingInviteOrgID)
        userDefaults.removeObject(forKey: Key.pendingInviteOrgName)
        userDefaults.removeObject(forKey: Key.pendingInviteToken)
        userDefaults.removeObject(forKey: Key.pendingInviteRole)
    }

    private func migrateLegacyStateIfNeeded() {
        if userDefaults.data(forKey: Key.selectionState) == nil {
            let migratedState = SelectionState(
                organizationID: userDefaults.string(forKey: Key.currentOrganizationID),
                projectID: nil
            )
            selectionState = migratedState
        }

        guard userDefaults.data(forKey: Key.pendingInvite) == nil,
              let organizationID = userDefaults.string(forKey: Key.pendingInviteOrgID) else {
            return
        }

        let organizationName = userDefaults.string(forKey: Key.pendingInviteOrgName) ?? "Organization"
        let inviteToken = userDefaults.string(forKey: Key.pendingInviteToken) ?? UUID().uuidString
        let roleString = userDefaults.string(forKey: Key.pendingInviteRole)
        let role = OrganizationRole(rawValue: roleString ?? OrganizationRole.member.rawValue) ?? .member

        pendingInvite = PendingInvite(
            organizationId: organizationID,
            organizationName: organizationName,
            inviteToken: inviteToken,
            role: role,
            source: .legacyStorage
        )
    }
}

protocol OrganizationRepository {
    func joinOrganization(
        organizationID: String,
        role: OrganizationRole,
        completion: @escaping (Result<Organization, Error>) -> Void
    )
}

final class CloudKitOrganizationRepository: OrganizationRepository {
    private weak var authViewModel: AuthViewModel?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    func joinOrganization(
        organizationID: String,
        role: OrganizationRole,
        completion: @escaping (Result<Organization, Error>) -> Void
    ) {
        authViewModel?.joinOrganization(with: organizationID, role: role) { success, errorMessage in
            guard let authViewModel = self.authViewModel else {
                completion(.failure(SessionStoreError.organizationUnavailable))
                return
            }

            if success, let organization = authViewModel.currentOrg {
                completion(.success(organization))
            } else {
                completion(.failure(SessionStoreError.inviteJoinFailed(errorMessage ?? "Unable to join organization.")))
            }
        }
    }
}

enum SessionStoreError: LocalizedError {
    case invalidInvite
    case organizationUnavailable
    case inviteJoinFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidInvite:
            return "This invite link is missing organization details."
        case .organizationUnavailable:
            return "The requested organization is no longer available."
        case .inviteJoinFailed(let message):
            return message
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var state: AppSessionState = .launching
    @Published private(set) var pendingInvite: PendingInvite?
    @Published private(set) var selectionState: SelectionState
    @Published var alertMessage: String?

    private let authViewModel: AuthViewModel
    private let projectViewModel: ProjectViewModel
    private let localCache: LocalCacheStore
    private let organizationRepository: OrganizationRepository
    private let launchDelayNanoseconds: UInt64

    private var cancellables = Set<AnyCancellable>()
    private var hasConnected = false
    private var hasFinishedLaunch = false
    private var isProcessingInvite = false
    private var isChoosingOrganization = false

    init(
        authViewModel: AuthViewModel,
        projectViewModel: ProjectViewModel,
        localCache: LocalCacheStore = .shared,
        organizationRepository: OrganizationRepository? = nil,
        launchDelayNanoseconds: UInt64 = 900_000_000
    ) {
        self.authViewModel = authViewModel
        self.projectViewModel = projectViewModel
        self.localCache = localCache
        self.pendingInvite = localCache.pendingInvite
        self.selectionState = localCache.selectionState
        self.organizationRepository = organizationRepository ?? CloudKitOrganizationRepository(authViewModel: authViewModel)
        self.launchDelayNanoseconds = launchDelayNanoseconds
    }

    func connectIfNeeded() {
        guard !hasConnected else { return }
        hasConnected = true

        authViewModel.setProjectViewModel(projectViewModel)
        bind()

        Task {
            if launchDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: launchDelayNanoseconds)
            }
            hasFinishedLaunch = true
            refreshState(reason: "launch complete")
            processPendingInviteIfPossible()
            restoreProjectSelectionIfPossible()
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard let invite = PendingInvite.parse(from: url) else {
            Logger.session.error("Ignored unsupported URL.")
            return
        }

        Logger.session.info("Stored invite for organization \(invite.organizationName, privacy: .private(mask: .hash)).")
        pendingInvite = invite
        localCache.pendingInvite = invite
        refreshState(reason: "incoming invite")
        processPendingInviteIfPossible()
    }

    func clearPendingInvite() {
        pendingInvite = nil
        localCache.clearPendingInvite()
        authViewModel.clearPendingInvite()
        isProcessingInvite = false
        alertMessage = nil
        refreshState(reason: "pending invite cleared")
    }

    func retryPendingInvite() {
        alertMessage = nil
        processPendingInviteIfPossible()
    }

    func showOrganizationSelector() {
        isChoosingOrganization = true
        refreshState(reason: "organization selector requested")
    }

    func cancelOrganizationSelection() {
        isChoosingOrganization = false
        refreshState(reason: "organization selector dismissed")
    }

    func selectOrganization(_ organization: Organization) {
        localCache.previousOrganizationID = authViewModel.currentOrg?.id
        selectionState.organizationID = organization.id
        selectionState.projectID = nil
        localCache.selectionState = selectionState
        isChoosingOrganization = false
        authViewModel.setCurrentOrganization(organization)
        refreshState(reason: "organization selected")
    }

    func selectProject(_ project: Project) {
        projectViewModel.selectProject(project)
        guard let currentOrganizationID = authViewModel.currentOrg?.id else { return }
        selectionState.organizationID = currentOrganizationID
        selectionState.projectID = project.id.uuidString
        localCache.selectionState = selectionState
        localCache.storeLastSelectedProjectID(project.id.uuidString, for: currentOrganizationID)
    }

    private func bind() {
        authViewModel.$user
            .sink { [weak self] _ in
                self?.refreshState(reason: "user changed")
                self?.processPendingInviteIfPossible()
            }
            .store(in: &cancellables)

        authViewModel.$currentOrg
            .sink { [weak self] organization in
                guard let self else { return }
                if let organization {
                    self.selectionState.organizationID = organization.id
                    self.localCache.selectionState = self.selectionState
                }
                self.refreshState(reason: "organization changed")
                self.restoreProjectSelectionIfPossible()
            }
            .store(in: &cancellables)

        authViewModel.$showAdminInfoUpdate
            .sink { [weak self] _ in
                self?.refreshState(reason: "admin onboarding changed")
            }
            .store(in: &cancellables)

        authViewModel.$organizations
            .sink { [weak self] _ in
                self?.refreshState(reason: "organization list changed")
            }
            .store(in: &cancellables)

        authViewModel.$isLoadingOrgs
            .sink { [weak self] _ in
                self?.refreshState(reason: "organization loading changed")
            }
            .store(in: &cancellables)

        projectViewModel.$accessibleProjects
            .sink { [weak self] _ in
                self?.restoreProjectSelectionIfPossible()
            }
            .store(in: &cancellables)

        projectViewModel.$selectedProject
            .sink { [weak self] project in
                guard let self else { return }
                guard let organizationID = self.authViewModel.currentOrg?.id else { return }
                self.selectionState.organizationID = organizationID
                self.selectionState.projectID = project?.id.uuidString
                self.localCache.selectionState = self.selectionState
                self.localCache.storeLastSelectedProjectID(project?.id.uuidString, for: organizationID)
            }
            .store(in: &cancellables)
    }

    private func refreshState(reason: String) {
        let nextState: AppSessionState

        if !hasFinishedLaunch {
            nextState = .launching
        } else if authViewModel.user == nil {
            nextState = .signedOut
        } else if pendingInvite != nil || isProcessingInvite {
            nextState = .processingInvite
        } else if authViewModel.showAdminInfoUpdate && authViewModel.currentOrg != nil {
            nextState = .adminOnboarding
        } else if authViewModel.currentOrg == nil || isChoosingOrganization {
            nextState = .selectingOrganization
        } else {
            nextState = .ready
        }

        if nextState != state {
            Logger.session.info("Session state changed: \(String(describing: nextState), privacy: .public) [\(reason, privacy: .public)]")
        }
        state = nextState
    }

    private func processPendingInviteIfPossible() {
        guard !isProcessingInvite,
              authViewModel.user != nil,
              let invite = pendingInvite else {
            return
        }

        guard let organizationID = invite.organizationId else {
            alertMessage = SessionStoreError.invalidInvite.localizedDescription
            return
        }

        isProcessingInvite = true
        refreshState(reason: "processing invite")

        organizationRepository.joinOrganization(organizationID: organizationID, role: invite.role) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isProcessingInvite = false

                switch result {
                case .success(let organization):
                    self.authViewModel.inviteStatus = "Joined \(organization.name) as \(invite.role.displayName)."
                    self.clearPendingInvite()
                    self.selectOrganization(organization)
                case .failure(let error):
                    self.authViewModel.errorMessage = error.localizedDescription
                    self.alertMessage = error.localizedDescription
                    self.refreshState(reason: "invite failed")
                }
            }
        }
    }

    private func restoreProjectSelectionIfPossible() {
        guard let organizationID = authViewModel.currentOrg?.id else {
            projectViewModel.deselectProject()
            return
        }

        let activeProjects = projectViewModel.accessibleProjects
            .filter { $0.organizationID == organizationID && $0.status == .active }

        if let selectedProject = projectViewModel.selectedProject,
           activeProjects.contains(where: { $0.id == selectedProject.id }) {
            localCache.storeLastSelectedProjectID(selectedProject.id.uuidString, for: organizationID)
            return
        }

        let storedProjectID = localCache.lastSelectedProjectID(for: organizationID) ?? selectionState.projectID
        if let storedProjectID,
           let restoredProject = activeProjects.first(where: { $0.id.uuidString == storedProjectID }) {
            projectViewModel.selectProject(restoredProject)
            return
        }

        if activeProjects.count == 1, let onlyProject = activeProjects.first {
            projectViewModel.selectProject(onlyProject)
            return
        }

        projectViewModel.deselectProject()
        selectionState.projectID = nil
        localCache.selectionState = selectionState
    }
}
