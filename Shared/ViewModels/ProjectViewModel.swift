//
//  ProjectViewModel.swift
//  RHEIR
//
//  Created by Kevin Barrett on 1/2/24.
//

import Foundation
import SwiftUI
import CloudKit
import Combine

@MainActor
class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var organizationProjects: [Project] = []
    @Published var isDataLoading = false
    @Published var dataLoadError: Error?
    @Published var currentOrganization: Organization?
    @Published var currentOrganizationRole: TeamMemberRole?
    @Published var isBulkSyncing = false
    @Published var bulkSyncProgress: Double = 0.0
    
    // PHASE 2A: Add missing properties for LandingPageView compatibility
    @Published var navigateToBudgetBreakdown: Bool = false
    @Published var accessibleProjects: [Project] = []
    @Published var currentOrganizationID: String?
    @Published var isSavingProject: Bool = false
    @Published var activeSaveOperations: [String] = []
    
    // Team member properties
    @Published var teamMembers: [TeamMember] = []
    internal var teamMembersCache: [UUID: TeamMember] = [:]
    internal var teamMemberNameCache: [String: TeamMember] = [:]
    
    // Receipt properties
    private var receiptVendorCache: [UUID: Vendor] = [:]
    private var receiptPaymentMethodCache: [UUID: PaymentMethod] = [:]
    
    // PHASE 2A: Add missing properties for compatibility
    @Published var laborTotalsByTeamMember: [String: (unpaid: Double, paid: Double)] = [:]
    @Published var groupedHoursByTeamMember: [String: [WorkHour]] = [:]
    @Published var isMigratingPhotos: Bool = false
    @Published var isOnline: Bool = true // Stub: assume online for Phase 1
    @Published var migrationProgress: String = "" // For DataManagementSection compatibility
    
    // PHASE 2A: Add missing flags and error handling
    @Published var isUsingCloudKitForOrganizationData: Bool = false
    @Published var zoneSetupError: Error?
    
    // PHASE 1 STUB SERVICES - TODO: Replace with proper service architecture in Phase 2
    var paymentMethodService: PaymentMethodManagementService = PaymentMethodManagementService()
    var vendorService: VendorManagementService = VendorManagementService()
    
    // Services - Only keep the ones that exist
    private let offlineDataManager: OfflineDataManager
    
    // Timers
    private var savingTimer: Timer?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(
        offlineDataManager: OfflineDataManager
        // TODO: Re-add service dependencies in Phase 2
        // cloudKitService: CloudKitService,
        // sharingService: SimpleCloudKitSharingService,
        // photoService: CloudKitPhotoService,
        // migrationService: PhotoDataMigrationService,
        // vendorService: VendorKnowledgeService,
        // paymentMethodService: PaymentMethodKnowledgeService,
        // organizationKnowledgeService: OrganizationKnowledgeService
    ) {
        self.offlineDataManager = offlineDataManager
        
        // CRITICAL: Set default organization ID for Phase 1
        self.currentOrganizationID = "RHEIR-DEFAULT-ORG"
        
        // TODO: Re-add service assignments in Phase 2
        // self.cloudKitService = cloudKitService
        // self.sharingService = sharingService
        // self.photoService = photoService
        // self.migrationService = migrationService
        // self.vendorService = vendorService
        // self.paymentMethodService = paymentMethodService
        // self.organizationKnowledgeService = organizationKnowledgeService
        
        setupDataObservation()
        
        print("✅ ProjectViewModel initialized with organization ID: \(currentOrganizationID ?? "none")")
    }
    
    // MARK: - PHASE 1 STUB METHODS - TODO: Implement in Phase 2
    
    func addTeamMemberToOrganization(_ teamMember: TeamMember) {
        print("🎯 ADD TEAM MEMBER: Adding team member to organization...")
        print("   Name: \(teamMember.name)")
        print("   Role: \(teamMember.role.displayName)")
        print("   Organization: \(teamMember.organizationID.prefix(8))...")
        print("   App User ID: \(teamMember.appUserID ?? "none")")
        
        // CRITICAL: Check for duplicates before adding
        let existingMember = teamMembers.firstIndex { existing in
            // Check by app user ID and organization ID for app users
            if let existingAppUserID = existing.appUserID,
               let newAppUserID = teamMember.appUserID,
               existing.organizationID == teamMember.organizationID {
                return existingAppUserID == newAppUserID
            }
            
            // Check by name and organization for non-app users (fallback)
            return existing.name == teamMember.name && 
                   existing.organizationID == teamMember.organizationID
        }
        
        if let existingIndex = existingMember {
            print("⚠️ DUPLICATE PREVENTION: Team member already exists at index \(existingIndex)")
            print("   Existing: \(teamMembers[existingIndex].name) (\(teamMembers[existingIndex].role.displayName))")
            print("   Attempted: \(teamMember.name) (\(teamMember.role.displayName))")
            
            // Update existing member if new one has more complete data
            if teamMember.rates.count > teamMembers[existingIndex].rates.count ||
               !teamMember.email.isEmpty && teamMembers[existingIndex].email.isEmpty {
                print("🔄 UPDATING: Existing member with more complete data")
                teamMembers[existingIndex] = teamMember
                updateTeamMemberCaches()
            }
            return
        }
        
        // Add new team member
        teamMembers.append(teamMember)
        updateTeamMemberCaches()
        
        // Save to CloudKit if this is organization data
        if isUsingCloudKitForOrganizationData {
            Task {
                do {
                    try await saveTeamMemberToCloudKit(teamMember)
                    print("✅ CLOUDKIT: Team member saved to CloudKit")
                } catch {
                    print("⚠️ CLOUDKIT: Failed to save team member: \(error)")
                }
            }
        }
        
        // Also persist locally
        Task {
            await addTeamMember(teamMember)
        }
        
        print("✅ ADD TEAM MEMBER: Successfully added \(teamMember.name) to organization")
        print("   Total team members: \(teamMembers.count)")
        print("   Organization team members: \(teamMembers.filter { $0.organizationID == teamMember.organizationID }.count)");
    }
    
    /// Save team member to CloudKit using proper schema
    private func saveTeamMemberToCloudKit(_ teamMember: TeamMember) async throws {
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDatabase = container.privateCloudDatabase
        
        // Create TeamMember record using CloudKit schema
        let recordID = CKRecord.ID(recordName: "team_member_\(teamMember.id.uuidString)")
        let record = CKRecord(recordType: "TeamMember", recordID: recordID)
        
        // Map to CloudKit schema fields (based on provided schema)
        record["id"] = teamMember.id.uuidString as CKRecordValue
        record["name"] = teamMember.name as CKRecordValue
        record["email"] = teamMember.email as CKRecordValue
        record["phone"] = teamMember.phone as CKRecordValue
        record["jobTitle"] = teamMember.jobTitle as CKRecordValue
        record["organizationID"] = teamMember.organizationID as CKRecordValue
        record["role"] = teamMember.role.rawValue as CKRecordValue
        record["isActive"] = (teamMember.isActive ? 1 : 0) as CKRecordValue
        record["hasAppAccess"] = (teamMember.hasAppAccess ? 1 : 0) as CKRecordValue
        record["employmentStatus"] = teamMember.employmentStatus.rawValue as CKRecordValue
        record["employmentType"] = teamMember.employmentType.rawValue as CKRecordValue
        record["environment"] = "production" as CKRecordValue
        record["dateAdded"] = Date() as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        // Add app user ID if available
        if let appUserID = teamMember.appUserID {
            record["appUserID"] = appUserID as CKRecordValue
        }
        
        // Encode rates as BYTES (per CloudKit schema)
        if let ratesData = try? JSONEncoder().encode(teamMember.rates) {
            record["rates"] = ratesData as CKRecordValue
        }
        
        // Set default rate if available
        if let defaultRate = teamMember.rates.first(where: { $0.isDefault }) {
            record["defaultRate"] = defaultRate.rate as CKRecordValue
        }
        
        // Add notes if available
        if !teamMember.notes.isEmpty {
            record["notes"] = teamMember.notes as CKRecordValue
        }
        
        _ = try await privateDatabase.save(record)
        print("✅ CLOUDKIT SCHEMA: TeamMember saved with proper field mapping")
    }
    
    func markProjectAsCompleted(_ project: Project) {
        print("🎯 PROJECT COMPLETION: Marking project as completed: \(project.name)")
        
        var updatedProject = project
        updatedProject.status = .completed
        updatedProject.lastModifiedDate = Date()
        
        // Create a formatted date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let completionDate = dateFormatter.string(from: Date())
        
        // Update description to include completion info
        if updatedProject.description.isEmpty {
            updatedProject.description = "Project completed on \(completionDate)"
        } else if !updatedProject.description.contains("completed on") {
            updatedProject.description += "\n\nProject completed on \(completionDate)"
        }
        
        Task {
            await updateProject(updatedProject)
            print("✅ PROJECT COMPLETION: Project '\(project.name)' marked as completed successfully")
        }
    }
    
    func syncAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        print("🔄 CLOUDKIT SYNC: Starting sync of all projects to CloudKit...")
        
        Task {
            let success = await saveAllProjectsToCloudKit()
            completion(success, success ? "Sync completed successfully" : "Sync failed")
        }
    }
    
    func organizationDidChange() async {
        print("🔄 ORGANIZATION CHANGED: Starting organization data synchronization...")
        
        guard let currentOrgID = currentOrganizationID else {
            print("⚠️ ORGANIZATION CHANGED: No organization ID - clearing data")
            await MainActor.run {
                organizationProjects = []
                accessibleProjects = []
                teamMembers = []
                selectedProject = nil
            }
            return
        }
        
        print("🔄 ORGANIZATION CHANGED: Switching to organization: \(currentOrgID.prefix(8))...")
        
        // Step 1: Clear old organization data
        await MainActor.run {
            organizationProjects = []
            accessibleProjects = []
            selectedProject = nil
            isDataLoading = true
        }
        
        // Step 2: Set up CloudKit zone for the new organization
        await setupCloudKitZoneForOrganization(currentOrgID)
        
        // Step 3: Load projects for the new organization
        await loadOrganizationSpecificProjects(organizationID: currentOrgID)
        
        // Step 4: Load team members for the new organization
        await loadOrganizationTeamMembers(organizationID: currentOrgID)
        
        // Step 5: Update organization projects and accessible projects
        await MainActor.run {
            updateOrganizationProjects()
            isDataLoading = false
        }
        
        // Step 6: Try to load from CloudKit for latest data
        do {
            let cloudKitProjects = try await loadProjectsFromCloudKit()
            await MainActor.run {
                mergeCloudKitProjects(cloudKitProjects)
            }
            print("✅ ORGANIZATION CHANGED: Loaded \(cloudKitProjects.count) projects from CloudKit")
        } catch {
            print("⚠️ ORGANIZATION CHANGED: CloudKit load failed, using local data: \(error)")
        }
        
        print("✅ ORGANIZATION CHANGED: Successfully switched to organization \(currentOrgID.prefix(8))...")
        print("   Organization projects: \(organizationProjects.count)")
        print("   Team members: \(teamMembers.count)")
        print("   CloudKit enabled: \(isUsingCloudKitForOrganizationData)")
    }
    
    /// Load team members for a specific organization
    private func loadOrganizationTeamMembers(organizationID: String) async {
        let teamMembersKey = "team_members_\(organizationID)"
        print("👥 TEAM LOAD: Loading team members from key: \(teamMembersKey)")
        
        guard let data = UserDefaults.standard.data(forKey: teamMembersKey),
              let members = try? JSONDecoder().decode([TeamMember].self, from: data) else {
            print("👥 TEAM LOAD: No team member data found for organization: \(organizationID.prefix(8))...")
            
            await MainActor.run {
                self.teamMembers = []
                self.updateTeamMemberCaches()
            }
            return
        }
        
        await MainActor.run {
            // Verify all team members belong to this organization
            let verifiedMembers = members.filter { member in
                member.organizationID == organizationID
            }
            
            if verifiedMembers.count != members.count {
                print("🔒 SECURITY: Filtered out \(members.count - verifiedMembers.count) team members that didn't belong to organization \(organizationID.prefix(8))...")
            }
            
            self.teamMembers = verifiedMembers
            self.updateTeamMemberCaches()
            print("✅ TEAM LOAD: Loaded \(verifiedMembers.count) verified team members for organization \(organizationID.prefix(8))...")
        }
    }
    
    func emergencyRecoverFromBackup() async -> Bool {
        print("TODO: emergencyRecoverFromBackup - Phase 2")
        // Stub implementation
        return false
    }
    
    func select(_ project: Project) {
        selectProject(project)
    }
    
    func invalidateReceiptCache() {
        print("🗑️ CACHE INVALIDATION: Clearing receipt cache for organization data refresh")
        
        // Clear internal caches
        receiptVendorCache.removeAll()
        receiptPaymentMethodCache.removeAll()
        
        // Clear team member caches as they might affect receipt processing
        updateTeamMemberCaches()
        
        // Force UI update to refresh any receipt-dependent views
        objectWillChange.send()
        
        print("✅ CACHE INVALIDATION: Receipt cache cleared successfully")
    }
    
    func recomputeFilteredReceipts() {
        print("TODO: recomputeFilteredReceipts - Phase 2")
        // Stub implementation
    }
    
    func debouncedSaveProjects() {
        print("TODO: debouncedSaveProjects - Phase 2")
        // Stub implementation
    }
    
    // MARK: - Data Initialization
    
    func loadProjects() async {
        print("🔄 loadProjects - Loading projects from organization-specific storage")
        isDataLoading = true
        
        if let orgID = currentOrganizationID {
            // PHASE 2: Load from both CloudKit and local storage for persistence
            await loadOrganizationSpecificProjects(organizationID: orgID)
            
            // Try to load from CloudKit if available
            do {
                let cloudKitProjects = try await loadProjectsFromCloudKit()
                await MainActor.run {
                    // Merge CloudKit projects with local projects (CloudKit takes precedence)
                    mergeCloudKitProjects(cloudKitProjects)
                }
                print("✅ CLOUDKIT LOAD: Loaded \(cloudKitProjects.count) projects from CloudKit")
            } catch {
                print("⚠️ CLOUDKIT LOAD: Failed to load from CloudKit, using local data: \(error)")
            }
        } else {
            // Load projects using OfflineDataManager as fallback
            let loadedProjects = offlineDataManager.loadProjectsOffline()
            
            await MainActor.run {
                organizationProjects = loadedProjects
                updateOrganizationProjects()
            }
        }
        
        await MainActor.run {
            isDataLoading = false
        }
        
        print("✅ loadProjects - Loaded \(organizationProjects.count) projects")
    }
    
    /// Load projects from CloudKit using simple CloudKit approach
    private func loadProjectsFromCloudKit() async throws -> [Project] {
        guard let currentOrganizationID = currentOrganizationID else {
            return []
        }
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDatabase = container.privateCloudDatabase
        
        // Query for projects belonging to this organization
        let predicate = NSPredicate(format: "organizationID == %@", currentOrganizationID)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        // CRITICAL FIX: Remove unsupported sort descriptor that causes CloudKit error
        // query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = try await privateDatabase.records(matching: query)
        
        let projects = result.matchResults.compactMap { (_, result) -> Project? in
            switch result {
            case .success(let record):
                // Try to decode from full project data first
                if let projectData = record["fullProjectData"] as? Data,
                   let project = try? JSONDecoder().decode(Project.self, from: projectData) {
                    return project
                }
                
                // Fallback: construct from individual fields
                guard let name = record["name"] as? String,
                      let client = record["client"] as? String,
                      let totalBudget = record["totalBudget"] as? Double,
                      let startDate = record["startDate"] as? Date,
                      let endDate = record["endDate"] as? Date else {
                    return nil
                }
                
                return Project(
                    name: name,
                    client: client,
                    totalBudget: totalBudget,
                    materialCost: 0,
                    laborCost: 0,
                    generalConditions: 0,
                    contingency: 0,
                    startDate: startDate,
                    endDate: endDate,
                    organizationID: currentOrganizationID
                )
            case .failure(let error):
                print("❌ Failed to fetch project: \(error)")
                return nil
            }
        }
        
        print("✅ CLOUDKIT LOAD: Loaded \(projects.count) projects from CloudKit (fixed query)")
        return projects
    }
    
    /// Merge CloudKit projects with local projects, giving CloudKit precedence
    private func mergeCloudKitProjects(_ cloudKitProjects: [Project]) {
        var mergedProjects: [Project] = []
        var processedIDs: Set<UUID> = []
        
        // Add all CloudKit projects first (they take precedence)
        for cloudProject in cloudKitProjects {
            mergedProjects.append(cloudProject)
            processedIDs.insert(cloudProject.id)
        }
        
        // Add local projects that aren't in CloudKit
        for localProject in organizationProjects {
            if !processedIDs.contains(localProject.id) {
                mergedProjects.append(localProject)
            }
        }
        
        organizationProjects = mergedProjects
        updateOrganizationProjects()
        
        print("✅ MERGE: Merged \(cloudKitProjects.count) CloudKit + \(organizationProjects.count - cloudKitProjects.count) local projects")
    }
    
    /// Simple CloudKit persistence using standard CloudKit APIs
    private func saveProjectToCloudKit(_ project: Project) async throws {
        guard let currentOrganizationID = currentOrganizationID else {
            throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No organization ID"])
        }
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDatabase = container.privateCloudDatabase
        
        // Create record with organization-specific ID
        let recordID = CKRecord.ID(recordName: "project_\(project.id.uuidString)")
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        // Set project data
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["startDate"] = project.startDate as CKRecordValue
        record["endDate"] = project.endDate as CKRecordValue
        record["status"] = project.status.rawValue as CKRecordValue
        record["organizationID"] = currentOrganizationID as CKRecordValue
        
        // Store complete project data as JSON for full data integrity
        if let projectData = try? JSONEncoder().encode(project) {
            record["fullProjectData"] = projectData as CKRecordValue
        }
        
        _ = try await privateDatabase.save(record)
        print("✅ SIMPLE CLOUDKIT: Project '\(project.name)' saved to CloudKit")
    }
    
    /// Save all projects to CloudKit for bulk sync using simple approach
    internal func saveAllProjectsToCloudKit() async -> Bool {
        guard !organizationProjects.isEmpty else {
            print("⚠️ No projects to sync to CloudKit")
            return true
        }
        
        isBulkSyncing = true
        defer { isBulkSyncing = false }
        
        let projectsToSync = organizationProjects
        bulkSyncProgress = 0.0
        
        print("🔄 SIMPLE CLOUDKIT BULK SYNC: Starting sync of \(projectsToSync.count) projects...")
        
        var successCount = 0
        
        for (index, project) in projectsToSync.enumerated() {
            do {
                try await saveProjectToCloudKit(project)
                successCount += 1
                bulkSyncProgress = Double(index + 1) / Double(projectsToSync.count)
                print("✅ SIMPLE CLOUDKIT BULK SYNC: \(index + 1)/\(projectsToSync.count) - \(project.name)")
            } catch {
                print("❌ SIMPLE CLOUDKIT BULK SYNC: Failed to sync \(project.name): \(error)")
            }
        }
        
        bulkSyncProgress = 1.0
        print("✅ SIMPLE CLOUDKIT BULK SYNC: Completed sync - \(successCount)/\(projectsToSync.count) projects saved")
        
        return successCount == projectsToSync.count
    }
    
    private func setupDataObservation() {
        // Set up data observation from offline data manager
        offlineDataManager.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projects in
                self?.projects = projects
                self?.updateOrganizationProjects()
                // Note: recomputeLaborData() will be called by ProjectViewModel+Clocking when needed
            }
            .store(in: &cancellables)
        
        offlineDataManager.$teamMembers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] teamMembers in
                self?.teamMembers = teamMembers
                self?.updateTeamMemberCaches()
                // Note: recomputeLaborData() will be called by ProjectViewModel+Clocking when needed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Organization Management
    
    func setCurrentOrganization(_ organization: Organization?, role: TeamMemberRole? = nil) {
        self.currentOrganization = organization
        self.currentOrganizationRole = role
        // CRITICAL FIX: Set currentOrganizationID to the REAL organization ID from CloudKit
        if let org = organization {
            self.currentOrganizationID = org.id
            print("🔧 CRITICAL FIX: Set currentOrganizationID to real CloudKit org ID: \(org.id.prefix(8))...")
            
            // PHASE 2: Enable CloudKit project persistence
            self.isUsingCloudKitForOrganizationData = true
            print("✅ CLOUDKIT PERSISTENCE: Enabled for organization \(org.id.prefix(8))...")
        } else {
            self.currentOrganizationID = nil
            self.isUsingCloudKitForOrganizationData = false
        }
        
        // CRITICAL FIX: Update organization projects synchronously to prevent count issues
        updateOrganizationProjects()
        
        // Load projects for this organization using the REAL ID
        if let orgID = self.currentOrganizationID {
            Task {
                await loadOrganizationSpecificProjects(organizationID: orgID)
                // CRITICAL FIX: Update again after loading to ensure UI reflects correct counts
                await MainActor.run {
                    updateOrganizationProjects()
                }
            }
        }
    }
    
    private func updateOrganizationProjects() {
        print("🔄 UPDATING ORGANIZATION PROJECTS")
        print("📊 Current organization: \(currentOrganization?.name ?? "None")")
        print("📊 Current organization ID: \(currentOrganizationID ?? "None")")
        print("📊 Total projects: \(projects.count)")
        
        if let currentOrgID = currentOrganizationID {
            let filteredProjects = projects.filter { project in
                let matches = project.organizationID == currentOrgID
                if !matches {
                    // CRITICAL FIX: Remove unnecessary nil coalescing since organizationID is non-optional
                    print("🔍 PROJECT FILTER: Excluding '\(project.name)' - OrgID: \(project.organizationID) vs Current: \(currentOrgID)")
                }
                return matches
            }
            
            // CRITICAL FIX: Also merge with organization-specific loaded projects to prevent duplicates
            var uniqueProjects: [Project] = []
            var projectIDs: Set<UUID> = []
            
            // Add filtered projects first
            for project in filteredProjects {
                if !projectIDs.contains(project.id) {
                    uniqueProjects.append(project)
                    projectIDs.insert(project.id)
                }
            }
            
            // Add organization projects that might not be in the main projects array
            for project in organizationProjects {
                if !projectIDs.contains(project.id) && project.organizationID == currentOrgID {
                    uniqueProjects.append(project)
                    projectIDs.insert(project.id)
                    print("🔧 PROJECT SYNC: Added missing project from organizationProjects: \(project.name)")
                }
            }
            
            organizationProjects = uniqueProjects
            print("✅ FILTERED PROJECTS: \(organizationProjects.count) unique projects for organization \(currentOrgID.prefix(8))...")
            
            for (i, project) in organizationProjects.enumerated() {
                print("  \(i + 1): \(project.name) - ID: \(project.id)")
            }
            
            // Update accessible projects based on user role
            updateAccessibleProjects()
        } else {
            print("⚠️ NO ORGANIZATION: Clearing organization projects")
            organizationProjects = []
            accessibleProjects = []
        }
        
        // CRITICAL FIX: Ensure UI updates immediately
        objectWillChange.send()
    }
    
    internal func updateAccessibleProjects() {
        // CRITICAL FIX: For Phase 1, accessible projects are the same as organization projects
        // but ensure the array is properly synchronized
        accessibleProjects = organizationProjects
        
        print("🔧 ACCESSIBLE PROJECTS: Updated to \(accessibleProjects.count) projects")
        print("   Organization projects count: \(organizationProjects.count)")
        print("   Projects array count: \(projects.count)")
        
        // Verify no duplicates
        let uniqueIDs = Set(accessibleProjects.map { $0.id })
        if uniqueIDs.count != accessibleProjects.count {
            print("⚠️ DUPLICATE DETECTION: Found duplicates in accessible projects")
            // Remove duplicates
            var uniqueProjects: [Project] = []
            var seenIDs: Set<UUID> = []
            
            for project in accessibleProjects {
                if !seenIDs.contains(project.id) {
                    uniqueProjects.append(project)
                    seenIDs.insert(project.id)
                }
            }
            
            accessibleProjects = uniqueProjects
            print("🔧 DUPLICATE FIX: Removed duplicates, now \(accessibleProjects.count) unique projects")
        }
    }
    
    // MARK: - CRITICAL FIX: Organization-Specific Data Storage (From Golden Backup)
    
    /// Save data using organization-specific keys to prevent data bleeding
    internal func saveOrganizationSpecificBackup() {
        guard let orgID = currentOrganizationID else {
            print("💾 SECURITY: Cannot save backup - no organization ID")
            return
        }
        
        print("💾 SECURE SAVE: Saving organization-specific backup for \(orgID.prefix(8))...")
        
        // Save projects with ORGANIZATION-SPECIFIC key
        let projectsKey = "projects_\(orgID)"
        if let projectData = try? JSONEncoder().encode(organizationProjects) {
            UserDefaults.standard.set(projectData, forKey: projectsKey)
            print("💾 Saved \(organizationProjects.count) projects to key: \(projectsKey)")
        } else {
            print("❌ Failed to encode projects for organization: \(orgID)")
        }
        
        // Save organization with SPECIFIC key
        if let org = currentOrganization,
           let orgData = try? JSONEncoder().encode(org) {
            let orgKey = "organization_\(orgID)"
            UserDefaults.standard.set(orgData, forKey: orgKey)
            print("💾 Saved organization data to key: \(orgKey)")
        }
        
        UserDefaults.standard.synchronize()
        print("✅ SECURE SAVE: Organization-specific backup completed for \(orgID.prefix(8))...")
    }
    
    /// Load projects using organization-specific keys
    private func loadOrganizationSpecificProjects(organizationID: String) async {
        let projectsKey = "projects_\(organizationID)"
        print("📂 SECURE LOAD: Loading projects from organization-specific key: \(projectsKey)")
        
        guard let data = UserDefaults.standard.data(forKey: projectsKey),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else { 
            print("📂 No organization-specific project data found for \(organizationID.prefix(8))... - starting with empty projects")
            
            await MainActor.run {
                self.organizationProjects = []
            }
            return 
        }
        
        await MainActor.run {
            // CRITICAL: Verify all loaded projects belong to this organization
            let verifiedProjects = projects.filter { project in
                project.organizationID == organizationID
            }
            
            if verifiedProjects.count != projects.count {
                print("🔒 SECURITY: Filtered out \(projects.count - verifiedProjects.count) projects that didn't belong to organization \(organizationID.prefix(8))...")
            }
            
            self.organizationProjects = verifiedProjects
            print("✅ SECURE LOAD: Loaded \(verifiedProjects.count) verified projects for organization \(organizationID.prefix(8))...")
        }
    }
    
    // MARK: - Project Management
    
    func createNewProject(project: Project) async throws {
        guard let orgID = currentOrganizationID else {
            print("❌ SECURITY: Cannot create project - no organization selected")
            throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No organization selected"])
        }
        
        // CRITICAL: Ensure new project has correct organization ID
        var secureProject = project
        secureProject.organizationID = orgID
        
        // CRITICAL FIX: Add to BOTH arrays so UI updates immediately
        await MainActor.run {
            organizationProjects.append(secureProject)
            projects.append(secureProject)
            selectedProject = secureProject
        }
        
        // Save to organization-specific storage
        saveOrganizationSpecificBackup()
        
        // CRITICAL FIX: Also save to the OfflineDataManager so projects array stays synced
        await MainActor.run {
            offlineDataManager.addProject(secureProject)
        }
        
        // PHASE 2: Save to CloudKit for persistence across app reinstalls
        do {
            try await saveProjectToCloudKit(secureProject)
            print("✅ CLOUDKIT SAVE: Project '\(secureProject.name)' saved to CloudKit")
        } catch {
            print("⚠️ CLOUDKIT SAVE: Failed to save to CloudKit (local save succeeded): \(error)")
        }
        
        print("✅ Created new project for organization \(orgID.prefix(8))...: \(secureProject.name)")
    }
    
    func addProject(_ project: Project) async {
        guard let orgID = currentOrganizationID else {
            print("❌ SECURITY: Cannot add project - no organization selected")
            return
        }
        
        // CRITICAL: Ensure project belongs to current organization
        var secureProject = project
        secureProject.organizationID = orgID
        
        // Add to local storage
        await MainActor.run {
            if !organizationProjects.contains(where: { $0.id == secureProject.id }) {
                organizationProjects.append(secureProject)
            }
        }
        
        // Save to organization-specific storage
        saveOrganizationSpecificBackup()
        
        // PHASE 2: Save to CloudKit for persistence across app reinstalls
        do {
            try await saveProjectToCloudKit(secureProject)
            print("✅ CLOUDKIT SAVE: Project '\(secureProject.name)' saved to CloudKit")
        } catch {
            print("⚠️ CLOUDKIT SAVE: Failed to save to CloudKit (local save succeeded): \(error)")
        }
        
        print("✅ Added project '\(secureProject.name)' to organization: \(orgID.prefix(8))...")
    }
    
    func updateProject(_ project: Project) async {
        guard let orgID = currentOrganizationID else {
            print("❌ SECURITY: Cannot update project - no organization selected")
            return
        }
        
        // CRITICAL: Ensure project belongs to current organization
        var secureProject = project
        secureProject.organizationID = orgID
        secureProject.lastModifiedDate = Date()
        
        // Update in local storage
        await MainActor.run {
            if let index = organizationProjects.firstIndex(where: { $0.id == secureProject.id }) {
                organizationProjects[index] = secureProject
            } else {
                organizationProjects.append(secureProject)
            }
            
            if selectedProject?.id == secureProject.id { 
                selectedProject = secureProject 
            }
        }
        
        // Save to organization-specific storage
        saveOrganizationSpecificBackup()
        
        // PHASE 2: Save to CloudKit for persistence across app reinstalls
        do {
            try await saveProjectToCloudKit(secureProject)
            print("✅ CLOUDKIT UPDATE: Project '\(secureProject.name)' updated in CloudKit")
        } catch {
            print("⚠️ CLOUDKIT UPDATE: Failed to update in CloudKit (local update succeeded): \(error)")
        }
        
        print("✅ Updated project: \(secureProject.name)")
    }
    
    func deleteProject(_ project: Project) async {
        // Delete from local storage
        await MainActor.run {
            offlineDataManager.deleteProject(project)
        }
    }
    
    func deleteProjectPermanently(_ project: Project) async {
        // Delete permanently from local storage
        await MainActor.run {
            offlineDataManager.deleteProjectPermanently(project)
        }
    }
    
    // MARK: - CloudKit Integration
    
    func triggerManualSync() async -> Bool {
        return await saveAllProjectsToCloudKit()
    }
    
    /// CRITICAL FIX: Actually create CloudKit zones for organizations instead of just setting flags
    func setupCloudKitZoneForOrganization(_ orgID: UUID) async {
        print("🔧 CLOUDKIT ZONE: Setting up zone for organization: \(orgID.uuidString.prefix(8))...")
        
        // Convert UUID to String
        let orgIDString = orgID.uuidString
        currentOrganizationID = orgIDString
        
        isUsingCloudKitForOrganizationData = true
        zoneSetupError = nil
        
        // CRITICAL FIX: Create CloudKit zone using CloudKit container directly
        // This avoids import issues while still creating the actual zones
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
            let privateDatabase = container.privateCloudDatabase
            
            // Create organization-specific zone
            let zoneName = "Org-\(orgIDString)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            let zone = CKRecordZone(zoneID: zoneID)
            
            let savedZone = try await privateDatabase.save(zone)
            print("✅ CLOUDKIT ZONE: Zone created successfully: \(savedZone.zoneID.zoneName)")
            
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, which is fine
            print("✅ CLOUDKIT ZONE: Zone already exists for organization: \(orgIDString.prefix(8))...")
        } catch {
            print("❌ CLOUDKIT ZONE: Failed to create zone: \(error)")
            zoneSetupError = error
            // Don't throw - allow app to continue with local data
        }
        
        print("✅ CLOUDKIT ZONE: Zone setup completed for organization: \(orgIDString.prefix(8))...")
    }
    
    func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        // CRITICAL FIX: Create CloudKit zones using CloudKit container directly
        print("🔧 CLOUDKIT ZONE: Setting up zone for organization: \(organizationID.prefix(8))...")
        
        currentOrganizationID = organizationID
        isUsingCloudKitForOrganizationData = true
        zoneSetupError = nil
        
        // CRITICAL FIX: Create CloudKit zone using CloudKit container directly
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
            let privateDatabase = container.privateCloudDatabase
            
            // Create organization-specific zone
            let zoneName = "Org-\(organizationID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            let zone = CKRecordZone(zoneID: zoneID)
            
            let savedZone = try await privateDatabase.save(zone)
            print("✅ CLOUDKIT ZONE: Zone created successfully: \(savedZone.zoneID.zoneName)")
            
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, which is fine
            print("✅ CLOUDKIT ZONE: Zone already exists for organization: \(organizationID.prefix(8))...")
        } catch {
            print("❌ CLOUDKIT ZONE: Failed to create zone: \(error)")
            zoneSetupError = error
            // Don't throw - allow app to continue with local data
        }
        
        print("✅ CLOUDKIT ZONE: Zone setup completed for organization: \(organizationID.prefix(8))...")
    }
    
    // MARK: - Team Member Management
    
    func addTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.addTeamMember(teamMember)
        }
    }
    
    func updateTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.updateTeamMember(teamMember)
        }
    }
    
    func removeTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.removeTeamMember(teamMember)
        }
    }
    
    internal func updateTeamMemberCaches() {
        teamMembersCache.removeAll()
        teamMemberNameCache.removeAll()
        
        for member in teamMembers {
            teamMembersCache[member.id] = member
            teamMemberNameCache[member.name] = member
        }
    }
    
    func getTeamMember(by id: UUID) -> TeamMember? {
        return teamMembersCache[id]
    }
    
    func getTeamMember(by name: String) -> TeamMember? {
        return teamMemberNameCache[name]
    }
    
    // MARK: - Task Management
    
    func addTask(_ task: ProjectTask, to projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.tasks.append(task)
        
        await updateProject(updatedProject)
    }
    
    func updateTask(_ task: ProjectTask, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        if let taskIndex = updatedProject.tasks.firstIndex(where: { $0.id == task.id }) {
            updatedProject.tasks[taskIndex] = task
            await updateProject(updatedProject)
        }
    }
    
    func deleteTask(_ task: ProjectTask, from projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.tasks.removeAll { $0.id == task.id }
        
        await updateProject(updatedProject)
    }
    
    // MARK: - Progress Log Management
    
    func addProgressLog(_ progressLog: ProgressLog, to projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.progressLogs.append(progressLog)
        
        await updateProject(updatedProject)
    }
    
    func updateProgressLog(_ progressLog: ProgressLog, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        if let logIndex = updatedProject.progressLogs.firstIndex(where: { $0.id == progressLog.id }) {
            updatedProject.progressLogs[logIndex] = progressLog
            await updateProject(updatedProject)
        }
    }
    
    func updateProgressLog(_ progressLog: ProgressLog, employees: [UUID], images: [UIImage]) {
        guard let selectedProject = selectedProject else { return }
        
        Task {
            await updateProgressLog(progressLog, in: selectedProject.id)
        }
    }
    
    func removeProgressLog(_ logID: UUID) {
        guard let selectedProject = selectedProject else { return }
        
        Task {
            let logToRemove = ProgressLog(
                id: logID,
                date: Date(),
                workDescription: "",
                notes: "",
                employeeIDs: [],
                photoIDs: []
            )
            await deleteProgressLog(logToRemove, from: selectedProject.id)
        }
    }
    
    func deleteProgressLog(_ progressLog: ProgressLog, from projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.progressLogs.removeAll { $0.id == progressLog.id }
        
        await updateProject(updatedProject)
    }
    
    // MARK: - Receipt Management
    
    func addReceipt(_ receipt: Receipt, to projectID: UUID) async {
        print("🔍 RECEEPT DEBUG: Looking for project ID: \(projectID)")
        print("🔍 RECEIPT DEBUG: Organization projects count: \(organizationProjects.count)")
        print("🔍 RECEIPT DEBUG: All projects count: \(projects.count)")
        
        // CRITICAL FIX: Check BOTH organizationProjects AND all projects to handle sync issues
        var targetProject: Project?
        var projectIndex: Int?
        var isInOrganizationProjects = false
        
        // First, try to find in organizationProjects (preferred)
        if let orgIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) {
            targetProject = organizationProjects[orgIndex]
            projectIndex = orgIndex
            isInOrganizationProjects = true
            print("✅ RECEIPT DEBUG: Found project in organizationProjects at index \(orgIndex)")
        }
        // If not found, try all projects (fallback for sync issues)
        else if let allIndex = projects.firstIndex(where: { $0.id == projectID }) {
            targetProject = projects[allIndex]
            projectIndex = allIndex
            isInOrganizationProjects = false
            print("⚠️ RECEIPT DEBUG: Found project in all projects (not in org projects) at index \(allIndex)")
            print("🔧 RECEIPT DEBUG: This indicates a data sync issue - adding to organizationProjects")
            
            // CRITICAL FIX: Add project to organizationProjects if it belongs to current org
            let foundProject = projects[allIndex]
            if let currentOrgID = currentOrganizationID, foundProject.organizationID == currentOrgID {
                await MainActor.run {
                    organizationProjects.append(foundProject)
                    print("✅ RECEIPT DEBUG: Added project to organizationProjects to fix sync issue")
                }
                isInOrganizationProjects = true
                projectIndex = organizationProjects.count - 1
            }
        }
        
        guard let project = targetProject, let index = projectIndex else { 
            print("❌ RECEIPT ADD FAILED: Project not found with ID: \(projectID)")
            print("💡 AVAILABLE ORGANIZATION PROJECTS:")
            for (i, proj) in organizationProjects.enumerated() {
                print("  \(i): \(proj.name) (ID: \(proj.id))")
            }
            print("💡 AVAILABLE ALL PROJECTS:")
            for (i, proj) in projects.enumerated() {
                print("  \(i): \(proj.name) (ID: \(proj.id)) - OrgID: \(proj.organizationID)")
            }
            return 
        }
        
        print("💾 ADDING RECEIPT: \(receipt.vendor) - \(receipt.amount.formatAsCurrency()) to project: \(project.name)")
        
        var updatedProject = project
        updatedProject.receipts.append(receipt)
        updatedProject.lastModifiedDate = Date()
        
        // Update the project in the correct array
        if isInOrganizationProjects {
            await MainActor.run {
                organizationProjects[index] = updatedProject
            }
        } else {
            await MainActor.run {
                projects[index] = updatedProject
            }
        }
        
        // CRITICAL: Also update the selectedProject if it matches
        await MainActor.run {
            if selectedProject?.id == projectID {
                selectedProject = updatedProject
                print("✅ RECEIPT ADDED: Updated selected project with new receipt")
            }
        }
        
        // Save to organization-specific storage
        saveOrganizationSpecificBackup()
        
        // PHASE 2: Save updated project to CloudKit for receipt persistence
        do {
            try await saveProjectToCloudKit(updatedProject)
            print("✅ RECEIPT CLOUDKIT: Project with new receipt saved to CloudKit")
        } catch {
            print("⚠️ RECEIPT CLOUDKIT: Failed to save to CloudKit (local save succeeded): \(error)")
        }
        
        print("✅ RECEIPT PERSISTENCE: Receipt added and project updated successfully")
    }
    
    func updateReceipt(_ receipt: Receipt, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        if let receiptIndex = updatedProject.receipts.firstIndex(where: { $0.id == receipt.id }) {
            updatedProject.receipts[receiptIndex] = receipt
            await updateProject(updatedProject)
        }
    }
    
    func deleteReceipt(_ receipt: Receipt, from projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.receipts.removeAll { $0.id == receipt.id }
        
        await updateProject(updatedProject)
    }
    
    // MARK: - Work Hour Management
    
    func logHours(_ workHour: WorkHour, for projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.workHours.append(workHour)
        
        await updateProject(updatedProject)
    }
    
    func updateWorkHour(_ workHour: WorkHour, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        if let hourIndex = updatedProject.workHours.firstIndex(where: { $0.id == workHour.id }) {
            updatedProject.workHours[hourIndex] = workHour
            await updateProject(updatedProject)
        }
    }
    
    func deleteWorkHour(_ workHour: WorkHour, from projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.workHours.removeAll { $0.id == workHour.id }
        
        await updateProject(updatedProject)
    }
    
    // MARK: - Team Member Management Methods (For PHASE 2 compatibility)
    
    func saveTeamMembersToCloudKit() async {
        print("💾 CLOUDKIT TEAM SYNC: Starting team members sync to CloudKit...")
        
        guard !teamMembers.isEmpty else {
            print("⚠️ CLOUDKIT TEAM SYNC: No team members to sync")
            return
        }
        
        guard let currentOrgID = currentOrganizationID else {
            print("❌ CLOUDKIT TEAM SYNC: No organization ID")
            return
        }
        
        let teamMembersToSync = teamMembers.filter { $0.organizationID == currentOrgID }
        print("💾 CLOUDKIT TEAM SYNC: Syncing \(teamMembersToSync.count) team members for organization \(currentOrgID.prefix(8))...")
        
        var successCount = 0
        
        for teamMember in teamMembersToSync {
            do {
                try await saveTeamMemberToCloudKit(teamMember)
                successCount += 1
                print("✅ CLOUDKIT TEAM SYNC: Saved \(teamMember.name)")
            } catch {
                print("❌ CLOUDKIT TEAM SYNC: Failed to save \(teamMember.name): \(error)")
            }
        }
        
        // Also save team members to organization-specific local storage
        let teamMembersKey = "team_members_\(currentOrgID)"
        if let teamMembersData = try? JSONEncoder().encode(teamMembersToSync) {
            UserDefaults.standard.set(teamMembersData, forKey: teamMembersKey)
            print("💾 LOCAL SYNC: Saved \(teamMembersToSync.count) team members to key: \(teamMembersKey)")
        }
        
        UserDefaults.standard.synchronize()
        
        print("✅ CLOUDKIT TEAM SYNC: Completed - \(successCount)/\(teamMembersToSync.count) team members saved")
    }
    
    // MARK: - PHASE 2A: UUID/String Organization ID Compatibility
    
    func organizationDidChange(_ orgID: String?) async {
        await organizationDidChange()
    }
    
    func organizationDidChange(_ orgID: UUID) async {
        await organizationDidChange()
    }
    
    // MARK: - PHASE 2A: Missing Legacy Compatibility Methods
    
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: UUID) {
        print("🔐 ROLE MANAGEMENT: Setting user role to \(role.displayName) for organization: \(organizationID.uuidString.prefix(8))...")
        
        // Convert OrganizationRole to TeamMemberRole for ProjectViewModel compatibility
        let teamMemberRole: TeamMemberRole = {
            switch role {
            case .admin:
                return .admin
            case .member:
                return .member  
            case .contractor:
                return .member // Contractors are treated as members in project context
            case .viewer:
                return .member // Viewers are treated as members with limited permissions
            }
        }()
        
        // Update the current organization role
        currentOrganizationRole = teamMemberRole
        
        // Ensure we're working with the correct organization
        let orgIDString = organizationID.uuidString
        if currentOrganizationID != orgIDString {
            print("🔐 ROLE SYNC WARNING: Role set for organization \(orgIDString.prefix(8))... but current org is \(currentOrganizationID?.prefix(8) ?? "none")")
        }
        
        // Update accessible projects based on new role
        updateAccessibleProjects()
        
        print("✅ ROLE MANAGEMENT: User role set to \(teamMemberRole.displayName) (converted from \(role.displayName))")
        print("   Organization: \(orgIDString.prefix(8))...")
        print("   Current Org Role: \(currentOrganizationRole?.displayName ?? "none")")
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: String) {
        if let uuid = UUID(uuidString: organizationID) {
            setCurrentUserRole(role, forOrganization: uuid)
        } else {
            print("❌ ROLE MANAGEMENT: Invalid organization ID format: \(organizationID)")
        }
    }
    
    func setUserProjectAssignments(_ projectIDs: [String]) {
        print("TODO: setUserProjectAssignments - Phase 2B implementation needed")
        // Stub implementation for compatibility
    }
    
    func getOrganizationDataMigrationStatus() -> String {
        return "Migration status not available in Phase 1"
    }
    
    func getOrganizationVendorSpendingAnalytics() -> [(vendor: String, amount: Double)] {
        var vendorSpending: [String: Double] = [:]
        
        for project in organizationProjects {
            for receipt in project.receipts {
                let vendorName = receipt.vendor
                vendorSpending[vendorName, default: 0] += receipt.amount
            }
        }
        
        return vendorSpending.map { (vendor: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    func getOrganizationPaymentMethodSpendingAnalytics() -> [(paymentMethod: String, amount: Double)] {
        var paymentMethodSpending: [String: Double] = [:]
        
        for project in organizationProjects {
            for receipt in project.receipts {
                let paymentMethodName = receipt.paymentMethod
                paymentMethodSpending[paymentMethodName, default: 0] += receipt.amount
            }
        }
        
        return paymentMethodSpending.map { (paymentMethod: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    func forceMigrateOrganizationDataToCloudKit() async throws {
        throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit migration not available in Phase 1"])
    }
    
    func updateTeamMemberInOrganization(_ teamMember: TeamMember) {
        Task {
            await updateTeamMember(teamMember)
        }
    }
    
    func fixMissingOrganizationIDs(completion: @escaping (Bool, String) -> Void) {
        completion(true, "Organization ID fix not needed in Phase 1")
    }
    
    var needsLaborHoursMigration: Bool {
        return false
    }
    
    func getLaborHoursMigrationStatus() -> String {
        return "Labor hours migration status not available in Phase 1"
    }
    
    func migrateLaborHoursToTeamMemberIDs() {
        // Stub implementation for Phase 1
    }
    
    func emergencyDataRecovery() async -> String {
        return "Emergency data recovery not available in Phase 1"
    }
    
    // MARK: - Helper Methods
    
    var bulkSyncProgressText: String {
        if isBulkSyncing {
            return "Syncing... \(Int(bulkSyncProgress * 100))%"
        }
        return ""
    }
    
    func selectProject(_ project: Project) {
        selectedProject = project
    }
    
    func deselectProject() {
        selectedProject = nil
    }
    
    // MARK: - Computed Properties
    
    var activeProjects: [Project] {
        return organizationProjects.filter { $0.status == .active }
    }
    
    var completedProjects: [Project] {
        return organizationProjects.filter { $0.status == .completed }
    }
    
    var pastDueProjects: [Project] {
        let today = Date()
        return organizationProjects.filter { 
            $0.status == .active && $0.endDate < today
        }
    }
    
    // MARK: - Legacy Compatibility Properties
    
    var allProjects: [Project] {
        return projects
    }
    
    // MARK: - Debug and Diagnostics
    
    /// Consolidated debug information for troubleshooting
    func debugOrganizationState() {
        print("🔍 ORGANIZATION DEBUG STATE:")
        print("  Current Org: \(currentOrganization?.name ?? "None")")
        print("  Current Org ID: \(currentOrganizationID ?? "None")")
        print("  Projects Array: \(projects.count)")
        print("  Organization Projects: \(organizationProjects.count)")
        print("  Accessible Projects: \(accessibleProjects.count)")
        print("  Team Members: \(teamMembers.count)")
        print("  CloudKit Enabled: \(isUsingCloudKitForOrganizationData)")
        print("  Data Loading: \(isDataLoading)")
        
        if let error = zoneSetupError {
            print("  Zone Setup Error: \(error.localizedDescription)")
        }
        
        // Show project details if count mismatch
        if projects.count != organizationProjects.count {
            print("  ⚠️ PROJECT COUNT MISMATCH:")
            print("    All Projects: \(projects.map { "\($0.name) (\($0.organizationID))" })")
            print("    Org Projects: \(organizationProjects.map { "\($0.name) (\($0.organizationID))" })")
        }
    }
}