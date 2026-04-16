import Combine
import Foundation
import SwiftUI

private enum UITestLaunchMode: String {
    case signedOut = "signed_out"
    case ready = "ready"
}

private enum UITestLaunchEnvironment {
    static let modeKey = "RHEIR_UI_TEST_MODE"
    static let skipLaunchDelayKey = "RHEIR_UI_TEST_SKIP_LAUNCH_DELAY"
}

private struct AppLaunchConfiguration {
    let uiTestMode: UITestLaunchMode?
    let launchDelayNanoseconds: UInt64
    let shouldConnectProjectViewModel: Bool

    init(processInfo: ProcessInfo = .processInfo) {
        let environment = processInfo.environment
        self.uiTestMode = UITestLaunchMode(rawValue: environment[UITestLaunchEnvironment.modeKey] ?? "")
        self.shouldConnectProjectViewModel = uiTestMode == nil

        if environment[UITestLaunchEnvironment.skipLaunchDelayKey] == "1" || uiTestMode != nil {
            self.launchDelayNanoseconds = 0
        } else {
            self.launchDelayNanoseconds = 900_000_000
        }
    }

    @MainActor
    func applyBootstrap(authViewModel: AuthViewModel, projectViewModel: ProjectViewModel) {
        guard uiTestMode == .ready else { return }

        let user = User(id: "ui-test-ready-user", email: "ready-ui-test@rheirhome.com")
        let organization = Organization(
            id: "ui-test-ready-org",
            name: "UI Test Contracting",
            members: [user.id],
            adminUserID: user.id
        )

        authViewModel.user = user
        authViewModel.organizations = [organization]
        authViewModel.userOrganizations = [organization]
        authViewModel.organizationRoles = [organization.id: .admin]
        authViewModel.errorMessage = nil
        authViewModel.inviteStatus = ""
        authViewModel.isLoadingOrgs = false
        authViewModel.needsOrganizationSetup = false
        authViewModel.showOrganizationSetup = false
        authViewModel.showAdminInfoUpdate = false
        authViewModel.setCurrentOrganization(organization)

        projectViewModel.projects = []
        projectViewModel.organizationProjects = []
        projectViewModel.accessibleProjects = []
        projectViewModel.deselectProject()
        projectViewModel.setCurrentOrganization(organization, role: .admin)
    }
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
        let authService: AuthService

        switch launchConfiguration.uiTestMode {
        case .signedOut:
            authService = SignedOutUITestAuthService()
        case .ready:
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
