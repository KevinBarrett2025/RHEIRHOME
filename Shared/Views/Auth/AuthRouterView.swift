import SwiftUI

struct AuthRouterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel

    var body: some View {
        NavigationStack {
            if authVM.user != nil {
                productionUserFlow
            } else {
                // User not authenticated - show login
                LoginView(vm: authVM)
            }
        }
    }
    
    @ViewBuilder
    private var productionUserFlow: some View {
        Group {
            if let pendingOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") {
                // Show loading screen while processing invite
                inviteProcessingView(orgName: pendingOrgName)
            } else if authVM.needsOrganizationSetup || authVM.showOrganizationSetup {
                // PRIORITY 1: Show integrated organization setup (includes admin onboarding)
                IntegratedOrganizationSetupView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                    .onAppear {
                        print("🏢 INTEGRATED SETUP: Showing integrated organization setup")
                        print("   needsOrganizationSetup: \(authVM.needsOrganizationSetup)")
                        print("   showOrganizationSetup: \(authVM.showOrganizationSetup)")
                    }
            } else if authVM.showAdminInfoUpdate, let currentOrg = authVM.currentOrg {
                // PRIORITY 2: Show separate admin onboarding (only if not using integrated setup)
                AdminOnboardingView(organization: currentOrg)
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                    .interactiveDismissDisabled(true)
                    .onAppear {
                        print("🎯 SEPARATE ADMIN ONBOARDING: Showing AdminOnboardingView")
                        print("   Organization: \(currentOrg.name)")
                        print("   This should only appear for legacy flows")
                    }
            } else if authVM.currentOrg != nil {
                // PRIORITY 3: User has organization - show main app
                MainTabView()
                    .environmentObject(authVM)
                    .onAppear {
                        print("🚀 MAIN APP: Showing MainTabView for authenticated user")
                        print("   Current organization: \(authVM.currentOrg?.name ?? "nil")")
                        print("   Organization ID: \(authVM.currentOrg?.id.prefix(8) ?? "nil")...")
                        print("   showAdminInfoUpdate: \(authVM.showAdminInfoUpdate)")
                        print("   User: \(authVM.user?.email ?? "Unknown")")
                        print("✅ ROUTING CORRECT: MainTabView shown for completed setup")
                    }
            } else if authVM.isLoadingOrgs {
                // Loading organizations - show inline loading
                organizationLoadingView
                    .onAppear {
                        print("⏳ LOADING: Showing organization loading view")
                        print("   isLoadingOrgs: \(authVM.isLoadingOrgs)")
                    }
            } else if !authVM.organizations.isEmpty {
                // User has organizations but no current org selected
                OrgListView(vm: authVM)
                    .onAppear {
                        print("🏢 ORG SELECTION: User has \(authVM.organizations.count) organizations")
                        print("   Showing organization selection view")
                    }
            } else {
                // Fallback - show integrated setup
                IntegratedOrganizationSetupView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                    .onAppear {
                        print("🏢 FALLBACK: Showing integrated setup as fallback")
                    }
            }
        }
    }
    
    @ViewBuilder
    private func inviteProcessingView(orgName: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Joining \(orgName)...")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Please wait while we connect you to the organization")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !authVM.inviteStatus.isEmpty {
                Text(authVM.inviteStatus)
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let errorMessage = authVM.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            authVM.clearPendingInvite()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Retry") {
                            authVM.retryPendingInvite()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                // Show cancel button after 10 seconds
                Button("Taking too long? Cancel") {
                    authVM.clearPendingInvite()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .font(.caption)
                .opacity(0.7)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var organizationLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Organizations...")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Please wait while we fetch your organizations")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct AuthRouterView_Previews: PreviewProvider {
    static var previews: some View {
        AuthRouterView()
            .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}