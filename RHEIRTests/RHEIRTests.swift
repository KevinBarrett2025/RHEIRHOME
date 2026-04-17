import Foundation
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
