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
        Group {
            if let pendingOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") {
                // Show loading screen while processing invite
                inviteProcessingView(orgName: pendingOrgName)
            } else if authViewModel.showAdminInfoUpdate, let currentOrg = authViewModel.currentOrg {
                // CRITICAL FIX: Show professional admin onboarding after organization creation
                AdminOnboardingView(organization: currentOrg)
                    .environmentObject(authViewModel)
                    .interactiveDismissDisabled(true) // Prevent accidental dismissal
                    .onAppear {
                        print("🎯 ADMIN ONBOARDING VIEW: Successfully displaying AdminOnboardingView")
                        print("   Organization: \(currentOrg.name)")
                        print("   Organization ID: \(currentOrg.id.prefix(8))...")
                        print("   showAdminInfoUpdate: \(authViewModel.showAdminInfoUpdate)")
                        print("   User: \(authViewModel.user?.email ?? "Unknown")")
                        print("✅ ROUTING SUCCESS: Admin onboarding flow triggered correctly")
                    }
                    .onDisappear {
                        print("🎯 ADMIN ONBOARDING VIEW: AdminOnboardingView disappearing")
                        print("   showAdminInfoUpdate flag: \(authViewModel.showAdminInfoUpdate)")
                        
                        if authViewModel.showAdminInfoUpdate {
                            print("⚠️ CRITICAL: Onboarding disappeared but flag still true!")
                            print("   This suggests premature dismissal - investigating...")
                            
                            // CRITICAL FIX: Add recovery mechanism
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if authViewModel.showAdminInfoUpdate {
                                    print("🔧 RECOVERY: Re-triggering admin onboarding after premature dismissal")
                                    authViewModel.objectWillChange.send()
                                }
                            }
                        } else {
                            print("✅ ONBOARDING COMPLETE: Properly finished - proceeding to MainTabView")
                        }
                    }
            } else if authViewModel.currentOrg != nil {
                // User has a current organization - proceed to main app
                MainTabView()
                    .environmentObject(authViewModel)
                    .onAppear {
                        print("🚀 MAIN APP: Showing MainTabView for authenticated user")
                        print("   Current organization: \(authViewModel.currentOrg?.name ?? "nil")")
                        print("   Organization ID: \(authViewModel.currentOrg?.id.prefix(8) ?? "nil")...")
                        print("   showAdminInfoUpdate: \(authViewModel.showAdminInfoUpdate)")
                        print("   User: \(authViewModel.user?.email ?? "Unknown")")
                        
                        // CRITICAL FIX: Enhanced debug - check if we should be in onboarding instead
                        if authViewModel.showAdminInfoUpdate {
                            print("⚠️ ROUTING ERROR: showAdminInfoUpdate is true but showing MainTabView!")
                            print("   This indicates a critical state management bug")
                            print("   Expected: AdminOnboardingView")
                            print("   Actual: MainTabView")
                            print("   Organization available: \(authViewModel.currentOrg != nil)")
                            
                            // CRITICAL FIX: Emergency recovery - force return to onboarding
                            print("🚨 EMERGENCY RECOVERY: Forcing return to admin onboarding")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                authViewModel.objectWillChange.send()
                                print("🔧 EMERGENCY: UI state refresh triggered")
                            }
                        } else {
                            print("✅ ROUTING CORRECT: MainTabView shown for completed admin profile")
                        }
                    }
            } else if authViewModel.isLoadingOrgs {
                // Loading organizations - show inline loading
                organizationLoadingView
                    .onAppear {
                        print("⏳ LOADING: Showing organization loading view")
                        print("   isLoadingOrgs: \(authViewModel.isLoadingOrgs)")
                    }
            } else if !authViewModel.organizations.isEmpty {
                // User has organizations but no current org selected
                OrgListView(vm: authViewModel)
                    .onAppear {
                        print("🏢 ORG SELECTION: User has \(authViewModel.organizations.count) organizations")
                        print("   Showing organization selection view")
                        print("   showAdminInfoUpdate: \(authViewModel.showAdminInfoUpdate)")
                    }
            } else if authViewModel.needsOrganizationSetup || authViewModel.showOrganizationSetup {
                // User has no organizations - show setup
                OrganizationSetupView()
                    .environmentObject(authViewModel)
                    .onAppear {
                        print("🏢 ORG SETUP: No organizations found - showing setup")
                        print("   needsOrganizationSetup: \(authViewModel.needsOrganizationSetup)")
                        print("   showOrganizationSetup: \(authViewModel.showOrganizationSetup)")
                        // Ensure we're not showing duplicate setup views
                        authViewModel.showOrganizationSetup = false
                    }
            } else {
                // Fallback - show organization setup
                OrganizationSetupView()
                    .environmentObject(authViewModel)
                    .onAppear {
                        print("🏢 FALLBACK: Showing organization setup as fallback")
                        print("   This should rarely be triggered")
                        authViewModel.showOrganizationSetup = false
                    }
            }
        }
        // CRITICAL FIX: Improve animation timing and add comprehensive state tracking
        .animation(.easeInOut(duration: 0.25), value: authViewModel.showAdminInfoUpdate)
        .animation(.easeInOut(duration: 0.25), value: authViewModel.currentOrg?.id)
        .onChange(of: authViewModel.showAdminInfoUpdate) { oldValue, newValue in
            print("🎯 STATE CHANGE: showAdminInfoUpdate \(oldValue) → \(newValue)")
            print("   Timestamp: \(Date().timeIntervalSince1970)")
            print("   Current Org: \(authViewModel.currentOrg?.name ?? "nil")")
            print("   Organizations count: \(authViewModel.organizations.count)")
            
            if newValue && authViewModel.currentOrg == nil {
                print("⚠️ INCONSISTENT STATE: showAdminInfoUpdate=true but no currentOrg!")
                print("   This should not happen - investigating...")
            } else if newValue && authViewModel.currentOrg != nil {
                print("✅ VALID STATE: Admin onboarding triggered with organization ready")
            } else if !newValue {
                print("✅ ONBOARDING COMPLETE: showAdminInfoUpdate set to false")
            }
        }
        .onChange(of: authViewModel.currentOrg) { oldValue, newValue in
            print("🏢 STATE CHANGE: currentOrg \(oldValue?.name ?? "nil") → \(newValue?.name ?? "nil")")
            print("   Timestamp: \(Date().timeIntervalSince1970)")
            print("   showAdminInfoUpdate: \(authViewModel.showAdminInfoUpdate)")
            
            if newValue != nil && authViewModel.showAdminInfoUpdate {
                print("✅ PERFECT TIMING: Organization set with pending admin onboarding")
            } else if newValue != nil && !authViewModel.showAdminInfoUpdate {
                print("✅ NORMAL FLOW: Organization change for existing admin")
            }
        }
        .onAppear {
            print("🎯 AUTH ROUTER: ProductionUserFlow appeared")
            print("   User: \(authViewModel.user?.email ?? "nil")")
            print("   showAdminInfoUpdate: \(authViewModel.showAdminInfoUpdate)")
            print("   currentOrg: \(authViewModel.currentOrg?.name ?? "nil")")
            print("   Organizations: \(authViewModel.organizations.count)")
            print("   isLoadingOrgs: \(authViewModel.isLoadingOrgs)")
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
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            authViewModel.clearPendingInvite()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Retry") {
                            authViewModel.retryPendingInvite()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                // Show cancel button after 10 seconds
                Button("Taking too long? Cancel") {
                    authViewModel.clearPendingInvite()
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