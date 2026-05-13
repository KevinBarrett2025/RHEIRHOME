import Foundation
import CloudKit
import Combine
import Testing
@testable import RHEIR

private final class RecordingProjectRepository: ProjectRepository {
    var fetchedProjectsByOrganization: [String: [Project]] = [:]
    var savedProjects: [(project: Project, organizationID: String)] = []
    var savedAssignmentsByOrganization: [String: [String]] = [:]

    func fetchProjects(for organizationID: String) async throws -> [Project] {
        fetchedProjectsByOrganization[organizationID] ?? []
    }

    func saveProject(_ project: Project, organizationID: String) async throws {
        savedProjects.append((project, organizationID))
    }

    func saveProjectAssignments(_ projectIDs: [String], organizationID: String) async throws {
        savedAssignmentsByOrganization[organizationID] = projectIDs
    }

    func loadProjectAssignments(organizationID: String) async -> [String] {
        savedAssignmentsByOrganization[organizationID] ?? []
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

        store.clearAllKnownSessionKeys()

        #expect(store.selectionState.organizationID == nil)
        #expect(store.selectionState.projectID == nil)
        #expect(store.previousOrganizationID == nil)
        #expect(store.pendingInvite == nil)
        #expect(store.lastSelectedProjectID(for: "org-1") == nil)
        #expect(store.appleEmail(for: "user-1") == nil)
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
        #expect(sessionStore.state == .selectingOrganization)

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
        #expect(compactedOrgProjects.first?.receipts.first?.receiptImageName == nil)
        #expect(compactedBackupProjects.first?.receipts.first?.receiptImageData == nil)
        #expect(compactedBackupProjects.first?.receipts.first?.receiptImageName == nil)
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
        #expect(loadedProjects.first?.receipts.first?.receiptImageName == nil)
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
        #expect(decodedProject.receipts.first?.receiptImageName == nil)
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
        #expect(decodedProjects.first?.receipts.first?.receiptImageName == nil)
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
