import SwiftUI

extension Notification.Name {
    static let deepLinkInvite = Notification.Name("deepLinkInvite")
}

struct RootView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showNewProject = false
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
                        // Auto-dismiss splash after short delay for initial app load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                isInitialAppLoading = false
                            }
                        }
                    }
            } else {
                // Route based on authentication state (no more splash interruptions)
                if authVM.user != nil && authVM.currentOrg != nil {
                    MainTabView()
                } else {
                    AuthRouterView()
                        .environmentObject(authVM)
                }
            }
        }
        .environmentObject(projectVM)
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
    }
}