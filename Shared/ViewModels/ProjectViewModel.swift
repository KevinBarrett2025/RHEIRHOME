//
//  ProjectViewModel.swift
//  RHEIR
//
//  Created by Kevin Barrett on 1/2/24.
//

import Combine
import CloudKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    
    // MARK: - Computed Properties (PHASE 1 STUBS)
    
    // Remove duplicate declaration - use the @Published property instead
    // var currentOrganizationID: String? {
    //     return currentOrganization?.id
    // }
    
    // MARK: - PHASE 1 STUB METHODS - TODO: Implement in Phase 2
    
    func setupCloudKitZoneForOrganization(_ orgID: UUID) async {
        print("TODO: setupCloudKitZoneForOrganization - Phase 2")
        // Stub implementation
        isUsingCloudKitForOrganizationData = false
        zoneSetupError = nil
    }
    
    func addTeamMemberToOrganization(_ teamMember: TeamMember) {
        print("TODO: addTeamMemberToOrganization - Phase 2")
        // For now, just add to local storage
        Task {
            await addTeamMember(teamMember)
        }
    }
    
    func markProjectAsCompleted(_ project: Project) {
        print("TODO: markProjectAsCompleted - Phase 2")
        // Basic implementation
        var updatedProject = project
        updatedProject.status = .completed
        updatedProject.lastModifiedDate = Date()
        
        Task {
            await updateProject(updatedProject)
        }
    }
    
    func syncAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        print("TODO: syncAllProjectsToCloudKit - Phase 2")
        // Stub implementation
        completion(false, "CloudKit sync not available in Phase 1")
    }
    
    func organizationDidChange(_ orgID: UUID) async {
        print("TODO: organizationDidChange with orgID - Phase 2")
        await organizationDidChange()
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
        print("TODO: invalidateReceiptCache - Phase 2")
        // Stub implementation
    }
    
    func saveAllProjectsToCloudKit() async {
        print("TODO: saveAllProjectsToCloudKit - Phase 2")
        // Stub implementation - does nothing in Phase 1
    }
    
    func recomputeFilteredReceipts() {
        print("TODO: recomputeFilteredReceipts - Phase 2")
        // Stub implementation
    }
    
    func debouncedSaveProjects() {
        print("TODO: debouncedSaveProjects - Phase 2")
        // Stub implementation
    }
    
    // MARK: - PHASE 1 BRIDGE: Missing Methods
    
    // MARK: - Data Initialization
    
    func loadProjects() async {
        print("🔄 loadProjects - Loading projects from organization-specific storage")
        isDataLoading = true
        
        if let orgID = currentOrganizationID {
            // Load projects using organization-specific method
            await loadOrganizationSpecificProjects(organizationID: orgID)
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
        } else {
            self.currentOrganizationID = nil
        }
        updateOrganizationProjects()
        
        // Load projects for this organization using the REAL ID
        if let orgID = self.currentOrganizationID {
            Task {
                await loadOrganizationSpecificProjects(organizationID: orgID)
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
                    print("🔍 PROJECT FILTER: Excluding '\(project.name)' - OrgID: \(project.organizationID) vs Current: \(currentOrgID)")
                }
                return matches
            }
            
            organizationProjects = filteredProjects
            print("✅ FILTERED PROJECTS: \(organizationProjects.count) projects for organization \(currentOrgID.prefix(8))...")
            
            for (i, project) in organizationProjects.enumerated() {
                print("  \(i): \(project.name) - ID: \(project.id)")
            }
            
            // Update accessible projects based on user role
            updateAccessibleProjects()
        } else {
            print("⚠️ NO ORGANIZATION: Clearing organization projects")
            organizationProjects = []
            accessibleProjects = []
        }
        
        // Trigger UI update
        objectWillChange.send()
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
    
    private func updateAccessibleProjects() {
        // For Phase 1, accessible projects are the same as organization projects
        // In Phase 2, this will be filtered based on role and project assignments
        accessibleProjects = organizationProjects
        
        // TODO: Phase 2 - Implement role-based filtering
        // if let role = currentOrganizationRole {
        //     switch role {
        //     case .admin, .member:
        //         accessibleProjects = organizationProjects
        //     case .contractor:
        //         // Filter to only assigned projects
        //         accessibleProjects = organizationProjects.filter { project in
        //             // Check if user is assigned to this project
        //             // This will be implemented with proper project assignment system
        //             return true // For now, show all
        //         }
        //     case .viewer:
        //         // Read-only access to assigned projects
        //         accessibleProjects = organizationProjects.filter { project in
        //             // Check if user has view access to this project
        //             return true // For now, show all
        //         }
        //     }
        // }
    }
    
    // TODO: Re-enable in Phase 2 with proper CloudKit architecture
    // private func syncOrganizationData(_ organization: Organization) async {
    //     // Sync team members
    //     await syncTeamMembers(for: organization)
    //     
    //     // Sync vendors and payment methods
    //     await syncOrganizationKnowledge(for: organization)
    // }
    
    // TODO: Re-enable in Phase 2
    // private func syncTeamMembers(for organization: Organization) async {
    //     do {
    //         let members = try await cloudKitService.fetchTeamMembers(for: organization.id)
    //         await MainActor.run {
    //             offlineDataManager.updateTeamMembers(members)
    //         }
    //     } catch {
    //         print("Failed to sync team members: \(error)")
    //     }
    // }
    
    // TODO: Re-enable in Phase 2
    // private func syncOrganizationKnowledge(for organization: Organization) async {
    //     // Sync vendors
    //     do {
    //         let vendors = try await vendorService.fetchOrganizationVendors(organizationID: organization.id)
    //         await MainActor.run {
    //             offlineDataManager.updateVendors(vendors)
    //         }
    //     } catch {
    //         print("Failed to sync organization vendors: \(error)")
    //     }
    //     
    //     // Sync payment methods
    //     do {
    //         let paymentMethods = try await paymentMethodService.fetchOrganizationPaymentMethods(organizationID: organization.id)
    //         await MainActor.run {
    //             offlineDataManager.updatePaymentMethods(paymentMethods)
    //         }
    //     } catch {
    //         print("Failed to sync organization payment methods: \(error)")
    //     }
    // }
    
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
        
        print("✅ Updated project: \(secureProject.name)")
    }
    
    func deleteProject(_ project: Project) async {
        // Delete from local storage
        await MainActor.run {
            offlineDataManager.deleteProject(project)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Delete from CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await deleteProjectFromCloudKitSharedZone(project)
        //         print("DEBUG: deleteProject - Project deleted from CloudKit")
        //     } catch {
        //         print("DEBUG: deleteProject - Failed to delete from CloudKit: \(error)")
        //     }
        // }
    }
    
    func deleteProjectPermanently(_ project: Project) async {
        // Delete permanently from local storage
        await MainActor.run {
            offlineDataManager.deleteProjectPermanently(project)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Delete permanently from CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await deleteProjectFromCloudKitSharedZone(project)
        //         print("DEBUG: deleteProjectPermanently - Project deleted from CloudKit")
        //     } catch {
        //         print("DEBUG: deleteProjectPermanently - Failed to delete from CloudKit: \(error)")
        //     }
        // }
    }
    
    // MARK: - CloudKit Integration (Phase 2)
    // TODO: Re-implement with proper service architecture
    
    // func saveProjectToCloudKitSharedZone(_ project: Project) throws {
    //     print("DEBUG: saveProjectToCloudKitSharedZone called for project: \(project.name)")
    //     
    //     guard let currentOrg = currentOrganization else {
    //         print("DEBUG: No current organization, skipping CloudKit save")
    //         return
    //     }
    //     
    //     print("DEBUG: Current organization ID: \(currentOrg.id.uuidString)")
    //     print("DEBUG: Current organization name: \(currentOrg.name)")
    //     
    //     Task {
    //         do {
    //             try await sharingService.saveProject(project, to: currentOrg.id)
    //             print("DEBUG: Project successfully saved to CloudKit shared zone")
    //         } catch {
    //             print("DEBUG: Error saving project to CloudKit: \(error)")
    //             throw error
    //         }
    //     }
    // }
    
    // func loadProjectsFromCloudKitZone() async throws -> [Project] {
    //     guard let currentOrg = currentOrganization else {
    //         print("DEBUG: No current organization, returning empty projects array")
    //         return []
    //     }
    //     
    //     print("DEBUG: Loading projects from CloudKit for organization: \(currentOrg.name)")
    //     
    //     do {
    //         let projects = try await sharingService.fetchProjects(for: currentOrg.id)
    //         print("DEBUG: Loaded \(projects.count) projects from CloudKit")
    //         return projects
    //     } catch {
    //         print("DEBUG: Error loading projects from CloudKit: \(error)")
    //         throw error
    //     }
    // }
    
    // func deleteProjectFromCloudKitSharedZone(_ project: Project) throws {
    //     guard let currentOrg = currentOrganization else {
    //         print("DEBUG: No current organization, skipping CloudKit delete")
    //         return
    //     }
    //     
    //     Task {
    //         do {
    //             try await sharingService.deleteProject(project, from: currentOrg.id)
    //             print("DEBUG: Project successfully deleted from CloudKit shared zone")
    //         } catch {
    //             print("DEBUG: Error deleting project from CloudKit: \(error)")
    //             throw error
    //         }
    //     }
    // }
    
    // MARK: - Team Member Management
    
    func addTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.addTeamMember(teamMember)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Save to CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await sharingService.saveTeamMember(teamMember, to: currentOrg.id)
        //         print("DEBUG: Team member saved to CloudKit")
        //     } catch {
        //         print("DEBUG: Failed to save team member to CloudKit: \(error)")
        //     }
        // }
    }
    
    func updateTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.updateTeamMember(teamMember)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Update in CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await sharingService.saveTeamMember(teamMember, to: currentOrg.id)
        //         print("DEBUG: Team member updated in CloudKit")
        //     } catch {
        //         print("DEBUG: Failed to update team member in CloudKit: \(error)")
        //     }
        // }
    }
    
    func removeTeamMember(_ teamMember: TeamMember) async {
        await MainActor.run {
            offlineDataManager.removeTeamMember(teamMember)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Remove from CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await sharingService.deleteTeamMember(teamMember, from: currentOrg.id)
        //         print("DEBUG: Team member removed from CloudKit")
        //     } catch {
        //         print("DEBUG: Failed to remove team member from CloudKit: \(error)")
        //     }
        // }
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
    
    // PHASE 1 BRIDGE: Additional progress log methods for EditProgressView compatibility
    func updateProgressLog(_ progressLog: ProgressLog, employees: [UUID], images: [UIImage]) {
        // For now, just update the progress log with the basic info
        // TODO: Phase 2 - Handle employee associations and image uploads
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
        print("🔍 RECEIPT DEBUG: Looking for project ID: \(projectID)")
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
        
        print("💾 ADDING RECEIPT: \(receipt.vendor ?? "Unknown vendor") - \(receipt.amount.formatAsCurrency()) to project: \(project.name)")
        
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
        
        print("✅ RECEIPT PERSISTENCE: Receipt added and project updated successfully")
        
        // TODO: Re-enable in Phase 2
        // Process receipt for organization intelligence
        // if let currentOrg = currentOrganization {
        //     organizationKnowledgeService.processReceiptForOrganizationIntelligence(receipt, in: currentOrg)
        // }
    }
    
    func updateReceipt(_ receipt: Receipt, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        if let receiptIndex = updatedProject.receipts.firstIndex(where: { $0.id == receipt.id }) {
            updatedProject.receipts[receiptIndex] = receipt
            await updateProject(updatedProject)
        }
        
        // TODO: Re-enable in Phase 2
        // Process receipt for organization intelligence
        // if let currentOrg = currentOrganization {
        //     organizationKnowledgeService.processReceiptForOrganizationIntelligence(receipt, in: currentOrg)
        // }
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
    
    // MARK: - Data Sync (Phase 2)
    // TODO: Re-implement with proper CloudKit architecture
    
    // func syncAllProjectsToCloudKit() async {
    //     guard let currentOrg = currentOrganization else { return }
    //     
    //     isBulkSyncing = true
    //     defer { isBulkSyncing = false }
    //     
    //     let projectsToSync = organizationProjects
    //     bulkSyncProgress = 0.0
    //     
    //     for (index, project) in projectsToSync.enumerated() {
    //         do {
    //             try await saveProjectToCloudKitSharedZone(project)
    //             bulkSyncProgress = Double(index + 1) / Double(projectsToSync.count)
    //             print("DEBUG: Synced project \(index + 1)/\(projectsToSync.count): \(project.name)")
    //         } catch {
    //             print("DEBUG: Failed to sync project \(project.name): \(error)")
    //         }
    //     }
    //     
    //     bulkSyncProgress = 1.0
    //     print("DEBUG: Completed bulk sync of \(projectsToSync.count) projects")
    // }
    
    func organizationDidChange() async {
        print("DEBUG: organizationDidChange called")
        updateOrganizationProjects()
        
        // TODO: Re-enable CloudKit loading in Phase 2
        // Check if CloudKit is enabled for this organization
        // if let currentOrg = currentOrganization {
        //     let isCloudKitEnabled = await sharingService.isCloudKitEnabled(for: currentOrg.id)
        //     print("DEBUG: CloudKit enabled for organization: \(isCloudKitEnabled)")
        //     
        //     if isCloudKitEnabled {
        //         // Load projects from CloudKit
        //         do {
        //             let cloudProjects = try await loadProjectsFromCloudKitZone()
        //             await MainActor.run {
        //                 offlineDataManager.updateProjects(cloudProjects)
        //             }
        //             print("DEBUG: Loaded \(cloudProjects.count) projects from CloudKit")
        //         } catch {
        //             print("DEBUG: Failed to load projects from CloudKit: \(error)")
        //         }
        //     }
        // }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - PHASE 1 BRIDGE: Additional Missing Properties and Methods
    
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
}

// MARK: - Extensions

extension ProjectViewModel {
    // MARK: - Enterprise Intelligence Methods (Phase 2)
    // TODO: Re-implement with proper service architecture
    
    // func getBusinessIntelligenceReport() async -> OrganizationIntelligenceReport? {
    //     guard let currentOrg = currentOrganization else { return nil }
    //     
    //     return await organizationKnowledgeService.generateIntelligenceReport(for: currentOrg.id)
    // }
    
    // func getNewProjectSuggestions() async -> [ProjectSuggestion] {
    //     guard let currentOrg = currentOrganization else { return [] }
    //     
    //     return await organizationKnowledgeService.getNewProjectSuggestions(for: currentOrg.id)
    // }
    
    // func activateRealTimeIntelligence() async {
    //     guard let currentOrganization else { return }
    //     
    //     // Process all existing projects for intelligence
    //     for project in organizationProjects {
    //         for receipt in project.receipts {
    //             organizationKnowledgeService.processReceiptForOrganizationIntelligence(receipt, in: currentOrganization)
    //         }
    //     }
    // }
    
    // func getIntelligenceStatus() -> IntelligenceStatus {
    //     guard let currentOrganization else { 
    //         return IntelligenceStatus(isReady: false, message: "No organization selected")
    //     }
    //     
    //     let hasVendors = !offlineDataManager.vendors.isEmpty
    //     let hasPaymentMethods = !offlineDataManager.paymentMethods.isEmpty
    //     let hasProjects = !organizationProjects.isEmpty
    //     
    //     if hasVendors && hasPaymentMethods && hasProjects {
    //         return IntelligenceStatus(isReady: true, message: "Enterprise Intelligence is active")
    //     } else {
    //         return IntelligenceStatus(isReady: false, message: "Building organizational knowledge...")
    //     }
    // }

    // ... existing code ...
}

// MARK: - PHASE 2A: Missing Legacy Compatibility Methods

extension ProjectViewModel {
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: UUID) {
        print("TODO: setCurrentUserRole - Phase 2B implementation needed")
        // Stub implementation for compatibility
        // This will be properly implemented in Phase 2B with CloudKit
    }
    
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: String) {
        if let uuid = UUID(uuidString: organizationID) {
            setCurrentUserRole(role, forOrganization: uuid)
        }
    }
    
    func setUserProjectAssignments(_ projectIDs: [String]) {
        print("TODO: setUserProjectAssignments - Phase 2B implementation needed")
        // Stub implementation for compatibility
        // Filter projects based on assignments - basic implementation
        // This will be properly implemented in Phase 2B
    }
    
    // MARK: - Organization Data Migration Methods (Phase 2 Stubs)
    
    func getOrganizationDataMigrationStatus() -> String {
        print("TODO: getOrganizationDataMigrationStatus - Phase 2 implementation needed")
        return "Migration status not available in Phase 1"
    }
    
    func getOrganizationVendorSpendingAnalytics() -> [(vendor: String, amount: Double)] {
        print("TODO: getOrganizationVendorSpendingAnalytics - Phase 2 implementation needed")
        // Return basic analytics from current projects
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
        print("TODO: getOrganizationPaymentMethodSpendingAnalytics - Phase 2 implementation needed")
        // Return basic analytics from current projects
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
        print("TODO: forceMigrateOrganizationDataToCloudKit - Phase 2 implementation needed")
        // Stub implementation for Phase 1
        throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit migration not available in Phase 1"])
    }
    
    func updateTeamMemberInOrganization(_ teamMember: TeamMember) {
        print("TODO: updateTeamMemberInOrganization - Phase 2 implementation needed")
        // For Phase 1, just call the regular updateTeamMember method
        Task {
            await updateTeamMember(teamMember)
        }
    }

    // MARK: - PHASE 2A: UUID/String Organization ID Compatibility
    
    func organizationDidChange(_ orgID: String?) async {
        if let orgIDString = orgID, let uuid = UUID(uuidString: orgIDString) {
            await organizationDidChange(uuid)
        } else {
            await organizationDidChange()
        }
    }
    
    func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        if let uuid = UUID(uuidString: organizationID) {
            await setupCloudKitZoneForOrganization(uuid)
        }
    }
    
    // MARK: - PHASE 1 BRIDGE: Additional Missing Methods
    
    func fixMissingOrganizationIDs(completion: @escaping (Bool, String) -> Void) {
        print("TODO: fixMissingOrganizationIDs - Phase 2 implementation needed")
        // Stub implementation for Phase 1
        completion(true, "Organization ID fix not needed in Phase 1")
    }
    
    // MARK: - Labor Hours Migration Methods (Phase 1 Stubs)
    
    var needsLaborHoursMigration: Bool {
        print("TODO: needsLaborHoursMigration - Phase 2 implementation needed")
        return false // No migration needed in Phase 1
    }
    
    func getLaborHoursMigrationStatus() -> String {
        print("TODO: getLaborHoursMigrationStatus - Phase 2 implementation needed")
        return "Labor hours migration status not available in Phase 1"
    }
    
    func migrateLaborHoursToTeamMemberIDs() {
        print("TODO: migrateLaborHoursToTeamMemberIDs - Phase 2 implementation needed")
        // Stub implementation for Phase 1
    }
    
    func emergencyDataRecovery() async -> String {
        print("TODO: emergencyDataRecovery - Phase 2 implementation needed")
        // Stub implementation for Phase 1
        return "Emergency data recovery not available in Phase 1"
    }
}