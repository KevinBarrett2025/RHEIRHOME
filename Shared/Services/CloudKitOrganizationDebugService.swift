import Foundation
import CloudKit
import Combine

/// Service to diagnose and fix CloudKit organization sync issues
@MainActor
class CloudKitOrganizationDebugService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing: Bool = false
    @Published var analysisResults: String = ""
    @Published var userCountDiscrepancy: Int = 0
    @Published var projectPersistenceIssues: [String] = []
    @Published var recommendedActions: [String] = []
    
    // MARK: - Services
    private let organizationZoneService: OrganizationZoneService
    
    init(
        organizationZoneService: OrganizationZoneService = OrganizationZoneService()
    ) {
        self.organizationZoneService = organizationZoneService
    }
    
    // MARK: - Main Diagnostic Methods
    
    func performCompleteAnalysis(organization: Organization, authVM: AuthViewModel, projectVM: ProjectViewModel) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        print("🔍 Starting complete CloudKit organization analysis...")
        
        var results = "🔍 CLOUDKIT ORGANIZATION ANALYSIS\n"
        results += "Generated: \(Date().formatted())\n\n"
        
        // 1. Organization Member Analysis
        results += await analyzeOrganizationMembers(organization: organization, authVM: authVM)
        results += "\n"
        
        // 2. Team Member Sync Analysis
        results += await analyzeTeamMemberSync(organization: organization, projectVM: projectVM)
        results += "\n"
        
        // 3. Project Persistence Analysis
        results += await analyzeProjectPersistence(organization: organization, projectVM: projectVM)
        results += "\n"
        
        // 4. CloudKit Zone Health
        results += await analyzeCloudKitZoneHealth()
        results += "\n"
        
        // 5. Generate Recommendations
        results += generateRecommendations()
        
        analysisResults = results
        print("✅ Complete analysis finished")
    }
    
    // MARK: - Individual Analysis Methods
    
    private func analyzeOrganizationMembers(organization: Organization, authVM: AuthViewModel) async -> String {
        var analysis = "👥 ORGANIZATION MEMBERS ANALYSIS\n"
        analysis += "=====================================\n"
        
        // CloudKit organization data
        let cloudKitMembers = organization.members
        let adminUserID = organization.adminUserID
        let totalCloudKitUsers = cloudKitMembers.count + 1 // +1 for admin
        
        analysis += "CloudKit Organization Data:\n"
        analysis += "• Admin User ID: \(adminUserID.prefix(8))...\n"
        analysis += "• Member Count: \(cloudKitMembers.count)\n"
        analysis += "• Total Users: \(totalCloudKitUsers)\n"
        
        // Current user verification
        if let currentUser = authVM.user {
            analysis += "• Current User: \(currentUser.id.prefix(8))...\n"
            analysis += "• Is Admin: \(currentUser.id == adminUserID ? "✅ Yes" : "❌ No")\n"
            analysis += "• In Members List: \(cloudKitMembers.contains(currentUser.id) ? "✅ Yes" : "❌ No")\n"
        } else {
            analysis += "• Current User: ❌ Not logged in\n"
        }
        
        // Member details
        if !cloudKitMembers.isEmpty {
            analysis += "\nMember Details:\n"
            for (index, memberID) in cloudKitMembers.enumerated() {
                analysis += "  \(index + 1). \(memberID.prefix(8))...\n"
            }
        }
        
        return analysis
    }
    
    private func analyzeTeamMemberSync(organization: Organization, projectVM: ProjectViewModel) async -> String {
        var analysis = "👷 TEAM MEMBER SYNC ANALYSIS\n"
        analysis += "===================================\n"
        
        let localTeamMembers = projectVM.teamMembers
        let localAppUsers = localTeamMembers.filter { $0.hasAppAccess }.count + 1 // +1 for current user
        let cloudKitUsers = organization.members.count + 1
        
        analysis += "Local Team Members Data:\n"
        analysis += "• Total Team Members: \(localTeamMembers.count)\n"
        analysis += "• Members with App Access: \(localTeamMembers.filter { $0.hasAppAccess }.count)\n"
        analysis += "• Total Local App Users: \(localAppUsers)\n"
        
        analysis += "\nSync Comparison:\n"
        analysis += "• CloudKit Users: \(cloudKitUsers)\n"
        analysis += "• Local App Users: \(localAppUsers)\n"
        
        let discrepancy = cloudKitUsers - localAppUsers
        userCountDiscrepancy = discrepancy
        
        analysis += "• Discrepancy: \(discrepancy > 0 ? "+" : "")\(discrepancy)\n"
        
        if discrepancy == 0 {
            analysis += "• Status: ✅ COUNTS MATCH\n"
        } else {
            analysis += "• Status: ❌ COUNTS DON'T MATCH\n"
            
            if discrepancy > 0 {
                analysis += "\n⚠️ ISSUE: CloudKit has more users than local records\n"
                analysis += "Possible causes:\n"
                analysis += "• Ghost/orphaned user in CloudKit organization\n"
                analysis += "• Team member invited but not added to local team\n"
                analysis += "• Organization member without team member record\n"
            } else {
                analysis += "\n⚠️ ISSUE: Local has more app users than CloudKit\n"
                analysis += "Possible causes:\n"
                analysis += "• Team members marked with app access but not in CloudKit\n"
                analysis += "• Local data out of sync with CloudKit organization\n"
            }
        }
        
        // Detailed team member analysis
        if !localTeamMembers.isEmpty {
            analysis += "\nLocal Team Member Details:\n"
            for member in localTeamMembers {
                analysis += "• \(member.name): "
                analysis += "Active: \(member.employmentStatus == .active ? "✅" : "❌"), "
                analysis += "App Access: \(member.hasAppAccess ? "✅" : "❌")\n"
            }
        } else {
            analysis += "\n⚠️ No local team members found\n"
        }
        
        return analysis
    }
    
    private func analyzeProjectPersistence(organization: Organization, projectVM: ProjectViewModel) async -> String {
        var analysis = "🏗️ PROJECT PERSISTENCE ANALYSIS\n"
        analysis += "====================================\n"
        
        let organizationProjects = projectVM.organizationProjects
        let localBackupProjects = projectVM.projects
        
        analysis += "Project Data:\n"
        analysis += "• Organization Projects (CloudKit): \(organizationProjects.count)\n"
        analysis += "• Local Backup Projects: \(localBackupProjects.count)\n"
        
        // Check for persistence issues
        projectPersistenceIssues = []
        
        if organizationProjects.isEmpty && localBackupProjects.isEmpty {
            analysis += "• Status: ❌ NO PROJECTS FOUND ANYWHERE\n"
            projectPersistenceIssues.append("No projects found in CloudKit or local backup")
        } else if organizationProjects.isEmpty && !localBackupProjects.isEmpty {
            analysis += "• Status: ⚠️ PROJECTS ONLY IN LOCAL BACKUP\n"
            analysis += "• Issue: Projects not persisting to CloudKit\n"
            projectPersistenceIssues.append("Projects not saving to CloudKit - only in local backup")
        } else if !organizationProjects.isEmpty && localBackupProjects.isEmpty {
            analysis += "• Status: ✅ PROJECTS IN CLOUDKIT, NO LOCAL BACKUP\n"
        } else {
            analysis += "• Status: ✅ PROJECTS IN BOTH LOCATIONS\n"
        }
        
        // Check CloudKit zone status
        let zoneActive = organizationZoneService.isOrganizationSharingActive()
        analysis += "• CloudKit Zone Active: \(zoneActive ? "✅ Yes" : "❌ No")\n"
        
        if !zoneActive {
            projectPersistenceIssues.append("CloudKit organization zone not active")
        }
        
        // Organization ID consistency check
        if let currentOrgID = projectVM.currentOrganizationID {
            analysis += "• Current Organization ID: \(currentOrgID.prefix(8))...\n"
            analysis += "• Matches Analysis Org: \(currentOrgID == organization.id ? "✅ Yes" : "❌ No")\n"
            
            if currentOrgID != organization.id {
                projectPersistenceIssues.append("Organization ID mismatch between ProjectVM and analysis")
            }
        } else {
            analysis += "• Current Organization ID: ❌ NOT SET\n"
            projectPersistenceIssues.append("No organization ID set in ProjectViewModel")
        }
        
        return analysis
    }
    
    private func analyzeCloudKitZoneHealth() async -> String {
        var analysis = "☁️ CLOUDKIT ZONE HEALTH\n"
        analysis += "==========================\n"
        
        let zoneStatus = organizationZoneService.getOrganizationSharingStatus()
        let diagnostics = await organizationZoneService.getZoneDiagnostics()
        
        analysis += zoneStatus
        analysis += "\n"
        analysis += diagnostics
        
        return analysis
    }
    
    private func generateRecommendations() -> String {
        var recommendations = "💡 RECOMMENDED ACTIONS\n"
        recommendations += "========================\n"
        
        recommendedActions = []
        
        // User count discrepancy fixes
        if userCountDiscrepancy != 0 {
            if userCountDiscrepancy > 0 {
                recommendedActions.append("Sync CloudKit organization members with local team members")
                recommendedActions.append("Check for ghost users in CloudKit organization")
            } else {
                recommendedActions.append("Update local team members to match CloudKit organization")
                recommendedActions.append("Remove excess local app access permissions")
            }
        }
        
        // Project persistence fixes
        if !projectPersistenceIssues.isEmpty {
            recommendedActions.append("Reset and reinitialize CloudKit organization zone")
            recommendedActions.append("Force sync all projects to CloudKit")
            recommendedActions.append("Verify organization ID consistency")
        }
        
        // Zone health fixes
        if !organizationZoneService.isOrganizationSharingActive() {
            recommendedActions.append("Reinitialize CloudKit organization zone")
            recommendedActions.append("Check CloudKit container permissions")
        }
        
        if recommendedActions.isEmpty {
            recommendations += "✅ No issues detected - system appears healthy\n"
        } else {
            for (index, action) in recommendedActions.enumerated() {
                recommendations += "\(index + 1). \(action)\n"
            }
        }
        
        return recommendations
    }
    
    // MARK: - Fix Methods
    
    func fixUserCountDiscrepancy(organization: Organization, authVM: AuthViewModel, projectVM: ProjectViewModel) async -> Bool {
        print("🔧 Fixing user count discrepancy...")
        
        guard userCountDiscrepancy != 0 else {
            print("✅ No discrepancy to fix")
            return true
        }
        
        do {
            if userCountDiscrepancy > 0 {
                // CloudKit has more users - sync organization members to team members
                await syncOrganizationMembersToTeamMembers(organization: organization, projectVM: projectVM)
            } else {
                // Local has more - remove excess app access or sync to CloudKit
                await syncTeamMembersToOrganization(organization: organization, authVM: authVM, projectVM: projectVM)
            }
            
            return true
        } catch {
            print("❌ Failed to fix user count discrepancy: \(error)")
            return false
        }
    }
    
    private func syncOrganizationMembersToTeamMembers(organization: Organization, projectVM: ProjectViewModel) async {
        print("🔄 Syncing organization members to local team members...")
        
        // For each organization member that's not in team members,
        // create a placeholder team member with app access
        for memberID in organization.members {
            let existingMember = projectVM.teamMembers.first { $0.userID == memberID }
            
            if existingMember == nil {
                // Create placeholder team member
                let newTeamMember = TeamMember(
                    name: "User \(memberID.prefix(8))",
                    userID: memberID,
                    organizationID: organization.id,
                    hasAppAccess: true,
                    employmentStatus: .active
                )
                
                projectVM.addTeamMemberToOrganization(newTeamMember)
                print("✅ Added placeholder team member for user \(memberID.prefix(8))...")
            }
        }
        
        await projectVM.saveTeamMembersToCloudKit()
        print("✅ Organization members synced to team members")
    }
    
    private func syncTeamMembersToOrganization(organization: Organization, authVM: AuthViewModel, projectVM: ProjectViewModel) async {
        print("🔄 Syncing team members to organization...")
        
        // Remove app access from team members who aren't in the organization
        for i in 0..<projectVM.teamMembers.count {
            let member = projectVM.teamMembers[i]
            
            if member.hasAppAccess && member.userID != organization.adminUserID && !organization.members.contains(member.userID ?? "") {
                // Since teamMembers is computed, we need to update the organization directly
                if let memberID = member.id {
                    if var orgMember = projectVM.getTeamMember(by: memberID) {
                        orgMember.hasAppAccess = false
                        projectVM.updateTeamMemberInOrganization(orgMember)
                        print("✅ Removed app access from \(member.name) - not in organization")
                    }
                }
            }
        }
        
        await projectVM.saveTeamMembersToCloudKit()
        print("✅ Team members synced to organization")
    }
    
    func fixProjectPersistenceIssues(projectVM: ProjectViewModel) async -> Bool {
        print("🔧 Fixing project persistence issues...")
        
        do {
            // 1. Reset and reinitialize CloudKit zone
            await organizationZoneService.resetOrganizationZone()
            
            // 2. Force sync all projects
            let success = await projectVM.triggerManualSync()
            
            if success {
                print("✅ Project persistence issues fixed")
                return true
            } else {
                print("⚠️ Manual sync reported issues")
                return false
            }
        } catch {
            print("❌ Failed to fix project persistence: \(error)")
            return false
        }
    }
    
    func performEmergencyRecovery(projectVM: ProjectViewModel) async -> Bool {
        print("🚨 Performing emergency recovery...")
        
        do {
            // Use ProjectViewModel's emergency recovery method
            let success = await projectVM.emergencyRecoverFromBackup()
            
            if success {
                print("✅ Emergency recovery completed")
                return true
            } else {
                print("❌ Emergency recovery failed")
                return false
            }
        } catch {
            print("❌ Emergency recovery error: \(error)")
            return false
        }
    }
    
    // MARK: - Utility Methods
    
    func getQuickDiagnostic(organization: Organization, projectVM: ProjectViewModel) -> String {
        let cloudKitUsers = organization.members.count + 1
        let localAppUsers = projectVM.teamMembers.filter { $0.hasAppAccess }.count + 1
        let organizationProjects = projectVM.organizationProjects.count
        let zoneActive = organizationZoneService.isOrganizationSharingActive()
        
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
    
    func clearAnalysis() {
        analysisResults = ""
        userCountDiscrepancy = 0
        projectPersistenceIssues = []
        recommendedActions = []
    }
}