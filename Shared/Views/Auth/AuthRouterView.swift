import SwiftUI

struct AuthRouterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            if authViewModel.user != nil {
                productionUserFlow
            } else {
                // User not authenticated - show login
                LoginView(vm: authViewModel)
            }
        }
    }
    
    @ViewBuilder
    private var productionUserFlow: some View {
        if let pendingOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") {
            // Show loading screen while processing invite
            inviteProcessingView(orgName: pendingOrgName)
        } else if authViewModel.currentOrg != nil {
            // User has a current organization - proceed to main app
            MainTabView()
                .environmentObject(authViewModel)
        } else if authViewModel.isLoadingOrgs {
            // Loading organizations - show inline loading
            organizationLoadingView
        } else if !authViewModel.organizations.isEmpty {
            // User has organizations but no current org selected
            OrgListView(vm: authViewModel)
                .onAppear {
                    print("🏢 User has \(authViewModel.organizations.count) organizations - showing selection")
                }
        } else {
            // User has no organizations - show setup
            OrganizationSetupView()
                .environmentObject(authViewModel)
                .onAppear {
                    print("🏢 No organizations found - showing setup")
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
            
            if !authViewModel.inviteStatus.isEmpty {
                Text(authViewModel.inviteStatus)
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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