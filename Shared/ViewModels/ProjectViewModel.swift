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
    
    // Team member properties
    @Published var teamMembers: [TeamMember] = []
    private var teamMembersCache: [UUID: TeamMember] = [:]
    private var teamMemberNameCache: [String: TeamMember] = [:]
    
    // Receipt properties
    private var receiptVendorCache: [UUID: Vendor] = [:]
    private var receiptPaymentMethodCache: [UUID: PaymentMethod] = [:]
    
    // PHASE 2A: Add missing properties for compatibility
    @Published var laborTotalsByTeamMember: [String: (unpaid: Double, paid: Double)] = [:]
    @Published var groupedHoursByTeamMember: [String: [WorkHour]] = [:]
    
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
        // TODO: Re-add service assignments in Phase 2
        // self.cloudKitService = cloudKitService
        // self.sharingService = sharingService
        // self.photoService = photoService
        // self.migrationService = migrationService
        // self.vendorService = vendorService
        // self.paymentMethodService = paymentMethodService
        // self.organizationKnowledgeService = organizationKnowledgeService
        
        setupDataObservation()
    }
    
    // MARK: - Computed Properties (PHASE 1 STUBS)
    
    var currentOrganizationID: String? {
        return currentOrganization?.id.uuidString
    }
    
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
        updateOrganizationProjects()
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Sync organization data
        // if let org = organization {
        //     Task {
        //         await syncOrganizationData(org)
        //     }
        // }
    }
    
    private func updateOrganizationProjects() {
        if let currentOrg = currentOrganization {
            organizationProjects = projects.filter { $0.organizationID == currentOrg.id.uuidString }
        } else {
            organizationProjects = []
        }
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
        // Add to local storage first
        let newProject = project
        await MainActor.run {
            offlineDataManager.addProject(newProject)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Save to CloudKit if enabled
        // if let currentOrg = currentOrganization, 
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await saveProjectToCloudKitSharedZone(newProject)
        //         print("DEBUG: Project saved to CloudKit successfully")
        //     } catch {
        //         print("DEBUG: Failed to save project to CloudKit: \(error)")
        //     }
        // } else {
        //     print("DEBUG: CloudKit not enabled for organization or no current organization")
        // }
    }
    
    func addProject(_ project: Project) async {
        // Add to local storage
        await MainActor.run {
            offlineDataManager.addProject(project)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Save to CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await saveProjectToCloudKitSharedZone(project)
        //         print("DEBUG: addProject - Project saved to CloudKit")
        //     } catch {
        //         print("DEBUG: addProject - Failed to save to CloudKit: \(error)")
        //     }
        // } else {
        //     print("DEBUG: addProject - CloudKit not enabled or no organization")
        // }
    }
    
    func updateProject(_ project: Project) async {
        // Update in local storage
        await MainActor.run {
            offlineDataManager.updateProject(project)
        }
        
        // TODO: Re-enable CloudKit sync in Phase 2
        // Update in CloudKit if enabled
        // if let currentOrg = currentOrganization,
        //    await sharingService.isCloudKitEnabled(for: currentOrg.id) {
        //     do {
        //         try await saveProjectToCloudKitSharedZone(project)
        //         print("DEBUG: updateProject - Project updated in CloudKit")
        //     } catch {
        //         print("DEBUG: updateProject - Failed to update in CloudKit: \(error)")
        //     }
        // }
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
    
    private func updateTeamMemberCaches() {
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
    
    func deleteProgressLog(_ progressLog: ProgressLog, from projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.progressLogs.removeAll { $0.id == progressLog.id }
        
        await updateProject(updatedProject)
    }
    
    // MARK: - Receipt Management
    
    func addReceipt(_ receipt: Receipt, to projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        var updatedProject = organizationProjects[projectIndex]
        updatedProject.receipts.append(receipt)
        
        await updateProject(updatedProject)
        
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
    //     guard let currentOrg = currentOrganization else { return }
    //     
    //     // Process all existing projects for intelligence
    //     for project in organizationProjects {
    //         for receipt in project.receipts {
    //             organizationKnowledgeService.processReceiptForOrganizationIntelligence(receipt, in: currentOrg)
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
    
    // MARK: - Team Member Computed Properties
    
    var activeTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.status == .active }
    }
    
    var inactiveTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.status != .active }
    }
    
    func getTeamMembersForProject(_ project: Project) -> [TeamMember] {
        let projectTeamMemberIDs = project.assignedUserIDs
        return teamMembers.filter { teamMember in
            projectTeamMemberIDs.contains(teamMember.id.uuidString)
        }
    }
    
    // MARK: - Receipt Computed Properties
    
    func getVendorsForProject(_ project: Project) -> [Vendor] {
        let projectReceipts = project.receipts
        let vendorIDs = projectReceipts.compactMap { $0.vendorID }
        return offlineDataManager.vendors.filter { vendor in
            vendorIDs.contains(vendor.id.uuidString)
        }
    }
    
    func getPaymentMethodsForProject(_ project: Project) -> [PaymentMethod] {
        let projectReceipts = project.receipts
        let paymentMethodIDs = projectReceipts.compactMap { $0.paymentMethodID }
        return offlineDataManager.paymentMethods.filter { paymentMethod in
            paymentMethodIDs.contains(paymentMethod.id.uuidString)
        }
    }
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
    
    func rebuildTeamMemberCache() {
        print("PHASE 2A: Rebuilding team member cache...")
        updateTeamMemberCaches()
        // Note: recomputeLaborData() is already defined in ProjectViewModel+Clocking.swift
        recomputeLaborData() // Call the existing comprehensive method
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
}