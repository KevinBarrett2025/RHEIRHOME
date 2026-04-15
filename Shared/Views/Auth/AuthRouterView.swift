import SwiftUI

struct AuthRouterView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            content
        }
        .animation(.easeInOut(duration: 0.2), value: sessionStore.state)
    }

    @ViewBuilder
    private var content: some View {
        switch sessionStore.state {
        case .launching:
            SplashScreenView()

        case .signedOut:
            LoginView(vm: authVM)

        case .processingInvite:
            inviteProcessingView(orgName: sessionStore.pendingInvite?.organizationName ?? "Organization")

        case .adminOnboarding:
            if let currentOrg = authVM.currentOrg {
                AdminOnboardingView(organization: currentOrg)
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                    .interactiveDismissDisabled(true)
            } else {
                organizationLoadingView
            }

        case .selectingOrganization:
            if authVM.isLoadingOrgs {
                organizationLoadingView
            } else if authVM.organizations.isEmpty {
                OrganizationSetupView()
                    .environmentObject(authVM)
            } else {
                OrgListView(vm: authVM)
                    .environmentObject(sessionStore)
            }

        case .ready:
            MainTabView()
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

            Text("Please wait while we connect you to the organization.")
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

            if let errorMessage = authVM.errorMessage ?? sessionStore.alertMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sessionStore.clearPendingInvite()
                        }
                        .buttonStyle(.bordered)

                        Button("Retry") {
                            sessionStore.retryPendingInvite()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Button("Cancel") {
                    sessionStore.clearPendingInvite()
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

            Text("Please wait while we fetch your organizations.")
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
        let authViewModel = AuthViewModel(service: CloudKitAuthService())
        let projectViewModel = ProjectViewModel(offlineDataManager: OfflineDataManager())

        AuthRouterView()
            .environmentObject(authViewModel)
            .environmentObject(projectViewModel)
            .environmentObject(
                SessionStore(
                    authViewModel: authViewModel,
                    projectViewModel: projectViewModel
                )
            )
    }
}
