import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum UITestLaunchMode: String {
    case signedOut = "signed_out"
    case ready = "ready"
    case noOrganization = "no_organization"
    case selectingOrganization = "selecting_organization"
    case projectSelection = "project_selection"
    case selectedProject = "selected_project"
    case laborManagement = "labor_management"
    case taskManagement = "task_management"
    case estimatorMapping = "estimator_mapping"
    case scannedReceiptReview = "scanned_receipt_review"
    case mixedCategoryReceipt = "mixed_category_receipt"
    case restoredSession = "restored_session"
}

private enum UITestLaunchEnvironment {
    static let modeKey = "RHEIR_UI_TEST_MODE"
    static let skipLaunchDelayKey = "RHEIR_UI_TEST_SKIP_LAUNCH_DELAY"
    static let preserveStateKey = "RHEIR_UI_TEST_PRESERVE_STATE"
}

private struct AppLaunchConfiguration {
    let uiTestMode: UITestLaunchMode?
    let launchDelayNanoseconds: UInt64
    let shouldConnectProjectViewModel: Bool
    let shouldPreserveState: Bool

    init(processInfo: ProcessInfo = .processInfo) {
        let environment = processInfo.environment
        self.uiTestMode = UITestLaunchMode(rawValue: environment[UITestLaunchEnvironment.modeKey] ?? "")
        self.shouldPreserveState = environment[UITestLaunchEnvironment.preserveStateKey] == "1"
        self.shouldConnectProjectViewModel = uiTestMode == nil

        if environment[UITestLaunchEnvironment.skipLaunchDelayKey] == "1" || uiTestMode != nil {
            self.launchDelayNanoseconds = 0
        } else {
            self.launchDelayNanoseconds = 900_000_000
        }
    }

    @MainActor
    func applyBootstrap(authViewModel: AuthViewModel, projectViewModel: ProjectViewModel) {
        switch uiTestMode {
        case .ready:
            let user = User(id: "ui-test-ready-user", email: "ready-ui-test@rheirhome.com")
            let organization = Organization(
                id: "ui-test-ready-org",
                name: "UI Test Contracting",
                members: [user.id],
                adminUserID: user.id
            )

            applyCommonBootstrap(
                authViewModel: authViewModel,
                projectViewModel: projectViewModel,
                user: user,
                organizations: [organization],
                organizationRoles: [organization.id: .admin]
            )
            authViewModel.setCurrentOrganization(organization)
            projectViewModel.setCurrentOrganization(organization, role: .admin)

        case .noOrganization:
            let user = User(id: "ui-test-no-org-user", email: "no-org-ui-test@rheirhome.com")
            applyCommonBootstrap(
                authViewModel: authViewModel,
                projectViewModel: projectViewModel,
                user: user,
                organizations: [],
                organizationRoles: [:]
            )

        case .selectingOrganization:
            let user = User(id: "ui-test-org-user", email: "org-ui-test@rheirhome.com")
            let builderOrganization = Organization(
                id: "ui-test-org-builders",
                name: "UI Test Builders",
                members: [user.id, "builder-member-2"],
                adminUserID: user.id
            )
            let roofingOrganization = Organization(
                id: "ui-test-org-roofing",
                name: "Ready Roofing Co",
                members: [user.id],
                adminUserID: "roofing-admin"
            )

            applyCommonBootstrap(
                authViewModel: authViewModel,
                projectViewModel: projectViewModel,
                user: user,
                organizations: [builderOrganization, roofingOrganization],
                organizationRoles: [
                    builderOrganization.id: .admin,
                    roofingOrganization.id: .contractor
                ]
            )
            authViewModel.currentOrg = nil

        case .projectSelection, .selectedProject, .laborManagement, .taskManagement, .estimatorMapping, .scannedReceiptReview, .mixedCategoryReceipt:
            let user = User(id: "ui-test-project-user", email: "project-ui-test@rheirhome.com")
            let organization = Organization(
                id: "ui-test-project-org",
                name: "Project Picker Builders",
                members: [user.id, "project-member-2"],
                adminUserID: user.id
            )
            let kitchenProjectSeed = makeUITestProject(
                id: UUID(uuidString: "A7A92AF6-2E2B-4F51-BEA4-4B53CF2A7D11")!,
                name: "Kitchen Remodel",
                client: "Avery Homes",
                organizationID: organization.id
            )
            let kitchenProject: Project
            switch uiTestMode {
            case .laborManagement, .taskManagement:
                kitchenProject = makeUITestLaborManagementProject(from: kitchenProjectSeed).project
            case .estimatorMapping:
                kitchenProject = makeUITestEstimatorMappingProject(from: kitchenProjectSeed)
            case .mixedCategoryReceipt:
                kitchenProject = makeUITestMixedCategoryProject(from: kitchenProjectSeed)
            default:
                kitchenProject = kitchenProjectSeed
            }
            let bathProject = makeUITestProject(
                id: UUID(uuidString: "4F874307-DB41-446C-9A9E-DB94283E4E28")!,
                name: "Primary Bath Upgrade",
                client: "Northline Custom",
                organizationID: organization.id
            )
            var completedProject = makeUITestProject(
                id: UUID(uuidString: "2D617D4E-8B4F-4C3A-B874-2F774AAFE61C")!,
                name: "Completed Deck Build",
                client: "Harper Family",
                organizationID: organization.id
            )
            completedProject.status = .completed
            completedProject.receipts = [
                Receipt(
                    id: "ui-test-completed-receipt-001",
                    vendor: "Lumber Yard",
                    date: Date(timeIntervalSince1970: 1_737_676_800),
                    amount: 812.44,
                    category: .material,
                    paymentMethod: "Card"
                )
            ]

            applyCommonBootstrap(
                authViewModel: authViewModel,
                projectViewModel: projectViewModel,
                user: user,
                organizations: [organization],
                organizationRoles: [organization.id: .admin]
            )
            authViewModel.setCurrentOrganization(organization)
            projectViewModel.currentOrganization = organization
            projectViewModel.currentOrganizationRole = .admin
            projectViewModel.currentOrganizationID = organization.id
            projectViewModel.isUsingCloudKitForOrganizationData = false
            projectViewModel.projects = [kitchenProject, bathProject, completedProject]
            projectViewModel.organizationProjects = [kitchenProject, bathProject, completedProject]
            projectViewModel.accessibleProjects = [kitchenProject, bathProject, completedProject]
            if uiTestMode == .laborManagement || uiTestMode == .taskManagement {
                let seed = makeUITestLaborManagementProject(from: kitchenProjectSeed)
                let selectedProject = uiTestMode == .taskManagement
                    ? makeUITestTaskManagementProject(from: seed.project, teamMembers: seed.teamMembers)
                    : seed.project
                projectViewModel.projects = [selectedProject, bathProject, completedProject]
                projectViewModel.organizationProjects = [selectedProject, bathProject, completedProject]
                projectViewModel.accessibleProjects = [selectedProject, bathProject, completedProject]
                seed.teamMembers.forEach { member in
                    projectViewModel.addTeamMemberToOrganization(member)
                }
                projectViewModel.selectProject(selectedProject)
                projectViewModel.recomputeLaborData()
            } else if uiTestMode == .selectedProject || uiTestMode == .estimatorMapping || uiTestMode == .scannedReceiptReview || uiTestMode == .mixedCategoryReceipt {
                projectViewModel.selectProject(kitchenProject)
            } else {
                projectViewModel.deselectProject()
            }

        case .restoredSession:
            let user = User(id: "ui-test-project-user", email: "project-ui-test@rheirhome.com")
            let organization = Organization(
                id: "ui-test-project-org",
                name: "Project Picker Builders",
                members: [user.id, "project-member-2"],
                adminUserID: user.id
            )

            applyCommonBootstrap(
                authViewModel: authViewModel,
                projectViewModel: projectViewModel,
                user: user,
                organizations: [organization],
                organizationRoles: [organization.id: .admin]
            )
            let localCache = LocalCacheStore.shared
            let restoredProjects = ProjectStore().loadProjects(for: organization.id)

            authViewModel.currentOrg = organization
            projectViewModel.currentOrganization = organization
            projectViewModel.currentOrganizationRole = .admin
            projectViewModel.currentOrganizationID = organization.id
            projectViewModel.isUsingCloudKitForOrganizationData = false
            projectViewModel.projects = restoredProjects
            projectViewModel.organizationProjects = restoredProjects
            projectViewModel.accessibleProjects = restoredProjects

            let restoredProjectID = localCache.lastSelectedProjectID(for: organization.id)
                ?? localCache.selectionState.projectID
            if let restoredProjectID,
               let restoredProject = restoredProjects.first(where: { $0.id.uuidString == restoredProjectID }) {
                projectViewModel.selectProject(restoredProject)
            }

        case .signedOut, .none:
            break
        }
    }

    @MainActor
    private func applyCommonBootstrap(
        authViewModel: AuthViewModel,
        projectViewModel: ProjectViewModel,
        user: User,
        organizations: [Organization],
        organizationRoles: [String: OrganizationRole]
    ) {
        authViewModel.user = user
        authViewModel.organizations = organizations
        authViewModel.userOrganizations = organizations
        authViewModel.organizationRoles = organizationRoles
        authViewModel.currentOrg = nil
        authViewModel.errorMessage = nil
        authViewModel.inviteStatus = ""
        authViewModel.isLoadingOrgs = false
        authViewModel.needsOrganizationSetup = false
        authViewModel.showOrganizationSetup = false
        authViewModel.showAdminInfoUpdate = false

        projectViewModel.projects = []
        projectViewModel.organizationProjects = []
        projectViewModel.accessibleProjects = []
        projectViewModel.deselectProject()
    }

    private func makeUITestProject(
        id: UUID,
        name: String,
        client: String,
        organizationID: String
    ) -> Project {
        Project(
            id: id,
            name: name,
            client: client,
            description: "\(name) UI smoke project",
            totalBudget: 48_000,
            materialCost: 12_500,
            laborCost: 8_000,
            startDate: Date(timeIntervalSince1970: 1_735_171_200),
            endDate: Date(timeIntervalSince1970: 1_741_392_000),
            status: .active,
            priority: .high,
            assignedUserIDs: [],
            organizationID: organizationID
        )
    }

    private func makeUITestEstimatorMappingProject(from project: Project) -> Project {
        var seededProject = project

        var receipt = Receipt(
            id: "ui-test-estimator-receipt-001",
            vendor: "Builder Supply",
            date: Date(timeIntervalSince1970: 1_736_207_200),
            amount: 286.42,
            notes: "Blocking and framing hardware",
            category: .material,
            paymentMethod: "Card"
        )
        receipt.projectID = project.id

        let workHour = WorkHour(
            id: UUID(uuidString: "5D8CB53E-67D7-468C-8171-1A0A0C830511")!,
            date: Date(timeIntervalSince1970: 1_736_208_000),
            startTime: Date(timeIntervalSince1970: 1_736_208_000),
            endTime: Date(timeIntervalSince1970: 1_736_222_400),
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
            id: UUID(uuidString: "8A6A2F75-0B87-4E33-9264-BF6C3E3BC84D")!,
            title: "Install backing for kitchen cabinets",
            description: "Prep the wall framing for cabinet layout and blocking.",
            priority: .high,
            category: .materials,
            estimatedHours: 3.5,
            actualHours: 0,
            projectID: project.id
        )

        seededProject.receipts = [receipt]
        seededProject.workHours = [workHour]
        seededProject.tasks = [task]
        return seededProject
    }

    private func makeUITestLaborManagementProject(from project: Project) -> (project: Project, teamMembers: [TeamMember]) {
        let leadID = UUID(uuidString: "AA8E5BDE-0B7E-4632-B2D4-DF74D104F0E1")!
        let helperID = UUID(uuidString: "BC02E8DE-0E43-4B8A-BA12-4B8E99730BE7")!
        let lead = TeamMember(
            id: leadID,
            name: "Sam Carter",
            email: "sam@example.com",
            phone: "555-0100",
            jobTitle: "Lead Carpenter",
            rates: [EmployeeRate(taskType: "Framing", rate: 52, isDefault: true)],
            organizationID: project.organizationID
        )
        let helper = TeamMember(
            id: helperID,
            name: "Mia Lopez",
            email: "mia@example.com",
            phone: "555-0101",
            jobTitle: "Helper",
            rates: [EmployeeRate(taskType: "Labor", rate: 34, isDefault: true)],
            organizationID: project.organizationID
        )

        var unpaidHour = WorkHour(
            id: UUID(uuidString: "DA7A5D5E-9150-43EE-B0E4-B9CE93457D15")!,
            date: Date(timeIntervalSince1970: 1_736_208_000),
            startTime: Date(timeIntervalSince1970: 1_736_208_000),
            endTime: Date(timeIntervalSince1970: 1_736_222_400),
            lunchStart: nil,
            lunchEnd: nil,
            employee: lead.name,
            employeeID: lead.id,
            rate: 52,
            category: "Framing",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        unpaidHour.recordPayment(
            amount: 80,
            method: "Cash",
            reference: "PARTIAL-01",
            note: "Partial advance"
        )

        var paidHour = WorkHour(
            id: UUID(uuidString: "B0F08852-83BF-460C-8D9B-7A5E7C0F5B20")!,
            date: Date(timeIntervalSince1970: 1_736_294_400),
            startTime: Date(timeIntervalSince1970: 1_736_294_400),
            endTime: Date(timeIntervalSince1970: 1_736_305_200),
            lunchStart: nil,
            lunchEnd: nil,
            employee: helper.name,
            employeeID: helper.id,
            rate: 34,
            category: "Cleanup",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        paidHour.recordPayment(
            amount: paidHour.effectiveUnpaidAmount,
            method: "Check",
            reference: "1021",
            note: "Weekly payroll"
        )

        var seededProject = project
        seededProject.loggedHours = [unpaidHour, paidHour]
        seededProject.assignTeamMember(lead.id.uuidString)
        seededProject.assignTeamMember(helper.id.uuidString)
        return (seededProject, [lead, helper])
    }

    private func makeUITestTaskManagementProject(from project: Project, teamMembers: [TeamMember]) -> Project {
        var seededProject = project
        let leadID = teamMembers[0].id
        let helperID = teamMembers[1].id
        seededProject.tasks = [
            ProjectTask(
                id: UUID(uuidString: "A11B1F20-08A0-4B3B-9A52-9A687EE92001")!,
                title: "Frame pantry wall",
                description: "Frame the new pantry opening before inspection.",
                dueDate: Date(timeIntervalSinceNow: -86_400),
                priority: .high,
                category: .general,
                estimatedHours: 4,
                projectID: project.id,
                assignedEmployeeIDs: [leadID]
            ),
            ProjectTask(
                id: UUID(uuidString: "A11B1F20-08A0-4B3B-9A52-9A687EE92002")!,
                title: "Protect finished floors",
                description: "Lay ram board before cabinet delivery.",
                dueDate: Date(timeIntervalSinceNow: 86_400),
                priority: .medium,
                category: .cleanup,
                estimatedHours: 1,
                projectID: project.id,
                assignedEmployeeIDs: [helperID]
            )
        ]
        return seededProject
    }

    private func makeUITestMixedCategoryProject(from project: Project) -> Project {
        var seededProject = project

        var receipt = Receipt(
            id: "ui-test-mixed-category-receipt-001",
            vendor: "UI Test Mixed Category Vendor",
            date: Date(timeIntervalSince1970: 1_736_207_200),
            amount: 36.29,
            notes: "Mixed-category Home Depot run",
            category: .material,
            paymentMethod: "Credit Card"
        )
        receipt.projectID = project.id
        receipt.receiptNumber = "MIX-3629"
        receipt.taxAmount = 2.29
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

        #if canImport(UIKit)
        receipt.setReceiptImage(makeUITestReceiptImage())
        #endif

        seededProject.receipts = [receipt]
        return seededProject
    }

    #if canImport(UIKit)
    private func makeUITestReceiptImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 640))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 640))

            UIColor(white: 0.94, alpha: 1).setFill()
            context.fill(CGRect(x: 24, y: 24, width: 272, height: 592))

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            NSString(string: "Mixed Category Supply").draw(at: CGPoint(x: 40, y: 52), withAttributes: titleAttributes)

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
            NSString(string: "Copper Tee      $12.34").draw(at: CGPoint(x: 40, y: 124), withAttributes: bodyAttributes)
            NSString(string: "2x4 Stud        $15.55").draw(at: CGPoint(x: 40, y: 160), withAttributes: bodyAttributes)
            NSString(string: "Roof Patch      $8.40").draw(at: CGPoint(x: 40, y: 196), withAttributes: bodyAttributes)
            NSString(string: "Tax             $2.29").draw(at: CGPoint(x: 40, y: 264), withAttributes: bodyAttributes)
            NSString(string: "Total           $36.29").draw(at: CGPoint(x: 40, y: 300), withAttributes: bodyAttributes)
            NSString(string: "Receipt # MIX-3629").draw(at: CGPoint(x: 40, y: 352), withAttributes: bodyAttributes)
        }
    }
    #endif
}

private final class SignedOutUITestAuthService: AuthService {
    var currentUser: User?

    init() {
        self.currentUser = nil
    }

    func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: Self.unsupportedError("Sign-up is unavailable in signed-out UI test mode."))
            .eraseToAnyPublisher()
    }

    func login(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: Self.unsupportedError("Login is unavailable in signed-out UI test mode."))
            .eraseToAnyPublisher()
    }

    func signInWithApple() -> AnyPublisher<User, Error> {
        Fail(error: Self.unsupportedError("Apple Sign-In is unavailable in signed-out UI test mode."))
            .eraseToAnyPublisher()
    }

    func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        Fail(error: Self.unsupportedError("Invites are unavailable in signed-out UI test mode."))
            .eraseToAnyPublisher()
    }

    func signOut() {
        currentUser = nil
    }

    private static func unsupportedError(_ description: String) -> NSError {
        NSError(
            domain: "SignedOutUITestAuthService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

@main
struct RheirApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var projectViewModel: ProjectViewModel
    @StateObject private var sessionStore: SessionStore

    init() {
        let launchConfiguration = AppLaunchConfiguration()
        if launchConfiguration.uiTestMode != nil && !launchConfiguration.shouldPreserveState {
            LocalCacheStore.shared.clearAllKnownSessionKeys()
            ProjectStore().clearAllStoredData()
            OfflineStorageManager.clearUITestArtifacts()
            SQLiteEstimatorStore.clearUITestArtifacts()
        }
        let authService: AuthService

        switch launchConfiguration.uiTestMode {
        case .signedOut:
            authService = SignedOutUITestAuthService()
        case .ready:
            authService = SignedOutUITestAuthService()
        case .noOrganization:
            authService = SignedOutUITestAuthService()
        case .selectingOrganization:
            authService = SignedOutUITestAuthService()
        case .projectSelection:
            authService = SignedOutUITestAuthService()
        case .selectedProject:
            authService = SignedOutUITestAuthService()
        case .laborManagement:
            authService = SignedOutUITestAuthService()
        case .taskManagement:
            authService = SignedOutUITestAuthService()
        case .estimatorMapping:
            authService = SignedOutUITestAuthService()
        case .scannedReceiptReview:
            authService = SignedOutUITestAuthService()
        case .mixedCategoryReceipt:
            authService = SignedOutUITestAuthService()
        case .restoredSession:
            authService = SignedOutUITestAuthService()
        case .none:
            authService = CloudKitAuthService()
        }

        let authViewModel = AuthViewModel(service: authService)
        let projectViewModel = ProjectViewModel(offlineDataManager: OfflineDataManager())
        launchConfiguration.applyBootstrap(authViewModel: authViewModel, projectViewModel: projectViewModel)
        let sessionStore = SessionStore(
            authViewModel: authViewModel,
            projectViewModel: projectViewModel,
            localCache: .shared,
            launchDelayNanoseconds: launchConfiguration.launchDelayNanoseconds,
            shouldConnectProjectViewModel: launchConfiguration.shouldConnectProjectViewModel
        )

        _authViewModel = StateObject(wrappedValue: authViewModel)
        _projectViewModel = StateObject(wrappedValue: projectViewModel)
        _sessionStore = StateObject(wrappedValue: sessionStore)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(projectViewModel)
                .environmentObject(sessionStore)
                .onOpenURL { url in
                    sessionStore.handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        sessionStore.handleIncomingURL(url)
                    }
                }
        }
    }
}
