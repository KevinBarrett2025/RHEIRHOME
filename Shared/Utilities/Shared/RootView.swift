import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    private let uiTestMode = ProcessInfo.processInfo.environment["RHEIR_UI_TEST_MODE"]

    var body: some View {
        Group {
            switch sessionStore.state {
            case .launching:
                SplashScreenView()
            case .ready:
                if uiTestMode == "budget_breakdown" {
                    BudgetBreakdownUITestRoot()
                } else {
                    MainTabView()
                }
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

private struct BudgetBreakdownUITestRoot: View {
    @State private var selectedTab: Tab = .projects

    var body: some View {
        NavigationStack {
            BudgetBreakdownView(selectedTab: $selectedTab)
        }
    }
}
