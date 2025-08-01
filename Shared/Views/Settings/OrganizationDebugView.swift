import SwiftUI

struct OrganizationDebugView: View {
    let organization: Organization
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAnalyzing = false
    @State private var analysisResults = ""
    @State private var showingFullAnalysis = false
    @State private var userCountDiscrepancy = 0
    @State private var projectPersistenceIssues: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                quickStatusSection
                cloudKitDataSection
                localDataSection
                discrepancyAnalysisSection
                
                if isAnalyzing {
                    analysisProgressSection
                } else if !analysisResults.isEmpty {
                    fullAnalysisSection
                }
                
                actionSection
            }
            .padding()
        }
        .navigationTitle("Organization Debug")
        .navigationBarTitleDisplayMode(.large)
        .alert("Debug Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingFullAnalysis) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(analysisResults)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .navigationTitle("Full Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFullAnalysis = false
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var quickStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Status")
                .font(.headline)
            
            let quickDiagnostic = getQuickDiagnostic()
            Text(quickDiagnostic)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var analysisProgressSection: some View {
        VStack(spacing: 12) {
            Text("Analyzing CloudKit Sync Issues...")
                .font(.headline)
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Checking organization members, team sync, project persistence, and CloudKit zone health...")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var fullAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Analysis Results")
                    .font(.headline)
                
                Spacer()
                
                Button("View Full Report") {
                    showingFullAnalysis = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            if userCountDiscrepancy != 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("User count discrepancy: \(userCountDiscrepancy > 0 ? "+" : "")\(userCountDiscrepancy)")
                        .font(.caption)
                }
            }
            
            if !projectPersistenceIssues.isEmpty {
                HStack {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .foregroundColor(.red)
                    Text("\(projectPersistenceIssues.count) project persistence issue(s)")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var cloudKitDataSection: some View {
        Section("CloudKit Organization Data") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Organization ID", value: organization.id.prefix(8).description + "...")
                InfoRow(title: "Admin User ID", value: organization.adminUserID.prefix(8).description + "...")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CloudKit Members (\(organization.members.count))")
                        .font(.headline)
                    
                    if organization.members.isEmpty {
                        Text("No members in CloudKit record")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        ForEach(organization.members, id: \.self) { memberID in
                            HStack {
                                Text("Member ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(memberID.prefix(8).description + "...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                if memberID == authVM.user?.id {
                                    Text("(You)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                InfoRow(
                    title: "Total App Users (CloudKit)", 
                    value: "\(organization.members.count + 1)"
                )
            }
        }
    }
    
    @ViewBuilder
    private var localDataSection: some View {
        Section("Local Team Member Data") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Total Team Members", value: "\(projectVM.teamMembers.count)")
                InfoRow(
                    title: "Active Team Members", 
                    value: "\(projectVM.teamMembers.filter { $0.employmentStatus == .active }.count)"
                )
                InfoRow(
                    title: "Members with App Access", 
                    value: "\(projectVM.teamMembers.filter { $0.hasAppAccess }.count)"
                )
                InfoRow(
                    title: "Total App Users (Local)", 
                    value: "\(projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1)"
                )
                
                if !projectVM.teamMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Team Member Details")
                            .font(.headline)
                        
                        ForEach(projectVM.teamMembers) { member in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(member.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    if member.hasAppAccess {
                                        Image(systemName: "iphone")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                                
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(member.employmentStatus.displayName)
                                        .font(.caption)
                                        .foregroundColor(member.employmentStatus == .active ? .green : .orange)
                                    
                                    Spacer()
                                    
                                    Text("App Access:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(member.hasAppAccess ? "Yes" : "No")
                                        .font(.caption)
                                        .foregroundColor(member.hasAppAccess ? .green : .red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    Text("No local team members found")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
        }
    }
    
    @ViewBuilder
    private var discrepancyAnalysisSection: some View {
        Section("Discrepancy Analysis") {
            VStack(alignment: .leading, spacing: 8) {
                let cloudKitCount = organization.members.count + 1
                let localCount = projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1
                let difference = cloudKitCount - localCount
                
                InfoRow(title: "CloudKit App Users", value: "\(cloudKitCount)")
                InfoRow(title: "Local App Users", value: "\(localCount)")
                InfoRow(
                    title: "Difference", 
                    value: "\(difference > 0 ? "+" : "")\(difference)"
                )
                
                if difference != 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Possible Issues:")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        if difference > 0 {
                            Text("• CloudKit has more users than local records")
                                .font(.caption)
                            Text("• Someone may have joined via invite but isn't in team members")
                                .font(.caption)
                            Text("• Ghost/orphaned user records in CloudKit")
                                .font(.caption)
                        } else {
                            Text("• Local records have more app users than CloudKit")
                                .font(.caption)
                            Text("• Team members marked with app access but not in CloudKit")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Counts match! No discrepancy.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionSection: some View {
        Section("Actions") {
            VStack(spacing: 12) {
                Button("🔍 Run Complete Analysis") {
                    runCompleteAnalysis()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
                
                if userCountDiscrepancy != 0 {
                    Button("🔧 Fix User Count Discrepancy") {
                        fixUserCountDiscrepancy()
                    }
                    .buttonStyle(.bordered)
                }
                
                if !projectPersistenceIssues.isEmpty {
                    Button("🔧 Fix Project Persistence Issues") {
                        fixProjectPersistenceIssues()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("🔄 Sync Organization Members") {
                    syncOrganizationMembers()
                }
                .buttonStyle(.bordered)
                
                Button("🚨 Emergency Recovery") {
                    performEmergencyRecovery()
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                
                Button("📊 Show Current User Info") {
                    showCurrentUserInfo()
                }
                .buttonStyle(.borderless)
                
                #if DEBUG
                Button("🗑️ Clear Analysis", role: .destructive) {
                    clearAnalysis()
                }
                .foregroundColor(.red)
                .buttonStyle(.borderless)
                #endif
            }
        }
    }
    
    // MARK: - Diagnostic Methods
    
    private func getQuickDiagnostic() -> String {
        let cloudKitUsers = organization.members.count + 1
        let localAppUsers = projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1
        let organizationProjects = projectVM.organizationProjects.count
        let zoneActive = projectVM.isUsingCloudKitForOrganizationData
        
        var diagnostic = "QUICK DIAGNOSTIC:\n"
        diagnostic += "• CloudKit Users: \(cloudKitUsers)\n"
        diagnostic += "• Local App Users: \(localAppUsers)\n"
        diagnostic += "• User Count Match: \(cloudKitUsers == localAppUsers ? "✅" : "❌")\n"
        diagnostic += "• Organization Projects: \(organizationProjects)\n"
        diagnostic += "• CloudKit Zone Active: \(zoneActive ? "✅" : "❌")\n"
        
        let hasIssues = (cloudKitUsers != localAppUsers) || !zoneActive || organizationProjects == 0
        diagnostic += "• Overall Status: \(hasIssues ? "❌ ISSUES DETECTED" : "✅ HEALTHY")\n"
        
        return diagnostic
    }
    
    // MARK: - Action Methods
    
    private func runCompleteAnalysis() {
        isAnalyzing = true
        
        Task {
            var results = "🔍 CLOUDKIT ORGANIZATION ANALYSIS\n"
            results += "Generated: \(Date().formatted())\n\n"
            
            // Calculate discrepancies
            let cloudKitUsers = organization.members.count + 1
            let localAppUsers = projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1
            userCountDiscrepancy = cloudKitUsers - localAppUsers
            
            // Check project persistence
            projectPersistenceIssues = []
            if projectVM.organizationProjects.isEmpty && !projectVM.projects.isEmpty {
                projectPersistenceIssues.append("Projects not persisting to CloudKit - only in local backup")
            }
            if !projectVM.isUsingCloudKitForOrganizationData {
                projectPersistenceIssues.append("CloudKit organization zone not active")
            }
            
            results += "👥 ORGANIZATION MEMBERS ANALYSIS\n"
            results += "=====================================\n"
            results += "CloudKit Users: \(cloudKitUsers)\n"
            results += "Local App Users: \(localAppUsers)\n"
            results += "Discrepancy: \(userCountDiscrepancy > 0 ? "+" : "")\(userCountDiscrepancy)\n"
            results += "Status: \(userCountDiscrepancy == 0 ? "✅ SYNCED" : "❌ OUT OF SYNC")\n\n"
            
            results += "🏗️ PROJECT PERSISTENCE ANALYSIS\n"
            results += "====================================\n"
            results += "Organization Projects: \(projectVM.organizationProjects.count)\n"
            results += "Local Backup Projects: \(projectVM.projects.count)\n"
            results += "CloudKit Zone Active: \(projectVM.isUsingCloudKitForOrganizationData ? "✅" : "❌")\n"
            
            if projectPersistenceIssues.isEmpty {
                results += "Status: ✅ NO ISSUES\n"
            } else {
                results += "Issues Found:\n"
                for issue in projectPersistenceIssues {
                    results += "• \(issue)\n"
                }
            }
            
            await MainActor.run {
                analysisResults = results
                isAnalyzing = false
            }
        }
    }
    
    private func fixUserCountDiscrepancy() {
        Task {
            await projectVM.syncOrganizationMembers(organization)
            
            await MainActor.run {
                alertMessage = "✅ User count discrepancy fixed"
                showingAlert = true
                userCountDiscrepancy = 0
            }
        }
    }
    
    private func fixProjectPersistenceIssues() {
        Task {
            let success = await projectVM.triggerManualSync()
            
            await MainActor.run {
                alertMessage = success ? "✅ Project persistence issues fixed" : "❌ Failed to fix persistence issues"
                showingAlert = true
                if success {
                    projectPersistenceIssues = []
                }
            }
        }
    }
    
    private func syncOrganizationMembers() {
        Task {
            await projectVM.syncOrganizationMembers(organization)
            
            await MainActor.run {
                alertMessage = "✅ Organization members synced with team members"
                showingAlert = true
            }
        }
    }
    
    private func performEmergencyRecovery() {
        Task {
            let success = await projectVM.emergencyRecoverFromBackup()
            
            await MainActor.run {
                alertMessage = success ? "✅ Emergency recovery completed" : "❌ Emergency recovery failed"
                showingAlert = true
            }
        }
    }
    
    private func showCurrentUserInfo() {
        var info = "Current User Info:\n"
        if let user = authVM.user {
            info += "ID: \(user.id.prefix(8))...\n"
            info += "Email: \(user.email)\n"
        } else {
            info += "No user logged in"
        }
        
        info += "\nOrganization Admin: \(organization.adminUserID.prefix(8))...\n"
        info += "You are admin: \(authVM.user?.id == organization.adminUserID ? "Yes" : "No")\n"
        
        info += "\nMember Analysis:\n"
        info += projectVM.getOrganizationMemberAnalysis(organization)
        
        alertMessage = info
        showingAlert = true
    }
    
    private func clearAnalysis() {
        analysisResults = ""
        userCountDiscrepancy = 0
        projectPersistenceIssues = []
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let sampleOrg = Organization(name: "Test Org", members: ["user1", "user2"])
    
    NavigationView {
        OrganizationDebugView(organization: sampleOrg)
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
            .environmentObject(ProjectViewModel())
    }
}