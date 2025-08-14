import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @AppStorage("preferredMapProvider") private var preferredMapProvider: MapProvider = .apple
    
    @StateObject private var resetService = CompleteDataResetService()
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showingNuclearResetAlert = false
    @State private var isResetting = false
    @State private var resetProgress = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingCacheAlert = false
    @State private var showingSubscriptionSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Organization Section
                if let org = authVM.currentOrg {
                    organizationSection(org)
                }
                
                // Enhanced Subscription Management
                subscriptionSection
                
                // Preferences Section
                preferencesSection
                
                // App Information
                appInfoSection
                
                // Debug & Maintenance Section
                debugSection
                
                // Account Actions
                accountSection
                
                // Development Section
                developmentSection
            }
            .navigationTitle("Personal App Toolbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // New Toolbox Icon
                    Image(systemName: "case.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingSubscriptionSheet) {
                SubscriptionTierSelectionView()
                    .environmentObject(authVM)
            }
            .alert("CloudKit Status", isPresented: $showingStatusAlert) {
                Button("OK") { }
            } message: {
                Text(statusMessage)
            }
            .alert("Nuclear Reset", isPresented: $showingNuclearResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset All Data", role: .destructive) {
                    performNuclearReset()
                }
            } message: {
                Text("This will permanently delete ALL local data and CloudKit data including:\n\n• All organizations\n• All team members\n• All vendors & payment methods\n• All cached projects\n• All settings\n\nThe app will restart automatically after reset. This cannot be undone.")
            }
            .alert("Debug Action", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Cache Cleared", isPresented: $showingCacheAlert) {
                Button("OK") { }
            } message: {
                Text("All local cache has been cleared. The app will refresh with fresh CloudKit data.")
            }
        }
    }
    
    @ViewBuilder
    private func organizationSection(_ organization: Organization) -> some View {
        Section("Organization") {
            NavigationLink(destination: EnhancedOrganizationDirectoryView(organization: organization)) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(organization.name) Directory")
                                .font(.headline)
                            
                            Spacer()
                            
                            // Organization Subscription Badge
                            InlineSubscriptionBadge(tier: organization.subscriptionTier)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CloudKit: \(organization.members.count + 1) app users")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Local: \(projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1) app users")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Team members: \(projectVM.teamMembers.filter { $0.employmentStatus == .active }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: OrganizationDebugView(organization: organization)) {
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Organization Data")
                            .font(.headline)
                        Text("See CloudKit vs Local data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: TeamInviteView().environmentObject(authVM).environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))) {
                HStack {
                    Image(systemName: "person.badge.plus.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invite Team Members")
                            .font(.headline)
                        Text("Share organization access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var subscriptionSection: some View {
        if let org = authVM.currentOrg {
            Section("Subscription Management") {
                Button(action: {
                    showingSubscriptionSheet = true
                }) {
                    HStack(spacing: 16) {
                        // Large subscription badge
                        SubscriptionBadgeView(tier: org.subscriptionTier, size: .medium, showLabel: false)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Current Plan")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                InlineSubscriptionBadge(tier: org.subscriptionTier)
                            }
                            
                            if org.subscriptionTier.monthlyPrice == 0 {
                                Text("Free • \(org.subscriptionTier.projectUsageDisplay(current: projectVM.projects.count)) projects")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("$\(Int(org.subscriptionTier.monthlyPrice))/month • \(org.subscriptionTier.projectUsageDisplay(current: projectVM.projects.count)) projects")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(org.subscriptionTier.teamMemberUsageDisplay(current: projectVM.teamMembers.count) + " team members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Manage your subscription tier and test features. This affects all organizations you belong to.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private var preferencesSection: some View {
        Section("App Preferences") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Updated Map Icon
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "map.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                        )
                    
                    Text("Default Map App")
                        .font(.headline)
                    
                    Spacer()
                }
                
                Picker("Map Provider", selection: $preferredMapProvider) {
                    ForEach(MapProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.vertical, 4)
            
            NavigationLink(destination: ChatGPTSettingsView()) {
                HStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ChatGPT Integration")
                            .font(.headline)
                        Text("AI-powered receipt processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var appInfoSection: some View {
        Section("App Information") {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version & Build")
                        .font(.headline)
                    Text("v1.0.0 (2025.1) • Enterprise Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var debugSection: some View {
        Section("Debug & Testing") {
            NavigationLink(destination: CloudKitDebugView()) {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CloudKit Debug Console")
                            .font(.headline)
                        Text("Test zone creation and sharing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: CloudKitDataView()) {
                HStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "cylinder.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CloudKit Data Browser")
                            .font(.headline)
                        Text("View raw CloudKit records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Fix Team Member Labor Hours") {
                let migrationStatus = projectVM.getLaborHoursMigrationStatus()
                
                if projectVM.needsLaborHoursMigration {
                    projectVM.migrateLaborHoursToTeamMemberIDs()
                    alertMessage = "✅ Migration completed!\n\n" + projectVM.getLaborHoursMigrationStatus()
                } else {
                    alertMessage = "ℹ️ No migration needed.\n\n" + migrationStatus
                }
                
                showingAlert = true
            }
            .foregroundColor(.purple)
            
            Button("🆘 Emergency Data Recovery") {
                Task {
                    let recoveryReport = await projectVM.emergencyDataRecovery()
                    await MainActor.run {
                        alertMessage = recoveryReport
                        showingAlert = true
                    }
                }
            }
            .foregroundColor(.red)
            
            Button("Show Labor Hours Migration Status") {
                alertMessage = projectVM.getLaborHoursMigrationStatus()
                showingAlert = true
            }
            .foregroundColor(.blue)
            
            Button("Clear Pending Invites") {
                UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
                UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
                UserDefaults.standard.removeObject(forKey: "pending_invite_token")
                
                alertMessage = "Cleared all pending invite data"
                showingAlert = true
            }
            .foregroundColor(.orange)
            
            Button("Show UserDefaults Keys") {
                let keys = UserDefaults.standard.dictionaryRepresentation().keys
                let rheirKeys = keys.filter { $0.contains("invite") || $0.contains("org") || $0.contains("RHEIR") }
                
                alertMessage = "RHEIR-related keys:\n\(rheirKeys.joined(separator: "\n"))"
                showingAlert = true
            }
            .foregroundColor(.blue)
            
            Button("Force Zone Recreation") {
                Task {
                    statusMessage = await authVM.repairMissingOrganizationZones()
                    showingStatusAlert = true
                }
            }
            .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let user = authVM.user {
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in as")
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Button("Sign Out") {
                authVM.signOut()
            }
            .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var developmentSection: some View {
        Section("Development & Debug") {
            Group {
                NavigationLink(destination: CloudKitDebugView()) {
                    Label("CloudKit Debug", systemImage: "icloud.and.arrow.up.and.down")
                }
                
                NavigationLink(destination: CloudKitConsistencyDebugView(authVM: authVM)) {
                    Label("Data Consistency Debug", systemImage: "checkmark.shield")
                        .foregroundColor(.orange)
                }
                
                NavigationLink(destination: OrganizationDebugView()) {
                    Label("Organization Debug", systemImage: "building.2")
                }
                
                Button(action: {
                    authVM.clearAllLocalCache()
                    showingCacheAlert = true
                }) {
                    Label("Nuclear Reset", systemImage: "trash.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Legacy Methods (keep for compatibility)
    
    private func fixOrganizationIDs() {
        projectVM.fixMissingOrganizationIDs { success, message in
            statusMessage = message
            showingStatusAlert = true
        }
    }
    
    private func performNuclearReset() {
        isResetting = true
        resetProgress = "Starting nuclear reset..."
        
        Task {
            do {
                try await resetService.performCompleteReset()
                
                await MainActor.run {
                    resetProgress = "Reset complete! Restarting app..."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        restartApp()
                    }
                }
            } catch {
                await MainActor.run {
                    isResetting = false
                    statusMessage = "❌ Nuclear reset failed: \(error.localizedDescription)"
                    showingStatusAlert = true
                }
            }
        }
    }
    
    private func restartApp() {
        #if os(iOS)
        exit(0)
        #else
        NSApplication.shared.terminate(nil)
        #endif
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}