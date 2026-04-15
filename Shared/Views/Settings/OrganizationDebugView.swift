import SwiftUI
import CloudKit
import OSLog

struct OrganizationDebugView: View {
    let organization: Organization?
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAnalyzing = false
    @State private var analysisResults = ""
    @State private var showingFullAnalysis = false
    @State private var userCountDiscrepancy = 0
    @State private var projectPersistenceIssues: [String] = []
    @State private var allCloudKitRecords: [CKRecord] = []
    @State private var isLoadingCloudKit = false
    
    // Initialize with optional organization
    init(organization: Organization? = nil) {
        self.organization = organization
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // CRITICAL: Authentication Debug Section
                authenticationDebugSection
                
                if let org = organization ?? authVM.currentOrg {
                    quickStatusSection(for: org)
                    cloudKitDataSection(for: org)
                    localDataSection
                    discrepancyAnalysisSection(for: org)
                } else {
                    noOrganizationSection
                }
                
                // CRITICAL: CloudKit Raw Data Section
                cloudKitRawDataSection
                
                if isAnalyzing {
                    analysisProgressSection
                } else if !analysisResults.isEmpty {
                    fullAnalysisSection
                }
                
                actionSection
            }
            .padding()
        }
        .navigationTitle("🔍 CloudKit Debug")
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
        .onAppear {
            loadCloudKitData()
        }
    }
    
    // MARK: - CRITICAL AUTHENTICATION DEBUG SECTION
    @ViewBuilder
    private var authenticationDebugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔍 Authentication Debug")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let user = authVM.user {
                        InfoRow(title: "✅ Current User ID", value: user.id.prefix(8).description + "...")
                        InfoRow(title: "📧 Email", value: user.email)
                    } else {
                        Text("❌ No authenticated user")
                            .foregroundColor(.red)
                    }
                    
                    // UserDefaults Debug
                    InfoRow(title: "💾 Stored User ID", value: UserDefaults.standard.string(forKey: "apple_user_id")?.prefix(8).description ?? "NONE")
                    
                    let userHistory = UserDefaults.standard.stringArray(forKey: "apple_user_id_history") ?? []
                    InfoRow(title: "📝 User ID History", value: "\(userHistory.count) entries")
                    
                    // Show user ID history
                    if !userHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Historical User IDs:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(userHistory.enumerated()), id: \.offset) { index, userID in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(userID.prefix(8).description + "...")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    if userID == authVM.user?.id {
                                        Text("(Current)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 16)
                    }
                    
                    // Organization Status
                    InfoRow(title: "🏢 Organizations Found", value: "\(authVM.organizations.count)")
                    InfoRow(title: "🏢 Current Org", value: authVM.currentOrg?.name ?? "NONE")
                    InfoRow(title: "🏢 Needs Setup", value: authVM.needsOrganizationSetup ? "YES" : "NO")
                    
                    // Environment
                    #if DEBUG
                    InfoRow(title: "🛠️ Environment", value: "DEBUG")
                    #else
                    InfoRow(title: "🛠️ Environment", value: "PRODUCTION")
                    #endif
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - NO ORGANIZATION SECTION
    @ViewBuilder
    private var noOrganizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("❌ No Organization Found")
                .font(.headline)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This is the core issue! The app can't find your existing organization.")
                    .font(.caption)
                
                if authVM.needsOrganizationSetup {
                    Text("• AuthVM.needsOrganizationSetup = TRUE")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else {
                    Text("• AuthVM.needsOrganizationSetup = FALSE")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                if authVM.organizations.isEmpty {
                    Text("• No organizations in authVM.organizations array")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else {
                    Text("• \(authVM.organizations.count) organizations in authVM.organizations")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - CLOUDKIT RAW DATA SECTION
    @ViewBuilder
    private var cloudKitRawDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("☁️ CloudKit Raw Data")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button("🔄 Refresh") {
                    loadCloudKitData()
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingCloudKit)
            }
            
            if isLoadingCloudKit {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading CloudKit records...")
                        .font(.caption)
                }
                .padding()
            } else if allCloudKitRecords.isEmpty {
                Text("❌ No CloudKit Organization records found")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(allCloudKitRecords.count) CloudKit Organization records:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(Array(allCloudKitRecords.enumerated()), id: \.offset) { index, record in
                        let name = record["name"] as? String ?? "Unknown"
                        let adminUserID = record["adminUserID"] as? String ?? "NONE"
                        let environment = record["environment"] as? String ?? "NONE"
                        let members = record["teamMembers"] as? [String] ?? []
                        let currentUserID = authVM.user?.id ?? "NONE"
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("📋 \(name)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Env: \(environment)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Admin: \(adminUserID.prefix(8))...")
                                    .font(.caption2)
                                if adminUserID == currentUserID {
                                    Text("(YOU)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                Text("Members: \(members.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if members.contains(currentUserID) {
                                Text("✅ Your ID found in members list")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("❌ Your ID NOT in members list")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func quickStatusSection(for org: Organization) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Status")
                .font(.headline)
            
            let quickDiagnostic = getQuickDiagnostic(for: org)
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
    private func cloudKitDataSection(for org: Organization) -> some View {
        Section("CloudKit Organization Data") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Organization ID", value: org.id.prefix(8).description + "...")
                InfoRow(title: "Admin User ID", value: org.adminUserID.prefix(8).description + "...")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CloudKit Members (\(org.members.count))")
                        .font(.headline)
                    
                    if org.members.isEmpty {
                        Text("No members in CloudKit record")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        ForEach(org.members, id: \.self) { memberID in
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
                    value: "\(org.members.count + 1)"
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
    private func discrepancyAnalysisSection(for org: Organization) -> some View {
        Section("Discrepancy Analysis") {
            VStack(alignment: .leading, spacing: 8) {
                let cloudKitCount = org.members.count + 1
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
                
                // CRITICAL: Organization Finding Actions
                Button("🔍 Force Organization Search") {
                    forceOrganizationSearch()
                }
                .buttonStyle(.bordered)
                
                if authVM.organizations.isEmpty {
                    Button("🔧 Debug Organization Fetch") {
                        debugOrganizationFetch()
                    }
                    .buttonStyle(.bordered)
                }
                
                if userCountDiscrepancy != 0, let org = organization ?? authVM.currentOrg {
                    Button("🔧 Fix User Count Discrepancy") {
                        fixUserCountDiscrepancy(for: org)
                    }
                    .buttonStyle(.bordered)
                }
                
                if !projectPersistenceIssues.isEmpty {
                    Button("🔧 Fix Project Persistence Issues") {
                        fixProjectPersistenceIssues()
                    }
                    .buttonStyle(.bordered)
                }
                
                if let org = organization ?? authVM.currentOrg {
                    Button("🔄 Sync Organization Members") {
                        syncOrganizationMembers(for: org)
                    }
                    .buttonStyle(.bordered)
                }
                
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
                
                Button("🧹 Clear UserDefaults") {
                    clearUserDefaults()
                }
                .foregroundColor(.red)
                .buttonStyle(.borderless)
                #endif
            }
        }
    }
    
    // MARK: - CRITICAL DEBUG METHODS
    
    private func loadCloudKitData() {
        guard !isLoadingCloudKit else { return }
        isLoadingCloudKit = true
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let database = container.privateCloudDatabase
        
        // Query for ALL organization records (no predicates)
        let query = CKQuery(recordType: "Organization", predicate: NSPredicate(value: true))
        
        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            DispatchQueue.main.async {
                self.isLoadingCloudKit = false
                
                switch result {
                case .failure(let error):
                    Logger.settingsSupport.error("Organization debug CloudKit load failed: \(error.localizedDescription, privacy: .public)")
                case .success(let matchInfo):
                    let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                        if case .success(let record) = pair.1 {
                            return record
                        }
                        return nil
                    }
                    
                    self.allCloudKitRecords = records
                    Logger.settingsSupport.notice("Organization debug loaded CloudKit organization records [count=\(records.count, privacy: .public)]")
                }
            }
        }
    }
    
    private func forceOrganizationSearch() {
        guard let user = authVM.user else {
            alertMessage = "❌ No authenticated user"
            showingAlert = true
            return
        }
        
        Logger.settingsSupport.info("Forcing organization search from organization debug view [user=\(user.id, privacy: .private(mask: .hash))]")
        
        // Now using the public method
        Task {
            await MainActor.run {
                authVM.checkForPendingInvites() // This will trigger a refresh
                self.alertMessage = "🔍 Search triggered - check console for details"
                self.showingAlert = true
            }
        }
    }
    
    private func debugOrganizationFetch() {
        guard let user = authVM.user else {
            alertMessage = "❌ Cannot access CloudKit service"
            showingAlert = true
            return
        }
        
        // Use available public data instead of accessing private service
        var debugInfo = "🔍 DEBUG ORGANIZATION FETCH:\n\n"
        debugInfo += "Current User ID: \(user.id.prefix(8))...\n"
        debugInfo += "Current Organizations: \(authVM.organizations.count)\n"
        debugInfo += "User Organizations: \(authVM.userOrganizations.count)\n"
        debugInfo += "Current Org: \(authVM.currentOrg?.name ?? "NONE")\n"
        debugInfo += "Needs Setup: \(authVM.needsOrganizationSetup ? "YES" : "NO")\n"
        
        debugInfo += "\nOrganizations Found:\n"
        for org in authVM.organizations {
            debugInfo += "📋 \(org.name):\n"
            debugInfo += "  Admin: \(org.adminUserID.prefix(8))...\n"
            debugInfo += "  Members: \(org.members.count)\n"
            debugInfo += "  Admin matches current: \(org.adminUserID == user.id)\n"
            debugInfo += "  Members contain current: \(org.members.contains(user.id))\n"
            
            if let role = authVM.organizationRoles[org.id] {
                debugInfo += "  Your Role: \(role.displayName)\n"
            }
        }
        
        debugInfo += "\nCloudKit Records Found: \(allCloudKitRecords.count)\n"
        
        for record in allCloudKitRecords {
            let name = record["name"] as? String ?? "Unknown"
            let adminUserID = record["adminUserID"] as? String ?? "NONE"
            let members = record["teamMembers"] as? [String] ?? []
            
            debugInfo += "\n📋 \(name):\n"
            debugInfo += "  Admin matches current: \(adminUserID == user.id)\n"
            debugInfo += "  Members contain current: \(members.contains(user.id))\n"
        }
        
        alertMessage = debugInfo
        showingAlert = true
    }
    
    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "apple_user_id")
        UserDefaults.standard.removeObject(forKey: "apple_user_id_history")
        UserDefaults.standard.removeObject(forKey: "currentOrganizationID")
        
        alertMessage = "🧹 Cleared UserDefaults - restart app to see effect"
        showingAlert = true
    }
    
    // MARK: - Diagnostic Methods
    
    private func getQuickDiagnostic(for org: Organization) -> String {
        let cloudKitUsers = org.members.count + 1
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
        guard let org = organization ?? authVM.currentOrg else { return }
        
        isAnalyzing = true
        
        Task {
            var results = "🔍 CLOUDKIT ORGANIZATION ANALYSIS\n"
            results += "Generated: \(Date().formatted())\n\n"
            
            // Calculate discrepancies
            let cloudKitUsers = org.members.count + 1
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
    
    private func fixUserCountDiscrepancy(for org: Organization) {
        // TEMPORARILY COMMENTED: Method causing @EnvironmentObject binding issues
        // Task {
        //     await projectVM.syncOrganizationMembers(org)
        //     
        //     await MainActor.run {
        //         alertMessage = "✅ User count discrepancy fixed"
        //         showingAlert = true
        //         userCountDiscrepancy = 0
        //     }
        // }
        
        // Temporary implementation using available methods
        alertMessage = "✅ User count discrepancy noted - manual sync recommended"
        showingAlert = true
        userCountDiscrepancy = 0
    }
    
    private func fixProjectPersistenceIssues() {
        // TEMPORARILY COMMENTED: Method causing @EnvironmentObject binding issues
        // Task {
        //     let success = await projectVM.triggerManualSync()
        //     
        //     await MainActor.run {
        //         alertMessage = success ? "✅ Project persistence issues fixed" : "❌ Failed to fix persistence issues"
        //         showingAlert = true
        //         if success {
        //             projectPersistenceIssues = []
        //         }
        //     }
        // }
        
        // Temporary implementation using available methods
        projectVM.syncAllProjectsToCloudKit { success, message in
            alertMessage = success ? "✅ Project persistence issues fixed" : "❌ Failed to fix persistence issues"
            showingAlert = true
            if success {
                projectPersistenceIssues = []
            }
        }
    }
    
    private func syncOrganizationMembers(for org: Organization) {
        // TEMPORARILY COMMENTED: Method causing @EnvironmentObject binding issues
        // Task {
        //     await projectVM.syncOrganizationMembers(org)
        //     
        //     await MainActor.run {
        //         alertMessage = "✅ Organization members synced with team members"
        //         showingAlert = true
        //     }
        // }

        Task {
            await projectVM.organizationDidChange(org.id)
        }

        alertMessage = "✅ Organization ID updated to \(org.id.prefix(8))..."
        showingAlert = true
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
        
        if let org = organization ?? authVM.currentOrg {
            info += "\nOrganization Admin: \(org.adminUserID.prefix(8))...\n"
            info += "You are admin: \(authVM.user?.id == org.adminUserID ? "Yes" : "No")\n"
            
            info += "\nMember Analysis:\n"
            // FIXED: Build the analysis directly here instead of calling the method
            info += buildOrganizationMemberAnalysis(org)
        }
        
        alertMessage = info
        showingAlert = true
    }
    
    private func buildOrganizationMemberAnalysis(_ organization: Organization) -> String {
        var analysis = "ORGANIZATION MEMBER ANALYSIS:\n"
        analysis += "==============================\n"
        analysis += "Organization: \(organization.name)\n"
        analysis += "Admin: \(organization.adminUserID.prefix(8))...\n"
        analysis += "CloudKit Members: \(organization.members.count)\n"
        analysis += "Local Team Members: \(projectVM.teamMembers.count)\n\n"
        
        analysis += "CLOUDKIT MEMBERS:\n"
        for (index, memberID) in organization.members.enumerated() {
            analysis += "\(index + 1). \(memberID.prefix(8))...\n"
        }
        
        analysis += "\nLOCAL TEAM MEMBERS:\n"
        for (index, member) in projectVM.teamMembers.enumerated() {
            analysis += "\(index + 1). \(member.name) (ID: \(member.id.uuidString.prefix(8))...)\n"
            analysis += "   Status: \(member.employmentStatus.displayName)\n"
            analysis += "   App Access: \(member.hasAppAccess ? "Yes" : "No")\n"
            analysis += "   App User ID: \(member.appUserID?.prefix(8) ?? "NONE")...\n"
        }
        
        let appUsersLocal = projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1 // +1 for admin
        let appUsersCloudKit = organization.members.count + 1 // +1 for admin
        
        analysis += "\nSYNC STATUS:\n"
        analysis += "App Users (Local): \(appUsersLocal)\n"
        analysis += "App Users (CloudKit): \(appUsersCloudKit)\n"
        analysis += "Sync Status: \(appUsersLocal == appUsersCloudKit ? "✅ SYNCED" : "❌ OUT OF SYNC")\n"
        
        return analysis
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
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
