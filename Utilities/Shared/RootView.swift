import SwiftUI

extension Notification.Name {
    static let deepLinkInvite = Notification.Name("deepLinkInvite")
}

struct RootView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // MARK: - Invite handling
    @State private var showAcceptInvite = false
    @State private var pendingInviteToken: String?
    
    // MARK: - Initial app loading state (separate from organization loading)
    @State private var isInitialAppLoading = true

    var body: some View {
        Group {
            // Show splash only during initial app launch
            if isInitialAppLoading {
                SplashScreenView()
                    .onAppear {
                        print("🚀 SPLASH: Showing splash screen")
                        // Connect the coordinator to view models
                        onboardingCoordinator.connect(authViewModel: authVM, projectViewModel: projectVM)
                        
                        // Auto-dismiss splash after short delay for initial app load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                print("🚀 SPLASH: Dismissing splash screen")
                                isInitialAppLoading = false
                            }
                        }
                    }
            } else {
                // ENTERPRISE STATE MACHINE ROUTING - Single source of truth
                switch onboardingCoordinator.state {
                case .splash:
                    SplashScreenView()
                    
                case .signIn:
                    AuthRouterView()
                        .environmentObject(authVM)
                        .environmentObject(onboardingCoordinator)
                        .onAppear {
                            print("🚀 ROUTING: Showing sign-in via OnboardingCoordinator")
                        }
                    
                case .createOrganization:
                    AuthRouterView()
                        .environmentObject(authVM)
                        .environmentObject(onboardingCoordinator)
                        .onAppear {
                            print("🚀 ROUTING: Showing organization setup via OnboardingCoordinator")
                        }
                    
                case .adminProfile(let organization):
                    AuthRouterView()
                        .environmentObject(authVM)
                        .environmentObject(onboardingCoordinator)
                        .onAppear {
                            print("🚀 ROUTING: Showing admin profile setup for \(organization.name)")
                        }
                    
                case .complete(let organization):
                    MainTabView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                        .onAppear {
                            print("🚀 ROUTING: Onboarding complete - showing MainTabView for \(organization.name)")
                        }
                }
            }
        }
        .sheet(isPresented: $showAcceptInvite) {
            if pendingInviteToken != nil {
                Text("Invite acceptance coming soon")
                    .navigationTitle("Accept Invite")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkInvite)) { notification in
            if let token = notification.object as? String {
                pendingInviteToken = token
                showAcceptInvite = true
            }
        }
        .onChange(of: authVM.user) { _, newUser in
            if newUser != nil {
                onboardingCoordinator.userDidSignIn()
            } else {
                onboardingCoordinator.userDidSignOut()
            }
        }
        .onChange(of: authVM.currentOrg) { _, newOrg in
            if let organization = newOrg {
                onboardingCoordinator.organizationDidCreate(organization)
            }
        }
    }
}