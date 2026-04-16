import Combine
import Foundation
import SwiftUI

private enum UITestLaunchMode: String {
    case signedOut = "signed_out"
}

private enum UITestLaunchEnvironment {
    static let modeKey = "RHEIR_UI_TEST_MODE"
    static let skipLaunchDelayKey = "RHEIR_UI_TEST_SKIP_LAUNCH_DELAY"
}

private struct AppLaunchConfiguration {
    let uiTestMode: UITestLaunchMode?
    let launchDelayNanoseconds: UInt64

    init(processInfo: ProcessInfo = .processInfo) {
        let environment = processInfo.environment
        self.uiTestMode = UITestLaunchMode(rawValue: environment[UITestLaunchEnvironment.modeKey] ?? "")

        if environment[UITestLaunchEnvironment.skipLaunchDelayKey] == "1" || uiTestMode != nil {
            self.launchDelayNanoseconds = 0
        } else {
            self.launchDelayNanoseconds = 900_000_000
        }
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
        case .none:
            authService = CloudKitAuthService()
        }

        let authViewModel = AuthViewModel(service: authService)
        let projectViewModel = ProjectViewModel(offlineDataManager: OfflineDataManager())
        let sessionStore = SessionStore(
            authViewModel: authViewModel,
            projectViewModel: projectViewModel,
            localCache: .shared,
            launchDelayNanoseconds: launchConfiguration.launchDelayNanoseconds
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
