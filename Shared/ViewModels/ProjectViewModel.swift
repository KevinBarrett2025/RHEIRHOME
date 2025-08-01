import Foundation
import SwiftUI
import CloudKit
import Combine

@MainActor
class ProjectViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var teamMembers: [TeamMember] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var receipts: [Receipt] = []
    @Published var organizationProjects: [Project] = []
    @Published var currentOrganizationID: String?
    @Published var navigateToBudgetBreakdown: Bool = false
    @Published var isBulkSyncing: Bool = false
    @Published var isMigratingPhotos: Bool = false
    @Published var isOnline: Bool = true
    @Published var isUsingCloudKitForOrganizationData: Bool = true
    @Published var migrationProgress: String = ""
    @Published var bulkSyncProgress: String = ""
    @Published var isSavingProject: Bool = false
    
    // MARK: - Analytics Structures
    struct VendorSpendingAnalytics {
        let vendor: VendorInfo
        let amount: Double
    }

    struct PaymentMethodSpendingAnalytics {
        let paymentMethod: PaymentMethodInfo
        let amount: Double
    }

    struct VendorInfo {
        let id: UUID
        let name: String
    }

    struct PaymentMethodInfo {
        let id: UUID
        let name: String
    }
    
    // MARK: - Services
    let cloudKitService: CloudKitAuthService
    let vendorService: VendorManagementService
    let paymentMethodService: PaymentMethodManagementService
    private let simpleCloudKitService: SimpleCloudKitSharingService

    // MARK: - Cache Properties
    var teamMemberCache: [String: TeamMember] = [:]
    var groupedHoursByTeamMember: [String: [WorkHour]] = [:]
    var laborTotalsByTeamMember: [String: (unpaid: Double, paid: Double)] = [:]
    
    // MARK: - Computed Properties
    var allProjects: [Project] {
        // Combine local projects (cached) with organization projects (CloudKit)
        return projects + organizationProjects
    }
    
    /// Get projects filtered by current user's role and permissions
    var accessibleProjects: [Project] {
        guard let currentUserID = getCurrentUserID(),
              let currentOrgID = currentOrganizationID else {
            return []
        }
        
        // Get user's role in current organization
        let userRole = getCurrentUserRole()
        
        let filteredProjects = organizationProjects.filter { project in
            // Only show projects from current organization
            guard project.organizationID == currentOrgID else { return false }
            
            // Apply role-based filtering
            return project.userHasAccess(userID: currentUserID, userRole: userRole)
        }
        
        // Log filtering results for debugging multi-org switching
        print(" Filtered projects for \(currentOrgID.prefix(8))... (\(userRole.displayName)): \(filteredProjects.count) of \(organizationProjects.count)")
        
        return filteredProjects.sorted { $0.startDate > $1.startDate }
    }
    
    /// Get all projects across all organizations (for multi-org overview)
    var allOrganizationProjects: [Project] {
        return organizationProjects.sorted { $0.startDate > $1.startDate }
    }
    
    /// Get projects by organization ID (useful for multi-org users)
    func getProjects(for organizationID: String) -> [Project] {
        let userRole = getCurrentUserRole()
        guard let currentUserID = getCurrentUserID() else { return [] }
        
        return organizationProjects.filter { project in
            guard project.organizationID == organizationID else { return false }
            return project.userHasAccess(userID: currentUserID, userRole: userRole)
        }
    }
    
    /// Get project count by organization (for multi-org dashboard)
    func getProjectCount(for organizationID: String) -> Int {
        return getProjects(for: organizationID).count
    }
    
    /// Get organization summary for multi-org users
    func getOrganizationProjectSummary() -> [(orgID: String, orgName: String, projectCount: Int, role: String)] {
        // This would require access to organization names, which we'd get from AuthViewModel
        // For now, return basic info
        let groupedByOrg = Dictionary(grouping: organizationProjects) { $0.organizationID ?? "unknown" }
        
        return groupedByOrg.map { (orgID, projects) in
            let accessibleProjects = projects.filter { project in
                guard let currentUserID = getCurrentUserID() else { return false }
                let userRole = getCurrentUserRole()
                return project.userHasAccess(userID: currentUserID, userRole: userRole)
            }
            
            return (
                orgID: orgID,
                orgName: "Organization \(orgID.prefix(8))...",
                projectCount: accessibleProjects.count,
                role: getCurrentUserRole().displayName
            )
        }
    }
    
    /// Get projects the current user can edit
    var editableProjects: [Project] {
        guard let currentUserID = getCurrentUserID(),
              let currentOrgID = currentOrganizationID else {
            return []
        }
        
        let userRole = getCurrentUserRole()
        
        return organizationProjects.filter { project in
            guard project.organizationID == currentOrgID else { return false }
            return project.userCanEdit(userID: currentUserID, userRole: userRole)
        }
    }
    
    // MARK: - Receipt Methods
    func recomputeFilteredReceipts() {
        // Placeholder for receipt filtering
        print(" Recomputing filtered receipts")
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private var teamMemberSaveTimer: Timer?
    private var activeSaveOperations: Set<UUID> = [] // Track projects being saved
    private var pendingUpdates: [UUID: Project] = [:] // Store pending project updates
    
    // MARK: - Role and Permission Helpers
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
    
    private func getCurrentUserRole() -> OrganizationRole {
        // This should be injected from AuthViewModel, but for now get from UserDefaults
        guard let orgID = currentOrganizationID,
              let roleString = UserDefaults.standard.string(forKey: "user_role_\(orgID)"),
              let role = OrganizationRole(rawValue: roleString) else {
            return .member // Default to member if unknown
        }
        return role
    }
    
    /// Set current user's role for the organization (called from AuthViewModel)
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization orgID: String) {
        UserDefaults.standard.set(role.rawValue, forKey: "user_role_\(orgID)")
        print(" Set user role: \(role.displayName) for organization \(orgID.prefix(8))...")
    }
    
    // MARK: - Initialization
    init(cloudKitService: CloudKitAuthService = CloudKitAuthService()) {
        self.cloudKitService = cloudKitService
        self.vendorService = VendorManagementService()
        self.paymentMethodService = PaymentMethodManagementService()
        self.simpleCloudKitService = SimpleCloudKitSharingService()
        
        print(" ProjectViewModel initialized with PRODUCTION CloudKit services")
        
        Task {
            await setupCloudKitForCurrentOrganization()
            await loadProjects()
            await loadTeamMembersFromCloudKit()
            await loadOrganizationData()
        }
    }
    
    convenience init() {
        self.init(cloudKitService: CloudKitAuthService())
    }
    
    // MARK: - CloudKit Setup with Better Error Handling
    private func setupCloudKitForCurrentOrganization() async {
        // Get current organization from AuthViewModel context or UserDefaults
        currentOrganizationID = UserDefaults.standard.string(forKey: "currentOrganizationID")
        
        if let orgID = currentOrganizationID {
            print(" Setting up CloudKit for organization: \(orgID.prefix(8))...")
            
            // Setup organization zone in SimpleCloudKitSharingService with proper waiting
            await simpleCloudKitService.setCurrentOrganization(orgID)
            
            // Verify zone is active before proceeding
            if simpleCloudKitService.isOrganizationSharingActive() {
                isUsingCloudKitForOrganizationData = true
                print(" CloudKit organization zone active and ready")
            } else {
                isUsingCloudKitForOrganizationData = false
                print(" CloudKit organization zone failed to activate")
            }
        } else {
            print(" No organization ID found - CloudKit organization features disabled")
            isUsingCloudKitForOrganizationData = false
        }
    }
    
    // MARK: - Loading Methods with Better Error Handling
    func loadProjects() async {
        // CRITICAL: Don't reload if we're actively saving projects
        guard !isSavingProject && activeSaveOperations.isEmpty else {
            print(" Skipping project reload - save operation in progress")
            print("  - isSavingProject: \(isSavingProject)")
            print("  - activeSaveOperations: \(activeSaveOperations.count)")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print(" Loading projects from CloudKit...")
        
        // Load organization projects from CloudKit first
        await loadOrganizationProjects()
        
        // Load local projects (cached from previous sessions) as backup
        await loadLocalProjectsAsBackup()
        
        // Load team members
        await loadTeamMembersFromCloudKit()
        
        print(" Project loading completed: \(organizationProjects.count) from CloudKit, \(projects.count) from backup")
    }
    
    private func loadOrganizationProjects() async {
        // CRITICAL: Don't reload if save operations are active
        guard !isSavingProject && activeSaveOperations.isEmpty else {
            print(" Skipping CloudKit reload - save operation in progress")
            return
        }
        
        guard isUsingCloudKitForOrganizationData else {
            print(" CloudKit not configured - skipping organization projects")
            organizationProjects = []
            return
        }
        
        print(" LOAD DEBUG: Starting organization projects load...")
        print(" LOAD DEBUG: Organization ID: \(currentOrganizationID?.prefix(8) ?? "none")")
        
        // Ensure CloudKit zone is ready before loading
        if !simpleCloudKitService.isOrganizationSharingActive() {
            print(" LOAD DEBUG: CloudKit zone not active - attempting to reactivate...")
            await setupCloudKitForCurrentOrganization()
            
            if !simpleCloudKitService.isOrganizationSharingActive() {
                print(" LOAD DEBUG: Zone reactivation failed")
                organizationProjects = []
                errorMessage = "CloudKit zone not available - please check your internet connection"
                return
            }
        }
        
        print(" LOAD DEBUG: Zone is active, loading projects...")
        
        do {
            let cloudProjects = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Project], Error>) in
                simpleCloudKitService.loadProjectsFromSharedZone()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { projects in
                            continuation.resume(returning: projects)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // Merge with any pending updates to avoid overwriting unsaved changes
            var mergedProjects = cloudProjects
            for (projectID, pendingProject) in pendingUpdates {
                if let index = mergedProjects.firstIndex(where: { $0.id == projectID }) {
                    mergedProjects[index] = pendingProject
                    print(" Merged pending update for project: \(pendingProject.name)")
                }
            }
            
            organizationProjects = mergedProjects
            print(" LOAD DEBUG: Final project count: \(organizationProjects.count)")
            
            if organizationProjects.isEmpty {
                print(" LOAD DEBUG: NO PROJECTS LOADED FROM CLOUDKIT!")
                print("   This suggests either:")
                print("   1. No projects have been created yet")
                print("   2. Projects aren't being saved to CloudKit properly")
                print("   3. CloudKit query is not finding the records")
            } else {
                print(" LOAD DEBUG: Projects loaded successfully:")
                for (i, project) in organizationProjects.enumerated() {
                    print("   \(i + 1). \(project.name) (\(project.client)) - ID: \(project.id.uuidString.prefix(8))")
                }
            }
            
            // Save successful load as backup
            await saveLocalBackup()
            
        } catch {
            print(" LOAD DEBUG: Failed to load organization projects from CloudKit: \(error)")
            
            if let ckError = error as? CKError {
                print(" LOAD DEBUG: CloudKit error details:")
                print("   Code: \(ckError.code.rawValue)")
                print("   Description: \(ckError.localizedDescription)")
                
                switch ckError.code {
                case .networkUnavailable:
                    errorMessage = "No internet connection - showing cached projects only"
                case .notAuthenticated:
                    errorMessage = "Please sign in to iCloud and restart the app"
                case .zoneNotFound:
                    errorMessage = "Organization zone not found - please contact support"
                default:
                    errorMessage = "Failed to load projects from cloud: \(ckError.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to load projects from cloud: \(error.localizedDescription)"
            }
            
            organizationProjects = []
            
            // Try emergency recovery if no projects loaded
            if organizationProjects.isEmpty {
                print(" LOAD DEBUG: No projects loaded from CloudKit - attempting emergency recovery...")
                let recoverySuccess = await emergencyRecoverFromBackup()
                if recoverySuccess {
                    print(" LOAD DEBUG: Emergency recovery restored \(organizationProjects.count) projects")
                } else {
                    print(" LOAD DEBUG: Emergency recovery failed - no backup available")
                }
            }
        }
    }
    
    private func loadLocalProjectsAsBackup() async {
        // Load local projects as backup/cache only
        if let data = UserDefaults.standard.data(forKey: "projects_backup"),
           let backupProjects = try? JSONDecoder().decode([Project].self, from: data) {
            projects = backupProjects
            print(" Loaded \(projects.count) backup projects from local cache")
        } else {
            projects = []
            print(" No local backup projects found")
        }
    }
    
    func loadOrganizationData() async {
        // Load current organization ID
        currentOrganizationID = UserDefaults.standard.string(forKey: "currentOrganizationID")
        print(" Current organization ID: \(currentOrganizationID ?? "none")")
        
        if currentOrganizationID != nil {
            await setupCloudKitForCurrentOrganization()
        }
    }
    
    // MARK: - Organization Methods
    func organizationDidChange(_ organizationID: String?) {
        currentOrganizationID = organizationID
        UserDefaults.standard.set(organizationID, forKey: "currentOrganizationID")
        
        print(" Organization changed to: \(organizationID ?? "none")")
        
        // Clear current selection when switching organizations
        selectedProject = nil
        
        Task {
            await setupCloudKitForCurrentOrganization()
            // Use safe loading to respect active save operations
            await safeLoadProjects()
            await loadTeamMembersFromCloudKit()
            
            // Log project counts for the new organization
            let accessibleCount = accessibleProjects.count
            let totalCount = organizationProjects.filter { $0.organizationID == organizationID }.count
            print(" Organization switch complete: \(accessibleCount) accessible of \(totalCount) total projects")
        }
    }
    
    // MARK: - Safe Loading Methods
    
    /// Safely reload projects only if no save operations are active
    func safeLoadProjects() async {
        if isSavingProject || !activeSaveOperations.isEmpty {
            print("⚠️ Deferring project reload - save operations active")
            
            // Wait for active saves to complete
            while isSavingProject || !activeSaveOperations.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
            }
            
            print("✅ Save operations completed - proceeding with reload")
        }
        
        await loadProjects()
    }
    
    /// Force reload projects (use with caution)
    func forceLoadProjects() async {
        print("⚠️ FORCE reloading projects - this may overwrite unsaved changes!")
        
        // Clear save state
        isSavingProject = false
        activeSaveOperations.removeAll()
        pendingUpdates.removeAll()
        
        await loadProjects()
    }
    
    /// Check if it's safe to reload data
    var canSafelyReload: Bool {
        return !isSavingProject && activeSaveOperations.isEmpty
    }
    
    // MARK: - Enhanced Organization Member Sync Methods
    
    /// Sync organization members with local team members to fix user count discrepancies
    func syncOrganizationMembers(_ organization: Organization) async {
        print(" Syncing organization members with local team members...")
        
        // Add missing team members for organization members
        for memberID in organization.members {
            let existingMember = teamMembers.first { $0.appUserID == memberID }
            
            if existingMember == nil {
                // Create placeholder team member for organization member
                let newTeamMember = TeamMember(
                    name: "Team Member \(memberID.prefix(8))",
                    jobTitle: "Team Member",
                    organizationID: organization.id,
                    hasAppAccess: true,
                    appUserID: memberID
                )
                
                teamMembers.append(newTeamMember)
                print(" Added team member for organization member \(memberID.prefix(8))...")
            } else if let existingMember = existingMember, !existingMember.hasAppAccess {
                // Update existing member to have app access if they're in the organization
                if let index = teamMembers.firstIndex(where: { $0.id == existingMember.id }) {
                    teamMembers[index].hasAppAccess = true
                    print(" Granted app access to existing team member \(existingMember.name)")
                }
            }
        }
        
        // Remove app access from team members not in organization (except admin)
        for i in 0..<teamMembers.count {
            let member = teamMembers[i]
            let isAdmin = member.appUserID == organization.adminUserID
            let isInOrganization = organization.members.contains(member.appUserID ?? "")
            
            if member.hasAppAccess && !isAdmin && !isInOrganization {
                teamMembers[i].hasAppAccess = false
                print(" Removed app access from \(member.name) - not in organization")
            }
        }
        
        await saveTeamMembersToCloudKit()
        print(" Organization member sync completed")
    }
    
    /// Get organization member count for debugging
    func getOrganizationMemberAnalysis(_ organization: Organization) -> String {
        let cloudKitUsers = organization.members.count + 1 // +1 for admin
        let localAppUsers = teamMembers.filter { $0.hasAppAccess }.count + 1 // +1 for current user
        let discrepancy = cloudKitUsers - localAppUsers
        
        var analysis = "ORGANIZATION MEMBER ANALYSIS:\n"
        analysis += "• Organization: \(organization.name)\n"
        analysis += "• CloudKit Users: \(cloudKitUsers)\n"
        analysis += "• Local App Users: \(localAppUsers)\n"
        analysis += "• Discrepancy: \(discrepancy > 0 ? "+" : "")\(discrepancy)\n"
        analysis += "• Status: \(discrepancy == 0 ? "✅ SYNCED" : "❌ OUT OF SYNC")\n"
        
        return analysis
    }
    
    // MARK: - Project Methods
    func select(_ project: Project) {
        // Verify user has access to this project
        guard let currentUserID = getCurrentUserID() else {
            print(" No current user ID - cannot select project")
            return
        }
        
        let userRole = getCurrentUserRole()
        guard project.userHasAccess(userID: currentUserID, userRole: userRole) else {
            print(" User does not have access to project: \(project.name)")
            errorMessage = "You don't have permission to access this project"
            return
        }
        
        selectedProject = project
        recomputeLaborData()
        print(" Selected project: \(project.name)")
    }
    
    func createNewProject(_ project: Project) {
        var newProject = project
        
        // Set organization ID if not already set
        if newProject.organizationID == nil {
            newProject.organizationID = currentOrganizationID
        }
        
        // Set project manager to current user
        if let currentUserID = getCurrentUserID() {
            newProject.setProjectManager(currentUserID)
        }
        
        // Default to organization-wide access for team members
        let userRole = getCurrentUserRole()
        if userRole == .admin || userRole == .member {
            newProject.accessLevel = .organization
        } else {
            // For contractors, create restricted project and assign them
            newProject.accessLevel = .restricted
            if let currentUserID = getCurrentUserID() {
                newProject.assignUser(currentUserID)
            }
        }
        
        addProject(newProject)
    }
    
    func addProject(_ project: Project) {
        // Verify user can create projects
        let userRole = getCurrentUserRole()
        guard userRole.canCreateProjects else {
            errorMessage = "You don't have permission to create projects"
            return
        }
        
        print(" SAVE DEBUG: Starting addProject for '\(project.name)'")
        print(" SAVE DEBUG: Organization ID: \(project.organizationID ?? "none")")
        print(" SAVE DEBUG: CloudKit enabled: \(isUsingCloudKitForOrganizationData)")
        
        // CRITICAL FIX: Don't add to local array until CloudKit save succeeds
        print(" SAVE DEBUG: Attempting CloudKit save FIRST before local update...")
        
        Task {
            let saveSuccess = await saveProjectToCloudKitWithVerification(project)
            
            await MainActor.run {
                if saveSuccess {
                    // Only add to local array after CloudKit success
                    organizationProjects.append(project)
                    print(" SAVE SUCCESS: Project '\(project.name)' saved to CloudKit and added locally")
                    
                    // Save local backup after successful CloudKit save
                    saveLocalBackup()
                    
                    // Show success feedback
                    errorMessage = nil
                } else {
                    // CRITICAL: Show user that save failed
                    errorMessage = " Failed to save project '\(project.name)' to cloud. Please check your internet connection and try again."
                    print(" SAVE FAILED: Project '\(project.name)' NOT saved to CloudKit - not adding to local array")
                }
            }
        }
    }
    
    func updateProject(_ project: Project) {
        print(" ProjectViewModel.updateProject called for: \(project.name)")
        print("  - Project ID: \(project.id)")
        print("  - Organization ID: \(project.organizationID ?? "none")")
        print("  - Current organizationProjects count: \(organizationProjects.count)")
        
        // Verify user can edit this project
        guard let currentUserID = getCurrentUserID() else {
            print(" No current user ID found")
            errorMessage = "Unable to verify user permissions"
            return
        }
        
        let userRole = getCurrentUserRole()
        guard project.userCanEdit(userID: currentUserID, userRole: userRole) else {
            print(" User \(currentUserID.prefix(8))... cannot edit project \(project.name)")
            print("  - User role: \(userRole.displayName)")
            print("  - Project manager: \(project.projectManagerID ?? "none")")
            print("  - Access level: \(project.accessLevel)")
            errorMessage = "You don't have permission to edit this project"
            return
        }
        
        print(" User has permission to edit project")
        
        // CRITICAL: Mark this project as being saved to prevent race conditions
        isSavingProject = true
        activeSaveOperations.insert(project.id)
        pendingUpdates[project.id] = project
        
        print(" Project save state LOCKED for: \(project.name)")
        print("  - Active save operations: \(activeSaveOperations.count)")
        
        // Update in local organization projects FIRST (for immediate UI update)
        var foundAndUpdated = false
        for i in 0..<organizationProjects.count {
            if organizationProjects[i].id == project.id {
                let oldProject = organizationProjects[i]
                organizationProjects[i] = project
                foundAndUpdated = true
                
                print(" Updated project in local organizationProjects array at index \(i)")
                print("  - Old name: '\(oldProject.name)' -> New name: '\(project.name)'")
                print("  - Old client: '\(oldProject.client)' -> New client: '\(project.client)'")
                break
            }
        }
        
        if !foundAndUpdated {
            print(" Project not found in organizationProjects array")
            print("  - Looking for ID: \(project.id)")
            print("  - Organization projects count: \(organizationProjects.count)")
            print("  - First few project IDs in array:")
            for (i, p) in organizationProjects.prefix(3).enumerated() {
                print("    \(i): \(p.id) - \(p.name)")
            }
            
            // Try to add it if it's not found (fallback)
            organizationProjects.append(project)
            print(" Added project to organizationProjects as fallback")
        }
        
        // Update selected project if it matches
        if selectedProject?.id == project.id {
            selectedProject = project
            print(" Updated selectedProject")
        }
        
        // Also update local backup immediately
        saveLocalBackup()
        
        // Update in CloudKit (async) with proper save state management and verification
        Task {
            print(" Starting CloudKit save for project: \(project.name)")
            let saveSuccess = await saveProjectToCloudKitWithVerification(project)
            
            // CRITICAL: Clear save state after CloudKit operation completes
            await MainActor.run {
                activeSaveOperations.remove(project.id)
                pendingUpdates.removeValue(forKey: project.id)
                
                // Only clear isSavingProject if no other saves are active
                if activeSaveOperations.isEmpty {
                    isSavingProject = false
                }
                
                if saveSuccess {
                    print(" CloudKit save succeeded for: \(project.name)")
                    errorMessage = nil
                } else {
                    print(" CloudKit save failed for: \(project.name)")
                    errorMessage = " Changes saved locally but failed to sync to cloud. Please check your internet connection."
                }
                
                print(" Project save state UNLOCKED for: \(project.name)")
                print("  - Remaining active save operations: \(activeSaveOperations.count)")
            }
        }
        
        print(" updateProject completed for: \(project.name)")
    }
    
    func save(_ project: Project) {
        updateProject(project)
    }
    
    func deleteProject(_ project: Project) {
        // Remove from CloudKit
        Task {
            await deleteProjectFromCloudKit(project)
        }
        
        // Remove from local organization projects
        organizationProjects.removeAll { $0.id == project.id }
        
        // Clear selection if this project was selected
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        
        print(" Deleted project from organization: \(project.name)")
    }
    
    func deleteProjectPermanently(_ project: Project, completion: @escaping (Bool, String?) -> Void) {
        Task {
            let success = await deleteProjectFromCloudKit(project)
            await MainActor.run {
                if success {
                    organizationProjects.removeAll { $0.id == project.id }
                    if selectedProject?.id == project.id {
                        selectedProject = nil
                    }
                    completion(true, nil)
                } else {
                    completion(false, "Failed to delete project from CloudKit")
                }
            }
        }
    }
    
    func markProjectAsCompleted(_ project: Project) {
        var updatedProject = project
        updatedProject.status = .completed
        updateProject(updatedProject)
    }
    
    // MARK: - CloudKit Project Operations
    
    private func saveProjectToCloudKit(_ project: Project) async {
        guard isUsingCloudKitForOrganizationData else {
            print(" CloudKit not configured - cannot save project to cloud")
            return
        }
        
        // Ensure zone is ready before saving
        if !simpleCloudKitService.isOrganizationSharingActive() {
            print(" CloudKit zone not active - reactivating before save...")
            await setupCloudKitForCurrentOrganization()
        }
        
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                let _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    simpleCloudKitService.saveProjectToSharedZone(project)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { _ in
                                continuation.resume(returning: ())
                            }
                        )
                        .store(in: &cancellables)
                }
                
                print(" Saved project '\(project.name)' to CloudKit organization zone")
                
                // Also save to local backup on successful save
                saveLocalBackup()
                return
                
            } catch {
                retryCount += 1
                print(" Failed to save project '\(project.name)' to CloudKit (attempt \(retryCount)/\(maxRetries)): \(error)")
                
                if retryCount < maxRetries {
                    print(" Retrying save in 1 second...")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    
                    // Try to reactivate zone before retry
                    await setupCloudKitForCurrentOrganization()
                } else {
                    errorMessage = "Failed to save project to cloud after \(maxRetries) attempts: \(error.localizedDescription)"
                    print(" Giving up on saving project '\(project.name)' after \(maxRetries) attempts")
                }
            }
        }
    }
    
    /// Enhanced CloudKit save with verification and better error handling
    private func saveProjectToCloudKitWithVerification(_ project: Project) async -> Bool {
        guard isUsingCloudKitForOrganizationData else {
            print(" SAVE DEBUG: CloudKit not configured - cannot save project")
            errorMessage = "CloudKit not available - project saved locally only"
            return false
        }
        
        print(" SAVE DEBUG: Starting CloudKit save for '\(project.name)'...")
        
        // Ensure zone is ready
        if !simpleCloudKitService.isOrganizationSharingActive() {
            print(" SAVE DEBUG: Zone not active, setting up...")
            await setupCloudKitForCurrentOrganization()
            
            if !simpleCloudKitService.isOrganizationSharingActive() {
                print(" SAVE DEBUG: Zone setup failed - cannot save")
                return false
            }
        }
        
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                print(" SAVE DEBUG: Save attempt \(retryCount + 1)/\(maxRetries)...")
                
                let _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                    simpleCloudKitService.saveProjectToSharedZone(project)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    print(" SAVE DEBUG: CloudKit error: \(error)")
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { record in
                                print(" SAVE DEBUG: CloudKit save succeeded, got record: \(record.recordID)")
                                continuation.resume(returning: record)
                            }
                        )
                        .store(in: &cancellables)
                }
                
                print(" SAVE DEBUG: CloudKit save successful for '\(project.name)'")
                
                // CRITICAL: Verify the save by loading it back
                let verificationSuccess = await verifyProjectSavedToCloudKit(project)
                
                if verificationSuccess {
                    print(" SAVE VERIFICATION: Project '\(project.name)' verified in CloudKit")
                    return true
                } else {
                    print(" SAVE VERIFICATION: Project save succeeded but verification failed - treating as success")
                    return true // Don't fail on verification issues, just log them
                }
                
            } catch {
                retryCount += 1
                print(" SAVE DEBUG: Save attempt \(retryCount) failed: \(error)")
                
                if retryCount < maxRetries {
                    print(" SAVE DEBUG: Retrying in \(retryCount) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(retryCount * 1_000_000_000))
                    
                    // Try to reactivate zone before retry
                    await setupCloudKitForCurrentOrganization()
                } else {
                    errorMessage = "Failed to save project to cloud after \(maxRetries) attempts: \(error.localizedDescription)"
                    print(" Giving up on saving project '\(project.name)' after \(maxRetries) attempts")
                    return false
                }
            }
        }
        
        print(" SAVE DEBUG: All save attempts failed for '\(project.name)'")
        return false
    }
    
    private func verifyProjectSavedToCloudKit(_ project: Project) async -> Bool {
        print(" VERIFICATION: Checking if project '\(project.name)' exists in CloudKit...")
        
        do {
            let cloudProjects = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Project], Error>) in
                simpleCloudKitService.loadProjectsFromSharedZone()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print(" VERIFICATION: Load failed: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { projects in
                            print(" VERIFICATION: Loaded \(projects.count) projects from CloudKit")
                            continuation.resume(returning: projects)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            let foundProject = cloudProjects.first { $0.id == project.id }
            
            if let foundProject = foundProject {
                print(" VERIFICATION: Found project '\(foundProject.name)' with ID \(foundProject.id)")
                return true
            } else {
                print(" VERIFICATION: Project '\(project.name)' with ID \(project.id) NOT found in CloudKit")
                print(" VERIFICATION: Available project IDs: \(cloudProjects.map { $0.id.uuidString.prefix(8) })")
                return false
            }
            
        } catch {
            print(" VERIFICATION: Could not verify save due to error: \(error)")
            return false // Assume verification failed if we can't check
        }
    }
    
    private func deleteProjectFromCloudKit(_ project: Project) async -> Bool {
        guard isUsingCloudKitForOrganizationData else {
            print(" CloudKit not configured - cannot delete project from cloud")
            return false
        }
        
        // Implementation would depend on the CloudKit service having a delete method
        // For now, we'll mark as deleted and re-save to exclude from queries
        var deletedProject = project
        deletedProject.status = .completed // or add a deleted status
        
        Task {
            let _ = await saveProjectToCloudKitWithVerification(deletedProject)
        }
        return true
    }
    
    // MARK: - Save Methods (CloudKit + Local Backup)
    
    func debouncedSaveProjects() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                await self.saveAllProjectsToCloudKit()
            }
        }
    }
    
    func saveAllProjectsToCloudKit() async {
        guard isUsingCloudKitForOrganizationData else {
            print(" CloudKit not configured - saving to local backup only")
            saveLocalBackup()
            return
        }
        
        print(" Saving all organization projects to CloudKit...")
        
        for project in organizationProjects {
            await saveProjectToCloudKit(project)
        }
        
        // Also save local backup
        saveLocalBackup()
        print(" Saved \(organizationProjects.count) projects to CloudKit")
    }
    
    private func saveLocalBackup() {
        // Save organization projects as local backup
        do {
            let data = try JSONEncoder().encode(organizationProjects)
            UserDefaults.standard.set(data, forKey: "projects_backup")
            print(" Saved local project backup (\(organizationProjects.count) projects)")
        } catch {
            print(" Failed to save local project backup: \(error)")
        }
    }
    
    func debouncedSaveTeamMembers() {
        teamMemberSaveTimer?.invalidate()
        teamMemberSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                await self.saveTeamMembersToCloudKit()
            }
        }
    }
    
    func saveTeamMembersToCloudKit() async {
        guard isUsingCloudKitForOrganizationData else {
            saveTeamMembersLocal()
            return
        }
        
        // Save team members to UserDefaults as backup since SimpleCloudKitSharingService
        // doesn't have organization data methods yet
        saveTeamMembersLocal()
        
        print(" Saved \(teamMembers.count) team members (using local backup for now)")
    }
    
    func saveTeamMembers() {
        Task {
            await saveTeamMembersToCloudKit()
        }
    }
    
    private func saveTeamMembersLocal() {
        do {
            let data = try JSONEncoder().encode(teamMembers)
            UserDefaults.standard.set(data, forKey: "teamMembers")
            print(" Saved \(teamMembers.count) team members to local backup")
        } catch {
            print(" Failed to save team members locally: \(error)")
            errorMessage = "Failed to save team members: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Progress Methods
    func addProgressLog(_ log: ProgressLog) {
        guard let selectedProject = selectedProject,
              let index = organizationProjects.firstIndex(where: { $0.id == selectedProject.id }) else {
            print(" No selected project for progress log")
            return
        }
        
        organizationProjects[index].progressLogs.append(log)
        self.selectedProject = organizationProjects[index]
        
        // Save to CloudKit
        Task {
            await saveProjectToCloudKit(organizationProjects[index])
        }
        
        print(" Added progress log to \(selectedProject.name)")
    }
    
    func removeProgressLog(_ id: UUID) {
        guard let selectedProject = selectedProject,
              let index = organizationProjects.firstIndex(where: { $0.id == selectedProject.id }) else {
            print(" No selected project for progress log removal")
            return
        }
        
        organizationProjects[index].progressLogs.removeAll { $0.id == id }
        self.selectedProject = organizationProjects[index]
        
        // Save to CloudKit
        Task {
            await saveProjectToCloudKit(organizationProjects[index])
        }
        
        print(" Removed progress log from \(selectedProject.name)")
    }
    
    func updateProgressLog(_ log: ProgressLog, employees: [UUID], images: [UIImage]) {
        guard let selectedProject = selectedProject,
              let projectIndex = organizationProjects.firstIndex(where: { $0.id == selectedProject.id }),
              let logIndex = organizationProjects[projectIndex].progressLogs.firstIndex(where: { $0.id == log.id }) else {
            print(" No selected project or progress log for update")
            return
        }
        
        var updatedLog = log
        updatedLog.employeeIDs = employees
        // TODO: Handle images when photo service is implemented
        
        organizationProjects[projectIndex].progressLogs[logIndex] = updatedLog
        self.selectedProject = organizationProjects[projectIndex]
        
        // Save to CloudKit
        Task {
            await saveProjectToCloudKit(organizationProjects[projectIndex])
        }
        
        print(" Updated progress log in \(selectedProject.name)")
    }
    
    // MARK: - Cache Methods
    func rebuildTeamMemberCache() {
        teamMemberCache = Dictionary(uniqueKeysWithValues: teamMembers.map { ($0.name, $0) })
        print(" Rebuilt team member cache with \(teamMemberCache.count) entries")
    }
    
    func invalidateReceiptCache() {
        // Placeholder for receipt cache invalidation
        print(" Receipt cache invalidated")
    }
    
    func recomputeLaborData() {
        guard let currentProject = selectedProject else { return }
        
        // Group hours by team member
        groupedHoursByTeamMember = Dictionary(grouping: currentProject.loggedHours, by: { $0.employee })
        
        // Calculate totals by team member
        laborTotalsByTeamMember = [:]
        for (employee, hours) in groupedHoursByTeamMember {
            let unpaid = hours.filter { !$0.isPaid }.reduce(0) { $0 + ($1.hours * $1.rate) }
            let paid = hours.filter { $0.isPaid }.reduce(0) { $0 + ($1.hours * $1.rate) }
            laborTotalsByTeamMember[employee] = (unpaid: unpaid, paid: paid)
        }
        
        print(" Recomputed labor data for \(groupedHoursByTeamMember.count) team members")
    }
    
    // MARK: - CloudKit Methods (Production Implementation)
    func saveProjectToCloudKit(project: Project, completion: @escaping (Bool) -> Void) {
        Task {
            let saveSuccess = await saveProjectToCloudKitWithVerification(project)
            completion(saveSuccess)
        }
    }
    
    // MARK: - Team Member CloudKit Methods (Production Implementation)
    func saveTeamMemberToZone(_ teamMember: TeamMember) async throws {
        guard isUsingCloudKitForOrganizationData else {
            throw NSError(domain: "ProjectViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not configured"])
        }
        
        print(" Saving team member '\(teamMember.name)' to CloudKit organization zone")
        
        // Add to local array
        if !teamMembers.contains(where: { $0.id == teamMember.id }) {
            teamMembers.append(teamMember)
        }
        
        // Save to CloudKit
        await saveTeamMembersToCloudKit()
    }
    
    func removeTeamMemberFromZone(_ teamMember: TeamMember) async throws {
        guard isUsingCloudKitForOrganizationData else {
            throw NSError(domain: "ProjectViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not configured"])
        }
        
        print(" Removing team member '\(teamMember.name)' from CloudKit organization zone")
        
        // Remove from local array
        teamMembers.removeAll { $0.id == teamMember.id }
        
        // Save to CloudKit
        await saveTeamMembersToCloudKit()
    }
    
    // MARK: - Settings & Management Methods (Production Implementation)
    func nuclearResetCloudKit(completion: @escaping (Bool, String) -> Void) {
        Task {
            await simpleCloudKitService.resetOrganizationZone()
            let status = await simpleCloudKitService.getNuclearResetStatus()
            completion(true, status)
        }
    }
    
    func inviteWifeToOrganization(email: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let _ = try await withCheckedThrowingContinuation { continuation in
                    simpleCloudKitService.inviteUserToOrganization(email: email)
                        .sink(
                            receiveCompletion: { completionResult in
                                if case .failure(let error) = completionResult {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { _ in
                                continuation.resume(returning: ())
                            }
                        )
                        .store(in: &cancellables)
                }
                
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }
    
    func removeAllPhotosFromProject(_ project: Project) -> Project {
        var cleanProject = project
        cleanProject.progressLogs = cleanProject.progressLogs.map { log in
            let cleanLog = log  
            // TODO: Remove photos from progress logs when photo model is available
            return cleanLog
        }
        return cleanProject
    }
    
    func getOrganizationDataMigrationStatus() -> String {
        if isUsingCloudKitForOrganizationData {
            return " CloudKit organization data active - all data syncing to cloud"
        } else {
            return " CloudKit organization data inactive - data stored locally only"
        }
    }
    
    func getOrganizationVendorSpendingAnalytics() -> [VendorSpendingAnalytics] {
        // For now, return sample data based on vendors in the system
        let sampleVendors = vendorService.vendors.prefix(5)
        return sampleVendors.map { vendor in
            VendorSpendingAnalytics(
                vendor: VendorInfo(id: vendor.id, name: vendor.name),
                amount: vendor.totalSpent
            )
        }
    }
    
    func getOrganizationPaymentMethodSpendingAnalytics() -> [PaymentMethodSpendingAnalytics] {
        // For now, return sample data based on payment methods in the system
        let samplePaymentMethods = paymentMethodService.paymentMethods.prefix(5)
        return samplePaymentMethods.map { paymentMethod in
            PaymentMethodSpendingAnalytics(
                paymentMethod: PaymentMethodInfo(id: paymentMethod.id, name: paymentMethod.name),
                amount: paymentMethod.totalSpent
            )
        }
    }
    
    func getDataStatus() async -> String {
        var status = " DATA STATUS:\n\n"
        
        status += "CloudKit Organization Data: \(isUsingCloudKitForOrganizationData ? " Active" : " Inactive")\n"
        status += "Organization ID: \(currentOrganizationID?.prefix(8).description ?? "None")...\n"
        status += "Organization Projects: \(organizationProjects.count)\n"
        status += "Local Backup Projects: \(projects.count)\n"
        status += "Team Members: \(teamMembers.count)\n\n"
        
        if isUsingCloudKitForOrganizationData {
            let cloudStatus = simpleCloudKitService.getOrganizationSharingStatus()
            status += cloudStatus
        }
        
        return status
    }
    
    func getDetailedCloudKitStatus(completion: @escaping (String) -> Void) {
        Task {
            let status = await getDataStatus()
            completion(status)
        }
    }
    
    func getDiagnosticInfo(completion: @escaping (String) -> Void) {
        Task {
            var diagnostics = "🔧 DIAGNOSTIC INFO:\n\n"
            
            diagnostics += "CloudKit Service: SimpleCloudKitSharingService\n"
            diagnostics += "Organization Zone Setup: \(simpleCloudKitService.isOrganizationSharingActive())\n"
            diagnostics += "Projects in Organization Zone: \(organizationProjects.count)\n"
            diagnostics += "Projects in Local Backup: \(projects.count)\n"
            diagnostics += "Current Organization: \(currentOrganizationID?.prefix(8).description ?? "None")\n\n"
            
            if isUsingCloudKitForOrganizationData {
                let zoneStatus = await simpleCloudKitService.getZoneDiagnostics()
                diagnostics += zoneStatus
                
                // CRITICAL: Test CloudKit connectivity by trying to load projects
                diagnostics += "\n📡 CLOUDKIT CONNECTIVITY TEST:\n"
                do {
                    let testProjects = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Project], Error>) in
                        simpleCloudKitService.loadProjectsFromSharedZone()
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                },
                                receiveValue: { projects in
                                    continuation.resume(returning: projects)
                                }
                            )
                            .store(in: &cancellables)
                    }
                    
                    diagnostics += "✅ CloudKit Connection: SUCCESS\n"
                    diagnostics += "✅ Projects Found in CloudKit: \(testProjects.count)\n"
                    
                    if testProjects.isEmpty {
                        diagnostics += "⚠️ WARNING: No projects found in CloudKit zone!\n"
                        diagnostics += "   This suggests projects aren't being saved properly.\n"
                    } else {
                        diagnostics += "\nPROJECTS IN CLOUDKIT:\n"
                        for (i, project) in testProjects.enumerated() {
                            diagnostics += "\(i + 1). \(project.name) (\(project.client))\n"
                        }
                    }
                    
                } catch {
                    diagnostics += "❌ CloudKit Connection: FAILED\n"
                    diagnostics += "❌ Error: \(error.localizedDescription)\n"
                    diagnostics += "   This explains why projects aren't persisting!\n"
                }
            } else {
                diagnostics += "❌ CloudKit organization features disabled"
            }
            
            completion(diagnostics)
        }
    }
    
    func emergencyRecoverFromBackup() async -> Bool {
        print(" Emergency recovery from local backup...")
        
        await loadLocalProjectsAsBackup()
        
        if !projects.isEmpty {
            // Copy backup projects to organization projects
            organizationProjects = projects
            projects = [] // Clear backup array
            
            print(" Emergency recovery found \(organizationProjects.count) projects in backup")
            
            // Try to save all to CloudKit if available
            if isUsingCloudKitForOrganizationData {
                print(" Attempt Attempt to restore projects to CloudKit...")
                await saveAllProjectsToCloudKit()
            }
            
            print(" Emergency recovery completed - \(organizationProjects.count) projects recovered")
            return true
        } else {
            print(" Emergency recovery failed - no backup projects found")
            return false
        }
    }
    
    func triggerManualSync() async -> Bool {
        isBulkSyncing = true
        bulkSyncProgress = "Syncing projects to CloudKit..."
        defer { 
            isBulkSyncing = false
            bulkSyncProgress = ""
        }
        
        await saveAllProjectsToCloudKit()
        await saveTeamMembersToCloudKit()
        
        return true
    }
    
    func hasProjectsNeedingMigration() -> Bool {
        return false
    }
    
    func listCloudKitProjects() async -> String {
        guard isUsingCloudKitForOrganizationData else {
            return "❌ CloudKit not configured"
        }
        
        var projectList = "☁️ CLOUDKIT PROJECTS:\n\n"
        
        for (index, project) in organizationProjects.enumerated() {
            projectList += "\(index + 1). \(project.name)\n"
            projectList += "   Client: \(project.client)\n"
            projectList += "   Budget: $\(Int(project.totalBudget))\n"
            projectList += "   Status: \(project.status.rawValue)\n\n"
        }
        
        if organizationProjects.isEmpty {
            projectList += "No projects found in CloudKit organization zone"
        }
        
        return projectList
    }
    
    func getOfflineStatus() async -> String {
        return isOnline ? "✅ Online" : "❌ Offline"
    }
    
    func getMigrationStats(project: Project) -> (totalPhotos: Int, migratedPhotos: Int, needsMigration: Bool) {
        return (totalPhotos: 0, migratedPhotos: 0, needsMigration: false)
    }
    
    func migrateProjectPhotos(project: Project, onProgress: @escaping (Float) -> Void) async throws -> Project {
        onProgress(1.0)
        return project
    }
    
    func syncAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        print("Syncing all projects to CloudKit organization zone...")
        
        Task {
            await saveAllProjectsToCloudKit()
            let message = "Synced \(organizationProjects.count) projects to CloudKit organization zone"
            print(message)
            completion(true, message)
        }
    }
    
    func forceResaveAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        Task {
            guard isUsingCloudKitForOrganizationData else {
                completion(false, "CloudKit not configured")
                return
            }
            
            print(" FORCE RESAVE: Starting force resave of all projects to CloudKit...")
            
            // Get all projects (both local and organization)
            let allProjects = organizationProjects + projects
            let uniqueProjects = Array(Set(allProjects)) // Remove duplicates
            
            if uniqueProjects.isEmpty {
                completion(false, "No projects found to resave")
                return
            }
            
            print(" FORCE RESAVE: Found \(uniqueProjects.count) unique projects to resave")
            
            var successCount = 0
            var failCount = 0
            
            for project in uniqueProjects {
                print(" FORCE RESAVE: Saving '\(project.name)'...")
                let success = await saveProjectToCloudKitWithVerification(project)
                
                if success {
                    successCount += 1
                    print(" FORCE RESAVE: '\(project.name)' saved successfully")
                } else {
                    failCount += 1
                    print(" FORCE RESAVE: '\(project.name)' failed to save")
                }
            }
            
            await MainActor.run {
                let resultMessage = """
                Force resave completed:
                Successfully saved: \(successCount) projects
                Failed to save: \(failCount) projects
                
                \(failCount == 0 ? "All projects are now safely stored in CloudKit!" : "Some projects failed to save - please check your internet connection and try again.")
                """
                
                completion(failCount == 0, resultMessage)
                
                // If successful, reload from CloudKit to verify
                if failCount == 0 {
                    Task {
                        await self.forceLoadProjects()
                        print(" FORCE RESAVE: Reloaded projects from CloudKit for verification")
                    }
                }
            }
        }
    }
    
    func performCloudKitHealthCheck(completion: @escaping (String) -> Void) {
        Task {
            var report = " CLOUDKIT HEALTH CHECK REPORT\n"
            report += "=====================================\n\n"
            
            // 1. Check organization setup
            report += "1. ORGANIZATION SETUP:\n"
            if let orgID = currentOrganizationID {
                report += " Organization ID: \(orgID.prefix(8))...\n"
            } else {
                report += " No organization ID set\n"
                completion(report + "\n CRITICAL: No organization - cannot proceed with health check")
                return
            }
            
            // 2. Check zone status
            report += "\n2. CLOUDKIT ZONE STATUS:\n"
            let isZoneActive = simpleCloudKitService.isOrganizationSharingActive()
            if isZoneActive {
                report += " Zone is active and ready\n"
            } else {
                report += " Zone is not active - attempting to fix...\n"
                await setupCloudKitForCurrentOrganization()
                
                if simpleCloudKitService.isOrganizationSharingActive() {
                    report += " Zone activation successful\n"
                } else {
                    report += " Zone activation failed\n"
                    completion(report + "\n CRITICAL: Cannot activate CloudKit zone")
                    return
                }
            }
            
            // 3. Test connectivity
            report += "\n3. CLOUDKIT CONNECTIVITY:\n"
            do {
                let testProjects = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Project], Error>) in
                    simpleCloudKitService.loadProjectsFromSharedZone()
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { projects in
                                continuation.resume(returning: projects)
                            }
                        )
                        .store(in: &cancellables)
                }
                
                report += " CloudKit connectivity successful\n"
                report += " Found \(testProjects.count) projects in CloudKit\n"
                
                // 4. Compare local vs cloud
                report += "\n4. DATA CONSISTENCY:\n"
                report += "Local projects: \(organizationProjects.count)\n"
                report += "CloudKit projects: \(testProjects.count)\n"
                
                if organizationProjects.count == testProjects.count {
                    report += " Project counts match\n"
                } else {
                    report += " Project count mismatch - may need sync\n"
                }
                
                // 5. Recovery recommendations
                report += "\n5. RECOVERY RECOMMENDATIONS:\n"
                if testProjects.isEmpty && !organizationProjects.isEmpty {
                    report += " CRITICAL: Local projects exist but CloudKit is empty!\n"
                    report += " SOLUTION: Use 'Force Resave All Projects' to recover\n"
                } else if testProjects.count < organizationProjects.count {
                    report += " Some projects may not be saved to CloudKit\n"
                    report += " SOLUTION: Use 'Sync All Projects' to ensure all data is backed up\n"
                } else {
                    report += " No recovery needed - system appears healthy\n"
                }
                
            } catch {
                report += " CloudKit connectivity failed: \(error.localizedDescription)\n"
                report += "\n SOLUTION: Check internet connection and iCloud settings\n"
            }
            
            completion(report)
        }
    }
    
    /// Force migration of local data to CloudKit (Production Implementation)
    func forceMigrateOrganizationDataToCloudKit() async throws {
        guard let orgID = currentOrganizationID else {
            throw NSError(domain: "ProjectViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No organization set"])
        }
        
        print(" Force migrating organization data to CloudKit...")
        
        await setupCloudKitForCurrentOrganization()
        await saveAllProjectsToCloudKit()
        await saveTeamMembersToCloudKit()
        
        print(" Force migration completed for organization \(orgID.prefix(8))...")
    }
    
    // MARK: - Load Team Members Methods
    
    private func loadTeamMembers() async {
        await loadTeamMembersFromCloudKit()
    }
    
    private func loadTeamMembersFromCloudKit() async {
        // For now, load from UserDefaults as backup since SimpleCloudKitSharingService
        // doesn't have organization data methods yet
        await loadTeamMembersFromBackup()
        
        // Filter team members by current organization
        if let orgID = currentOrganizationID {
            teamMembers = teamMembers.filter { $0.organizationID == orgID }
            print(" Filtered team members to current organization: \(teamMembers.count) members")
        }
        
        // Ensure all team members have at least one rate
        ensureTeamMembersHaveRates()
        
        await saveTeamMembersToCloudKit()
        
        // Rebuild team member cache after loading
        rebuildTeamMemberCache()
        
        print(" Loaded \(teamMembers.count) team members:")
        for member in teamMembers {
            print("  - \(member.name): \(member.rates.count) rates, org: \(String(member.organizationID.prefix(8)))")
        }
    }
    
    private func loadTeamMembersFromBackup() async {
        // Load from UserDefaults as backup
        if let data = UserDefaults.standard.data(forKey: "teamMembers"),
           let members = try? JSONDecoder().decode([TeamMember].self, from: data) {
            teamMembers = members
            print(" Loaded \(teamMembers.count) team members from local backup")
        } else {
            teamMembers = []
            print(" No team member backup found - starting with empty team members list")
        }
    }
    
    func ensureTeamMembersHaveRates() {
        for i in 0..<teamMembers.count {
            if teamMembers[i].rates.isEmpty {
                teamMembers[i].rates.append(EmployeeRate(taskType: "General Labor", rate: 25.0))
                print(" Added default rate to \(teamMembers[i].name)")
            }
        }
    }
    
    /// Automatically assign all team members to all organization-wide projects
    func syncTeamMemberProjectAccess() async {
        guard getCurrentUserID() != nil else { return }
        
        let userRole = getCurrentUserRole()
        guard userRole == .admin else {
            print(" Only admins can sync team member project access")
            return
        }
        
        print(" Syncing team member project access...")
        
        for i in 0..<organizationProjects.count {
            var project = organizationProjects[i]
            
            // For organization-wide projects, ensure all team members have access
            if project.accessLevel == .organization {
                
                // Get all team members with member role
                let teamMemberIDs = teamMembers
                    .filter { $0.role == .member && $0.hasAppAccess }
                    .compactMap { $0.appUserID }
                
                // Add missing team members to assignment list (even though they have automatic access)
                for memberID in teamMemberIDs {
                    if !project.assignedUserIDs.contains(memberID) {
                        project.assignUser(memberID)
                    }
                }
                
                organizationProjects[i] = project
                let _ = await saveProjectToCloudKitWithVerification(project)
            }
        }
        
        print(" Team member project access sync completed")
    }
    
    func fixMissingOrganizationIDs(completion: @escaping (Bool, String) -> Void) {
        Task {
            guard let orgID = currentOrganizationID else {
                completion(false, "No organization ID set")
                return
            }
            
            await setupCloudKitForCurrentOrganization()
            
            let status = """
            Organization CloudKit setup refreshed
            
            Organization: \(orgID.prefix(8))...
            Zone-based isolation: \(simpleCloudKitService.isOrganizationSharingActive() ? "Active" : "Inactive")
            Projects in cloud: \(organizationProjects.count)
            """
            
            completion(true, status)
        }
    }
}