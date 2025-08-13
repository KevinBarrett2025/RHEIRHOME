import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @AppStorage("preferredMapProvider") private var preferredMapProvider: MapProvider = .apple
    
    @StateObject private var resetService = CompleteDataResetService()
    
    var body: some View {
        NavigationStack {
            List {
                // Organization Section
                if let org = authVM.currentOrg {
                    organizationSection(org)
                }
                
                // Preferences Section
                preferencesSection
                
                // App Information
                appInfoSection
                
                // Debug & Maintenance Section
                debugSection
                
                // Account Actions
                accountSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
                Text("This will permanently delete ALL local data and CloudKit data including:\n\n• All 26 organizations\n• All team members\n• All vendors & payment methods\n• All cached projects\n• All settings\n\nThe app will restart automatically after reset. This cannot be undone.")
            }
            .alert("Debug Action", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
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
                        Text("\(organization.name) Directory")
                            .font(.headline)
                        // Debug: Show both counts to identify discrepancy
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
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Debug section to see organization members
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
    private var preferencesSection: some View {
        Section("Preferences") {
            // Map Provider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
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
            
            // Subscription Tier Testing
            subscriptionTierRow
            
            // ChatGPT Settings
            NavigationLink(destination: ChatGPTSettingsView()) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
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
    private var subscriptionTierRow: some View {
        if let org = authVM.currentOrg {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Tier (Testing)")
                        .font(.headline)
                    Text("Current: \(org.subscriptionTier.displayName) - $\(String(format: "%.0f", org.subscriptionTier.monthlyPrice))/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu("Change") {
                    ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                        Button("\(tier.displayName) - $\(String(format: "%.0f", tier.monthlyPrice))/month") {
                            authVM.updateSubscriptionTier(tier)
                        }
                    }
                }
                .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var appInfoSection: some View {
        Section("App Information") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("2025.1")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var debugSection: some View {
        Section("Debug & Testing") {
            NavigationLink(destination: CloudKitDebugView()) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
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
                    Image(systemName: "cylinder.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
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
            
            // MIGRATION SECTION - CRITICAL FIX
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
                    Text("Signed in as")
                    Spacer()
                    Text(user.email)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Sign Out") {
                authVM.signOut()
            }
            .foregroundColor(.red)
        }
    }
    
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showingNuclearResetAlert = false
    @State private var isResetting = false
    @State private var resetProgress = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                // Use the complete reset service for comprehensive cleanup
                try await resetService.performCompleteReset()
                
                await MainActor.run {
                    resetProgress = "Reset complete! Restarting app..."
                    
                    // Force app restart after a short delay
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
        // Force terminate the app - user will need to manually restart
        // This is the most reliable way to ensure clean state
        exit(0)
        #else
        // On macOS
        NSApplication.shared.terminate(nil)
        #endif
    }
}

// MARK: - Supporting Views (unchanged from original)

struct OrganizationDirectoryView: View {
    let organization: Organization
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingAddMember = false
    
    var body: some View {
        List {
            teamMembersSection
            organizationSettingsSection
        }
        .navigationTitle("\(organization.name) Directory")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddMember) {
            AddEmployeeView(isPresented: $showingAddMember)
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private var teamMembersSection: some View {
        Section("Team Members") {
            ForEach(projectVM.teamMembers) { member in
                teamMemberRow(member)
            }
            
            addTeamMemberButton
        }
    }
    
    @ViewBuilder
    private func teamMemberRow(_ member: TeamMember) -> some View {
        NavigationLink(destination: TeamMemberDetailView(member: member)) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.headline)
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !member.email.isEmpty {
                        Text(member.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let defaultRate = member.defaultRate {
                    Text(defaultRate.rate.formatAsCurrency())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var addTeamMemberButton: some View {
        Button(action: { showingAddMember = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Add Team Member")
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var organizationSettingsSection: some View {
        Section("Organization Settings") {
            HStack {
                Text("Organization ID")
                Spacer()
                Text(organization.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                Text("Members")
                Spacer()
                Text("\(projectVM.teamMembers.count)")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TeamMemberDetailView: View {
    let member: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        List {
            Section("Contact Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(member.name)
                        .foregroundColor(.secondary)
                }
                
                if !member.email.isEmpty {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(member.email)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Job Title")
                    Spacer()
                    Text(member.jobTitle)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Rates") {
                ForEach(member.rates) { rate in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rate.taskType)
                                .font(.headline)
                            if rate.isDefault {
                                Text("Default Rate")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Text(rate.rate.formatAsCurrency())
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}