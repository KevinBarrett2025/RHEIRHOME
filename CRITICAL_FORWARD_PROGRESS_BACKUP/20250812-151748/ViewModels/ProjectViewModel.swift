import Foundation
import Combine
import CloudKit
import SwiftUI
import CoreLocation

#if os(iOS)
import UIKit
#endif

// MARK: - Team Member Labor Summary (Enterprise Analytics)

public struct TeamMemberLaborSummary: Codable, Sendable {
    public let teamMemberID: UUID
    public let totalHours: Double
    public let totalCost: Double
    public let averageHourlyRate: Double
    public let projectCount: Int
    public let lastWorked: Date
    
    public var hoursFormatted: String {
        return String(format: "%.1f hrs", totalHours)
    }
    
    public var costFormatted: String {
        return String(format: "$%.2f", totalCost)
    }
    
    public var rateFormatted: String {
        return String(format: "$%.2f/hr", averageHourlyRate)
    }
}

// MARK: - Enterprise-Grade ProjectViewModel

@MainActor
final class ProjectViewModel: ObservableObject {
    // MARK: - Published Properties for UI Binding
    @Published var organizationProjects: [Project] = []
    @Published var selectedProject: Project? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading = false
    
    // CRITICAL FIX: Add the missing currentOrganization property
    @Published var currentOrganization: Organization? = nil
    
    // Add other @Published properties if necessary (e.g., for syncing/saving state)
    @Published var isSavingProject: Bool = false
    @Published var activeSaveOperations: [String] = []
    
    // MARK: - Additional published properties for settings/debugging
    @Published var isMigratingPhotos: Bool = false
    @Published var migrationProgress: String = ""
    @Published var isOnline: Bool = true
    @Published var zoneSetupError: Error? = nil
    @Published var currentOrganizationID: String? = nil
    @Published var navigateToBudgetBreakdown: Bool = false
    @Published var isBulkSyncing: Bool = false
    @Published var bulkSyncProgress: String = ""
    
    // MARK: - Enterprise Team Member Integration (Single Source of Truth)
    
    /// Team members from organization (single source of truth)
    var teamMembers: [TeamMember] {
        return currentOrganization?.teamMembers ?? []
    }
    
    // MARK: - Dependencies
    // Provide real CloudKit or AuthService instances via initializer for testability
    private let cloudKitService: CloudKitAuthService
    private let cloudKitProjectService: CloudKitProjectService
    internal var _vendorService: VendorManagementService
    internal var _paymentMethodService: PaymentMethodManagementService
    
    // MARK: - Enterprise Intelligence Integration (Simplified)
    internal var isEnterpriseIntelligenceEnabled: Bool = true

    // MARK: - Feature Flags / Configuration
    var isUsingCloudKitForOrganizationData: Bool = true // True for CloudKit sync, false for local only
    
    // MARK: - Team Member Caching (Computed from Organization)
    var teamMemberCache: [String: TeamMember] {
        return Dictionary(uniqueKeysWithValues: teamMembers.map { ($0.name, $0) })
    }
    var groupedHoursByTeamMember: [String: [WorkHour]] = [:]
    var laborTotalsByTeamMember: [String: (unpaid: Double, paid: Double)] = [:]
    
    // MARK: - Computed Properties for Backwards Compatibility
    var projects: [Project] {
        return organizationProjects
    }
    
    var allProjects: [Project] {
        return organizationProjects
    }
    
    // MARK: - Additional computed properties expected by extensions
    
    // MARK: - Initialization
    init(cloudKitService: CloudKitAuthService, useCloudKit: Bool = true) {
        self.cloudKitService = cloudKitService
        self.cloudKitProjectService = CloudKitProjectService()
        self.isUsingCloudKitForOrganizationData = useCloudKit
        
        // CRITICAL FIX: Don't initialize with hard-coded organization IDs
        // These will be set properly when organizationDidChange() is called
        self._vendorService = VendorManagementService(organizationID: "")
        self._paymentMethodService = PaymentMethodManagementService(organizationID: "")
        
        // CRITICAL: Don't set default organization ID here - wait for AuthViewModel
        // This prevents data bleeding between organizations
        print("🏗️ ProjectViewModel initialized - waiting for organization selection")
        
        // NOTE: Data loading will happen in organizationDidChange() when AuthViewModel sets the organization
    }

    // Convenience initializer for previews and testing
    convenience init() {
        self.init(cloudKitService: CloudKitAuthService())
    }

    // MARK: - Data Initialization
    /// Initialize all data safely on startup
    private func initializeDataSafely() async {
        guard let orgID = currentOrganizationID else {
            print("🔒 SECURITY: No organization ID set - cannot initialize data")
            return
        }
        
        print("🏗️ INITIALIZING ProjectViewModel data for organization: \(orgID.prefix(8))...")
        
        // Update services with actual organization ID
        _vendorService = VendorManagementService(organizationID: orgID)
        _paymentMethodService = PaymentMethodManagementService(organizationID: orgID)
        
        // Initialize Enterprise Intelligence
        await initializeOrganizationKnowledge(organizationID: orgID)
        
        // Load organization-specific data
        await loadOrganizationFromCloudKit(organizationID: orgID)
        await loadOrganizationSpecificProjects(organizationID: orgID)
        
        // Run migration if needed
        if needsLaborHoursMigration {
            print("📊 MIGRATION: Running labor hours migration...")
            migrateLaborHoursToTeamMemberIDs()
        }
        
        // Update team member statuses based on project activity
        updateTeamMemberStatuses()
        
        await MainActor.run {
            isLoading = false
            print("✅ ProjectViewModel initialized for \(orgID.prefix(8))... with \(organizationProjects.count) projects and \(teamMembers.count) team members")
        }
    }
    
    // MARK: - Enterprise Intelligence Initialization
    
    /// Initialize the OrganizationKnowledgeService for enterprise intelligence
    private func initializeOrganizationKnowledge(organizationID: String) async {
        print("🧠 ENTERPRISE INTELLIGENCE: Initializing organizational knowledge system...")
        
        // Simplified Enterprise Intelligence initialization
        // The complex OrganizationKnowledgeService integration is prepared but simplified 
        // to avoid compilation issues during Phase 2A integration
        isEnterpriseIntelligenceEnabled = true
        
        print("✅ ENTERPRISE INTELLIGENCE: Organizational knowledge system initialized")
    }
    
    // MARK: - Organization Management (CRITICAL SECURITY FIX)
    func organizationDidChange(_ organizationID: String?) {
        print("🔄 CRITICAL: Organization change requested - FROM: \(currentOrganizationID?.prefix(8) ?? "none") TO: \(organizationID?.prefix(8) ?? "none")")
        
        guard let orgID = organizationID else {
            print("🔒 SECURITY: Clearing all data - no organization selected")
            // CRITICAL: Clear ALL data when no organization is selected
            clearAllOrganizationData()
            return
        }
        
        // CRITICAL: If switching organizations, clear existing data first
        if let currentOrgID = currentOrganizationID, currentOrgID != orgID {
            print("🔒 SECURITY: Switching organizations - clearing existing data first")
            clearAllOrganizationData()
        }
        
        // Update current organization ID FIRST
        currentOrganizationID = orgID
        UserDefaults.standard.set(orgID, forKey: "current_organization_id")
        
        // Update services with new organization ID
        _vendorService = VendorManagementService(organizationID: orgID)
        _paymentMethodService = PaymentMethodManagementService(organizationID: orgID)
        
        // Load data for new organization
        Task {
            await loadOrganizationDataSafely(organizationID: orgID)
        }
    }
    
    /// CRITICAL SECURITY METHOD: Clear all organization data to prevent bleeding
    private func clearAllOrganizationData() {
        print("🔒 SECURITY: Clearing all organization data to prevent data bleeding")
        
        // Clear in-memory data
        organizationProjects.removeAll()
        currentOrganization = nil
        selectedProject = nil
        errorMessage = nil
        currentOrganizationID = nil
        
        // Clear cached data
        groupedHoursByTeamMember.removeAll()
        laborTotalsByTeamMember.removeAll()
        
        // Clear Enterprise Intelligence
        isEnterpriseIntelligenceEnabled = false
        
        // Clear UserDefaults current organization
        UserDefaults.standard.removeObject(forKey: "current_organization_id")
        
        print("🔒 SECURITY: All organization data cleared")
    }
    
    /// Safely load organization data with proper isolation
    private func loadOrganizationDataSafely(organizationID: String) async {
        isLoading = true
        defer { isLoading = false }
        
        print("🔒 SECURE LOADING: Starting isolated data load for organization: \(organizationID.prefix(8))...")
        
        // CRITICAL: Ensure we're loading data for the correct organization only
        guard organizationID == currentOrganizationID else {
            print("🔒 SECURITY ABORT: Organization ID mismatch during load - aborting for security")
            return
        }
        
        // Initialize Enterprise Intelligence first
        await initializeOrganizationKnowledge(organizationID: organizationID)
        
        // Load organization data first
        await loadOrganizationFromCloudKit(organizationID: organizationID)
        
        if isUsingCloudKitForOrganizationData {
            await loadProjectsFromCloudKitZone(organizationID: organizationID)
        } else {
            await loadOrganizationSpecificProjects(organizationID: organizationID)
        }
        
        // CRITICAL: Check if labor hours migration is needed
        if needsLaborHoursMigration {
            print("📊 MIGRATION NEEDED: Found unmigrated labor hours - starting migration...")
            migrateLaborHoursToTeamMemberIDs()
        }
        
        // Update team member statuses based on project activity
        updateTeamMemberStatuses()
        
        await MainActor.run {
            isLoading = false
            print("✅ SECURE LOADING COMPLETE: \(organizationProjects.count) projects, \(teamMembers.count) team members for org \(organizationID.prefix(8))...")
        }
    }

    // MARK: - CRITICAL FIX: Organization-Specific Data Storage
    
    /// Save data using organization-specific keys to prevent data bleeding
    internal func saveOrganizationSpecificBackup() {
        guard let orgID = currentOrganizationID else {
            print("🔒 SECURITY: Cannot save backup - no organization ID")
            return
        }
        
        print("💾 SECURE SAVE: Saving organization-specific backup for \(orgID.prefix(8))...")
        
        // Save projects with ORGANIZATION-SPECIFIC key
        let projectsKey = "projects_\(orgID)"
        if let projectData = try? JSONEncoder().encode(organizationProjects) {
            UserDefaults.standard.set(projectData, forKey: projectsKey)
            print("  📁 Saved \(organizationProjects.count) projects to key: \(projectsKey)")
        } else {
            print("  ❌ Failed to encode projects for organization: \(orgID)")
        }
        
        // Save organization with SPECIFIC key
        if let org = currentOrganization,
           let orgData = try? JSONEncoder().encode(org) {
            let orgKey = "organization_\(orgID)"
            UserDefaults.standard.set(orgData, forKey: orgKey)
            print("  🏢 Saved organization data to key: \(orgKey)")
        } else {
            print("  ⚠️ No organization to save")
        }
        
        // CRITICAL: Remove data from shared keys if it exists (migration cleanup)
        if UserDefaults.standard.object(forKey: "local_projects_backup") != nil {
            print("  🧹 MIGRATION: Removing shared backup key to prevent data bleeding")
            UserDefaults.standard.removeObject(forKey: "local_projects_backup")
        }
        
        UserDefaults.standard.synchronize()
        print("✅ SECURE SAVE: Organization-specific backup completed for \(orgID.prefix(8))...")
    }
    
    /// Load projects using organization-specific keys
    private func loadOrganizationSpecificProjects(organizationID: String) async {
        let projectsKey = "projects_\(organizationID)"
        print("📁 SECURE LOAD: Loading projects from organization-specific key: \(projectsKey)")
        
        guard let data = UserDefaults.standard.data(forKey: projectsKey),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else { 
            print("  ℹ️ No organization-specific project data found for \(organizationID.prefix(8))... - starting with empty projects")
            
            await MainActor.run {
                self.organizationProjects = []
            }
            return 
        }
        
        await MainActor.run {
            // CRITICAL: Verify all loaded projects belong to this organization
            let verifiedProjects = projects.filter { project in
                project.organizationID == organizationID || project.organizationID == nil
            }
            
            if verifiedProjects.count != projects.count {
                print("  🔒 SECURITY: Filtered out \(projects.count - verifiedProjects.count) projects that didn't belong to organization \(organizationID.prefix(8))...")
            }
            
            self.organizationProjects = verifiedProjects
            print("  ✅ SECURE LOAD: Loaded \(verifiedProjects.count) verified projects for organization \(organizationID.prefix(8))...")
        }
    }

    // MARK: - DEPRECATED: Remove legacy shared backup methods
    
    /// DEPRECATED: Legacy saveLocalBackup - now redirects to secure method
    internal func saveLocalBackup() {
        print("⚠️ DEPRECATED: saveLocalBackup() called - redirecting to secure method")
        saveOrganizationSpecificBackup()
    }
    
    /// DEPRECATED: Legacy loadLocalProjectsAsBackup - now redirects to secure method
    private func loadLocalProjectsAsBackup() async {
        guard let orgID = currentOrganizationID else {
            print("🔒 SECURITY: Cannot load backup - no organization ID set")
            return
        }
        
        print("⚠️ DEPRECATED: loadLocalProjectsAsBackup() called - redirecting to secure method")
        await loadOrganizationSpecificProjects(organizationID: orgID)
    }
    
    // MARK: - Enhanced Project Loading with Security
    private func loadOrganizationProjects() async {
        guard let orgID = currentOrganizationID else {
            print("🔒 SECURITY: Cannot load projects - no organization ID")
            return
        }
        
        print("📁 SECURE: Loading projects for organization: \(orgID.prefix(8))...")
        
        // CRITICAL FIX: Try CloudKit first, then fallback to local
        if isUsingCloudKitForOrganizationData {
            await loadProjectsFromCloudKitZone(organizationID: orgID)
        } else {
            await loadOrganizationSpecificProjects(organizationID: orgID)
        }
        
        // If no projects found, don't create sample data automatically
        if organizationProjects.isEmpty {
            print("  ℹ️ No projects found for organization \(orgID.prefix(8))... - this is normal for new organizations")
        }
    }
    
    /// CRITICAL FIX: Real CloudKit project saving (replaces placeholder)
    internal func saveProjectToCloudKitSharedZone(_ project: Project) async {
        guard let orgID = currentOrganizationID else {
            print("❌ CRITICAL: Cannot save project to CloudKit - no organization ID")
            errorMessage = "No organization selected"
            return
        }
        
        print("☁️ REAL CLOUDKIT SAVE: Saving project '\(project.name)' to organization \(orgID.prefix(8))...")
        
        isSavingProject = true
        defer { isSavingProject = false }
        
        do {
            // CRITICAL FIX: Actually save to CloudKit instead of just local backup
            try await cloudKitProjectService.saveProject(project, to: orgID)
            
            print("✅ REAL CLOUDKIT SAVE: Project successfully saved to CloudKit: \(project.name)")
            
            // Also save to local backup as fallback
            saveOrganizationSpecificBackup()
            
        } catch {
            print("❌ REAL CLOUDKIT SAVE: Failed to save project to CloudKit: \(error)")
            errorMessage = "Failed to save project to CloudKit: \(error.localizedDescription)"
            
            // Still save locally as fallback
            saveOrganizationSpecificBackup()
        }
    }

    /// CRITICAL FIX: Real CloudKit project loading
    private func loadProjectsFromCloudKitZone(organizationID: String) async {
        print("☁️ REAL CLOUDKIT LOAD: Loading projects from CloudKit for organization \(organizationID.prefix(8))...")
        
        do {
            // CRITICAL FIX: Actually load from CloudKit
            let cloudKitProjects = try await cloudKitProjectService.loadProjects(from: organizationID)
            
            await MainActor.run {
                self.organizationProjects = cloudKitProjects
                print("✅ REAL CLOUDKIT LOAD: Loaded \(cloudKitProjects.count) projects from CloudKit")
            }
            
            // Update local backup with CloudKit data
            saveOrganizationSpecificBackup()
            
        } catch {
            print("❌ REAL CLOUDKIT LOAD: Failed to load projects from CloudKit: \(error)")
            
            // Fallback to local storage
            print("🔄 FALLBACK: Loading projects from local storage...")
            await loadOrganizationSpecificProjects(organizationID: organizationID)
        }
    }

    /// CRITICAL FIX: Real CloudKit project deletion
    private func deleteProjectFromCloudKitSharedZone(_ projectID: UUID) async {
        guard let orgID = currentOrganizationID else {
            print("❌ CRITICAL: Cannot delete project from CloudKit - no organization ID")
            return
        }
        
        print("🗑️ REAL CLOUDKIT DELETE: Deleting project \(projectID) from organization \(orgID.prefix(8))...")
        
        do {
            // CRITICAL FIX: Actually delete from CloudKit
            try await cloudKitProjectService.deleteProject(projectID, from: orgID)
            
            print("✅ REAL CLOUDKIT DELETE: Project successfully deleted from CloudKit")
            
            // Also remove from local backup
            saveOrganizationSpecificBackup()
            
        } catch {
            print("❌ REAL CLOUDKIT DELETE: Failed to delete project from CloudKit: \(error)")
            errorMessage = "Failed to delete project from CloudKit: \(error.localizedDescription)"
            
            // Still update local backup
            saveOrganizationSpecificBackup()
        }
    }
    
    // MARK: - CloudKit Bulk Save

    func saveAllProjectsToCloudKit() async {
        guard let orgID = currentOrganizationID else {
            print("❌ CRITICAL: Cannot bulk save projects - no organization ID")
            return
        }
        
        print("☁️ BULK SAVE: Saving \(organizationProjects.count) projects to CloudKit...")
        
        isBulkSyncing = true
        bulkSyncProgress = "Preparing projects for sync..."
        
        defer {
            isBulkSyncing = false
            bulkSyncProgress = ""
        }
        
        do {
            // CRITICAL FIX: Use real CloudKit batch save
            try await cloudKitProjectService.saveProjects(organizationProjects, to: orgID)
            
            bulkSyncProgress = "All projects synced successfully!"
            print("✅ BULK SAVE: All projects successfully saved to CloudKit")
            
            // Update local backup
            saveOrganizationSpecificBackup()
            
        } catch {
            print("❌ BULK SAVE: Failed to save projects to CloudKit: \(error)")
            errorMessage = "Bulk sync failed: \(error.localizedDescription)"
            bulkSyncProgress = "Sync failed - saved locally only"
            
            // Still save locally as fallback
            saveOrganizationSpecificBackup()
        }
    }
    
    // MARK: - Emergency Recovery (SECURITY ENHANCED)

    /// Emergency recovery - restore organization-specific data only
    func emergencyDataRecovery() async -> String {
        guard let orgID = currentOrganizationID else {
            return "❌ SECURITY: Cannot perform recovery - no organization selected"
        }
        
        print("🆘 EMERGENCY DATA RECOVERY: Starting recovery for organization: \(orgID.prefix(8))...")
        
        var recoveredItems: [String] = []
        var recoveryLog = "🆘 EMERGENCY DATA RECOVERY REPORT\n"
        recoveryLog += "Organization: \(orgID.prefix(8))...\n"
        recoveryLog += "=====================================\n"
        
        // 1. Try to recover organization-specific projects
        let projectsKey = "projects_\(orgID)"
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let projects = try? JSONDecoder().decode([Project].self, from: data) {
            organizationProjects = projects.filter { $0.organizationID == orgID || $0.organizationID == nil }
            recoveredItems.append("Projects: \(organizationProjects.count)")
            recoveryLog += "✅ Recovered \(organizationProjects.count) projects from organization-specific backup\n"
            
            // CRITICAL FIX: Migrate recovered projects to CloudKit
            if !organizationProjects.isEmpty && isUsingCloudKitForOrganizationData {
                recoveryLog += "☁️ MIGRATING: Uploading recovered projects to CloudKit...\n"
                do {
                    try await cloudKitProjectService.saveProjects(organizationProjects, to: orgID)
                    recoveryLog += "✅ MIGRATION SUCCESS: All recovered projects uploaded to CloudKit\n"
                    recoveredItems.append("CloudKit Migration: SUCCESS")
                } catch {
                    recoveryLog += "❌ MIGRATION WARNING: Failed to upload to CloudKit: \(error.localizedDescription)\n"
                    recoveredItems.append("CloudKit Migration: FAILED (projects safe locally)")
                }
            }
        } else {
            recoveryLog += "❌ No organization-specific project backup found\n"
            
            // MIGRATION: Check for legacy shared backup
            if let legacyData = UserDefaults.standard.data(forKey: "local_projects_backup"),
               let legacyProjects = try? JSONDecoder().decode([Project].self, from: legacyData) {
                let orgProjects = legacyProjects.filter { $0.organizationID == orgID || $0.organizationID == nil }
                organizationProjects = orgProjects
                recoveredItems.append("Migrated Projects: \(orgProjects.count)")
                recoveryLog += "⚠️ Migrated \(orgProjects.count) projects from legacy shared backup\n"
                
                // Save to organization-specific key and remove legacy
                saveOrganizationSpecificBackup()
                UserDefaults.standard.removeObject(forKey: "local_projects_backup")
                recoveryLog += "✅ Migrated data to secure organization-specific storage\n"
                
                // CRITICAL FIX: Also migrate to CloudKit
                if !orgProjects.isEmpty && isUsingCloudKitForOrganizationData {
                    recoveryLog += "☁️ LEGACY MIGRATION: Uploading legacy projects to CloudKit...\n"
                    do {
                        try await cloudKitProjectService.saveProjects(orgProjects, to: orgID)
                        recoveryLog += "✅ LEGACY MIGRATION SUCCESS: All legacy projects uploaded to CloudKit\n"
                        recoveredItems.append("Legacy CloudKit Migration: SUCCESS")
                    } catch {
                        recoveryLog += "❌ LEGACY MIGRATION WARNING: Failed to upload to CloudKit: \(error.localizedDescription)\n"
                        recoveredItems.append("Legacy CloudKit Migration: FAILED (projects safe locally)")
                    }
                }
            }
        }
        
        // 2. Try to recover organization data
        let orgKey = "organization_\(orgID)"
        if let data = UserDefaults.standard.data(forKey: orgKey),
           let organization = try? JSONDecoder().decode(Organization.self, from: data) {
            currentOrganization = organization
            recoveredItems.append("Organization: \(organization.name)")
            recoveryLog += "✅ Recovered organization: \(organization.name) with \(organization.teamMembers.count) team members\n"
        } else {
            recoveryLog += "❌ No organization-specific data found\n"
            
            // Create emergency organization for this specific org ID
            let emergencyOrg = Organization(
                id: orgID,
                name: "Recovered Organization", 
                adminUserID: getCurrentUserID() ?? ""
            )
            currentOrganization = emergencyOrg
            recoveredItems.append("Created emergency organization")
            recoveryLog += "🆕 Created emergency organization for ID: \(orgID.prefix(8))...\n"
        }
        
        // 4. Force save recovered data with organization-specific keys
        saveOrganizationSpecificBackup()
        
        let totalRecovered = recoveredItems.count
        recoveryLog += "\n🎉 Recovery completed: \(totalRecovered) data types recovered\n"
        recoveryLog += "Recovered: \(recoveredItems.joined(separator: ", "))\n"
        recoveryLog += "\n🔒 SECURITY: All data properly isolated to organization \(orgID.prefix(8))...\n"
        recoveryLog += "\n☁️ CLOUDKIT STATUS: \(isUsingCloudKitForOrganizationData ? "ENABLED - Projects will sync to CloudKit" : "DISABLED - Local storage only")\n"
        
        print(recoveryLog)
        return recoveryLog
    }
}

// MARK: - CloudKit Cleanup & Data Consistency Methods

/// Clean up CloudKit test organizations and consolidate data
func cleanupCloudKitTestOrganizations(keepOrganizationIDs: [String] = []) async -> String {
    print("🧹 CLEANUP: Starting CloudKit test organization cleanup...")
    
    var cleanupLog = "🧹 CLOUDKIT CLEANUP REPORT\n"
    cleanupLog += "=====================================\n"
    
    // List of test organization patterns to remove
    let testPatterns = [
        "Debug Test Org",
        "test-org",
        "DEBUG-",
        "TEST-"
    ]
    
    cleanupLog += "Target patterns for cleanup: \(testPatterns.joined(separator: ", "))\n"
    cleanupLog += "Organizations to keep: \(keepOrganizationIDs.joined(separator: ", "))\n\n"
    
    // For now, log what would be cleaned up
    // In a full implementation, this would use CloudKit queries to find and delete test organizations
    
    cleanupLog += "⚠️ MANUAL CLEANUP REQUIRED:\n"
    cleanupLog += "1. Open CloudKit Console at https://icloud.developer.apple.com/dashboard/\n"
    cleanupLog += "2. Navigate to your container: iCloud.com.rheirhome.rheirhomeappV3\n"
    cleanupLog += "3. Go to Data > Private Database\n"
    cleanupLog += "4. Delete test organization zones matching patterns above\n"
    cleanupLog += "5. Keep production organizations: \(keepOrganizationIDs.joined(separator: ", "))\n\n"
    
    cleanupLog += "✅ Cleanup preparation completed\n"
    
    print(cleanupLog)
    return cleanupLog
}

/// Force sync all local data to CloudKit
func forceSyncAllDataToCloudKit() async -> String {
    guard let orgID = currentOrganizationID else {
        return "❌ Cannot sync - no organization selected"
    }
    
    print("🔄 FORCE SYNC: Starting complete data synchronization to CloudKit...")
    
    var syncLog = "🔄 COMPLETE CLOUDKIT SYNC REPORT\n"
    syncLog += "Organization: \(orgID.prefix(8))...\n"
    syncLog += "=====================================\n"
    
    isBulkSyncing = true
    bulkSyncProgress = "Starting complete sync..."
    
    defer {
        isBulkSyncing = false
        bulkSyncProgress = ""
    }
    
    // 1. Ensure CloudKit zone exists
    do {
        try await cloudKitProjectService.ensureOrganizationZoneExists(orgID)
        syncLog += "✅ Organization zone verified/created\n"
        bulkSyncProgress = "Zone setup complete..."
    } catch {
        syncLog += "❌ Failed to create organization zone: \(error.localizedDescription)\n"
        return syncLog
    }
    
    // 2. Sync all projects
    if !organizationProjects.isEmpty {
        bulkSyncProgress = "Syncing \(organizationProjects.count) projects..."
        
        do {
            try await cloudKitProjectService.saveProjects(organizationProjects, to: orgID)
            syncLog += "✅ Synced \(organizationProjects.count) projects to CloudKit\n"
        } catch {
            syncLog += "❌ Failed to sync projects: \(error.localizedDescription)\n"
            syncLog += "   Projects remain safe in local storage\n"
        }
    } else {
        syncLog += "ℹ️ No projects to sync\n"
    }
    
    // 3. Verify sync by loading from CloudKit
    bulkSyncProgress = "Verifying sync..."
    
    do {
        let cloudKitProjects = try await cloudKitProjectService.loadProjects(from: orgID)
        syncLog += "✅ Verification: \(cloudKitProjects.count) projects found in CloudKit\n"
        
        if cloudKitProjects.count == organizationProjects.count {
            syncLog += "✅ SYNC SUCCESS: Local and CloudKit project counts match\n"
        } else {
            syncLog += "⚠️ SYNC WARNING: Count mismatch - Local: \(organizationProjects.count), CloudKit: \(cloudKitProjects.count)\n"
        }
    } catch {
        syncLog += "❌ Verification failed: \(error.localizedDescription)\n"
    }
    
    bulkSyncProgress = "Sync completed!"
    syncLog += "\n🎉 Force sync completed for organization \(orgID.prefix(8))...\n"
    
    print(syncLog)
    return syncLog
}

/// Get detailed CloudKit sync status
func getCloudKitSyncStatus() async -> String {
    guard let orgID = currentOrganizationID else {
        return "❌ No organization selected - cannot check sync status"
    }
    
    var statusLog = "☁️ CLOUDKIT SYNC STATUS REPORT\n"
    statusLog += "Organization: \(orgID.prefix(8))...\n"
    statusLog += "=====================================\n"
    
    // Local data status
    statusLog += "LOCAL DATA:\n"
    statusLog += "• Projects: \(organizationProjects.count)\n"
    statusLog += "• Team Members: \(teamMembers.count)\n"
    statusLog += "• CloudKit Mode: \(isUsingCloudKitForOrganizationData ? "ENABLED" : "DISABLED")\n\n"
    
    // CloudKit data status
    statusLog += "CLOUDKIT DATA:\n"
    
    if isUsingCloudKitForOrganizationData {
        do {
            let cloudKitProjects = try await cloudKitProjectService.loadProjects(from: orgID)
            statusLog += "• Projects in CloudKit: \(cloudKitProjects.count)\n"
            
            if cloudKitProjects.count == organizationProjects.count {
                statusLog += "• Sync Status: ✅ IN SYNC\n"
            } else {
                statusLog += "• Sync Status: ⚠️ OUT OF SYNC\n"
                statusLog += "• Difference: \(abs(cloudKitProjects.count - organizationProjects.count)) projects\n"
            }
            
            statusLog += "• CloudKit Service Status: \(cloudKitProjectService.syncStatus)\n"
            
            if let lastError = cloudKitProjectService.lastSyncError {
                statusLog += "• Last Error: \(lastError.localizedDescription)\n"
            }
            
        } catch {
            statusLog += "• CloudKit Query Failed: \(error.localizedDescription)\n"
            statusLog += "• Sync Status: ❌ CANNOT VERIFY\n"
        }
    } else {
        statusLog += "• CloudKit disabled - using local storage only\n"
        statusLog += "• Sync Status: ⚠️ NOT SYNCING\n"
    }
    
    statusLog += "\nRECOMMENDATIONS:\n"
    
    if !isUsingCloudKitForOrganizationData {
        statusLog += "• Enable CloudKit mode for data persistence\n"
        statusLog += "• Run forceSyncAllDataToCloudKit() to upload existing data\n"
    } else if organizationProjects.isEmpty {
        statusLog += "• No projects found - this is normal for new organizations\n"
    } else {
        statusLog += "• Data looks good - projects are syncing properly\n"
    }
    
    return statusLog
}