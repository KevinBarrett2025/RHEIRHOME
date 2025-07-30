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
                        // Show correct count - app users vs team members
                        Text("\(projectVM.teamMembers.filter { $0.employmentStatus == .active }.count) team members • \(organization.members.count + 1) app users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: TeamInviteView().environmentObject(authVM).environmentObject(ProjectViewModel())) {
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
        Section("Debug & Maintenance") {
            Button("🔧 Fix Organization IDs") {
                fixOrganizationIDs()
            }
            
            Button("📊 Check CloudKit Status") {
                checkCloudKitStatus()
            }
            
            Button("🔍 Full Diagnostic Report") {
                getFullDiagnostic()
            }
            
            Button("💥 Nuclear Reset", role: .destructive) {
                showingNuclearResetAlert = true
            }
            .foregroundColor(.red)
            .disabled(resetService.isResetting)
            
            if resetService.isResetting {
                HStack {
                    Text(resetService.resetProgress)
                        .font(.caption)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .foregroundColor(.orange)
            }
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
    
    private func checkCloudKitStatus() {
        projectVM.getDetailedCloudKitStatus { status in
            statusMessage = status
            showingStatusAlert = true
        }
    }
    
    private func getFullDiagnostic() {
        projectVM.getDiagnosticInfo { report in
            statusMessage = report
            showingStatusAlert = true
        }
    }
    
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
            .environmentObject(ProjectViewModel())
    }
}