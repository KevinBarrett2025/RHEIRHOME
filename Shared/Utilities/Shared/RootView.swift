import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            switch sessionStore.state {
            case .launching:
                SplashScreenView()
            case .ready:
                MainTabView()
            case .signedOut, .processingInvite, .selectingOrganization, .adminOnboarding:
                AuthRouterView()
            }
        }
        .environmentObject(authVM)
        .environmentObject(projectVM)
        .environmentObject(sessionStore)
        .onAppear {
            sessionStore.connectIfNeeded()
        }
    }
}
