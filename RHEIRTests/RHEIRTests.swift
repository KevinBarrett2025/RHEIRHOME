import Foundation
import CloudKit
import Combine
import PDFKit
import Testing
@testable import RHEIR

private final class RecordingProjectRepository: ProjectRepository {
    private let lock = NSLock()
    private var _fetchedProjectsByOrganization: [String: [Project]] = [:]
    private var _savedProjects: [(project: Project, organizationID: String)] = []
    private var _savedAssignmentsByOrganization: [String: [String]] = [:]

    var fetchedProjectsByOrganization: [String: [Project]] {
        get { withLock { _fetchedProjectsByOrganization } }
        set { withLock { _fetchedProjectsByOrganization = newValue } }
    }

    var savedProjects: [(project: Project, organizationID: String)] {
        withLock { _savedProjects }
    }

    var savedAssignmentsByOrganization: [String: [String]] {
        get { withLock { _savedAssignmentsByOrganization } }
        set { withLock { _savedAssignmentsByOrganization = newValue } }
    }

    func fetchProjects(for organizationID: String) async throws -> [Project] {
        withLock { _fetchedProjectsByOrganization[organizationID] ?? [] }
    }

    func saveProject(_ project: Project, organizationID: String) async throws {
        withLock { _savedProjects.append((project, organizationID)) }
    }

    func saveProjectAssignments(_ projectIDs: [String], organizationID: String) async throws {
        withLock { _savedAssignmentsByOrganization[organizationID] = projectIDs }
    }

    func loadProjectAssignments(organizationID: String) async -> [String] {
        withLock { _savedAssignmentsByOrganization[organizationID] ?? [] }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class StubAuthService: AuthService {
    var currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: NSError(domain: "StubAuthService", code: -1)).eraseToAnyPublisher()
    }

    func login(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: NSError(domain: "StubAuthService", code: -1)).eraseToAnyPublisher()
    }

    func signInWithApple() -> AnyPublisher<User, Error> {
        Fail(error: NSError(domain: "StubAuthService", code: -1)).eraseToAnyPublisher()
    }

    func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func signOut() {
        currentUser = nil
    }
}

@MainActor
private final class RecordingSessionProjectViewModel: ProjectViewModel {
    var setCurrentOrganizationCalls: [String?] = []
    var zoneSetupCalls: [String] = []
    var organizationDidChangeCalls: [String?] = []
    var setCurrentUserRoleCalls: [(OrganizationRole, String)] = []

    init(repository: ProjectRepository = RecordingProjectRepository()) {
        super.init(
            offlineDataManager: OfflineDataManager(),
            projectRepository: repository
        )
    }

    override func setCurrentOrganization(_ organization: Organization?, role: TeamMemberRole? = nil) {
        setCurrentOrganizationCalls.append(organization?.id)
        currentOrganization = organization
        currentOrganizationRole = role
        currentOrganizationID = organization?.id
    }

    override func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        zoneSetupCalls.append(organizationID)
    }

    override func organizationDidChange(_ orgID: String?) async {
        organizationDidChangeCalls.append(orgID)
        if let orgID {
            zoneSetupCalls.append(orgID)
        }
    }

    override func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: String) {
        setCurrentUserRoleCalls.append((role, organizationID))
    }
}

@MainActor
private final class InterruptingOrganizationSyncProjectViewModel: ProjectViewModel {
    override func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        setCurrentOrganization(nil)
    }
}

private actor RecordingCloudKitProjectDatabase: CloudKitProjectDatabase {
    enum Failure: Error {
        case expectedFetchBeforeSave(String)
    }

    private var recordsByName: [String: CKRecord]
    private var fetchedRecordNames: [String] = []
    private var savedRecordNames: [String] = []
    private let requireFetchBeforeUpdatingExistingRecords: Bool

    init(
        existingRecords: [CKRecord] = [],
        requireFetchBeforeUpdatingExistingRecords: Bool = false
    ) {
        self.recordsByName = Dictionary(
            uniqueKeysWithValues: existingRecords.map { ($0.recordID.recordName, $0) }
        )
        self.requireFetchBeforeUpdatingExistingRecords = requireFetchBeforeUpdatingExistingRecords
    }

    func records(matching query: CKQuery) async throws -> [CKRecord] {
        Array(recordsByName.values)
    }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        fetchedRecordNames.append(recordID.recordName)

        guard let record = recordsByName[recordID.recordName] else {
            throw CKError(.unknownItem)
        }

        return record
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        let recordName = record.recordID.recordName

        if requireFetchBeforeUpdatingExistingRecords,
           recordsByName[recordName] != nil,
           !fetchedRecordNames.contains(recordName) {
            throw Failure.expectedFetchBeforeSave(recordName)
        }

        recordsByName[recordName] = record
        savedRecordNames.append(recordName)
        return record
    }

    func fetchedNames() -> [String] {
        fetchedRecordNames
    }

    func savedNames() -> [String] {
        savedRecordNames
    }

    func record(named recordName: String) -> CKRecord? {
        recordsByName[recordName]
    }
}

private func makeProject(
    organizationID: String,
    includeReceiptImageData: Bool = false,
    includeProgressLog: Bool = false
) -> Project {
    var project = Project(
        name: "Legacy Payload",
        client: "Client A",
        totalBudget: 42000,
        startDate: .now,
        endDate: .now.addingTimeInterval(86400),
        organizationID: organizationID
    )

    if includeReceiptImageData {
        var receipt = Receipt(
            vendor: "North Shore Supply",
            date: .now,
            amount: 199.95
        )
        receipt.setReceiptImageData(Data(repeating: 0xAA, count: 4096))
        project.receipts = [receipt]
    }

    if includeProgressLog {
        project.progressLogs = [
            ProgressLog(
                workDescription: "Legacy framing update",
                notes: "Wrapped beam header"
            )
        ]
    }

    return project
}

private func makeLegacyProjectPayload(
    organizationID: String,
    includeReceiptImageData: Bool = false,
    includeLegacyProgressImageDatas: Bool = false
) throws -> Data {
    let project = makeProject(
        organizationID: organizationID,
        includeReceiptImageData: includeReceiptImageData,
        includeProgressLog: includeLegacyProgressImageDatas
    )
    let baseData = try JSONEncoder().encode([project])

    guard includeLegacyProgressImageDatas else {
        return baseData
    }

    guard var payload = try JSONSerialization.jsonObject(with: baseData) as? [[String: Any]],
          var encodedProject = payload.first,
          var progressLogs = encodedProject["progressLogs"] as? [[String: Any]],
          !progressLogs.isEmpty else {
        return baseData
    }

    progressLogs[0]["imageDatas"] = ["legacy-inline-photo"]
    encodedProject["progressLogs"] = progressLogs
    payload[0] = encodedProject
    return try JSONSerialization.data(withJSONObject: payload)
}

private func makeUndecodableLegacyProjectPayload() throws -> Data {
    try JSONSerialization.data(
        withJSONObject: [
            [
                "name": "Legacy Project",
                "phone": "",
                "communications": [],
                "contingency": 0,
                "state": "",
                "street": "",
                "progressLogs": [
                    [
                        "id": UUID().uuidString,
                        "date": 777278742.152427,
                        "notes": "Legacy progress note",
                        "employeeIDs": [],
                        "imageDatas": ["legacy-inline-photo"]
                    ]
                ],
                "endDate": 779957128.401665,
                "changeOrders": [],
                "id": UUID().uuidString,
                "laborCost": 0,
                "taskTemplates": [],
                "city": "",
                "generalConditions": 0,
                "loggedHours": [],
                "totalBudget": 10000,
                "materialCost": 0,
                "notes": "",
                "client": "",
                "tasks": [],
                "status": "completed",
                "zip": "",
                "receipts": [],
                "startDate": 777278728.401662,
                "profit": 0,
                "spentContingency": 0
            ]
        ]
    )
}

struct RHEIRTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

struct SessionSupportTests {

    @Test
    func fastShipReleaseProfileIsDefault() {
        let profile = AppReleaseProfile(environment: [:])

        #expect(profile.mode == .fastShipV1)
        #expect(profile.mainTabs == [.projects, .receipts, .labor, .tasks])
        #expect(profile.shouldHideCompanySurface)
        #expect(profile.shouldHideAdvancedBudgetSurfaces)
        #expect(profile.shouldHideLegacyAIKeySettings)
    }

    @Test
    func legacyReleaseProfileRestoresDeferredSurfaces() {
        let profile = AppReleaseProfile(environment: [AppReleaseProfile.environmentKey: "legacy"])

        #expect(profile.mode == .legacy)
        #expect(profile.mainTabs == Tab.allCases)
        #expect(!profile.shouldHideCompanySurface)
        #expect(!profile.shouldHideAdvancedBudgetSurfaces)
        #expect(!profile.shouldHideLegacyAIKeySettings)
    }

    @Test
    func parsesCustomSchemeInvite() {
        let url = URL(string: "rheirhome://invite?orgID=org-123&name=RHEIR%20Builders&role=contractor&token=invite-token")!

        let invite = PendingInvite.parse(from: url)

        #expect(invite != nil)
        #expect(invite?.organizationId == "org-123")
        #expect(invite?.organizationName == "RHEIR Builders")
        #expect(invite?.role == .contractor)
        #expect(invite?.inviteToken == "invite-token")
        #expect(invite?.source == .customScheme)
    }

    @Test
    func parsesUniversalLinkInvite() {
        let url = URL(string: "https://app.rheirhome.com/invite?orgID=org-789&name=North%20Shore&role=viewer&token=abc123")!

        let invite = PendingInvite.parse(from: url)

        #expect(invite != nil)
        #expect(invite?.organizationId == "org-789")
        #expect(invite?.role == .viewer)
        #expect(invite?.source == .universalLink)
    }

    @Test
    func rejectsInviteWithoutOrganizationID() {
        let url = URL(string: "rheirhome://invite?name=Missing%20Org&token=abc123")!

        #expect(PendingInvite.parse(from: url) == nil)
    }

    @Test
    func migratesLegacySelectionAndInviteState() {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("org-legacy", forKey: "currentOrganizationID")
        defaults.set("org-legacy", forKey: "pending_invite_orgID")
        defaults.set("Legacy Builders", forKey: "pending_invite_orgName")
        defaults.set("legacy-token", forKey: "pending_invite_token")
        defaults.set(OrganizationRole.member.rawValue, forKey: "pending_invite_role")

        let store = LocalCacheStore(userDefaults: defaults)

        #expect(store.selectionState.organizationID == "org-legacy")
        #expect(store.pendingInvite?.organizationId == "org-legacy")
        #expect(store.pendingInvite?.organizationName == "Legacy Builders")
        #expect(store.pendingInvite?.inviteToken == "legacy-token")
        #expect(store.pendingInvite?.source == .legacyStorage)
    }

    @Test
    func persistsPerOrganizationProjectSelection() {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = LocalCacheStore(userDefaults: defaults)
        store.selectionState = SelectionState(organizationID: "org-1", projectID: "project-1")
        store.storeLastSelectedProjectID("project-1", for: "org-1")
        store.storeLastSelectedProjectID("project-2", for: "org-2")

        #expect(store.selectionState.organizationID == "org-1")
        #expect(store.lastSelectedProjectID(for: "org-1") == "project-1")
        #expect(store.lastSelectedProjectID(for: "org-2") == "project-2")
    }

    @Test
    func clearsKnownSessionKeys() {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = LocalCacheStore(userDefaults: defaults)
        store.selectionState = SelectionState(organizationID: "org-1", projectID: "project-1")
        store.previousOrganizationID = "org-0"
        store.pendingInvite = PendingInvite(
            organizationId: "org-1",
            organizationName: "Builders",
            inviteToken: "token-1",
            role: .member,
            source: .customScheme
        )
        store.storeLastSelectedProjectID("project-1", for: "org-1")
        store.storeAppleEmail("owner@example.com", for: "user-1")
        store.storeAppleDisplayName("Kevin Barrett", for: "user-1")

        store.clearAllKnownSessionKeys()

        #expect(store.selectionState.organizationID == nil)
        #expect(store.selectionState.projectID == nil)
        #expect(store.previousOrganizationID == nil)
        #expect(store.pendingInvite == nil)
        #expect(store.lastSelectedProjectID(for: "org-1") == nil)
        #expect(store.appleEmail(for: "user-1") == nil)
        #expect(store.appleDisplayName(for: "user-1") == nil)
    }

    @Test
    @MainActor
    func duplicateOrganizationActivationIsIgnored() async {
        let authViewModel = AuthViewModel(service: StubAuthService())
        let projectViewModel = RecordingSessionProjectViewModel()
        let organization = Organization(
            id: "org-duplicate",
            name: "North Shore Builders",
            members: ["member-1"],
            adminUserID: "admin-1"
        )

        authViewModel.organizationRoles[organization.id] = .admin
        authViewModel.setProjectViewModel(projectViewModel)

        authViewModel.setCurrentOrganization(organization)
        await Task.yield()
        authViewModel.setCurrentOrganization(organization)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(projectViewModel.setCurrentOrganizationCalls == [organization.id])
        #expect(projectViewModel.zoneSetupCalls == [organization.id])
        #expect(projectViewModel.organizationDidChangeCalls == [organization.id])
        #expect(projectViewModel.setCurrentUserRoleCalls.contains { role, organizationID in
            role == .admin && organizationID == organization.id
        })
        #expect(authViewModel.currentOrg?.id == organization.id)
    }

    @Test
    @MainActor
    func streamlinedSessionStoreResolvesOrganizationAfterLoadingCompletes() async {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let localCache = LocalCacheStore(userDefaults: defaults)
        let user = User(id: "fast-ship-user", email: "owner@rheirhome.com")
        let organization = Organization(
            id: "org-fast-ship",
            name: "Fast Ship Builders",
            members: [user.id],
            adminUserID: user.id
        )

        localCache.selectionState = SelectionState(organizationID: organization.id, projectID: nil)

        let authViewModel = AuthViewModel(service: StubAuthService())
        let projectViewModel = RecordingSessionProjectViewModel()
        let sessionStore = SessionStore(
            authViewModel: authViewModel,
            projectViewModel: projectViewModel,
            localCache: localCache,
            launchDelayNanoseconds: 0
        )

        sessionStore.connectIfNeeded()
        await Task.yield()

        authViewModel.isLoadingOrgs = true
        authViewModel.user = user
        authViewModel.organizations = [organization]
        authViewModel.userOrganizations = [organization]
        authViewModel.organizationRoles = [organization.id: .admin]

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(authViewModel.currentOrg == nil)
        #expect(projectViewModel.setCurrentOrganizationCalls.isEmpty)
        #expect(sessionStore.state == .launching)

        authViewModel.isLoadingOrgs = false

        try? await Task.sleep(nanoseconds: 150_000_000)

        #expect(authViewModel.currentOrg?.id == organization.id)
        #expect(projectViewModel.setCurrentOrganizationCalls == [organization.id])
        #expect(projectViewModel.zoneSetupCalls == [organization.id])
        #expect(projectViewModel.organizationDidChangeCalls == [organization.id])
        #expect(sessionStore.state == .ready)
    }

    @Test
    @MainActor
    func streamlinedSessionActivatesPersonalWorkspaceWhenNoCloudOrganizationsResolve() async {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let localCache = LocalCacheStore(userDefaults: defaults)
        let user = User(id: "fast-ship-no-org-user", email: "owner@rheirhome.com")
        let cachedWorkspaceID = "org-offline-personal"
        localCache.selectionState = SelectionState(organizationID: cachedWorkspaceID, projectID: nil)

        let authViewModel = AuthViewModel(service: StubAuthService())
        let projectViewModel = RecordingSessionProjectViewModel()
        let sessionStore = SessionStore(
            authViewModel: authViewModel,
            projectViewModel: projectViewModel,
            localCache: localCache,
            launchDelayNanoseconds: 0
        )

        sessionStore.connectIfNeeded()
        authViewModel.user = user
        authViewModel.organizations = []
        authViewModel.userOrganizations = []
        authViewModel.isLoadingOrgs = false

        try? await Task.sleep(nanoseconds: 150_000_000)

        #expect(sessionStore.state == .ready)
        #expect(authViewModel.currentOrg?.id == cachedWorkspaceID)
        #expect(authViewModel.currentOrg?.name == "Personal Workspace")
        #expect(authViewModel.needsOrganizationSetup == false)
        #expect(authViewModel.showOrganizationSetup == false)
        #expect(authViewModel.organizationRoles[cachedWorkspaceID] == .admin)
        #expect(projectViewModel.setCurrentOrganizationCalls == [cachedWorkspaceID])
        #expect(projectViewModel.zoneSetupCalls == [cachedWorkspaceID])
        #expect(projectViewModel.organizationDidChangeCalls == [cachedWorkspaceID])
    }

    @Test
    @MainActor
    func staleOrganizationSyncDoesNotRestoreProjectsAfterOrganizationClears() async {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let organization = Organization(
            id: "org-sync-stale",
            name: "North Shore Builders",
            members: ["member-1"],
            adminUserID: "admin-1"
        )
        let storedProject = Project(
            name: "Kitchen Remodel",
            client: "Taylor",
            totalBudget: 12000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: organization.id
        )

        let projectStore = ProjectStore(userDefaults: defaults)
        projectStore.saveProjects([storedProject], for: organization.id)

        let projectViewModel = InterruptingOrganizationSyncProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: projectStore
        )
        projectViewModel.setCurrentOrganization(organization)

        await projectViewModel.organizationDidChange()

        #expect(projectViewModel.currentOrganizationID == nil)
        #expect(projectViewModel.organizationProjects.isEmpty)
        #expect(projectViewModel.accessibleProjects.isEmpty)
        #expect(projectViewModel.selectedProject == nil)
    }

    @Test
    @MainActor
    func signOutClearsProjectViewModelOrganizationBeforeAsyncRefresh() async {
        let authViewModel = AuthViewModel(service: StubAuthService())
        let projectViewModel = RecordingSessionProjectViewModel()
        let organization = Organization(
            id: "org-signout-clear",
            name: "North Shore Builders",
            members: ["member-1"],
            adminUserID: "admin-1"
        )

        authViewModel.organizationRoles[organization.id] = .admin
        authViewModel.setProjectViewModel(projectViewModel)
        authViewModel.setCurrentOrganization(organization)
        try? await Task.sleep(nanoseconds: 100_000_000)

        authViewModel.signOut()
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(projectViewModel.setCurrentOrganizationCalls == [organization.id, nil])
        #expect(projectViewModel.organizationDidChangeCalls.count == 2)
        #expect(projectViewModel.organizationDidChangeCalls[0] == organization.id)
        #expect(projectViewModel.organizationDidChangeCalls[1] == nil)
        #expect(projectViewModel.currentOrganizationID == nil)
        #expect(authViewModel.currentOrg == nil)
    }

    @Test
    func compactsLegacyProjectPayloadsDuringInitialization() throws {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("org-legacy", forKey: "currentOrganizationID")

        let legacyPayload = try makeLegacyProjectPayload(
            organizationID: "org-legacy",
            includeReceiptImageData: true
        )
        defaults.set(legacyPayload, forKey: "projects_org-legacy")
        defaults.set(legacyPayload, forKey: "projects_backup")

        let store = LocalCacheStore(userDefaults: defaults)

        #expect(store.selectionState.organizationID == "org-legacy")

        let compactedOrgProjects = try JSONDecoder().decode(
            [Project].self,
            from: #require(defaults.data(forKey: "projects_org-legacy"))
        )
        let compactedBackupProjects = try JSONDecoder().decode(
            [Project].self,
            from: #require(defaults.data(forKey: "projects_backup"))
        )

        #expect(compactedOrgProjects.first?.receipts.first?.vendor == "North Shore Supply")
        #expect(compactedOrgProjects.first?.receipts.first?.receiptImageData == nil)
        #expect(compactedOrgProjects.first?.receipts.first?.receiptImageName != nil)
        #expect(compactedBackupProjects.first?.receipts.first?.receiptImageData == nil)
        #expect(compactedBackupProjects.first?.receipts.first?.receiptImageName != nil)
    }

    @Test
    func compactsLegacyProjectPayloadsWithLegacyProgressImagesDuringInitialization() throws {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("org-legacy", forKey: "currentOrganizationID")
        let legacyPayload = try makeUndecodableLegacyProjectPayload()
        defaults.set(legacyPayload, forKey: "projects_org-legacy")

        _ = LocalCacheStore(userDefaults: defaults)

        let compactedData = try #require(defaults.data(forKey: "projects_org-legacy"))
        let compactedPayload = try #require(String(data: compactedData, encoding: .utf8))
        #expect(!compactedPayload.contains("imageDatas"))
        #expect(compactedPayload.contains("\"Legacy progress note\""))
    }

    @Test
    func compactsLegacyProjectFilesDuringInitialization() throws {
        let suiteName = "SessionSupportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: documentsURL)
        }

        try makeUndecodableLegacyProjectPayload()
            .write(to: documentsURL.appendingPathComponent("projects.json"))
        try makeLegacyProjectPayload(
            organizationID: "org-legacy",
            includeReceiptImageData: true
        ).write(to: documentsURL.appendingPathComponent("offline_projects.json"))

        _ = LocalCacheStore(userDefaults: defaults, documentsURL: documentsURL)

        let compactedProjectsData = try Data(contentsOf: documentsURL.appendingPathComponent("projects.json"))
        let compactedOfflineData = try Data(contentsOf: documentsURL.appendingPathComponent("offline_projects.json"))
        let compactedProjectsPayload = try #require(String(data: compactedProjectsData, encoding: .utf8))
        let compactedOfflinePayload = try #require(String(data: compactedOfflineData, encoding: .utf8))

        #expect(!compactedProjectsPayload.contains("imageDatas"))
        #expect(!compactedOfflinePayload.contains("receiptImageData"))

        let compactedOfflineProjects = try JSONDecoder().decode([Project].self, from: compactedOfflineData)
        #expect(compactedProjectsPayload.contains("\"Legacy progress note\""))
        #expect(compactedOfflineProjects.first?.receipts.first?.vendor == "North Shore Supply")
        #expect(compactedOfflineProjects.first?.receipts.first?.receiptImageData == nil)
    }
}

struct BusinessWorkerRosterCacheTests {

    @Test
    func preservesCachedWorkersDuringTransientPartialRefresh() {
        let orgID = "org-workers"
        let kevin = TeamMember(
            id: UUID(uuidString: "AA111111-1111-1111-1111-111111111111")!,
            name: "Kevin Barrett",
            jobTitle: "Owner",
            organizationID: orgID
        )
        let rachel = TeamMember(
            id: UUID(uuidString: "BB222222-2222-2222-2222-222222222222")!,
            name: "Rachel",
            jobTitle: "Designer",
            organizationID: orgID
        )
        let newWorker = TeamMember(
            id: UUID(uuidString: "CC333333-3333-3333-3333-333333333333")!,
            name: "Jordan",
            jobTitle: "Plumber",
            organizationID: orgID
        )

        let reconciled = BusinessWorkerRosterCache.reconciled(
            cachedWorkers: [kevin, rachel],
            liveWorkers: [newWorker],
            allMembers: [newWorker]
        )

        #expect(reconciled.map(\.name) == ["Jordan", "Kevin Barrett", "Rachel"])
    }

    @Test
    func removesExplicitlyInactiveWorkersFromCache() {
        let orgID = "org-workers"
        let activeWorker = TeamMember(
            id: UUID(uuidString: "DD444444-4444-4444-4444-444444444444")!,
            name: "Active Worker",
            jobTitle: "Carpenter",
            organizationID: orgID
        )
        var terminatedWorker = TeamMember(
            id: UUID(uuidString: "EE555555-5555-5555-5555-555555555555")!,
            name: "Former Worker",
            jobTitle: "Painter",
            organizationID: orgID
        )
        terminatedWorker.terminate(reason: "Contract ended", type: .endOfContract)

        let reconciled = BusinessWorkerRosterCache.reconciled(
            cachedWorkers: [activeWorker, terminatedWorker],
            liveWorkers: [activeWorker],
            allMembers: [activeWorker, terminatedWorker]
        )

        #expect(reconciled.map(\.name) == ["Active Worker"])
    }
}

struct ProjectStoreTests {

    @Test
    func savesAndLoadsScopedProjects() {
        let suiteName = "ProjectStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ProjectStore(userDefaults: defaults)
        let orgID = "org-123"
        let matchingProject = Project(
            name: "Kitchen Remodel",
            client: "Client A",
            totalBudget: 120000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let foreignProject = Project(
            name: "Foreign Project",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-999"
        )

        store.saveProjects([matchingProject, foreignProject], for: orgID)
        let loadedProjects = store.loadProjects(for: orgID)

        #expect(loadedProjects.count == 1)
        #expect(loadedProjects.first?.id == matchingProject.id)
        #expect(loadedProjects.first?.organizationID == orgID)
    }

    @Test
    func savesAndLoadsOrganizationSnapshot() {
        let suiteName = "ProjectStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ProjectStore(userDefaults: defaults)
        let orgID = "org-456"
        let organization = Organization(id: orgID, name: "North Shore Builders")
        let teamMember = TeamMember(
            name: "Taylor Mason",
            email: "taylor@example.com",
            jobTitle: "Supervisor",
            organizationID: orgID
        )

        store.saveSnapshot(
            projects: [],
            organization: organization,
            teamMembers: [teamMember],
            for: orgID
        )

        let loadedOrganization = store.loadOrganization(for: orgID)
        let loadedTeamMembers = store.loadTeamMembers(for: orgID)

        #expect(loadedOrganization?.id == orgID)
        #expect(loadedOrganization?.name == "North Shore Builders")
        #expect(loadedTeamMembers.count == 1)
        #expect(loadedTeamMembers.first?.organizationID == orgID)
    }

    @Test
    func persistsProjectAssignmentsPerOrganization() {
        let suiteName = "ProjectStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ProjectStore(userDefaults: defaults)
        store.saveProjectAssignments(["project-1", "project-2"], for: "org-1")
        store.saveProjectAssignments(["project-9"], for: "org-2")

        #expect(store.loadProjectAssignments(for: "org-1") == ["project-1", "project-2"])
        #expect(store.loadProjectAssignments(for: "org-2") == ["project-9"])
    }

    @Test
    func stripsInlineReceiptImagesFromStoredProjects() {
        let suiteName = "ProjectStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ProjectStore(userDefaults: defaults)
        let orgID = "org-inline-receipts"
        var receipt = Receipt(
            vendor: "North Shore Supply",
            date: .now,
            amount: 128.42
        )
        receipt.setReceiptImageData(Data(repeating: 0xAB, count: 2048))

        var project = Project(
            name: "Inline Receipt Payload",
            client: "Client A",
            totalBudget: 120000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        project.receipts = [receipt]

        store.saveProjects([project], for: orgID)

        let loadedProjects = store.loadProjects(for: orgID)
        #expect(loadedProjects.count == 1)
        #expect(loadedProjects.first?.receipts.count == 1)
        #expect(loadedProjects.first?.receipts.first?.vendor == "North Shore Supply")
        #expect(loadedProjects.first?.receipts.first?.amount == 128.42)
        #expect(loadedProjects.first?.receipts.first?.receiptImageData == nil)
        #expect(loadedProjects.first?.receipts.first?.receiptImageName != nil)
    }
}

struct ProjectPersistencePayloadTests {

    @Test
    func stripsInlineReceiptImagesFromPersistenceSafeProjectPayload() throws {
        var receipt = Receipt(
            vendor: "Builder Depot",
            date: .now,
            amount: 64.99
        )
        receipt.setReceiptImageData(Data(repeating: 0xCD, count: 4096))

        var project = Project(
            name: "Cloud Payload",
            client: "Client A",
            totalBudget: 90000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-cloud-payload"
        )
        project.receipts = [receipt]

        let payload = try JSONEncoder().encode(project.persistenceSafeCopy)
        let decodedProject = try JSONDecoder().decode(Project.self, from: payload)
        #expect(decodedProject.receipts.count == 1)
        #expect(decodedProject.receipts.first?.vendor == "Builder Depot")
        #expect(decodedProject.receipts.first?.receiptImageData == nil)
        #expect(decodedProject.receipts.first?.receiptImageName != nil)
    }

    @Test
    func stripsInlineReceiptImagesFromOfflineProjectFilePayload() throws {
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: documentsURL)
        }

        let storage = OfflineStorageManager(documentsURL: documentsURL)
        let project = makeProject(
            organizationID: "org-offline-payload",
            includeReceiptImageData: true
        )

        #expect(storage.saveProjects([project]))

        let payloadURL = documentsURL.appendingPathComponent("offline_projects.json")
        let payloadData = try Data(contentsOf: payloadURL)
        let payloadString = try #require(String(data: payloadData, encoding: .utf8))
        #expect(!payloadString.contains("receiptImageData"))

        let decodedProjects = try JSONDecoder().decode([Project].self, from: payloadData)
        #expect(decodedProjects.count == 1)
        #expect(decodedProjects.first?.receipts.first?.vendor == "North Shore Supply")
        #expect(decodedProjects.first?.receipts.first?.receiptImageData == nil)
        #expect(decodedProjects.first?.receipts.first?.receiptImageName != nil)
    }

    @Test
    func normalizesDuplicateReceiptsBeforePersistence() throws {
        let duplicateReceiptID = UUID().uuidString
        var olderReceipt = Receipt(
            id: duplicateReceiptID,
            vendor: "North Shore Supply",
            date: .now,
            amount: 120.25
        )
        var newerReceipt = olderReceipt
        newerReceipt.amount = 236.24
        newerReceipt.notes = "Updated amount"
        olderReceipt.setReceiptImageData(Data(repeating: 0xAB, count: 512))

        var project = Project(
            name: "Duplicate Receipt Payload",
            client: "Client A",
            totalBudget: 90000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-duplicate-receipts"
        )
        project.receipts = [olderReceipt, newerReceipt]

        let payload = try JSONEncoder().encode(project.persistenceSafeCopy)
        let decodedProject = try JSONDecoder().decode(Project.self, from: payload)

        #expect(decodedProject.receipts.count == 1)
        #expect(decodedProject.receipts.first?.id == duplicateReceiptID)
        #expect(decodedProject.receipts.first?.amount == 236.24)
        #expect(decodedProject.receipts.first?.notes == "Updated amount")
        #expect(decodedProject.receipts.first?.receiptImageData == nil)
    }
}

struct ProjectOperationsFoundationTests {

    @Test
    func projectOperationsFieldsRoundTripAndDefaultForLegacyPayloads() throws {
        let projectID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1001")!
        let taskID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1002")!
        let milestoneID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1003")!
        let documentID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1004")!
        let checklistID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1005")!
        let shoppingID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1006")!
        let hiddenConditionID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1007")!
        let dueDate = Date(timeIntervalSince1970: 1_786_320_000)

        var task = ProjectTask(
            id: taskID,
            title: "Score rough electrical",
            dueDate: dueDate,
            category: .electrical,
            projectID: projectID
        )
        task.markCompleted(by: [], notes: "Inspection passed")

        var project = Project(
            id: projectID,
            name: "Operations Foundation Remodel",
            client: "Lisa Alexander",
            clientEmail: "lisa@example.com",
            clientPhone: "555-0101",
            clientAddress: "100 Main St, Lakewood, NJ 08701",
            totalBudget: 42_000,
            startDate: Date(timeIntervalSince1970: 1_786_060_800),
            endDate: Date(timeIntervalSince1970: 1_788_652_800),
            organizationID: "org-ops",
            clientProfile: ProjectClientProfile(
                name: "Lisa Alexander",
                email: "lisa@example.com",
                phone: "555-0101",
                billingAddress: "PO Box 7",
                jobSiteAddress: "100 Main St, Lakewood, NJ 08701",
                notes: "Prefers text updates"
            ),
            paymentMilestones: [
                ProjectPaymentMilestone(
                    id: milestoneID,
                    title: "Electrical rough-in payment",
                    amount: 8_500,
                    dueDate: dueDate,
                    trigger: .taskCompletion,
                    linkedTaskIDs: [taskID],
                    linkedDocumentIDs: [documentID]
                )
            ],
            projectDocuments: [
                ProjectDocument(
                    id: documentID,
                    title: "Signed construction agreement",
                    category: .contract,
                    fileName: "contract.pdf",
                    mimeType: "application/pdf",
                    storageKind: .externalURL,
                    storageIdentifier: "https://example.com/contract.pdf",
                    linkedMilestoneID: milestoneID
                )
            ],
            projectChecklists: [
                ProjectChecklist(
                    id: checklistID,
                    title: "Electrical tools",
                    category: .tools,
                    linkedTaskCategory: .electrical,
                    items: [
                        ProjectChecklistItem(title: "Voltage tester", isComplete: true),
                        ProjectChecklistItem(title: "Wire staples", quantity: 2, unit: "boxes")
                    ]
                )
            ],
            projectCalendarEvents: [
                ProjectCalendarEvent(
                    title: "Fixture delivery",
                    kind: .deliveryOrder,
                    startDate: dueDate.addingTimeInterval(86_400)
                )
            ],
            shoppingListItems: [
                ProjectShoppingListItem(
                    id: shoppingID,
                    title: "Wire staples",
                    storeName: "Supply House",
                    quantity: 2,
                    unit: "boxes"
                )
            ],
            hiddenConditions: [
                HiddenCondition(
                    id: hiddenConditionID,
                    title: "Hidden water damage",
                    internalNotes: "Vanity wall blocking is soft after demo.",
                    discoveredDate: dueDate,
                    severity: .high,
                    status: .approvalNeeded,
                    estimatedCostImpact: 1_250,
                    estimatedLaborHoursImpact: 6,
                    clientFacingSummary: "We found concealed water damage after opening the vanity wall."
                )
            ]
        )
        project.tasks = [task]

        let encoded = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: encoded)

        #expect(decoded.resolvedClientProfile.jobSiteAddress == "100 Main St, Lakewood, NJ 08701")
        #expect(decoded.paymentMilestonesReadyForPrompt(on: dueDate).map(\.title) == ["Electrical rough-in payment"])
        #expect(decoded.activeProjectDocuments.first?.category == .contract)
        #expect(decoded.activeProjectChecklists.first?.completionFraction == 0.5)
        #expect(decoded.activeProjectCalendarEvents.first?.kind == .deliveryOrder)
        #expect(decoded.activeShoppingListItems.first?.title == "Wire staples")
        #expect(decoded.activeHiddenConditions.first?.title == "Hidden water damage")
        #expect(decoded.activeHiddenConditions.first?.status == .approvalNeeded)
        #expect(decoded.projectTimelineEvents(on: dueDate).contains { $0.kind == .clientPaymentDue })

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "clientProfile")
        legacyObject.removeValue(forKey: "paymentMilestones")
        legacyObject.removeValue(forKey: "projectDocuments")
        legacyObject.removeValue(forKey: "projectChecklists")
        legacyObject.removeValue(forKey: "projectCalendarEvents")
        legacyObject.removeValue(forKey: "shoppingListItems")
        legacyObject.removeValue(forKey: "hiddenConditions")

        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try JSONDecoder().decode(Project.self, from: legacyData)

        #expect(legacyDecoded.clientProfile == nil)
        #expect(legacyDecoded.paymentMilestones == nil)
        #expect(legacyDecoded.resolvedClientProfile.name == "Lisa Alexander")
        #expect(legacyDecoded.activeProjectDocuments.isEmpty)
        #expect(legacyDecoded.activeProjectChecklists.isEmpty)
        #expect(legacyDecoded.activeProjectCalendarEvents.isEmpty)
        #expect(legacyDecoded.activeShoppingListItems.isEmpty)
        #expect(legacyDecoded.activeHiddenConditions.isEmpty)
    }

    @Test
    func projectOperationsMetadataAffectsProjectEquality() {
        let projectID = UUID(uuidString: "7E7D5745-C6F0-45CE-A3F6-4603EA7F1101")!
        let referenceDate = Date(timeIntervalSince1970: 1_786_060_800)
        let baseProject = Project(
            id: projectID,
            name: "Equality Remodel",
            client: "Lisa Alexander",
            totalBudget: 42_000,
            startDate: referenceDate,
            endDate: referenceDate.addingTimeInterval(604_800),
            organizationID: "org-ops",
            lastModifiedDate: referenceDate
        )

        var candidate = baseProject
        #expect(baseProject == candidate)

        candidate.clientProfile = ProjectClientProfile(name: "Lisa Alexander", notes: "Prefers text updates")
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.paymentMilestones = [
            ProjectPaymentMilestone(title: "Rough-in payment", amount: 8_500)
        ]
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.projectDocuments = [
            ProjectDocument(
                title: "Signed agreement",
                category: .contract,
                fileName: "agreement.pdf",
                mimeType: "application/pdf",
                storageKind: .externalURL,
                storageIdentifier: "https://example.com/agreement.pdf"
            )
        ]
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.projectChecklists = [
            ProjectChecklist(title: "Electrical prep", category: .tools)
        ]
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.projectCalendarEvents = [
            ProjectCalendarEvent(title: "Fixture delivery", kind: .deliveryOrder, startDate: referenceDate)
        ]
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.shoppingListItems = [
            ProjectShoppingListItem(title: "Wire staples")
        ]
        #expect(baseProject != candidate)

        candidate = baseProject
        candidate.hiddenConditions = [
            HiddenCondition(title: "Hidden water damage", status: .needsReview)
        ]
        #expect(baseProject != candidate)
    }

    @Test
    func receiptReturnMarkerDefaultsAndRoundTrips() throws {
        let item = ReceiptItem(
            name: "Wrong size fixture",
            quantity: 1,
            unitPrice: 118,
            totalPrice: 118,
            isMarkedForReturn: true
        )

        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ReceiptItem.self, from: encoded)
        #expect(decoded.isMarkedForReturn)
        #expect(decoded.returnExceptionQuantity == 1)
        #expect(decoded.hasReturnException)
        #expect(decoded.exceptionMetadata == nil)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "isMarkedForReturn")
        legacyObject.removeValue(forKey: "exceptionMetadata")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try JSONDecoder().decode(ReceiptItem.self, from: legacyData)
        #expect(!legacyDecoded.isMarkedForReturn)
        #expect(legacyDecoded.exceptionMetadata == nil)
        #expect(legacyDecoded.returnExceptionQuantity == 0)
        #expect(legacyDecoded.missingExceptionQuantity == 0)
        #expect(legacyDecoded.quantityToKeep == 1)
        #expect(!legacyDecoded.hasAnyLineItemException)
    }

    @Test
    func receiptItemExceptionMetadataRoundTrips() throws {
        let item = ReceiptItem(
            name: "Water supply line",
            quantity: 4,
            unitPrice: 12,
            totalPrice: 48,
            category: .plumbing,
            sku: "HD-1200",
            exceptionMetadata: ReceiptItemExceptionMetadata(
                returnQuantity: 2,
                missingQuantity: 1,
                status: .disputeNeeded,
                notes: "Two extras to return; one missing from pickup bag."
            )
        )

        #expect(!item.isMarkedForReturn)
        #expect(item.returnExceptionQuantity == 2)
        #expect(item.missingExceptionQuantity == 1)
        #expect(item.quantityToKeep == 1)
        #expect(item.hasReturnException)
        #expect(item.hasMissingException)
        #expect(item.hasAnyLineItemException)

        let decoded = try JSONDecoder().decode(
            ReceiptItem.self,
            from: JSONEncoder().encode(item)
        )

        #expect(decoded.exceptionMetadata?.returnQuantity == 2)
        #expect(decoded.exceptionMetadata?.missingQuantity == 1)
        #expect(decoded.exceptionMetadata?.status == .disputeNeeded)
        #expect(decoded.exceptionMetadata?.notes == "Two extras to return; one missing from pickup bag.")
        #expect(decoded.returnExceptionQuantity == 2)
        #expect(decoded.missingExceptionQuantity == 1)
        #expect(decoded.quantityToKeep == 1)
    }

    @Test
    func receiptItemExceptionQuantitiesNormalizeToLineItemQuantity() throws {
        let negativeItem = ReceiptItem(
            name: "Valve",
            quantity: 4,
            unitPrice: 9,
            totalPrice: 36,
            exceptionMetadata: ReceiptItemExceptionMetadata(
                returnQuantity: -2,
                missingQuantity: -1,
                status: .open
            )
        )

        #expect(negativeItem.returnExceptionQuantity == 0)
        #expect(negativeItem.missingExceptionQuantity == 0)
        #expect(negativeItem.quantityToKeep == 4)
        #expect(!negativeItem.hasAnyLineItemException)

        let oversizedItem = ReceiptItem(
            name: "Water supply line",
            quantity: 4,
            unitPrice: 12,
            totalPrice: 48,
            exceptionMetadata: ReceiptItemExceptionMetadata(
                returnQuantity: 3,
                missingQuantity: 3,
                status: .disputeNeeded,
                notes: "Pickup count did not match paid order."
            )
        )

        #expect(oversizedItem.returnExceptionQuantity == 3)
        #expect(oversizedItem.missingExceptionQuantity == 1)
        #expect(oversizedItem.quantityToKeep == 0)

        var rawObject = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(oversizedItem)
        ) as? [String: Any])
        rawObject["exceptionMetadata"] = [
            "returnQuantity": -4,
            "missingQuantity": 12,
            "status": ReceiptItemExceptionStatus.resolved.rawValue,
            "notes": "Resolved at service desk."
        ]
        let decoded = try JSONDecoder().decode(
            ReceiptItem.self,
            from: JSONSerialization.data(withJSONObject: rawObject)
        )

        #expect(decoded.returnExceptionQuantity == 0)
        #expect(decoded.missingExceptionQuantity == 4)
        #expect(decoded.quantityToKeep == 0)
        #expect(decoded.exceptionMetadata?.status == .resolved)
        #expect(decoded.exceptionMetadata?.notes == "Resolved at service desk.")
    }

    @Test
    func receiptItemExceptionsDoNotChangeReceiptTotalsOrBudgetMath() {
        var receipt = Receipt(
            id: "exception-source-receipt",
            vendor: "Home Depot",
            date: .now,
            amount: 105,
            category: .material,
            paymentMethod: "Card",
            taxAmount: 7
        )
        receipt.items = [
            ReceiptItem(
                name: "Water supply line",
                quantity: 4,
                unitPrice: 12,
                totalPrice: 48,
                category: .plumbing,
                exceptionMetadata: ReceiptItemExceptionMetadata(
                    returnQuantity: 2,
                    missingQuantity: 1,
                    status: .disputeNeeded
                )
            ),
            ReceiptItem(
                name: "Valve",
                quantity: 1,
                unitPrice: 50,
                totalPrice: 50,
                category: .plumbing
            )
        ]

        #expect(receipt.amount == 105)
        #expect(receipt.signedAmount == 105)
        #expect(receipt.scopedAmount(for: .plumbing) == 98)
        #expect(receipt.budgetScopedAmount(for: .plumbing) == 98)
        #expect(receipt.budgetScopedAmount(for: .general) == 0)
    }

    @Test
    func legacyProjectsDecodeWithoutReceiptExceptionReconciliations() throws {
        let project = Project(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891001")!,
            name: "Legacy Receipt Project",
            client: "Client A",
            totalBudget: 50_000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-receipt-reconciliation"
        )

        var rawObject = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(project)
        ) as? [String: Any])
        rawObject.removeValue(forKey: "receiptExceptionReconciliations")

        let decoded = try JSONDecoder().decode(
            Project.self,
            from: JSONSerialization.data(withJSONObject: rawObject)
        )

        #expect(decoded.receiptExceptionReconciliations == nil)
        #expect(decoded.id == project.id)
        #expect(decoded.receipts.isEmpty)
    }

    @Test
    func projectReceiptExceptionReconciliationsRoundTripAndAffectProjectEquality() throws {
        let itemID = UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891002")!
        let reconciliation = ReceiptExceptionReconciliation(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891003")!,
            sourceReceiptID: "source-receipt-100",
            sourceItemID: itemID,
            kind: .missingQuantity,
            quantity: 1,
            outcome: .storeCredit,
            refundReceiptID: "store-credit-100",
            resolvedDate: Date(timeIntervalSince1970: 1_747_300_000),
            notes: "Store issued a credit for missing pickup item.",
            createdAt: Date(timeIntervalSince1970: 1_747_260_000),
            updatedAt: Date(timeIntervalSince1970: 1_747_300_000)
        )

        var project = Project(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891004")!,
            name: "Reconciliation Project",
            client: "Client A",
            totalBudget: 50_000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-receipt-reconciliation"
        )
        var candidate = project
        candidate.receiptExceptionReconciliations = [reconciliation]
        #expect(project != candidate)

        project.receiptExceptionReconciliations = [reconciliation]
        let decoded = try JSONDecoder().decode(
            Project.self,
            from: JSONEncoder().encode(project)
        )

        #expect(decoded.receiptExceptionReconciliations == [reconciliation])
        #expect(decoded == project)
    }

    @Test
    func receiptExceptionReconciliationOutcomesRepresentManualResolutionPaths() {
        let sourceItemID = UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891005")!
        let outcomes: [ReceiptExceptionReconciliationOutcome] = [
            .refundReceipt,
            .storeCredit,
            .replacement,
            .disputeResolved,
            .noCredit,
            .other
        ]

        let reconciliations = outcomes.map { outcome in
            ReceiptExceptionReconciliation(
                sourceReceiptID: "source-receipt-200",
                sourceItemID: sourceItemID,
                kind: .returnQuantity,
                quantity: 1,
                outcome: outcome
            )
        }

        #expect(reconciliations.map(\.outcome) == outcomes)
        #expect(reconciliations.allSatisfy { $0.quantity == 1 })
    }

    @Test
    func receiptExceptionReconciliationQuantitiesNormalizeSafely() {
        let itemID = UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891006")!
        let negative = ReceiptExceptionReconciliation(
            sourceReceiptID: "source-receipt-300",
            sourceItemID: itemID,
            kind: .missingQuantity,
            quantity: -2,
            outcome: .disputeResolved
        )
        let oversized = ReceiptExceptionReconciliation(
            sourceReceiptID: "source-receipt-300",
            sourceItemID: itemID,
            kind: .returnQuantity,
            quantity: 8,
            outcome: .refundReceipt
        )

        #expect(negative.quantity == 0)
        #expect(negative.normalizedQuantity(for: 4) == 0)
        #expect(oversized.quantity == 8)
        #expect(oversized.normalizedQuantity(for: 4) == 4)
        #expect(oversized.normalized(for: 4).quantity == 4)
    }

    @Test
    func receiptExceptionReconciliationLinksExceptionToRefundWithoutChangingMoney() throws {
        var source = Receipt(
            id: "reconciliation-source",
            vendor: "Home Depot",
            date: Date(timeIntervalSince1970: 1_747_260_000),
            amount: 107,
            category: .material,
            paymentMethod: "Card",
            taxAmount: 7
        )
        let item = ReceiptItem(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891007")!,
            name: "Water supply line",
            quantity: 4,
            unitPrice: 25,
            totalPrice: 100,
            category: .plumbing,
            exceptionMetadata: ReceiptItemExceptionMetadata(
                returnQuantity: 2,
                missingQuantity: 1,
                status: .disputeNeeded,
                notes: "Pickup order count did not match paid receipt."
            )
        )
        source.items = [item]

        let refund = try #require(
            source.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 2)],
                existingReceipts: [],
                refundDate: Date(timeIntervalSince1970: 1_747_346_400),
                receiptNumber: "RET-300"
            )
        )
        let reconciliation = ReceiptExceptionReconciliation(
            sourceReceiptID: source.id,
            sourceItemID: item.id,
            kind: .returnQuantity,
            quantity: 2,
            outcome: .refundReceipt,
            refundReceiptID: refund.id,
            refundItemID: refund.items.first?.id,
            resolvedDate: refund.date,
            notes: "Refund receipt received for two extra supply lines."
        )
        var project = Project(
            name: "Money-Safe Reconciliation Project",
            client: "Client A",
            totalBudget: 50_000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-receipt-reconciliation"
        )
        project.receipts = [source, refund]
        project.receiptExceptionReconciliations = [reconciliation]

        #expect(project.receiptExceptionReconciliations?.first?.refundReceiptID == refund.id)
        #expect(project.receiptExceptionReconciliations?.first?.refundItemID == item.id)
        #expect(source.amount == 107)
        #expect(source.signedAmount == 107)
        #expect(source.scopedAmount(for: .plumbing) == 100)
        #expect(source.budgetScopedAmount(for: .material) == 100)
        #expect(refund.amount == 53.5)
        #expect(refund.signedAmount == -53.5)
        #expect(refund.scopedAmount(for: .plumbing) == -50)
        #expect(source.refundedAmount(in: project.receipts) == 53.5)
        #expect(source.remainingRefundableAmount(in: project.receipts) == 53.5)
    }
}

struct ProjectAssistantSnapshotTests {

    @Test
    func assistantSnapshotSeparatesDueWorkPrepReturnsAndRecentProgress() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let startOfToday = calendar.startOfDay(for: now)
        let projectID = UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890001")!

        let overdueTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890002")!,
            title: "Pull old vanity",
            dueDate: startOfToday.addingTimeInterval(-86_400),
            priority: .high,
            category: .plumbing,
            projectID: projectID
        )
        let dueTodayTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890003")!,
            title: "Confirm vanity delivery",
            dueDate: startOfToday.addingTimeInterval(15 * 3_600),
            priority: .medium,
            category: .materials,
            projectID: projectID
        )
        let upcomingTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890004")!,
            title: "Wire bath fan",
            dueDate: startOfToday.addingTimeInterval(2 * 86_400),
            priority: .medium,
            category: .electrical,
            projectID: projectID
        )
        var completedTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890005")!,
            title: "Measure bath footprint",
            priority: .medium,
            category: .general,
            projectID: projectID
        )
        completedTask.isCompleted = true
        completedTask.completedDate = startOfToday.addingTimeInterval(-12 * 3_600)

        var receipt = Receipt(
            id: "assistant-return-source",
            vendor: "Home Depot",
            date: startOfToday.addingTimeInterval(-2 * 86_400),
            amount: 118,
            category: .material,
            paymentMethod: "Card"
        )
        receipt.items = [
            ReceiptItem(
                id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890006")!,
                name: "Wrong size fixture",
                quantity: 1,
                unitPrice: 118,
                totalPrice: 118,
                isMarkedForReturn: true
            )
        ]

        var project = Project(
            id: projectID,
            name: "Assistant Remodel",
            client: "Client",
            totalBudget: 10_000,
            startDate: startOfToday,
            endDate: startOfToday.addingTimeInterval(14 * 86_400),
            organizationID: "org-assistant",
            paymentMilestones: [
                ProjectPaymentMilestone(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890007")!,
                    title: "Progress Draw",
                    amount: 2_500,
                    dueDate: startOfToday.addingTimeInterval(-3_600),
                    trigger: .date,
                    status: .planned
                )
            ],
            projectChecklists: [
                ProjectChecklist(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890008")!,
                    title: "Electrical Prep",
                    category: .tools,
                    linkedTaskCategory: .electrical,
                    items: [
                        ProjectChecklistItem(title: "Voltage tester"),
                        ProjectChecklistItem(title: "Wire staples", isComplete: true)
                    ]
                )
            ],
            projectCalendarEvents: [
                ProjectCalendarEvent(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72890009")!,
                    title: "Vanity pickup window",
                    kind: .pickupOrder,
                    startDate: startOfToday.addingTimeInterval(10 * 3_600),
                    status: .scheduled
                )
            ]
        )
        project.tasks = [overdueTask, dueTodayTask, upcomingTask, completedTask]
        project.receipts = [receipt]

        let snapshot = project.assistantSnapshot(on: now, calendar: calendar)

        #expect(overdueTask.isOverdue(on: now, calendar: calendar))
        #expect(!dueTodayTask.isOverdue(on: now, calendar: calendar))
        #expect(snapshot.overdueTasks.map(\.title) == ["Pull old vanity"])
        #expect(snapshot.dueTodayTasks.map(\.title) == ["Confirm vanity delivery"])
        #expect(snapshot.upcomingTasks.map(\.title) == ["Wire bath fan"])
        #expect(snapshot.dueTodayEvents.map(\.title) == ["Vanity pickup window"])
        #expect(snapshot.readyPaymentMilestones.map(\.title) == ["Progress Draw"])
        #expect(snapshot.checklistPrepItems.map(\.checklist.title) == ["Electrical Prep"])
        #expect(snapshot.markedReturnItems.map(\.itemName) == ["Wrong size fixture"])
        #expect(snapshot.recentCompletedTasks.map(\.title) == ["Measure bath footprint"])
        #expect(snapshot.openChecklistItemCount == 1)
        #expect(snapshot.actionCount == 6)
    }
}

struct ProjectOperationsSummaryTests {

    @Test
    func operationsSummaryCountsCurrentWorkWithoutMutatingProject() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let startOfToday = calendar.startOfDay(for: now)
        let projectID = UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891001")!

        let overdueTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891002")!,
            title: "Patch subfloor",
            dueDate: startOfToday.addingTimeInterval(-86_400),
            category: .general,
            projectID: projectID
        )
        let dueTodayTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891003")!,
            title: "Confirm tile pickup",
            dueDate: startOfToday.addingTimeInterval(12 * 3_600),
            category: .materials,
            projectID: projectID
        )
        var completedPastTask = ProjectTask(
            id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891004")!,
            title: "Measure floor",
            dueDate: startOfToday.addingTimeInterval(-2 * 86_400),
            category: .general,
            projectID: projectID
        )
        completedPastTask.isCompleted = true

        var receipt = Receipt(
            id: "operations-summary-return-source",
            vendor: "Supply House",
            date: startOfToday.addingTimeInterval(-86_400),
            amount: 95,
            category: .material,
            paymentMethod: "Card"
        )
        receipt.items = [
            ReceiptItem(
                id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891005")!,
                name: "Wrong transition strip",
                quantity: 1,
                unitPrice: 35,
                totalPrice: 35,
                isMarkedForReturn: true
            ),
            ReceiptItem(
                id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891006")!,
                name: "Extra tile spacers",
                quantity: 2,
                unitPrice: 12,
                totalPrice: 24,
                isMarkedForReturn: true
            ),
            ReceiptItem(
                id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891007")!,
                name: "Keep grout",
                quantity: 1,
                unitPrice: 36,
                totalPrice: 36
            )
        ]

        var project = Project(
            id: projectID,
            name: "Operations Summary Remodel",
            client: "Client",
            totalBudget: 10_000,
            startDate: startOfToday,
            endDate: startOfToday.addingTimeInterval(14 * 86_400),
            organizationID: "org-operations-summary",
            projectChecklists: [
                ProjectChecklist(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891008")!,
                    title: "Floor prep",
                    category: .quality,
                    items: [
                        ProjectChecklistItem(title: "Sweep subfloor", isComplete: true),
                        ProjectChecklistItem(title: "Prime patch")
                    ]
                ),
                ProjectChecklist(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891009")!,
                    title: "Closeout photos",
                    category: .closeout,
                    items: [
                        ProjectChecklistItem(title: "Take after photos", isComplete: true)
                    ]
                )
            ],
            projectCalendarEvents: [
                ProjectCalendarEvent(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891010")!,
                    title: "Inspection walk",
                    kind: .inspection,
                    startDate: startOfToday.addingTimeInterval(9 * 3_600),
                    status: .scheduled
                ),
                ProjectCalendarEvent(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891011")!,
                    title: "Tile delivery",
                    kind: .deliveryOrder,
                    startDate: startOfToday.addingTimeInterval(2 * 86_400),
                    status: .planned
                ),
                ProjectCalendarEvent(
                    id: UUID(uuidString: "413E5981-28C1-4E10-B43B-ABBB72891012")!,
                    title: "Cancelled pickup",
                    kind: .pickupOrder,
                    startDate: startOfToday.addingTimeInterval(86_400),
                    status: .cancelled
                )
            ],
            shoppingListItems: [
                ProjectShoppingListItem(title: "Tile spacers"),
                ProjectShoppingListItem(title: "Dust masks", isPurchased: true),
                ProjectShoppingListItem(title: "Contractor bags")
            ]
        )
        project.tasks = [overdueTask, dueTodayTask, completedPastTask]
        project.receipts = [receipt]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedBefore = try encoder.encode(project)
        let summary = project.operationsSummary(on: now, calendar: calendar)
        let encodedAfter = try encoder.encode(project)

        #expect(encodedBefore == encodedAfter)
        #expect(summary.openShoppingItemCount == 2)
        #expect(summary.completedShoppingItemCount == 1)
        #expect(summary.openChecklistCount == 1)
        #expect(summary.completedChecklistCount == 1)
        #expect(summary.openChecklistItemCount == 1)
        #expect(summary.completedChecklistItemCount == 2)
        #expect(summary.overdueTaskCount == 1)
        #expect(summary.dueTodayTaskCount == 1)
        #expect(!dueTodayTask.isOverdue(on: now, calendar: calendar))
        #expect(summary.dueTodayCalendarEventCount == 1)
        #expect(summary.upcomingCalendarEventCount == 1)
        #expect(summary.nextCalendarEvent?.title == "Inspection walk")
        #expect(summary.markedReturnItemCount == 2)
        #expect(summary.actionableItemCount == 8)
    }

    @Test
    func operationsSummaryDefaultsToSafeEmptyValues() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_057_600)
        let project = Project(
            name: "Empty Operations Summary",
            client: "Client",
            totalBudget: 10_000,
            startDate: now,
            endDate: now.addingTimeInterval(86_400),
            organizationID: "org-empty-operations-summary"
        )

        let summary = project.operationsSummary(on: now, calendar: calendar)

        #expect(summary.openShoppingItemCount == 0)
        #expect(summary.completedShoppingItemCount == 0)
        #expect(summary.openChecklistCount == 0)
        #expect(summary.completedChecklistCount == 0)
        #expect(summary.openChecklistItemCount == 0)
        #expect(summary.completedChecklistItemCount == 0)
        #expect(summary.overdueTaskCount == 0)
        #expect(summary.dueTodayTaskCount == 0)
        #expect(summary.dueTodayCalendarEventCount == 0)
        #expect(summary.upcomingCalendarEventCount == 0)
        #expect(summary.nextCalendarEvent == nil)
        #expect(summary.markedReturnItemCount == 0)
        #expect(summary.actionableItemCount == 0)
    }
}

struct CloudKitProjectRepositoryTests {

    @Test
    func fetchesExistingProjectRecordBeforeSavingUpdate() async throws {
        let organizationID = "org-cloudkit-update"
        let projectID = UUID()
        let recordID = CKRecord.ID(recordName: "project_\(projectID.uuidString)")
        let existingRecord = CKRecord(recordType: "Project", recordID: recordID)
        existingRecord["organizationID"] = organizationID as CKRecordValue
        existingRecord["name"] = "Old Name" as CKRecordValue

        let database = RecordingCloudKitProjectDatabase(
            existingRecords: [existingRecord],
            requireFetchBeforeUpdatingExistingRecords: true
        )
        let repository = CloudKitProjectRepository(database: database)
        let project = Project(
            id: projectID,
            name: "Updated Name",
            client: "Client A",
            totalBudget: 120000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: organizationID
        )

        try await repository.saveProject(project, organizationID: organizationID)

        let savedRecord = await database.record(named: recordID.recordName)
        #expect(await database.fetchedNames() == [recordID.recordName])
        #expect(await database.savedNames() == [recordID.recordName])
        #expect(savedRecord?["name"] as? String == "Updated Name")
    }

    @Test
    func fetchesExistingAssignmentRecordBeforeSavingUpdate() async throws {
        let organizationID = "org-cloudkit-assignments"
        let recordID = CKRecord.ID(recordName: "project_assignments_\(organizationID)")
        let existingRecord = CKRecord(recordType: "ProjectAssignments", recordID: recordID)
        existingRecord["organizationID"] = organizationID as CKRecordValue
        existingRecord["assignedProjectIDs"] = ["existing-project"] as CKRecordValue

        let database = RecordingCloudKitProjectDatabase(
            existingRecords: [existingRecord],
            requireFetchBeforeUpdatingExistingRecords: true
        )
        let repository = CloudKitProjectRepository(database: database)

        try await repository.saveProjectAssignments(
            ["existing-project", "new-project"],
            organizationID: organizationID
        )

        let savedRecord = await database.record(named: recordID.recordName)
        #expect(await database.fetchedNames() == [recordID.recordName])
        #expect(await database.savedNames() == [recordID.recordName])
        #expect(savedRecord?["assignedProjectIDs"] as? [String] == ["existing-project", "new-project"])
    }
}

struct OrganizationProjectSyncStoreTests {

    @Test
    func refreshesOrganizationProjectsFromAllAndCachedSources() {
        let orgID = "org-sync"
        let currentProject = Project(
            name: "Current Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let cachedOnlyProject = Project(
            name: "Cached Only",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let foreignProject = Project(
            name: "Foreign Project",
            client: "Client C",
            totalBudget: 25000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-foreign"
        )

        let syncStore = OrganizationProjectSyncStore(
            projectStore: ProjectStore(),
            projectRepository: RecordingProjectRepository()
        )

        let result = syncStore.refreshedProjects(
            allProjects: [currentProject, foreignProject],
            cachedOrganizationProjects: [cachedOnlyProject, currentProject],
            organizationID: orgID
        )

        #expect(result.organizationProjects.map(\.id) == [currentProject.id, cachedOnlyProject.id])
        #expect(result.accessibleProjects.map(\.id) == [currentProject.id, cachedOnlyProject.id])
    }

    @Test
    func mergesCloudKitProjectsWithLocalFallbackPrecedence() {
        let orgID = "org-cloudkit"
        let projectID = UUID()
        let cloudKitProject = Project(
            id: projectID,
            name: "CloudKit Version",
            client: "Client A",
            totalBudget: 120000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let localStaleProject = Project(
            id: projectID,
            name: "Local Version",
            client: "Client A",
            totalBudget: 90000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let localOnlyProject = Project(
            name: "Local Only",
            client: "Client B",
            totalBudget: 45000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let syncStore = OrganizationProjectSyncStore(
            projectStore: ProjectStore(),
            projectRepository: RecordingProjectRepository()
        )

        let result = syncStore.mergeCloudKitProjects(
            [cloudKitProject],
            with: [localStaleProject, localOnlyProject]
        )

        #expect(result.projects.map(\.name) == ["CloudKit Version", "Local Only"])
        #expect(result.localFallbackCount == 1)
    }

    @Test
    func savesSnapshotAndDelegatesRepositoryPersistence() async throws {
        let suiteName = "OrganizationProjectSyncStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = "org-persist"
        let organization = Organization(id: orgID, name: "North Shore Builders")
        let teamMember = TeamMember(
            name: "Taylor Mason",
            email: "taylor@example.com",
            jobTitle: "Supervisor",
            organizationID: orgID
        )
        let project = Project(
            name: "Persistent Project",
            client: "Client A",
            totalBudget: 110000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let projectStore = ProjectStore(userDefaults: defaults)
        let repository = RecordingProjectRepository()
        let syncStore = OrganizationProjectSyncStore(
            projectStore: projectStore,
            projectRepository: repository
        )

        syncStore.saveSnapshot(
            projects: [project],
            organization: organization,
            teamMembers: [teamMember],
            for: orgID
        )
        try await syncStore.saveProjectToCloudKit(project, organizationID: orgID)
        try await syncStore.saveProjectAssignmentsToCloudKit([project.id.uuidString], organizationID: orgID)

        #expect(projectStore.loadProjects(for: orgID).map(\.id) == [project.id])
        #expect(projectStore.loadOrganization(for: orgID)?.id == orgID)
        #expect(projectStore.loadTeamMembers(for: orgID).map(\.id) == [teamMember.id])
        #expect(repository.savedProjects.count == 1)
        #expect(repository.savedProjects.first?.organizationID == orgID)
        #expect(repository.savedAssignmentsByOrganization[orgID] == [project.id.uuidString])
        #expect(await syncStore.loadProjectAssignmentsFromCloudKit(organizationID: orgID) == [project.id.uuidString])
    }
}

struct ProjectAccessStoreTests {

    @Test
    func filtersAssignedProjectsAndClearsUnavailableSelection() {
        let orgID = "org-assignments"
        let allowedProject = Project(
            name: "Allowed Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let blockedProject = Project(
            name: "Blocked Project",
            client: "Client B",
            totalBudget: 60000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let store = ProjectAccessStore()
        let result = store.assignmentState(
            projectIDs: [allowedProject.id.uuidString],
            organizationProjects: [allowedProject, blockedProject],
            selectedProject: blockedProject
        )

        #expect(result.accessState.accessibleProjects.map(\.id) == [allowedProject.id])
        #expect(result.accessState.selectedProject == nil)
        #expect(result.restrictedCount == 1)
        #expect(result.appliesRestrictions)
    }

    @Test
    func normalizesDuplicateProjectsBeforeApplyingSelection() {
        let orgID = "org-project-access"
        let selectedID = UUID()
        let primaryProject = Project(
            id: selectedID,
            name: "Primary Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let duplicateProject = Project(
            id: selectedID,
            name: "Duplicate Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let secondaryProject = Project(
            name: "Secondary Project",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let store = ProjectAccessStore()
        let result = store.unrestrictedState(
            organizationProjects: [primaryProject, duplicateProject, secondaryProject],
            selectedProject: duplicateProject
        )

        #expect(result.accessibleProjects.map(\.id) == [selectedID, secondaryProject.id])
        #expect(result.selectedProject?.id == selectedID)
        #expect(result.duplicateCount == 1)
    }

    @Test
    func hydratesSelectedProjectFromAccessibleProjectPayload() {
        let orgID = "org-project-restore"
        let selectedID = UUID()
        let restoredShell = Project(
            id: selectedID,
            name: "Restored Shell",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        var loadedProject = restoredShell
        loadedProject.receipts = [
            Receipt(
                id: "persisted-receipt-1",
                vendor: "Home Depot",
                date: .now,
                amount: 59.71,
                category: .material,
                paymentMethod: "Credit Card"
            )
        ]

        let store = ProjectAccessStore()
        let result = store.unrestrictedState(
            organizationProjects: [loadedProject],
            selectedProject: restoredShell
        )

        #expect(result.selectedProject?.id == selectedID)
        #expect(result.selectedProject?.receipts.map(\.id) == ["persisted-receipt-1"])
        #expect(result.selectedProject?.receipts.first?.amount == 59.71)
    }
}

@MainActor
struct ProjectMutationPropagationTests {

    @Test
    func updateProjectPropagatesToVisibleCollectionsAndDerivedSnapshots() async {
        let suiteName = "ProjectMutationPropagationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let repository = RecordingProjectRepository()
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: projectStore,
            projectRepository: repository
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let teamMember = TeamMember(
            name: "Alice Mason",
            email: "alice@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: orgID
        )
        viewModel.teamMembers = [teamMember]
        viewModel.updateTeamMemberCaches()

        var project = Project(
            name: "Kitchen Remodel",
            client: "Client A",
            totalBudget: 42000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        let start = Date()
        let receipt = Receipt(
            id: "receipt-propagation",
            vendor: "Home Depot",
            date: start,
            amount: 120,
            category: .material,
            paymentMethod: "Credit Card"
        )
        let workHour = WorkHour(
            date: start,
            startTime: start,
            endTime: start.addingTimeInterval(7_200),
            lunchStart: nil,
            lunchEnd: nil,
            employee: teamMember.name,
            employeeID: teamMember.id,
            rate: 50,
            category: "Labor",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        let task = ProjectTask(
            title: "Frame wall",
            projectID: project.id
        )

        project.receipts = [receipt]
        project.loggedHours = [workHour]
        project.tasks = [task]

        let previousMutationVersion = viewModel.projectMutationVersion
        await viewModel.updateProject(project)

        #expect(viewModel.projectMutationVersion != previousMutationVersion)
        #expect(viewModel.lastProjectMutationReason == "update project")
        #expect(viewModel.selectedProject?.receipts.map(\.id) == [receipt.id])
        #expect(viewModel.organizationProjects.first(where: { $0.id == project.id })?.tasks.map(\.id) == [task.id])
        #expect(viewModel.projects.first(where: { $0.id == project.id })?.loggedHours.map(\.id) == [workHour.id])
        #expect(viewModel.accessibleProjects.first(where: { $0.id == project.id })?.receipts.map(\.id) == [receipt.id])
        #expect(viewModel.projectTotalHours == 2)
        #expect(viewModel.projectUnpaidAmount == 100)
        #expect(repository.savedProjects.first?.project.receipts.map(\.id) == [receipt.id])
        #expect(projectStore.loadProjects(for: orgID).first?.tasks.map(\.id) == [task.id])
    }

    @Test
    func operationsMetadataHelpersPersistAndReloadProjectState() async throws {
        let suiteName = "ProjectOperationsMutationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let repository = RecordingProjectRepository()
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(networkMonitoringEnabled: false),
            projectStore: projectStore,
            projectRepository: repository
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let projectID = UUID()
        let baselineDate = Date(timeIntervalSince1970: 1_714_030_000)
        let paymentMilestone = ProjectPaymentMilestone(title: "Deposit", amount: 2_000)
        let projectDocument = ProjectDocument(
            title: "Signed agreement",
            category: .contract,
            fileName: "agreement.pdf",
            mimeType: "application/pdf",
            storageKind: .externalURL,
            storageIdentifier: "https://example.com/agreement.pdf"
        )
        let project = Project(
            id: projectID,
            name: "Operations Mutation Project",
            client: "Client H",
            totalBudget: 34_000,
            startDate: baselineDate,
            endDate: baselineDate.addingTimeInterval(86_400),
            organizationID: orgID,
            lastModifiedDate: baselineDate,
            clientProfile: ProjectClientProfile(name: "Client H", notes: "Keep access note"),
            paymentMilestones: [paymentMilestone],
            projectDocuments: [projectDocument]
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        let shoppingID = UUID()
        let secondShoppingID = UUID()
        await viewModel.addOrUpdateShoppingListItem(
            ProjectShoppingListItem(id: shoppingID, title: "Contractor bags"),
            in: projectID
        )
        let shoppingModifiedDate = try #require(viewModel.selectedProject?.lastModifiedDate)
        #expect(shoppingModifiedDate > baselineDate)
        #expect(viewModel.selectedProject?.shoppingListItems?.map(\.title) == ["Contractor bags"])
        #expect(projectStore.loadProjects(for: orgID).first?.shoppingListItems?.map(\.title) == ["Contractor bags"])

        await viewModel.addOrUpdateShoppingListItem(
            ProjectShoppingListItem(id: shoppingID, title: "Heavy contractor bags", quantity: 2, unit: "boxes"),
            in: projectID
        )
        await viewModel.addOrUpdateShoppingListItem(
            ProjectShoppingListItem(id: secondShoppingID, title: "Dust masks"),
            in: projectID
        )

        let checklistID = UUID()
        await viewModel.addOrUpdateProjectChecklist(
            ProjectChecklist(
                id: checklistID,
                title: "Demo prep",
                category: .safety,
                items: [ProjectChecklistItem(title: "Shut off water")]
            ),
            in: projectID
        )
        await viewModel.addOrUpdateProjectChecklist(
            ProjectChecklist(
                id: checklistID,
                title: "Demo prep",
                category: .safety,
                items: [
                    ProjectChecklistItem(title: "Shut off water", isComplete: true),
                    ProjectChecklistItem(title: "Protect flooring")
                ]
            ),
            in: projectID
        )

        let eventID = UUID()
        await viewModel.addOrUpdateProjectCalendarEvent(
            ProjectCalendarEvent(
                id: eventID,
                title: "Dumpster delivery",
                kind: .deliveryOrder,
                startDate: baselineDate.addingTimeInterval(86_400)
            ),
            in: projectID
        )
        await viewModel.addOrUpdateProjectCalendarEvent(
            ProjectCalendarEvent(
                id: eventID,
                title: "Fixture delivery",
                kind: .deliveryOrder,
                startDate: baselineDate.addingTimeInterval(172_800)
            ),
            in: projectID
        )

        let hiddenConditionID = UUID()
        await viewModel.addOrUpdateHiddenCondition(
            HiddenCondition(
                id: hiddenConditionID,
                title: "Water damage behind vanity",
                internalNotes: "Soft drywall found during demo.",
                discoveredDate: baselineDate,
                severity: .high,
                status: .needsReview,
                estimatedCostImpact: 750,
                estimatedLaborHoursImpact: 4,
                clientFacingSummary: "Demo exposed hidden water damage that should be repaired before finishes go in."
            ),
            in: projectID
        )
        await viewModel.addOrUpdateHiddenCondition(
            HiddenCondition(
                id: hiddenConditionID,
                title: "Water damage behind vanity wall",
                internalNotes: "Soft drywall and blocking found during demo.",
                discoveredDate: baselineDate,
                severity: .high,
                status: .approvalNeeded,
                estimatedCostImpact: 1_250,
                estimatedLaborHoursImpact: 6,
                clientFacingSummary: "Demo exposed hidden water damage behind the vanity wall."
            ),
            in: projectID
        )

        let reloadedProject = try #require(projectStore.loadProjects(for: orgID).first { $0.id == projectID })
        #expect(reloadedProject.shoppingListItems?.map(\.title) == ["Heavy contractor bags", "Dust masks"])
        #expect(reloadedProject.shoppingListItems?.first?.quantity == 2)
        #expect(reloadedProject.projectChecklists?.first?.items.map(\.title) == ["Shut off water", "Protect flooring"])
        #expect(reloadedProject.projectChecklists?.first?.completionFraction == 0.5)
        #expect(reloadedProject.projectCalendarEvents?.first?.title == "Fixture delivery")
        #expect(reloadedProject.hiddenConditions?.first?.title == "Water damage behind vanity wall")
        #expect(reloadedProject.hiddenConditions?.first?.status == .approvalNeeded)
        #expect(reloadedProject.hiddenConditions?.first?.estimatedCostImpact == 1_250)
        #expect(reloadedProject.hiddenConditions?.first?.estimatedLaborHoursImpact == 6)
        #expect(reloadedProject.lastModifiedDate > baselineDate)
        #expect(viewModel.accessibleProjects.first?.shoppingListItems?.count == 2)
        #expect(viewModel.selectedProject?.projectChecklists?.first?.items.count == 2)
        #expect(viewModel.selectedProject?.hiddenConditions?.first?.clientFacingSummary == "Demo exposed hidden water damage behind the vanity wall.")
        #expect(repository.savedProjects.last?.project.projectCalendarEvents?.first?.title == "Fixture delivery")
        #expect(repository.savedProjects.last?.project.hiddenConditions?.first?.title == "Water damage behind vanity wall")

        await viewModel.removeShoppingListItem(shoppingID, from: projectID)
        await viewModel.removeProjectChecklist(checklistID, from: projectID)
        await viewModel.removeProjectCalendarEvent(eventID, from: projectID)

        let afterRemovalProject = try #require(projectStore.loadProjects(for: orgID).first { $0.id == projectID })
        #expect(afterRemovalProject.shoppingListItems?.map(\.title) == ["Dust masks"])
        #expect(afterRemovalProject.projectChecklists?.isEmpty == true)
        #expect(afterRemovalProject.projectCalendarEvents?.isEmpty == true)
        #expect(afterRemovalProject.clientProfile?.notes == "Keep access note")
        #expect(afterRemovalProject.paymentMilestones?.first == paymentMilestone)
        #expect(afterRemovalProject.projectDocuments?.first == projectDocument)
        #expect(afterRemovalProject.hiddenConditions?.first?.title == "Water damage behind vanity wall")
        #expect(afterRemovalProject.lastModifiedDate > baselineDate)
    }

    @Test
    func deleteProjectClearsVisibleCollectionsAndSelection() async {
        let suiteName = "ProjectMutationDeletionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: ProjectStore(userDefaults: defaults),
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let project = Project(
            name: "Bathroom Remodel",
            client: "Client B",
            totalBudget: 18000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        await viewModel.deleteProject(project)

        #expect(viewModel.selectedProject == nil)
        #expect(viewModel.organizationProjects.isEmpty)
        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.accessibleProjects.isEmpty)
        #expect(viewModel.lastProjectMutationReason == "delete project")
    }

    @Test
    func completingSelectedProjectPreservesItAsCompletedAndClearsWorkContext() async {
        let suiteName = "ProjectCompletionVisibilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(networkMonitoringEnabled: false),
            projectStore: projectStore,
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        var project = Project(
            name: "Closed Kitchen",
            client: "Client C",
            totalBudget: 24000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        project.status = .completed
        await viewModel.updateProject(project)

        #expect(viewModel.selectedProject == nil)
        #expect(viewModel.activeProjects.isEmpty)
        #expect(viewModel.completedProjects.map(\.id) == [project.id])
        #expect(viewModel.accessibleProjects.first?.status == .completed)
        #expect(projectStore.loadProjects(for: orgID).first?.status == .completed)
    }

    @Test
    func reopeningCompletedProjectReturnsItToActiveWorkContextWithDataIntact() async {
        let suiteName = "ProjectReopenVisibilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let repository = RecordingProjectRepository()
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: projectStore,
            projectRepository: repository
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let receipt = Receipt(
            id: "reopened-receipt",
            vendor: "Lumber Yard",
            date: .now,
            amount: 812.44,
            category: .material,
            paymentMethod: "Card"
        )
        let task = ProjectTask(title: "Final punch list", projectID: UUID())
        var project = Project(
            id: task.projectID,
            name: "Closed Deck",
            client: "Client D",
            totalBudget: 12000,
            startDate: .now,
            endDate: .now.addingTimeInterval(-86400),
            status: .completed,
            organizationID: orgID
        )
        project.receipts = [receipt]
        project.tasks = [task]
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.updateAccessibleProjects()

        let reopenedProject = await viewModel.reopenProject(project)

        #expect(reopenedProject?.status == .active)
        #expect(viewModel.selectedProject?.id == project.id)
        #expect(viewModel.activeProjects.map(\.id) == [project.id])
        #expect(viewModel.completedProjects.isEmpty)
        #expect(viewModel.selectedProject?.receipts.map(\.id) == [receipt.id])
        #expect(viewModel.selectedProject?.tasks.map(\.id) == [task.id])
        #expect(projectStore.loadProjects(for: orgID).first?.status == .active)
        #expect(repository.savedProjects.first?.project.status == .active)
    }

    @Test
    func projectRefreshTracksSameIDTaskAndLaborContentChanges() {
        let orgID = UUID().uuidString
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(networkMonitoringEnabled: false),
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let projectID = UUID()
        let modifiedDate = Date(timeIntervalSince1970: 1_714_000_000)
        let workDate = Date(timeIntervalSince1970: 1_714_003_600)
        let task = ProjectTask(
            id: UUID(),
            title: "Rough plumbing",
            description: "Before photo scope",
            dueDate: workDate,
            priority: .medium,
            category: .general,
            projectID: projectID,
            updatedAt: modifiedDate
        )
        let workHour = WorkHour(
            id: UUID(),
            date: workDate,
            startTime: workDate,
            endTime: workDate.addingTimeInterval(3_600),
            lunchStart: nil,
            lunchEnd: nil,
            employee: "Alex Rivera",
            employeeID: UUID(),
            rate: 45,
            category: "Demo",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        var project = Project(
            id: projectID,
            name: "Trust Refresh Project",
            client: "Client E",
            totalBudget: 21000,
            startDate: workDate,
            endDate: workDate.addingTimeInterval(86_400),
            organizationID: orgID,
            lastModifiedDate: modifiedDate
        )
        project.tasks = [task]
        project.loggedHours = [workHour]
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        var refreshedTask = task
        refreshedTask.title = "Finish plumbing"
        refreshedTask.description = "After proof attached"
        refreshedTask.completionPhotoIDs = [UUID()]
        refreshedTask.updatedAt = modifiedDate

        var refreshedHour = workHour
        refreshedHour.rate = 60
        refreshedHour.recordPayment(
            amount: 30,
            method: "Check",
            reference: "1004",
            note: "Partial progress payment",
            paidAt: workDate.addingTimeInterval(7_200)
        )

        var refreshedProject = project
        refreshedProject.tasks = [refreshedTask]
        refreshedProject.loggedHours = [refreshedHour]
        refreshedProject.lastModifiedDate = modifiedDate
        viewModel.organizationProjects = [refreshedProject]

        viewModel.updateAccessibleProjects()

        #expect(viewModel.selectedProject?.tasks.first?.title == "Finish plumbing")
        #expect(viewModel.selectedProject?.tasks.first?.completionPhotoIDs == refreshedTask.completionPhotoIDs)
        #expect(viewModel.accessibleProjects.first?.loggedHours.first?.rate == 60)
        #expect(viewModel.selectedProject?.loggedHours.first?.totalPaidAmount == 30)
    }

    @Test
    func projectRefreshTracksSameIDOperationsMetadataChanges() {
        let orgID = UUID().uuidString
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(networkMonitoringEnabled: false),
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let projectID = UUID()
        let modifiedDate = Date(timeIntervalSince1970: 1_714_020_000)
        var project = Project(
            id: projectID,
            name: "Operations Refresh Project",
            client: "Client G",
            totalBudget: 34_000,
            startDate: modifiedDate,
            endDate: modifiedDate.addingTimeInterval(86_400),
            organizationID: orgID,
            lastModifiedDate: modifiedDate
        )
        project.clientProfile = ProjectClientProfile(name: "Client G", notes: "Original access notes")
        project.paymentMilestones = [
            ProjectPaymentMilestone(title: "Deposit", amount: 2_000)
        ]
        project.projectDocuments = [
            ProjectDocument(
                title: "Original agreement",
                category: .contract,
                fileName: "agreement.pdf",
                mimeType: "application/pdf",
                storageKind: .externalURL,
                storageIdentifier: "https://example.com/agreement.pdf"
            )
        ]
        project.projectChecklists = [
            ProjectChecklist(title: "Demo prep", category: .tools)
        ]
        project.projectCalendarEvents = [
            ProjectCalendarEvent(title: "Dumpster delivery", kind: .deliveryOrder, startDate: modifiedDate)
        ]
        project.shoppingListItems = [
            ProjectShoppingListItem(title: "Contractor bags")
        ]
        project.hiddenConditions = [
            HiddenCondition(title: "Soft subfloor", status: .needsReview)
        ]

        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        var refreshedProject = project
        refreshedProject.lastModifiedDate = modifiedDate
        refreshedProject.clientProfile = ProjectClientProfile(name: "Client G", notes: "Use side gate")
        refreshedProject.paymentMilestones = [
            ProjectPaymentMilestone(title: "Rough-in draw", amount: 8_500)
        ]
        refreshedProject.projectDocuments = [
            ProjectDocument(
                title: "Signed change order",
                category: .other,
                fileName: "change-order.pdf",
                mimeType: "application/pdf",
                storageKind: .externalURL,
                storageIdentifier: "https://example.com/change-order.pdf"
            )
        ]
        refreshedProject.projectChecklists = [
            ProjectChecklist(
                title: "Electrical prep",
                category: .tools,
                items: [ProjectChecklistItem(title: "Voltage tester")]
            )
        ]
        refreshedProject.projectCalendarEvents = [
            ProjectCalendarEvent(title: "Fixture delivery", kind: .deliveryOrder, startDate: modifiedDate)
        ]
        refreshedProject.shoppingListItems = [
            ProjectShoppingListItem(title: "Wire staples", quantity: 2, unit: "boxes")
        ]
        refreshedProject.hiddenConditions = [
            HiddenCondition(
                title: "Soft subfloor near tub",
                status: .approvalNeeded,
                estimatedCostImpact: 900
            )
        ]
        viewModel.organizationProjects = [refreshedProject]

        viewModel.updateAccessibleProjects()

        #expect(viewModel.selectedProject?.clientProfile?.notes == "Use side gate")
        #expect(viewModel.accessibleProjects.first?.paymentMilestones?.first?.title == "Rough-in draw")
        #expect(viewModel.selectedProject?.projectDocuments?.first?.title == "Signed change order")
        #expect(viewModel.selectedProject?.projectChecklists?.first?.items.map(\.title) == ["Voltage tester"])
        #expect(viewModel.selectedProject?.projectCalendarEvents?.first?.title == "Fixture delivery")
        #expect(viewModel.accessibleProjects.first?.shoppingListItems?.first?.quantity == 2)
        #expect(viewModel.selectedProject?.hiddenConditions?.first?.title == "Soft subfloor near tub")
        #expect(viewModel.accessibleProjects.first?.hiddenConditions?.first?.estimatedCostImpact == 900)
    }

    @Test
    func receiptLaborAndTaskMutationsStayVisibleWhenOrganizationProjectsIsTemporarilyStale() async {
        let suiteName = "ProjectMutationFallbackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let repository = RecordingProjectRepository()
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(networkMonitoringEnabled: false),
            projectStore: projectStore,
            projectRepository: repository
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let projectID = UUID()
        let workDate = Date(timeIntervalSince1970: 1_714_010_000)
        let receipt = Receipt(
            id: "fallback-receipt",
            vendor: "Supply House",
            date: workDate,
            amount: 72,
            category: .material,
            paymentMethod: "Card"
        )
        let task = ProjectTask(
            id: UUID(),
            title: "Replace copper joint",
            description: "Left sink",
            projectID: projectID
        )
        let workHour = WorkHour(
            id: UUID(),
            date: workDate,
            startTime: workDate,
            endTime: workDate.addingTimeInterval(3_600),
            lunchStart: nil,
            lunchEnd: nil,
            employee: "Alex Rivera",
            employeeID: UUID(),
            rate: 45,
            category: "Plumbing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        var project = Project(
            id: projectID,
            name: "Fallback Project",
            client: "Client F",
            totalBudget: 9000,
            startDate: workDate,
            endDate: workDate.addingTimeInterval(86_400),
            organizationID: orgID
        )
        project.receipts = [receipt]
        project.tasks = [task]
        project.loggedHours = [workHour]
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.selectedProject = project
        viewModel.updateAccessibleProjects()

        viewModel.organizationProjects = []
        var editedReceipt = receipt
        editedReceipt.amount = 91
        await viewModel.updateReceipt(editedReceipt, in: projectID)

        viewModel.organizationProjects = []
        var editedTask = task
        editedTask.title = "Replace repaired copper joint"
        editedTask.completionNotes = "Verified no leak"
        await viewModel.updateTask(editedTask, in: projectID)

        viewModel.organizationProjects = []
        var editedHour = workHour
        editedHour.rate = 65
        viewModel.updateHours(editedHour)

        viewModel.organizationProjects = []
        guard let payableHour = viewModel.selectedProject?.loggedHours.first else {
            Issue.record("Expected selected project to keep the edited labor entry visible.")
            return
        }
        viewModel.recordLaborPayment(
            for: [payableHour],
            amount: 25,
            method: "Cash",
            reference: "drawer",
            note: "Partial payment"
        )

        let persistedProject = projectStore.loadProjects(for: orgID).first
        #expect(viewModel.selectedProject?.receipts.first?.amount == 91)
        #expect(viewModel.selectedProject?.tasks.first?.title == "Replace repaired copper joint")
        #expect(viewModel.selectedProject?.loggedHours.first?.rate == 65)
        #expect(viewModel.selectedProject?.loggedHours.first?.totalPaidAmount == 25)
        #expect(viewModel.organizationProjects.map(\.id) == [projectID])
        #expect(viewModel.accessibleProjects.map(\.id) == [projectID])
        #expect(persistedProject?.receipts.first?.amount == 91)
        #expect(persistedProject?.tasks.first?.completionNotes == "Verified no leak")
        #expect(persistedProject?.loggedHours.first?.totalPaidAmount == 25)
        #expect(repository.savedProjects.count >= 2)
    }
}

struct ReceiptIntelligenceStoreTests {

    @Test
    func capsReceiptIntelligenceHistoryPerOrganization() {
        let suiteName = "ReceiptIntelligenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ReceiptIntelligenceStore(userDefaults: defaults)
        let organizationID = "org-intel"

        for index in 0..<1005 {
            store.append(
                ReceiptIntelligenceRecord(
                    vendor: "Vendor \(index)",
                    paymentMethod: "Card",
                    amount: Double(index),
                    projectID: "project-\(index)",
                    date: Double(index),
                    organizationID: organizationID,
                    category: "materials",
                    paymentType: "creditCard"
                ),
                for: organizationID
            )
        }

        let records = store.loadRecords(for: organizationID)

        #expect(records.count == 1000)
        #expect(records.first?.vendor == "Vendor 5")
        #expect(records.last?.vendor == "Vendor 1004")
    }

    @Test
    func persistsOrganizationInsightsSnapshots() {
        let suiteName = "ReceiptIntelligenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ReceiptIntelligenceStore(userDefaults: defaults)
        let organizationID = "org-insights"
        let snapshot = OrganizationInsightsSnapshot(
            totalVendors: 8,
            totalPaymentMethods: 3,
            totalSpending: 1250.75,
            lastUpdated: 42,
            organizationID: organizationID
        )

        store.saveInsights(snapshot, for: organizationID)

        let loadedSnapshot = store.loadInsights(for: organizationID)

        #expect(loadedSnapshot == snapshot)
    }
}

struct LaborStoreTests {

    @Test
    func computesGroupedHoursAndPaidUnpaidTotals() {
        let orgID = "org-labor"
        let alice = TeamMember(
            name: "Alice Mason",
            email: "alice@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: orgID
        )
        let bob = TeamMember(
            name: "Bob Rivera",
            email: "bob@example.com",
            jobTitle: "Painter",
            organizationID: orgID
        )

        var project = Project(
            name: "Labor Test Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let start = Date()
        project.loggedHours = [
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(7200),
                lunchStart: nil,
                lunchEnd: nil,
                employee: "Legacy Alice",
                employeeID: alice.id,
                rate: 50,
                category: "Labor",
                isPaid: false,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            ),
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(3600),
                lunchStart: nil,
                lunchEnd: nil,
                employee: bob.name,
                employeeID: nil,
                rate: 60,
                category: "Labor",
                isPaid: true,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            )
        ]

        let store = LaborStore()
        let computation = store.recompute(project: project, teamMembers: [alice, bob])

        #expect(computation.groupedHoursByMember["Alice Mason"]?.count == 1)
        #expect(computation.groupedHoursByMember["Bob Rivera"]?.count == 1)
        #expect(computation.totalsByMember["Alice Mason"]?.unpaid == 100)
        #expect(computation.totalsByMember["Alice Mason"]?.paid == 0)
        #expect(computation.totalsByMember["Bob Rivera"]?.paid == 60)
        #expect(computation.totalHours == 3)
    }

    @Test
    func validatesOrphanedHoursAndCalculationMismatch() {
        let orgID = "org-labor-validation"
        let alice = TeamMember(
            name: "Alice Mason",
            email: "alice@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: orgID
        )

        var project = Project(
            name: "Validation Project",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let start = Date()
        project.loggedHours = [
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(3600),
                lunchStart: nil,
                lunchEnd: nil,
                employee: "Ghost Worker",
                employeeID: nil,
                rate: 40,
                category: "Labor",
                isPaid: false,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            ),
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(1800),
                lunchStart: nil,
                lunchEnd: nil,
                employee: alice.name,
                employeeID: UUID(),
                rate: 80,
                category: "Labor",
                isPaid: false,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            )
        ]

        let store = LaborStore()
        let issues = store.validate(project: project, teamMembers: [alice], calculatedUnpaidAmount: 0)

        #expect(issues.count == 3)
        #expect(issues.contains { $0.contains("Ghost Worker") })
        #expect(issues.contains { $0.contains("invalid team member ID") })
        #expect(issues.contains { $0.contains("Calculation mismatch") })
    }
}

@MainActor
struct LaborPaymentLedgerTests {

    @Test
    func recordsPartialPaymentsAndReversalsOnWorkHour() throws {
        let start = Date(timeIntervalSince1970: 1_736_208_000)
        var workHour = WorkHour(
            id: UUID(uuidString: "E88D1D1D-D3A3-49D2-A504-4FF915CD97F8")!,
            date: start,
            startTime: start,
            endTime: start.addingTimeInterval(14_400),
            lunchStart: nil,
            lunchEnd: nil,
            employee: "Sam Carter",
            employeeID: nil,
            rate: 50,
            category: "Framing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )

        workHour.recordPayment(
            amount: 50,
            method: "Cash",
            reference: "CASH-01",
            note: "Advance",
            paidAt: start.addingTimeInterval(60)
        )
        workHour.recordPayment(
            amount: 75,
            method: "Check",
            reference: "1042",
            note: "Progress payment",
            paidAt: start.addingTimeInterval(120)
        )

        #expect(workHour.straightTimePay == 200)
        #expect(workHour.effectivePaidAmount == 125)
        #expect(workHour.effectiveUnpaidAmount == 75)
        #expect(workHour.isPaid == false)
        #expect(workHour.hasAnyPayment == true)
        #expect(workHour.paymentEntries.count == 2)

        let encoded = try JSONEncoder().encode(workHour)
        let decoded = try JSONDecoder().decode(WorkHour.self, from: encoded)
        #expect(decoded.paymentEntries.map(\.reference) == ["CASH-01", "1042"])
        #expect(decoded.effectivePaidAmount == 125)

        workHour.recordPayment(amount: 200, method: "Check", reference: "1043", note: "Final payment")
        #expect(workHour.effectivePaidAmount == 200)
        #expect(workHour.effectiveUnpaidAmount == 0)
        #expect(workHour.isFullyPaid == true)
        #expect(workHour.isPaid == true)

        workHour.reversePayments(note: "Lost check; reissue needed", reversedAt: start.addingTimeInterval(180))
        #expect(workHour.effectivePaidAmount == 0)
        #expect(workHour.effectiveUnpaidAmount == 200)
        #expect(workHour.isPaid == false)
        #expect(workHour.paymentEntries.last?.isReversal == true)
    }

    @Test
    func paidCashSurvivesHourReductionAsOverpayment() {
        let start = Date(timeIntervalSince1970: 1_747_268_820)
        var workHour = WorkHour(
            id: UUID(uuidString: "C6F8E5C1-60D5-4C7C-8AF4-0B80E8E5A8DA")!,
            date: start,
            startTime: start,
            endTime: start.addingTimeInterval(3_600),
            lunchStart: nil,
            lunchEnd: nil,
            employee: "Kevin Barrett",
            employeeID: nil,
            rate: 45,
            category: "Admin",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )

        workHour.recordPayment(amount: 25, method: "Cash", note: "First partial", paidAt: start.addingTimeInterval(60))
        workHour.recordPayment(amount: 20, method: "Cash", note: "Second partial", paidAt: start.addingTimeInterval(120))

        #expect(workHour.straightTimePay == 45)
        #expect(workHour.totalPaidAmount == 45)
        #expect(workHour.effectivePaidAmount == 45)
        #expect(workHour.overpaidAmount == 0)

        workHour.endTime = start.addingTimeInterval(1_056.8)

        #expect(abs(workHour.straightTimePay - 13.21) < 0.01)
        #expect(workHour.totalPaidAmount == 45)
        #expect(abs(workHour.effectivePaidAmount - 13.21) < 0.01)
        #expect(abs(workHour.overpaidAmount - 31.79) < 0.01)
        #expect(workHour.effectiveUnpaidAmount == 0)
        #expect(workHour.isFullyPaid == true)

        workHour.reversePayments(note: "Refund or correction needed", reversedAt: start.addingTimeInterval(180))
        #expect(workHour.totalPaidAmount == 0)
        #expect(workHour.effectivePaidAmount == 0)
        #expect(abs(workHour.effectiveUnpaidAmount - 13.21) < 0.01)
        #expect(workHour.paymentEntries.last?.isReversal == true)
    }

    @Test
    func projectViewModelDistributesAndReversesLaborPaymentsThroughMutationSeam() {
        let suiteName = "LaborPaymentLedgerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: projectStore,
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let worker = TeamMember(
            name: "Sam Carter",
            email: "sam@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: orgID
        )
        viewModel.teamMembers = [worker]

        var project = Project(
            name: "Labor Ledger Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let start = Date(timeIntervalSince1970: 1_736_208_000)
        let framingHour = WorkHour(
            id: UUID(uuidString: "9C5D6B31-C7D5-4215-9B21-C84F6CF519D7")!,
            date: start,
            startTime: start,
            endTime: start.addingTimeInterval(7_200),
            lunchStart: nil,
            lunchEnd: nil,
            employee: worker.name,
            employeeID: worker.id,
            rate: 50,
            category: "Framing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        let cleanupHour = WorkHour(
            id: UUID(uuidString: "2A557953-0F3C-43FC-902D-8C41597D6D41")!,
            date: start.addingTimeInterval(86_400),
            startTime: start.addingTimeInterval(86_400),
            endTime: start.addingTimeInterval(91_800),
            lunchStart: nil,
            lunchEnd: nil,
            employee: worker.name,
            employeeID: worker.id,
            rate: 40,
            category: "Cleanup",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        project.loggedHours = [cleanupHour, framingHour]

        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.accessibleProjects = [project]
        viewModel.selectProject(project)

        viewModel.recordLaborPayment(
            for: project.loggedHours,
            amount: 125,
            method: "Check",
            reference: "2001",
            note: "Weekly payroll"
        )

        let paidFramingHour = viewModel.selectedProject?.loggedHours.first { $0.id == framingHour.id }
        let partiallyPaidCleanupHour = viewModel.selectedProject?.loggedHours.first { $0.id == cleanupHour.id }

        #expect(paidFramingHour?.effectivePaidAmount == 100)
        #expect(paidFramingHour?.isPaid == true)
        #expect(partiallyPaidCleanupHour?.effectivePaidAmount == 25)
        #expect(partiallyPaidCleanupHour?.effectiveUnpaidAmount == 35)
        #expect(viewModel.projectTotalLaborCost == 160)
        #expect(viewModel.projectUnpaidAmount == 35)
        #expect(projectStore.loadProjects(for: orgID).first?.loggedHours.count == 2)

        if let partiallyPaidCleanupHour {
            viewModel.reverseLaborPayments(for: partiallyPaidCleanupHour)
        }

        let reversedCleanupHour = viewModel.selectedProject?.loggedHours.first { $0.id == cleanupHour.id }
        #expect(reversedCleanupHour?.effectivePaidAmount == 0)
        #expect(reversedCleanupHour?.effectiveUnpaidAmount == 60)
        #expect(viewModel.projectUnpaidAmount == 60)
    }

    @Test
    func laborBusinessResourcesAcceptancePersistsPaymentReissueFlow() {
        let suiteName = "LaborBusinessResourcesAcceptance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let orgID = UUID().uuidString
        let projectStore = ProjectStore(userDefaults: defaults)
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectStore: projectStore,
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let project = Project(
            name: "Device Acceptance Kitchen",
            client: "Avery Homes",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.accessibleProjects = [project]
        viewModel.selectProject(project)

        var worker = TeamMember(
            name: "Jordan Lee",
            email: "jordan@example.com",
            phone: "555-0142",
            jobTitle: "Carpenter",
            rates: [EmployeeRate(taskType: "Framing", rate: 44, isDefault: true)],
            organizationID: orgID
        )
        viewModel.addTeamMember(worker)

        worker.jobTitle = "Lead Carpenter"
        worker.rates = [
            EmployeeRate(taskType: "Finish Carpentry", rate: 48, isDefault: true),
            EmployeeRate(taskType: "Demolition", rate: 42),
            EmployeeRate(taskType: "Office / Data Entry", rate: 30)
        ]
        viewModel.updateTeamMember(worker)

        let loadedWorker = projectStore.loadTeamMembers(for: orgID).first { $0.id == worker.id }
        #expect(loadedWorker?.jobTitle == "Lead Carpenter")
        #expect(loadedWorker?.defaultRate?.rate == 48)
        #expect(loadedWorker?.rates.map(\.taskType).contains("Demolition") == true)
        #expect(loadedWorker?.rates.map(\.taskType).contains("Office / Data Entry") == true)

        let shiftStart = Date(timeIntervalSince1970: 1_736_380_800)
        viewModel.logHours(
            startTime: shiftStart,
            endTime: shiftStart.addingTimeInterval(14_400),
            employee: worker.name,
            rate: 48,
            category: "Finish Carpentry",
            lunchBreakDuration: nil,
            employeeID: worker.id
        )

        guard let loggedHour = viewModel.selectedProject?.loggedHours.first else {
            Issue.record("Expected fresh logged labor hours to persist into the selected project.")
            return
        }

        #expect(viewModel.selectedProject?.assignedTeamMemberIDs.contains(worker.id.uuidString) == true)
        #expect(loggedHour.hours == 4)
        #expect(loggedHour.straightTimePay == 192)
        #expect(viewModel.projectUnpaidAmount == 192)

        var editedHour = loggedHour
        editedHour.endTime = shiftStart.addingTimeInterval(10_800)
        editedHour.rate = 42
        editedHour.category = "Demolition"
        viewModel.updateHours(editedHour)

        guard let correctedLoggedHour = viewModel.selectedProject?.loggedHours.first(where: { $0.id == loggedHour.id }) else {
            Issue.record("Expected edited labor hours to remain in the selected project.")
            return
        }

        #expect(correctedLoggedHour.hours == 3)
        #expect(correctedLoggedHour.rate == 42)
        #expect(correctedLoggedHour.category == "Demolition")
        #expect(correctedLoggedHour.straightTimePay == 126)
        #expect(viewModel.projectUnpaidAmount == 126)

        viewModel.recordLaborPayment(
            for: [correctedLoggedHour],
            amount: 75,
            method: "Check",
            reference: "CHK-2001",
            note: "Partial labor payment"
        )

        let partiallyPaidHour = viewModel.selectedProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(partiallyPaidHour?.effectivePaidAmount == 75)
        #expect(partiallyPaidHour?.effectiveUnpaidAmount == 51)
        #expect(partiallyPaidHour?.paymentEntries.last?.reference == "CHK-2001")

        if let partiallyPaidHour {
            viewModel.replaceLaborPayment(
                for: partiallyPaidHour,
                amount: 70,
                method: "Check",
                reference: "CHK-2001-CORRECTED",
                note: "Corrected check amount"
            )
        }

        let correctedPaymentHour = viewModel.selectedProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(correctedPaymentHour?.effectivePaidAmount == 70)
        #expect(correctedPaymentHour?.effectiveUnpaidAmount == 56)
        #expect(correctedPaymentHour?.paymentEntries.contains { $0.isReversal } == true)
        #expect(correctedPaymentHour?.paymentEntries.last?.reference == "CHK-2001-CORRECTED")

        viewModel.recordLaborPayment(
            for: viewModel.selectedProject?.loggedHours.filter { $0.id == loggedHour.id } ?? [],
            amount: 56,
            method: "Bank Transfer",
            reference: "ACH-2002",
            note: "Final split payment"
        )

        let fullyPaidHour = viewModel.selectedProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(fullyPaidHour?.effectivePaidAmount == 126)
        #expect(fullyPaidHour?.effectiveUnpaidAmount == 0)
        #expect(fullyPaidHour?.isFullyPaid == true)
        let finalPaymentReferences = fullyPaidHour?.paymentEntries.map(\.reference) ?? []
        #expect(Array(finalPaymentReferences.suffix(2)) == ["CHK-2001-CORRECTED", "ACH-2002"])
        #expect(viewModel.projectUnpaidAmount == 0)

        if let fullyPaidHour {
            viewModel.reverseLaborPayments(for: fullyPaidHour)
        }

        let reversedHour = viewModel.selectedProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(reversedHour?.effectivePaidAmount == 0)
        #expect(reversedHour?.effectiveUnpaidAmount == 126)
        #expect(reversedHour?.paymentEntries.last?.isReversal == true)

        viewModel.recordLaborPayment(
            for: viewModel.selectedProject?.loggedHours.filter { $0.id == loggedHour.id } ?? [],
            amount: 126,
            method: "Check",
            reference: "REISSUE-2003",
            note: "Reissued check"
        )

        let reissuedHour = viewModel.selectedProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(reissuedHour?.effectivePaidAmount == 126)
        #expect(reissuedHour?.effectiveUnpaidAmount == 0)
        #expect(reissuedHour?.paymentEntries.last?.reference == "REISSUE-2003")

        let restoredProject = projectStore.loadProjects(for: orgID).first { $0.id == project.id }
        let restoredHour = restoredProject?.loggedHours.first { $0.id == loggedHour.id }
        #expect(restoredHour?.category == "Demolition")
        #expect(restoredHour?.rate == 42)
        #expect(restoredHour?.effectivePaidAmount == 126)
        #expect(restoredHour?.effectiveUnpaidAmount == 0)
        #expect(restoredHour?.paymentEntries.last?.reference == "REISSUE-2003")

        var inactiveWorker = worker
        inactiveWorker.terminate(reason: "Removed from active worker list", type: .endOfContract, date: shiftStart.addingTimeInterval(900))
        viewModel.updateTeamMember(inactiveWorker)

        let restoredInactiveWorker = projectStore.loadTeamMembers(for: orgID).first { $0.id == worker.id }
        #expect(restoredInactiveWorker?.isActive == false)
        #expect(restoredInactiveWorker?.employmentStatus == .terminated)
        #expect(restoredInactiveWorker?.terminationType == .endOfContract)
        #expect(projectStore.loadProjects(for: orgID).first { $0.id == project.id }?.loggedHours.contains { $0.employeeID == worker.id } == true)
    }

    @Test
    func loggedLunchBreakReducesPayableHoursAndUnpaidAmount() {
        let orgID = UUID().uuidString
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectRepository: RecordingProjectRepository()
        )
        viewModel.setCurrentOrganization(
            Organization(id: orgID, name: "Personal Workspace"),
            role: .admin
        )

        let worker = TeamMember(
            name: "Rachel",
            email: "rachel@example.com",
            jobTitle: "Designer",
            rates: [EmployeeRate(taskType: "Design", rate: 100, isDefault: true)],
            organizationID: orgID
        )
        viewModel.teamMembers = [worker]

        let project = Project(
            name: "Lunch Accounting Project",
            client: "Client",
            totalBudget: 10_000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86_400),
            organizationID: orgID
        )
        viewModel.projects = [project]
        viewModel.organizationProjects = [project]
        viewModel.accessibleProjects = [project]
        viewModel.selectProject(project)

        let shiftStart = Date(timeIntervalSince1970: 1_747_268_820)
        viewModel.logHours(
            startTime: shiftStart,
            endTime: shiftStart.addingTimeInterval(18_000),
            employee: worker.name,
            rate: 100,
            category: "Design",
            lunchBreakDuration: 1,
            employeeID: worker.id
        )

        let loggedHour = viewModel.selectedProject?.loggedHours.first
        #expect(loggedHour?.lunchBreakDuration == 1)
        #expect(loggedHour?.hours == 4)
        #expect(loggedHour?.straightTimePay == 400)
        #expect(viewModel.projectUnpaidAmount == 400)
    }
}

struct CompanyStoreTests {

    @Test
    func categorizesTeamMembersByProjectStatus() {
        let orgID = "org-company"
        let activeMember = TeamMember(
            name: "Active Member",
            email: "active@example.com",
            jobTitle: "Foreman",
            organizationID: orgID
        )
        let availableMember = TeamMember(
            name: "Available Member",
            email: "available@example.com",
            jobTitle: "Laborer",
            organizationID: orgID
        )
        let completedMember = TeamMember(
            name: "Completed Member",
            email: "completed@example.com",
            jobTitle: "Painter",
            organizationID: orgID
        )
        var inactiveMember = TeamMember(
            name: "Inactive Member",
            email: "inactive@example.com",
            jobTitle: "Electrician",
            organizationID: orgID
        )
        inactiveMember.employmentStatus = .terminated

        var activeProject = Project(
            name: "Active Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        activeProject.assignTeamMember(activeMember.id.uuidString)

        var completedProject = Project(
            name: "Completed Project",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        completedProject.status = .completed
        completedProject.assignTeamMember(completedMember.id.uuidString)

        let store = CompanyStore()
        let buckets = store.teamBuckets(
            teamMembers: [activeMember, availableMember, completedMember, inactiveMember],
            projects: [activeProject, completedProject]
        )

        #expect(buckets.active.map(\.name) == ["Active Member"])
        #expect(buckets.betweenProjects.map(\.name) == ["Available Member"])
        #expect(buckets.completed.map(\.name) == ["Completed Member"])
        #expect(buckets.inactive.map(\.name) == ["Inactive Member"])
    }

    @Test
    func summarizesOrganizationCountsAndAvailableProjects() {
        let orgID = "org-company-summary"
        let member = TeamMember(
            name: "Available Member",
            email: "available@example.com",
            jobTitle: "Laborer",
            organizationID: orgID
        )

        let organization = Organization(id: orgID, name: "North Shore Builders")

        var activeProject = Project(
            name: "Active Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        activeProject.status = .active

        var completedProject = Project(
            name: "Completed Project",
            client: "Client B",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        completedProject.status = .completed

        let store = CompanyStore()
        let summary = store.summary(
            organization: organization,
            projects: [activeProject, completedProject],
            teamMembers: [member]
        )
        let availableProjects = store.availableProjects(for: member, in: [activeProject, completedProject])

        #expect(summary.totalMembers == 1)
        #expect(summary.activeProjects == 1)
        #expect(summary.currentProjects == 2)
        #expect(summary.currentTeamMembers == 2)
        #expect(availableProjects.map(\.name) == ["Active Project"])
    }
}

@MainActor
struct ReportingServiceTests {

    @Test
    func projectPDFReportGeneratesReadableDocument() async throws {
        let service = ReportingService()
        var project = Project(
            name: "Field Report Project",
            client: "Client A",
            totalBudget: 50000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-reporting"
        )
        project.receipts = [
            Receipt(
                vendor: "Supply House",
                date: Date(timeIntervalSince1970: 1_747_268_820),
                amount: 128.45,
                category: .material,
                paymentMethod: "Visa"
            )
        ]
        project.tasks = [
            ProjectTask(
                title: "Replace rusted copper joint",
                description: "Left sink supply line",
                dueDate: Date(timeIntervalSince1970: 1_747_270_000),
                projectID: project.id,
                photoIDs: [UUID()],
                completionPhotoIDs: [UUID()]
            )
        ]

        let data = try #require(
            await service.generateProjectReport(
                project: project,
                teamMembers: [],
                organization: Organization(id: "org-reporting", name: "Avery Contracting")
            )
        )
        let document = try #require(PDFDocument(data: data))

        #expect(document.pageCount == 1)
        #expect(data.count > 1_000)
    }

    @Test
    func receiptsCSVExportsLineItemsForBookkeeping() throws {
        let service = ReportingService()
        var project = Project(
            name: "Reporting Project",
            client: "Client A",
            totalBudget: 50000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-reporting"
        )

        var receipt = Receipt(
            vendor: "North Shore Supply",
            date: Date(timeIntervalSince1970: 1_747_268_820),
            amount: 36.29,
            notes: "Kitchen rough-in",
            category: .material,
            subcategory: "Rough-In",
            paymentMethod: "Visa",
            taxAmount: 2.40,
            discountAmount: 1.00,
            receiptNumber: "R-1001"
        )
        receipt.items = [
            ReceiptItem(
                name: "Copper Tee",
                quantity: 1,
                unitPrice: 12.34,
                totalPrice: 12.34,
                category: .plumbing,
                subcategory: "Copper"
            ),
            ReceiptItem(
                name: "2x4 Stud",
                quantity: 2,
                unitPrice: 11.98,
                totalPrice: 23.96,
                category: .framing,
                subcategory: "Lumber"
            )
        ]
        project.receipts = [receipt]

        let data = try #require(service.generateReceiptsCSV(project: project))
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.contains("Line Item"))
        #expect(csv.contains("Copper Tee"))
        #expect(csv.contains("Plumbing"))
        #expect(csv.contains("2x4 Stud"))
        #expect(csv.contains("Framing"))
        #expect(csv.contains("R-1001"))
    }

    @Test
    func receiptsCSVExportsPartialRefundSourceLinkage() throws {
        let service = ReportingService()
        var source = Receipt(
            id: "source-r-2001",
            vendor: "Home Depot",
            date: Date(timeIntervalSince1970: 1_747_268_820),
            amount: 214,
            category: .material,
            paymentMethod: "Visa",
            taxAmount: 14
        )
        let item = ReceiptItem(
            name: "Copper Tee",
            quantity: 1,
            unitPrice: 200,
            totalPrice: 200,
            category: .plumbing
        )
        source.items = [item]
        let refund = try #require(
            source.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 1)],
                existingReceipts: [],
                receiptNumber: "RET-2001"
            )
        )

        var project = Project(
            name: "Reporting Refund Project",
            client: "Client B",
            totalBudget: 25000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-reporting"
        )
        project.receipts = [source, refund]

        let data = try #require(service.generateReceiptsCSV(project: project))
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.contains("Source Receipt ID"))
        #expect(csv.contains("RET-2001"))
        #expect(csv.contains("source-r-2001"))
    }

    @Test
    func receiptsCSVExportsRestaurantTipAndFuelPriceMetadata() throws {
        let service = ReportingService()
        var project = Project(
            name: "Receipt Metadata Project",
            client: "Client C",
            totalBudget: 25000,
            startDate: Date(timeIntervalSince1970: 1_747_260_000),
            endDate: Date(timeIntervalSince1970: 1_747_346_400),
            organizationID: "org-reporting"
        )
        project.receipts = [
            Receipt(
                vendor: "Bar Bix",
                date: Date(timeIntervalSince1970: 1_747_268_820),
                amount: 137.45,
                category: .general,
                paymentMethod: "Visa",
                tipAmount: 40
            ),
            Receipt(
                vendor: "Shell",
                date: Date(timeIntervalSince1970: 1_747_355_220),
                amount: 48.62,
                category: .general,
                paymentMethod: "Visa",
                pricePerGallon: 3.549
            )
        ]

        let data = try #require(service.generateReceiptsCSV(project: project))
        let csv = try #require(String(data: data, encoding: .utf8))

        #expect(csv.contains("Tip Amount"))
        #expect(csv.contains("Price Per Gallon"))
        #expect(csv.contains("40.00"))
        #expect(csv.contains("3.549"))
    }

    @Test
    func laborAndTaskExportsPreserveAccountingContext() throws {
        let service = ReportingService()
        let workerID = UUID(uuidString: "2F7BA1F4-B7E8-4A1F-9D10-1D5E7646F1E1")!
        let start = Date(timeIntervalSince1970: 1_747_268_820)

        let worker = TeamMember(
            id: workerID,
            name: "Sam Carter",
            email: "sam@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: "org-reporting"
        )

        var workHour = WorkHour(
            id: UUID(uuidString: "C6F8E5C1-60D5-4C7C-8AF4-0B80E8E5A8DA")!,
            date: start,
            startTime: start,
            endTime: start.addingTimeInterval(3_600),
            lunchStart: nil,
            lunchEnd: nil,
            employee: worker.name,
            employeeID: worker.id,
            rate: 45,
            category: "Framing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        workHour.recordPayment(
            amount: 25,
            method: "Cash",
            reference: "PARTIAL-01",
            note: "Advance",
            paidAt: start.addingTimeInterval(60)
        )
        workHour.recordPayment(
            amount: 20,
            method: "Check",
            reference: "CHK-1002",
            note: "Balance",
            paidAt: start.addingTimeInterval(120)
        )
        workHour.endTime = start.addingTimeInterval(1_056.8)

        var project = Project(
            name: "Reporting Project",
            client: "Client A",
            totalBudget: 50000,
            startDate: start,
            endDate: start.addingTimeInterval(86_400),
            organizationID: "org-reporting"
        )
        project.loggedHours = [workHour]
        project.tasks = [
            ProjectTask(
                title: "Replace rusted copper joint",
                description: "Left sink supply line",
                dueDate: start.addingTimeInterval(3_600),
                isCompleted: true,
                completedDate: start.addingTimeInterval(7_200),
                priority: .high,
                category: .plumbing,
                estimatedHours: 2,
                actualHours: 1.5,
                projectID: project.id,
                photoIDs: [UUID()],
                completionPhotoIDs: [UUID(), UUID()],
                assignedEmployeeIDs: [worker.id],
                completedByEmployeeIDs: [worker.id],
                completionNotes: "Joint replaced and leak tested."
            )
        ]

        let paymentData = try #require(service.generateLaborPaymentsCSV(project: project))
        let paymentCSV = try #require(String(data: paymentData, encoding: .utf8))
        #expect(paymentCSV.contains("PARTIAL-01"))
        #expect(paymentCSV.contains("CHK-1002"))
        #expect(paymentCSV.contains("31.79"))

        let timesheetData = try #require(
            service.generateTimesheetCSV(
                project: project,
                startDate: start.addingTimeInterval(-60),
                endDate: start.addingTimeInterval(7_200)
            )
        )
        let timesheetCSV = try #require(String(data: timesheetData, encoding: .utf8))
        #expect(timesheetCSV.contains("Paid Cash"))
        #expect(timesheetCSV.contains("Overpaid Balance"))
        #expect(timesheetCSV.contains("31.79"))

        let taskData = try #require(service.generateTasksCSV(project: project, teamMembers: [worker]))
        let taskCSV = try #require(String(data: taskData, encoding: .utf8))
        #expect(taskCSV.contains("Replace rusted copper joint"))
        #expect(taskCSV.contains("Sam Carter"))
        #expect(taskCSV.contains(",1,2,"))
        #expect(taskCSV.contains("Joint replaced and leak tested."))
    }
}

@MainActor
struct BudgetBridgeTests {

    @Test
    func detailedMaterialReceiptValidatesAgainstReceiptLevelLegacyBridge() {
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectRepository: RecordingProjectRepository()
        )

        var project = Project(
            name: "Bridge Validation Project",
            client: "Client",
            totalBudget: 1000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-budget-bridge"
        )

        project.receipts = [
            Receipt(
                vendor: "Supply House",
                date: .now,
                amount: 120,
                category: .plumbing,
                paymentMethod: "Cash"
            )
        ]

        viewModel.selectedProject = project

        let validation = viewModel.validateEnhancedCalculations()

        #expect(validation.contains("Materials:"))
        #expect(validation.contains("- Enhanced: $120.00"))
        #expect(validation.contains("- Legacy: $120.00"))
        #expect(validation.contains("Status: ✅ VALIDATED"))
    }

    @Test
    func itemizedBudgetBridgeCountsTraditionalCategoriesAcrossMixedReceipt() {
        let viewModel = ProjectViewModel(
            offlineDataManager: OfflineDataManager(),
            projectRepository: RecordingProjectRepository()
        )

        var project = Project(
            name: "Mixed Budget Receipt Project",
            client: "Client",
            totalBudget: 1000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-mixed-budget-bridge"
        )

        var receipt = Receipt(
            vendor: "Home Depot",
            date: .now,
            amount: 100,
            category: .material,
            paymentMethod: "Credit Card"
        )
        receipt.items = [
            ReceiptItem(name: "Stud Pack", unitPrice: 50, totalPrice: 50, category: .framing),
            ReceiptItem(name: "Permit Fee", unitPrice: 30, totalPrice: 30, category: .permits),
            ReceiptItem(name: "Unknown Overage", unitPrice: 20, totalPrice: 20, category: .contingency)
        ]
        project.receipts = [receipt]

        viewModel.selectedProject = project

        #expect(viewModel.spentMaterials == 50)
        #expect(viewModel.spentGeneralConditions == 30)
        #expect(viewModel.spentContingency == 20)
    }
}

struct TeamMemberStoreTests {

    @Test
    func mergesMoreCompleteDuplicateTeamMember() {
        let orgID = "org-team-member"
        let existingMember = TeamMember(
            name: "Taylor Mason",
            email: "",
            jobTitle: "Lead Carpenter",
            rates: [],
            organizationID: orgID
        )
        let updatedMember = TeamMember(
            name: "Taylor Mason",
            email: "taylor@example.com",
            jobTitle: "Lead Carpenter",
            rates: [EmployeeRate(taskType: "Finish Carpentry", rate: 65, isDefault: true)],
            organizationID: orgID
        )

        let store = TeamMemberStore()
        let result = store.upsert(updatedMember, into: [existingMember])

        #expect(result.action.logLabel == "updatedExisting")
        #expect(result.members.count == 1)
        #expect(result.members.first?.email == "taylor@example.com")
        #expect(result.members.first?.rates.count == 1)
    }

    @Test
    func verifiesOrganizationScopeAndPrunesForeignMembers() {
        let store = TeamMemberStore()
        let orgID = "org-primary"
        let primaryMember = TeamMember(
            name: "Primary Member",
            email: "primary@example.com",
            jobTitle: "Foreman",
            organizationID: orgID
        )
        let foreignMember = TeamMember(
            name: "Foreign Member",
            email: "foreign@example.com",
            jobTitle: "Painter",
            organizationID: "org-foreign"
        )

        let verification = store.verify([primaryMember, foreignMember], for: orgID)

        #expect(verification.members.map(\.name) == ["Primary Member"])
        #expect(verification.filteredCount == 1)
    }

    @Test
    func renamesAndRemovesLoggedHoursForDeletedTeamMember() {
        let orgID = "org-team-hours"
        let member = TeamMember(
            id: UUID(),
            name: "Taylor Mason",
            email: "taylor@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: orgID
        )

        var project = Project(
            name: "Team Hours Project",
            client: "Client A",
            totalBudget: 100000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let start = Date()
        project.loggedHours = [
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(3600),
                lunchStart: nil,
                lunchEnd: nil,
                employee: "Legacy Taylor",
                employeeID: member.id,
                rate: 55,
                category: "Labor",
                isPaid: false,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            ),
            WorkHour(
                id: UUID(),
                date: start,
                startTime: start,
                endTime: start.addingTimeInterval(1800),
                lunchStart: nil,
                lunchEnd: nil,
                employee: "Taylor Mason",
                employeeID: nil,
                rate: 55,
                category: "Labor",
                isPaid: true,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            )
        ]

        let store = TeamMemberStore()
        let rename = store.renameLoggedHours(in: project, from: "Legacy Taylor", to: member.name)
        let removal = store.removeLoggedHours(for: member, in: rename.project)

        #expect(rename.changedCount == 1)
        #expect(rename.project.loggedHours.first?.employee == "Taylor Mason")
        #expect(removal.changedCount == 2)
        #expect(removal.project.loggedHours.isEmpty)
    }
}

struct ReceiptCategoryBreakdownTests {
    @Test
    func itemizedReceiptsUseItemCategoriesForScopedSpend() {
        var receipt = Receipt(
            vendor: "Home Depot",
            date: .now,
            amount: 36.29,
            category: .material
        )
        receipt.items = [
            ReceiptItem(
                name: "Copper Tee",
                quantity: 1,
                unitPrice: 12.34,
                totalPrice: 12.34,
                category: .plumbing
            ),
            ReceiptItem(
                name: "2x4 Stud",
                quantity: 1,
                unitPrice: 15.55,
                totalPrice: 15.55,
                category: .framing
            ),
            ReceiptItem(
                name: "Roof Patch",
                quantity: 1,
                unitPrice: 8.40,
                totalPrice: 8.40,
                category: .roofing
            )
        ]

        #expect(receipt.representedCategories == Set([.plumbing, .framing, .roofing]))
        #expect(receipt.hasScopedCategory(.plumbing))
        #expect(receipt.hasScopedCategory(.framing))
        #expect(receipt.hasScopedCategory(.roofing))
        #expect(!receipt.hasScopedCategory(.material))
        #expect(receipt.scopedAmount(for: .plumbing) == 12.34)
        #expect(receipt.scopedAmount(for: .framing) == 15.55)
        #expect(receipt.scopedAmount(for: .roofing) == 8.40)
        #expect(receipt.scopedAmount(for: .material) == 0)
        #expect(receipt.budgetScopedAmount(for: .material) == 36.29)
        #expect(receipt.budgetScopedAmount(for: .general) == 0)
        #expect(receipt.budgetScopedAmount(for: .contingency) == 0)
    }

    @Test
    func legacyReceiptsFallbackToReceiptLevelCategory() {
        let receipt = Receipt(
            vendor: "Permit Office",
            date: .now,
            amount: 55,
            category: .permits
        )

        #expect(receipt.representedCategories == Set([.permits]))
        #expect(receipt.hasScopedCategory(.permits))
        #expect(receipt.scopedAmount(for: .permits) == 55)
        #expect(receipt.scopedAmount(for: .material) == 0)
    }
}

struct ReceiptPartialRefundTests {
    @Test
    func partialRefundAllocatesTaxDiscountAndPreservesReturnedItemCategories() throws {
        var receipt = Receipt(
            id: "source-receipt",
            vendor: "Home Depot",
            date: .now,
            amount: 1_050,
            category: .material,
            paymentMethod: "Card",
            taxAmount: 70,
            discountAmount: 20
        )
        let plumbingItem = ReceiptItem(
            id: UUID(),
            name: "Copper Elbow",
            quantity: 2,
            unitPrice: 200,
            totalPrice: 400,
            category: .plumbing
        )
        receipt.items = [
            plumbingItem,
            ReceiptItem(
                name: "Electrical Wire",
                quantity: 1,
                unitPrice: 600,
                totalPrice: 600,
                category: .electrical
            )
        ]

        let refund = try #require(
            receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: plumbingItem.id, quantity: 1)],
                existingReceipts: [],
                refundDate: Date(timeIntervalSince1970: 1_714_100_000),
                receiptNumber: "RET-1001",
                notes: "Returned extra fitting"
            )
        )

        #expect(refund.isReturn)
        #expect(refund.isPartialRefund)
        #expect(refund.sourceReceiptID == receipt.id)
        #expect(refund.amount == 210)
        #expect(refund.taxAmount == 14)
        #expect(refund.discountAmount == 4)
        #expect(refund.items.count == 1)
        #expect(refund.items.first?.id == plumbingItem.id)
        #expect(refund.items.first?.quantity == 1)
        #expect(refund.items.first?.totalPrice == 200)
        #expect(refund.scopedAmount(for: .plumbing) == -200)
        #expect(refund.scopedAmount(for: .electrical) == 0)
    }

    @Test
    func partialRefundPreventsOverRefundAndFinalRefundUsesRemainingGrossResidual() throws {
        var receipt = Receipt(
            id: "rounding-source",
            vendor: "Supply House",
            date: .now,
            amount: 32.01,
            category: .material,
            paymentMethod: "Card",
            taxAmount: 2.01
        )
        let item = ReceiptItem(
            id: UUID(),
            name: "Fastener Pack",
            quantity: 3,
            unitPrice: 10,
            totalPrice: 30,
            category: .framing
        )
        receipt.items = [item]

        let firstRefund = try #require(
            receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 1)],
                existingReceipts: []
            )
        )

        #expect(firstRefund.amount == 10.67)
        #expect(firstRefund.taxAmount == 0.67)
        #expect(receipt.remainingRefundableQuantity(for: item, in: [firstRefund]) == 2)
        #expect(
            receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 3)],
                existingReceipts: [firstRefund]
            ) == nil
        )

        let finalRefund = try #require(
            receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 2)],
                existingReceipts: [firstRefund]
            )
        )

        #expect(finalRefund.amount == 21.34)
        #expect(finalRefund.taxAmount == 1.34)
        #expect(receipt.refundedAmount(in: [firstRefund, finalRefund]) == 32.01)
        #expect(receipt.remainingRefundableAmount(in: [firstRefund, finalRefund]) == 0)
    }

    @Test
    func lineItemExceptionsDoNotChangePartialRefundCalculations() throws {
        var receipt = Receipt(
            id: "exception-refund-source",
            vendor: "Home Depot",
            date: .now,
            amount: 107,
            category: .material,
            paymentMethod: "Card",
            taxAmount: 7
        )
        let item = ReceiptItem(
            id: UUID(),
            name: "Water supply line",
            quantity: 4,
            unitPrice: 25,
            totalPrice: 100,
            category: .plumbing,
            exceptionMetadata: ReceiptItemExceptionMetadata(
                returnQuantity: 2,
                missingQuantity: 1,
                status: .disputeNeeded
            )
        )
        receipt.items = [item]

        let refund = try #require(
            receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: 1)],
                existingReceipts: []
            )
        )

        #expect(refund.amount == 26.75)
        #expect(refund.taxAmount == 1.75)
        #expect(refund.items.count == 1)
        #expect(refund.items.first?.quantity == 1)
        #expect(refund.items.first?.totalPrice == 25)
        #expect(receipt.remainingRefundableQuantity(for: item, in: [refund]) == 3)
        #expect(receipt.remainingRefundableAmount(in: [refund]) == 80.25)
    }
}

struct ReceiptProjectStoreTests {

    @Test
    func resolvesProjectFromOrganizationProjectsFirst() {
        let orgID = "org-receipt"
        let organizationProject = Project(
            name: "Organization Project",
            client: "Client A",
            totalBudget: 50000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )
        let allProject = Project(
            name: "All Projects Copy",
            client: "Client B",
            totalBudget: 75000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let store = ReceiptProjectStore()
        let resolution = store.resolveProject(
            projectID: organizationProject.id,
            organizationProjects: [organizationProject],
            allProjects: [allProject],
            currentOrganizationID: orgID
        )

        guard let resolution else {
            Issue.record("Expected receipt project resolution")
            return
        }

        #expect(resolution.project.id == organizationProject.id)
        #expect(resolution.storage.logLabel == "organizationProjects")
        #expect(resolution.resynchronizedFromAllProjects == false)
        #expect(resolution.synchronizedOrganizationProjects.count == 1)
    }

    @Test
    func resynchronizesMatchingAllProjectIntoOrganizationScope() {
        let orgID = "org-receipt-sync"
        let allProject = Project(
            name: "Recovered Project",
            client: "Client A",
            totalBudget: 82000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: orgID
        )

        let store = ReceiptProjectStore()
        let resolution = store.resolveProject(
            projectID: allProject.id,
            organizationProjects: [],
            allProjects: [allProject],
            currentOrganizationID: orgID
        )

        guard let resolution else {
            Issue.record("Expected resynchronized receipt project resolution")
            return
        }

        #expect(resolution.project.id == allProject.id)
        #expect(resolution.storage.logLabel == "organizationProjects")
        #expect(resolution.resynchronizedFromAllProjects == true)
        #expect(resolution.synchronizedOrganizationProjects.map(\.id) == [allProject.id])
    }

    @Test
    func rejectsCrossOrganizationProjectResolution() {
        let store = ReceiptProjectStore()
        let foreignProject = Project(
            name: "Foreign Project",
            client: "Client A",
            totalBudget: 62000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-foreign"
        )

        let resolution = store.resolveProject(
            projectID: foreignProject.id,
            organizationProjects: [],
            allProjects: [foreignProject],
            currentOrganizationID: "org-current"
        )

        #expect(resolution == nil)
    }
}

struct ReceiptScannerLifecycleTests {

    @Test
    func deferredScannerResultQueuesOneValueUntilConsumed() {
        var deferredResult = DeferredScannerResult<Int>()

        #expect(deferredResult.hasPendingValue == false)
        #expect(deferredResult.queue(7) == true)
        #expect(deferredResult.hasPendingValue == true)
        #expect(deferredResult.queue(9) == false)
        #expect(deferredResult.consume() == 7)
        #expect(deferredResult.hasPendingValue == false)
        #expect(deferredResult.queue(11) == true)
        #expect(deferredResult.consume() == 11)
    }

    @Test
    func documentScannerCompletionGateOnlyExecutesFirstCallback() {
        let gate = DocumentScannerCompletionGate()
        var callbackCount = 0

        #expect(gate.perform { callbackCount += 1 } == true)
        #expect(gate.perform { callbackCount += 1 } == false)
        #expect(callbackCount == 1)
    }

    @Test
    func presentationStateQueuesCancelledResultWithoutReopeningScanner() {
        var presentationState = ReceiptScannerPresentationState()

        presentationState.beginDocumentScan()

        #expect(presentationState.currentStep == .camera)
        #expect(presentationState.showingDocumentScanner == true)
        #expect(presentationState.queueDocumentResult(.cancelled) == true)
        #expect(presentationState.currentStep == .camera)
        #expect(presentationState.showingDocumentScanner == false)
        #expect(presentationState.queueDocumentResult(.cancelled) == false)

        switch presentationState.consumeQueuedDocumentResult() {
        case .cancelled?:
            break
        default:
            Issue.record("Expected scanner cancellation to remain queued until dismissal completes.")
        }
    }

    @Test
    func presentationStateReturnToEntryClearsQueuedScannerResult() {
        var presentationState = ReceiptScannerPresentationState()

        presentationState.beginDocumentScan()
        #expect(presentationState.queueDocumentResult(.cancelled) == true)

        presentationState.returnToEntry(hideIntro: true)

        #expect(presentationState.currentStep == .launcher)
        #expect(presentationState.showingDocumentScanner == false)

        switch presentationState.consumeQueuedDocumentResult() {
        case nil:
            break
        default:
            Issue.record("Expected returning to intro to clear any pending scanner result.")
        }
    }

    @Test
    func initialSetupOnlyAutoStartsScannerOnceWhenIntroHidden() {
        var presentationState = ReceiptScannerPresentationState()

        #expect(presentationState.performInitialSetup(hideIntro: true, hasAIAccess: true) == true)
        #expect(presentationState.currentStep == .camera)
        #expect(presentationState.showingDocumentScanner == true)

        presentationState.returnToEntry(hideIntro: true)

        #expect(presentationState.performInitialSetup(hideIntro: true, hasAIAccess: true) == false)
        #expect(presentationState.currentStep == .launcher)
        #expect(presentationState.showingDocumentScanner == false)
    }

    @MainActor
    @Test
    func scannerSessionRetainsLaunchStateAcrossHostReuse() {
        let session = ReceiptScannerSession(
            project: makeProject(organizationID: "org-123"),
            hideIntro: true,
            hasAIAccess: true
        )

        #expect(session.currentStep == .camera)
        #expect(session.showingDocumentScanner == true)

        session.returnToEntry(hideIntro: true)

        let reusedHostSession = session

        #expect(reusedHostSession.currentStep == .launcher)
        #expect(reusedHostSession.showingDocumentScanner == false)
    }
}

private func makeBudgetLine(
    id: UUID = UUID(),
    title: String,
    phase: String,
    lineType: BudgetLineType,
    quantity: Double,
    unitCost: Double,
    projectType: EstimateProjectType = .residentialRemodel,
    clientVisible: Bool = true
) -> BudgetLine {
    BudgetLine(
        id: id,
        projectType: projectType,
        scopeGroup: phase,
        costCode: "CC-\(lineType.sortPriority)-\(title.prefix(3).uppercased())",
        phase: phase,
        title: title,
        detail: "\(title) estimate",
        lineType: lineType,
        quantity: quantity,
        unit: lineType == .labor ? "hrs" : "ea",
        unitCost: unitCost,
        laborHours: lineType == .labor ? quantity : nil,
        crewRole: lineType == .labor ? "Lead Tech" : nil,
        sourceEvidence: [
            SourceEvidence(
                type: .regionalFallback,
                title: "Regional baseline",
                geographicScope: "02139",
                confidence: 0.72,
                note: "Test fixture"
            )
        ],
        clientVisible: clientVisible
    )
}

struct EstimatorDomainTests {

    @Test
    func rollsUpBudgetLineTotalsByLineType() {
        let lines = [
            makeBudgetLine(title: "Lumber", phase: "Framing", lineType: .materials, quantity: 12, unitCost: 24),
            makeBudgetLine(title: "Crew", phase: "Framing", lineType: .labor, quantity: 20, unitCost: 85),
            makeBudgetLine(title: "Dumpster", phase: "General", lineType: .generalConditions, quantity: 1, unitCost: 450),
            makeBudgetLine(title: "Contingency", phase: "General", lineType: .contingency, quantity: 1, unitCost: 600),
            makeBudgetLine(title: "Markup", phase: "General", lineType: .markup, quantity: 1, unitCost: 275)
        ]

        let totals = EstimateTotalsSummary(lines: lines)

        #expect(totals.materials == 288)
        #expect(totals.labor == 1700)
        #expect(totals.generalConditions == 450)
        #expect(totals.contingency == 600)
        #expect(totals.markup == 275)
        #expect(totals.directTotal == 1988)
        #expect(totals.internalTotal == 3038)
        #expect(totals.clientTotal == 3313)
    }

    @Test
    func appliesApprovedBaselineIntoProjectBridgeFields() {
        let baseline = BudgetBaseline(
            projectID: UUID(),
            estimateVersionID: UUID(),
            projectType: .houseFlip,
            zipCode: "10001",
            contingencyPercent: 10,
            lines: [
                makeBudgetLine(title: "Cabinets", phase: "Kitchen", lineType: .materials, quantity: 1, unitCost: 7200),
                makeBudgetLine(title: "Install Crew", phase: "Kitchen", lineType: .labor, quantity: 32, unitCost: 95),
                makeBudgetLine(title: "Permit", phase: "General", lineType: .permits, quantity: 1, unitCost: 450),
                makeBudgetLine(title: "Site Supervision", phase: "General", lineType: .generalConditions, quantity: 1, unitCost: 1200),
                makeBudgetLine(title: "Contingency", phase: "General", lineType: .contingency, quantity: 1, unitCost: 900),
                makeBudgetLine(title: "OH&P", phase: "General", lineType: .markup, quantity: 1, unitCost: 1400)
            ]
        )
        let originalProject = Project(
            name: "Kitchen Refresh",
            client: "Jordan",
            totalBudget: 1000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-estimator"
        )

        let updatedProject = originalProject.applyingBudgetBaseline(baseline)

        #expect(updatedProject.totalBudget == baseline.totals.clientTotal)
        #expect(updatedProject.materialCost == baseline.totals.materials + baseline.totals.equipment + baseline.totals.allowance)
        #expect(updatedProject.laborCost == baseline.totals.labor + baseline.totals.subcontract)
        #expect(updatedProject.generalConditions == baseline.totals.permits + baseline.totals.generalConditions + baseline.totals.overhead + baseline.totals.markup)
        #expect(updatedProject.contingency == baseline.totals.contingency)
        #expect(updatedProject.lastModifiedDate >= originalProject.lastModifiedDate)
    }

    @Test
    func buildsVarianceFromMappedActualsAndBudgetLinkedTasks() throws {
        let framingLineID = UUID()
        let cleanupLineID = UUID()
        let baseline = BudgetBaseline(
            projectID: UUID(),
            estimateVersionID: UUID(),
            projectType: .residentialRemodel,
            zipCode: "02139",
            contingencyPercent: 8,
            lines: [
                makeBudgetLine(id: framingLineID, title: "Framing Crew", phase: "Framing", lineType: .labor, quantity: 10, unitCost: 100),
                makeBudgetLine(id: cleanupLineID, title: "Final Cleanup", phase: "Closeout", lineType: .generalConditions, quantity: 1, unitCost: 250)
            ]
        )
        var project = Project(
            id: baseline.projectID,
            name: "Variance Test",
            client: "Client B",
            totalBudget: 10000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-estimator"
        )
        project.tasks = [
            ProjectTask(
                title: "Frame Powder Room",
                estimatedHours: 4,
                projectID: project.id,
                budgetLineID: framingLineID,
                estimateVersionID: baseline.estimateVersionID,
                phaseName: "Framing"
            )
        ]
        let links = [
            ActualCostLink(
                projectID: project.id,
                estimateVersionID: baseline.estimateVersionID,
                budgetLineID: framingLineID,
                sourceType: .receipt,
                sourceRecordID: UUID().uuidString,
                mappedAmount: 180
            ),
            ActualCostLink(
                projectID: project.id,
                estimateVersionID: baseline.estimateVersionID,
                budgetLineID: framingLineID,
                sourceType: .workHour,
                sourceRecordID: UUID().uuidString,
                mappedAmount: 220
            )
        ]

        let snapshot = VarianceSnapshot(project: project, baseline: baseline, actualCostLinks: links)
        let framingLine = try #require(snapshot.lines.first(where: { $0.id == framingLineID }))
        let cleanupLine = try #require(snapshot.lines.first(where: { $0.id == cleanupLineID }))

        #expect(framingLine.actual == 400)
        #expect(framingLine.committed == 800)
        #expect(framingLine.remaining == 600)
        #expect(framingLine.forecast == 1000)
        #expect(cleanupLine.actual == 0)
        #expect(cleanupLine.committed == 0)
        #expect(snapshot.totalActual == 400)
    }
}

struct SQLiteEstimatorStoreTests {

    @Test
    func persistsEstimatorArtifactsAcrossRoundTrip() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SQLiteEstimatorStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("estimator.sqlite")
        let store = SQLiteEstimatorStore(databaseURL: databaseURL)
        let projectID = UUID()
        let session = EstimateSession(
            projectID: projectID,
            input: EstimateIntakeInput(
                projectType: .commercialBuildout,
                zipCode: "60601",
                scopePrompt: "Tenant buildout for a boutique fitness studio."
            ),
            clarifications: [
                EstimateClarificationItem(question: "Is HVAC replacement required?", answer: "Yes, one rooftop unit.")
            ],
            status: .readyForDraft
        )
        let draft = EstimateDraft(
            sessionID: session.id,
            projectID: projectID,
            confidence: 0.81,
            assumptions: ["After-hours work allowed in the lease."],
            alternates: ["Alternate flooring package."],
            lines: [
                makeBudgetLine(title: "Demising Wall", phase: "Framing", lineType: .materials, quantity: 20, unitCost: 40)
            ],
            proposalView: ProposalView(
                title: "Fitness Studio",
                subtitle: "Initial Estimate",
                executiveSummary: "Buildout draft",
                sections: [ProposalSection(title: "Scope", body: "Frame, MEP, finishes")],
                assumptions: ["After-hours work allowed in the lease."],
                clientVisibleLines: []
            )
        )
        let baseline = BudgetBaseline(
            projectID: projectID,
            estimateVersionID: UUID(),
            projectType: .commercialBuildout,
            zipCode: "60601",
            contingencyPercent: 7,
            lines: draft.lines
        )
        let version = EstimateVersion(
            projectID: projectID,
            draftID: draft.id,
            assumptions: draft.assumptions,
            baseline: baseline,
            proposalView: draft.proposalView
        )
        let link = ActualCostLink(
            projectID: projectID,
            estimateVersionID: baseline.estimateVersionID,
            budgetLineID: baseline.lines[0].id,
            sourceType: .receipt,
            sourceRecordID: UUID().uuidString,
            mappedAmount: 320
        )

        try await store.saveSession(session)
        try await store.saveDraft(draft)
        try await store.saveBaseline(baseline)
        try await store.saveVersion(version)
        try await store.saveActualCostLink(link)

        let loadedSession = try await store.loadSession(projectID: projectID)
        let loadedDraft = try await store.loadDraft(projectID: projectID)
        let loadedBaseline = try await store.loadBaseline(projectID: projectID)
        let loadedVersions = try await store.loadVersions(projectID: projectID)
        let loadedLinks = try await store.loadActualCostLinks(projectID: projectID)

        #expect(loadedSession == session)
        #expect(loadedDraft == draft)
        #expect(loadedBaseline == baseline)
        #expect(loadedVersions == [version])
        #expect(loadedLinks == [link])
    }

    @Test
    func replacesActualCostLinkBySourceIdentity() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SQLiteEstimatorStoreReplace-\(UUID().uuidString)")
            .appendingPathComponent("estimator.sqlite")
        let store = SQLiteEstimatorStore(databaseURL: databaseURL)
        let projectID = UUID()
        let sourceRecordID = UUID().uuidString
        let original = ActualCostLink(
            projectID: projectID,
            estimateVersionID: UUID(),
            budgetLineID: UUID(),
            sourceType: .receipt,
            sourceRecordID: sourceRecordID,
            mappedAmount: 180
        )
        let replacement = ActualCostLink(
            projectID: projectID,
            estimateVersionID: original.estimateVersionID,
            budgetLineID: UUID(),
            sourceType: .receipt,
            sourceRecordID: sourceRecordID,
            mappedAmount: 260,
            note: "Updated allocation"
        )

        try await store.saveActualCostLink(original)
        try await store.replaceActualCostLink(replacement)

        let loadedLinks = try await store.loadActualCostLinks(projectID: projectID)

        #expect(loadedLinks == [replacement])
    }
}

@MainActor
struct AIProjectCalculatorWorkflowTests {

    @Test
    func createsDraftApprovesBaselineAndReloadsPersistedInput() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIProjectCalculatorWorkflow-\(UUID().uuidString)")
            .appendingPathComponent("estimator.sqlite")
        let store = SQLiteEstimatorStore(databaseURL: databaseURL)
        let service = HybridRHEIREstimationService()
        let project = Project(
            name: "Estimator Workflow",
            client: "Client C",
            clientAddress: "123 Main St, Cambridge, MA 02139",
            description: "Kitchen and bath renovation with electrical updates, new tile, and finish carpentry.",
            totalBudget: 85000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-estimator"
        )
        var historyReceipt = Receipt(
            vendor: "Builder Depot",
            date: .now,
            amount: 425,
            paymentMethod: "Card"
        )
        historyReceipt.projectID = project.id
        var historicalProject = project
        historicalProject.receipts = [historyReceipt]
        let organizationProjects = [historicalProject]

        let viewModel = AIProjectCalculatorViewModel(project: project, service: service, store: store)
        viewModel.input.projectType = EstimateProjectType.residentialRemodel
        viewModel.input.zipCode = "02139"
        viewModel.input.scopePrompt = "Kitchen and bath renovation with electrical updates, tile, carpentry, and finish work."
        viewModel.input.preferredVendors = ["Builder Depot"]
        viewModel.input.preferredStores = ["Local Supply"]
        viewModel.input.contingencyPercent = 12

        await viewModel.createSessionAndDraft(project: project, organizationProjects: organizationProjects)

        let draftedSession = try #require(viewModel.session)
        let generatedDraft = try #require(viewModel.draft)
        #expect(draftedSession.status == EstimateSessionStatus.drafted)
        #expect(generatedDraft.status == EstimateDraftStatus.review)
        #expect(generatedDraft.lines.isEmpty == false)
        #expect(generatedDraft.proposalView.sections.isEmpty == false)

        await viewModel.approveDraft(
            project: project,
            organizationProjects: organizationProjects,
            approvedByUserID: "user-123",
            applyBaseline: { _ in },
            generateTasks: { _, _ in }
        )

        let approvedSession = try #require(viewModel.session)
        let approvedDraft = try #require(viewModel.draft)
        let approvedBaseline = try #require(viewModel.approvedBaseline)

        #expect(approvedSession.status == EstimateSessionStatus.approved)
        #expect(approvedDraft.status == EstimateDraftStatus.approved)
        #expect(viewModel.versions.count == 1)
        #expect(approvedBaseline.lines == approvedDraft.lines)

        let reloadedViewModel = AIProjectCalculatorViewModel(project: project, service: service, store: store)
        await reloadedViewModel.load(project: project)

        #expect(reloadedViewModel.input.scopePrompt == viewModel.input.scopePrompt)
        #expect(reloadedViewModel.input.preferredStores == ["Local Supply"])
        #expect(reloadedViewModel.session?.status == EstimateSessionStatus.approved)
        #expect(reloadedViewModel.approvedBaseline == approvedBaseline)
    }

    @Test
    func mapsReceiptWorkHourAndTaskIntoVarianceAndClearsUnmatchedQueues() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIProjectCalculatorMappingWorkflow-\(UUID().uuidString)")
            .appendingPathComponent("estimator.sqlite")
        let store = SQLiteEstimatorStore(databaseURL: databaseURL)
        let service = HybridRHEIREstimationService()
        let projectID = UUID()
        var project = Project(
            id: projectID,
            name: "Estimator Mapping Workflow",
            client: "Client D",
            clientAddress: "45 Market St, Boston, MA 02110",
            description: "Kitchen remodel with framing touchups, electrical trim, fixture resets, and finish carpentry.",
            totalBudget: 64000,
            startDate: .now,
            endDate: .now.addingTimeInterval(86400),
            organizationID: "org-estimator"
        )

        var receipt = Receipt(
            id: "workflow-receipt-1",
            vendor: "Builder Supply",
            date: .now,
            amount: 286.42,
            notes: "Framing hardware",
            category: .material,
            paymentMethod: "Card"
        )
        receipt.projectID = project.id

        let workHour = WorkHour(
            id: UUID(uuidString: "22B3A73B-D8A9-4AA3-B1A9-0E52036E7718")!,
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3 * 3600),
            lunchStart: nil,
            lunchEnd: nil,
            employee: "Sam Carter",
            employeeID: nil,
            rate: 48,
            category: "Framing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )

        let task = ProjectTask(
            id: UUID(uuidString: "BF5BB517-9FB0-44E0-A30F-3EEC7E36B744")!,
            title: "Install backing for cabinets",
            description: "Prep framing for cabinet layout.",
            priority: .high,
            category: .materials,
            estimatedHours: 3.5,
            actualHours: 0,
            projectID: project.id
        )

        project.receipts = [receipt]
        project.workHours = [workHour]
        project.tasks = [task]

        let viewModel = AIProjectCalculatorViewModel(project: project, service: service, store: store)
        viewModel.input.projectType = .residentialRemodel
        viewModel.input.zipCode = "02110"
        viewModel.input.scopePrompt = project.description
        viewModel.input.preferredVendors = ["Builder Supply"]
        viewModel.input.preferredStores = ["Local Supply"]
        viewModel.autoGenerateStarterTasks = false

        await viewModel.createSessionAndDraft(project: project, organizationProjects: [project])
        await viewModel.approveDraft(
            project: project,
            organizationProjects: [project],
            approvedByUserID: "user-456",
            applyBaseline: { _ in },
            generateTasks: { _, _ in }
        )

        let baseline = try #require(viewModel.approvedBaseline)
        let mappedLine = try #require(baseline.lines.first)

        await viewModel.mapReceipt(receipt, to: mappedLine.id, project: project)
        await viewModel.mapWorkHour(workHour, to: mappedLine.id, project: project)
        await viewModel.mapTask(task, to: mappedLine.id, project: project)

        var mappedTask = task
        mappedTask.budgetLineID = mappedLine.id
        mappedTask.estimateVersionID = baseline.estimateVersionID
        mappedTask.phaseName = mappedLine.phase

        var mappedProject = project
        mappedProject.tasks = [mappedTask]
        viewModel.rebuildVariance(project: mappedProject)

        #expect(viewModel.actualCostLinks.count == 3)
        #expect(Set(viewModel.actualCostLinks.map(\.sourceType)) == Set([.receipt, .workHour, .task]))
        #expect(viewModel.unmatchedReceipts(for: mappedProject).isEmpty)
        #expect(viewModel.unmatchedWorkHours(for: mappedProject).isEmpty)
        #expect(viewModel.unmatchedTasks(for: mappedProject).isEmpty)

        let varianceSnapshot = try #require(viewModel.varianceSnapshot)
        let mappedVariance = try #require(varianceSnapshot.lines.first(where: { $0.id == mappedLine.id }))

        #expect(mappedVariance.actual == receipt.amount + workHour.totalPay)
        #expect(mappedVariance.committed == mappedVariance.actual + (mappedTask.estimatedHours * max(mappedLine.unitCost, 1)))
        #expect(varianceSnapshot.totalActual == mappedVariance.actual)
        #expect(varianceSnapshot.totalCommitted == mappedVariance.committed)
    }
}
