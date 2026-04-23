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

struct LegacyProjectPayloadCompactionResult: Equatable {
    var compactedKeys = 0
    var compactedFiles = 0
    var strippedInlineReceiptImages = 0
    var reclaimedBytes = 0

    mutating func merge(_ other: LegacyProjectPayloadCompactionResult) {
        compactedKeys += other.compactedKeys
        compactedFiles += other.compactedFiles
        strippedInlineReceiptImages += other.strippedInlineReceiptImages
        reclaimedBytes += other.reclaimedBytes
    }
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
        static let legacyProjects = "projects"
        static let legacyProjectsBackup = "projects_backup"
    }

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let documentsURL: URL?

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        documentsURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.documentsURL = documentsURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first

        var compactionResult = compactLegacyProjectPayloadsIfNeeded()
        compactionResult.merge(compactLegacyProjectFilesIfNeeded())

        if compactionResult.compactedKeys > 0 || compactionResult.compactedFiles > 0 {
            Logger.session.notice(
                "Compacted legacy project payloads before session restore [keys=\(compactionResult.compactedKeys, privacy: .public) files=\(compactionResult.compactedFiles, privacy: .public) images=\(compactionResult.strippedInlineReceiptImages, privacy: .public) reclaimedBytes=\(compactionResult.reclaimedBytes, privacy: .public)]"
            )
        }
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
            guard selectionState != newValue else {
                return
            }

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

    @discardableResult
    func compactLegacyProjectPayloadsIfNeeded() -> LegacyProjectPayloadCompactionResult {
        let candidateKeys = userDefaults.dictionaryRepresentation().keys.filter { key in
            Self.isLegacyProjectPayloadKey(key)
        }
        guard !candidateKeys.isEmpty else {
            return LegacyProjectPayloadCompactionResult()
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var result = LegacyProjectPayloadCompactionResult()

        for key in candidateKeys.sorted() {
            guard let data = userDefaults.data(forKey: key),
                  let compaction = compactedProjectPayloadData(from: data, encoder: encoder, decoder: decoder) else {
                continue
            }

            userDefaults.set(compaction.data, forKey: key)
            result.compactedKeys += 1
            result.strippedInlineReceiptImages += compaction.strippedInlinePayloads
            result.reclaimedBytes += max(data.count - compaction.data.count, 0)
        }

        return result
    }

    @discardableResult
    func compactLegacyProjectFilesIfNeeded() -> LegacyProjectPayloadCompactionResult {
        guard let documentsURL else {
            return LegacyProjectPayloadCompactionResult()
        }

        let candidateFiles = [
            documentsURL.appendingPathComponent("projects.json"),
            documentsURL.appendingPathComponent("offline_projects.json")
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var result = LegacyProjectPayloadCompactionResult()

        for fileURL in candidateFiles where fileManager.fileExists(atPath: fileURL.path) {
            guard let data = try? Data(contentsOf: fileURL),
                  let compaction = compactedProjectPayloadData(from: data, encoder: encoder, decoder: decoder) else {
                continue
            }

            do {
                try compaction.data.write(to: fileURL, options: .atomic)
            } catch {
                continue
            }

            result.compactedFiles += 1
            result.strippedInlineReceiptImages += compaction.strippedInlinePayloads
            result.reclaimedBytes += max(data.count - compaction.data.count, 0)
        }

        return result
    }

    private func compactedProjectPayloadData(
        from data: Data,
        encoder: JSONEncoder,
        decoder: JSONDecoder
    ) -> (data: Data, strippedInlinePayloads: Int)? {
        if let projects = try? decoder.decode([Project].self, from: data) {
            let compactedProjects = projects.map(\.persistenceSafeCopy)
            let strippedImages = projects.reduce(0) { count, project in
                count + project.inlineReceiptImageCount
            }

            if let compactedData = try? encoder.encode(compactedProjects),
               compactedData != data {
                return (compactedData, strippedImages)
            }
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let stripped = Self.strippingLegacyInlinePayloads(from: jsonObject)
        guard stripped.removedPayloads > 0,
              JSONSerialization.isValidJSONObject(stripped.value),
              let compactedData = try? JSONSerialization.data(withJSONObject: stripped.value),
              compactedData != data else {
            return nil
        }

        return (compactedData, stripped.removedPayloads)
    }

    private static func strippingLegacyInlinePayloads(from value: Any) -> (value: Any, removedPayloads: Int) {
        if let array = value as? [Any] {
            var removedPayloads = 0
            let strippedArray = array.map { element -> Any in
                let strippedElement = strippingLegacyInlinePayloads(from: element)
                removedPayloads += strippedElement.removedPayloads
                return strippedElement.value
            }
            return (strippedArray, removedPayloads)
        }

        if let dictionary = value as? [String: Any] {
            var removedPayloads = 0
            var strippedDictionary: [String: Any] = [:]

            for (key, childValue) in dictionary {
                if key == "receiptImageData" || key == "imageDatas" {
                    if let payloads = childValue as? [Any] {
                        removedPayloads += max(payloads.count, 1)
                    } else {
                        removedPayloads += 1
                    }
                    continue
                }

                let strippedChild = strippingLegacyInlinePayloads(from: childValue)
                strippedDictionary[key] = strippedChild.value
                removedPayloads += strippedChild.removedPayloads
            }

            return (strippedDictionary, removedPayloads)
        }

        return (value, 0)
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

    private static func isLegacyProjectPayloadKey(_ key: String) -> Bool {
        key.hasPrefix("projects_") || key == Key.legacyProjects || key == Key.legacyProjectsBackup
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
    private let shouldConnectProjectViewModel: Bool

    private var cancellables = Set<AnyCancellable>()
    private var hasConnected = false
    private var hasFinishedLaunch = false
    private var isProcessingInvite = false
    private var isChoosingOrganization = false
    private let releaseProfile = AppReleaseProfile.current

    init(
        authViewModel: AuthViewModel,
        projectViewModel: ProjectViewModel,
        localCache: LocalCacheStore = .shared,
        organizationRepository: OrganizationRepository? = nil,
        launchDelayNanoseconds: UInt64 = 900_000_000,
        shouldConnectProjectViewModel: Bool = true
    ) {
        self.authViewModel = authViewModel
        self.projectViewModel = projectViewModel
        self.localCache = localCache
        self.pendingInvite = localCache.pendingInvite
        self.selectionState = localCache.selectionState
        self.organizationRepository = organizationRepository ?? CloudKitOrganizationRepository(authViewModel: authViewModel)
        self.launchDelayNanoseconds = launchDelayNanoseconds
        self.shouldConnectProjectViewModel = shouldConnectProjectViewModel
    }

    func connectIfNeeded() {
        guard !hasConnected else { return }
        hasConnected = true

        if shouldConnectProjectViewModel {
            authViewModel.setProjectViewModel(projectViewModel)
        }
        bind()

        Task {
            if launchDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: launchDelayNanoseconds)
            }
            hasFinishedLaunch = true
            normalizeStateForReleaseProfile()
            refreshState(reason: "launch complete")
            processPendingInviteIfPossible()
            restoreProjectSelectionIfPossible()
        }
    }

    func handleIncomingURL(_ url: URL) {
        if releaseProfile.shouldHideCollaborationSurface {
            Logger.session.notice("Ignored incoming invite URL in fast-ship v1 release profile.")
            return
        }

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
        guard !releaseProfile.shouldHideCollaborationSurface else { return }
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
                self?.normalizeStateForReleaseProfile()
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
                self.normalizeStateForReleaseProfile()
                self.refreshState(reason: "organization changed")
                self.restoreProjectSelectionIfPossible()
            }
            .store(in: &cancellables)

        authViewModel.$showAdminInfoUpdate
            .sink { [weak self] _ in
                self?.normalizeStateForReleaseProfile()
                self?.refreshState(reason: "admin onboarding changed")
            }
            .store(in: &cancellables)

        authViewModel.$organizations
            .sink { [weak self] _ in
                self?.normalizeStateForReleaseProfile()
                self?.refreshState(reason: "organization list changed")
            }
            .store(in: &cancellables)

        authViewModel.$isLoadingOrgs
            .sink { [weak self] _ in
                self?.normalizeStateForReleaseProfile()
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
        normalizeStateForReleaseProfile()
        let nextState: AppSessionState

        if !hasFinishedLaunch {
            nextState = .launching
        } else if authViewModel.user == nil {
            nextState = .signedOut
        } else if !releaseProfile.shouldUseStreamlinedSessionRouting && (pendingInvite != nil || isProcessingInvite) {
            nextState = .processingInvite
        } else if !releaseProfile.shouldUseStreamlinedSessionRouting &&
                    authViewModel.showAdminInfoUpdate &&
                    authViewModel.currentOrg != nil {
            nextState = .adminOnboarding
        } else if authViewModel.currentOrg == nil || (!releaseProfile.shouldUseStreamlinedSessionRouting && isChoosingOrganization) {
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
        guard !releaseProfile.shouldHideCollaborationSurface else {
            clearPendingInviteIfNeededForReleaseProfile()
            return
        }

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

    private func normalizeStateForReleaseProfile() {
        guard releaseProfile.shouldUseStreamlinedSessionRouting else { return }

        isChoosingOrganization = false
        clearPendingInviteIfNeededForReleaseProfile()

        if authViewModel.showAdminInfoUpdate {
            authViewModel.dismissAdminInfoUpdate()
        }

        autoSelectCurrentOrganizationIfPossible()
    }

    private func clearPendingInviteIfNeededForReleaseProfile() {
        guard pendingInvite != nil || isProcessingInvite else { return }

        pendingInvite = nil
        localCache.clearPendingInvite()
        authViewModel.clearPendingInvite()
        isProcessingInvite = false
    }

    private func autoSelectCurrentOrganizationIfPossible() {
        guard authViewModel.user != nil,
              authViewModel.currentOrg == nil else {
            return
        }

        let availableOrganizations = authViewModel.userOrganizations.isEmpty
            ? authViewModel.organizations
            : authViewModel.userOrganizations

        guard !availableOrganizations.isEmpty else { return }

        let preferredOrganizationID = selectionState.organizationID ?? localCache.previousOrganizationID
        let resolvedOrganization = availableOrganizations.first(where: { $0.id == preferredOrganizationID }) ?? availableOrganizations.first

        guard let resolvedOrganization else { return }
        authViewModel.setCurrentOrganization(resolvedOrganization)
    }
}
