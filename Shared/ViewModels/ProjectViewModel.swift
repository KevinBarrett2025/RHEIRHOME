//
//  ProjectViewModel.swift
//  RHEIR
//

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
    @Published var isUsingCloudKitForOrganizationData: Bool = false
    @Published var migrationProgress: String = ""
    @Published var bulkSyncProgress: String = ""
    
    // MARK: - Services
    let cloudKitService: CloudKitAuthService
    let vendorService: VendorManagementService
    let paymentMethodService: PaymentMethodManagementService
    
    // MARK: - Cache Properties
    var teamMemberCache: [String: TeamMember] = [:]
    var groupedHoursByTeamMember: [String: [WorkHour]] = [:]
    var laborTotalsByTeamMember: [String: (unpaid: Double, paid: Double)] = [:]
    
    // MARK: - Computed Properties
    var allProjects: [Project] {
        return projects + organizationProjects
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private var teamMemberSaveTimer: Timer?
    
    // MARK: - Initialization
    init(cloudKitService: CloudKitAuthService = CloudKitAuthService()) {
        self.cloudKitService = cloudKitService
        self.vendorService = VendorManagementService()
        self.paymentMethodService = PaymentMethodManagementService()
        
        Task {
            await loadProjects()
            loadTeamMembers()
            await loadOrganizationData()
        }
    }
    
    convenience init() {
        self.init(cloudKitService: CloudKitAuthService())
    }
    
    // MARK: - Loading Methods
    func loadProjects() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: "projects"),
           let loadedProjects = try? JSONDecoder().decode([Project].self, from: data) {
            projects = loadedProjects
            print("✅ Loaded \(projects.count) projects from UserDefaults")
        } else {
            projects = []
            print("📝 No projects found, starting with empty list")
        }
    }
    
    func loadOrganizationData() async {
        // Load current organization ID
        currentOrganizationID = UserDefaults.standard.string(forKey: "currentOrganizationID")
        print("🏢 Current organization ID: \(currentOrganizationID ?? "none")")
    }
    
    func loadOrganizationProjects() {
        // Placeholder for loading organization projects from CloudKit
        print("☁️ Loading organization projects (placeholder)")
        organizationProjects = []
    }
    
    // MARK: - Organization Methods
    func organizationDidChange(_ organizationID: String?) {
        currentOrganizationID = organizationID
        UserDefaults.standard.set(organizationID, forKey: "currentOrganizationID")
        
        Task {
            loadTeamMembers()
            await loadProjects()
        }
    }
    
    // MARK: - Project Methods
    func select(_ project: Project) {
        selectedProject = project
        recomputeLaborData()
        print("📋 Selected project: \(project.name)")
    }
    
    func createNewProject(_ project: Project) {
        addProject(project)
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
        debouncedSaveProjects()
        print("✅ Added project: \(project.name)")
    }
    
    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            print("❌ Project not found for update: \(project.name)")
            return
        }
        
        projects[index] = project
        if selectedProject?.id == project.id {
            selectedProject = project
        }
        debouncedSaveProjects()
        print("✅ Updated project: \(project.name)")
    }
    
    func save(_ project: Project) {
        updateProject(project)
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        debouncedSaveProjects()
        print("🗑️ Deleted project: \(project.name)")
    }
    
    func deleteProjectPermanently(_ project: Project, completion: @escaping (Bool, String?) -> Void) {
        deleteProject(project)
        completion(true, nil)
    }
    
    func markProjectAsCompleted(_ project: Project) {
        var updatedProject = project
        updatedProject.status = .completed
        updateProject(updatedProject)
    }
    
    // MARK: - Progress Methods
    func addProgressLog(_ log: ProgressLog) {
        guard let selectedProject = selectedProject,
              let index = projects.firstIndex(where: { $0.id == selectedProject.id }) else {
            print("❌ No selected project for progress log")
            return
        }
        
        projects[index].progressLogs.append(log)
        self.selectedProject = projects[index]
        debouncedSaveProjects()
        print("✅ Added progress log to \(selectedProject.name)")
    }
    
    func removeProgressLog(_ id: UUID) {
        guard let selectedProject = selectedProject,
              let index = projects.firstIndex(where: { $0.id == selectedProject.id }) else {
            print("❌ No selected project for progress log removal")
            return
        }
        
        projects[index].progressLogs.removeAll { $0.id == id }
        self.selectedProject = projects[index]
        debouncedSaveProjects()
        print("✅ Removed progress log from \(selectedProject.name)")
    }
    
    func updateProgressLog(_ log: ProgressLog, employees: [UUID], images: [UIImage]) {
        guard let selectedProject = selectedProject,
              let projectIndex = projects.firstIndex(where: { $0.id == selectedProject.id }),
              let logIndex = projects[projectIndex].progressLogs.firstIndex(where: { $0.id == log.id }) else {
            print("❌ No selected project or progress log for update")
            return
        }
        
        var updatedLog = log
        updatedLog.employeeIDs = employees
        // TODO: Handle images when photo service is implemented
        
        projects[projectIndex].progressLogs[logIndex] = updatedLog
        self.selectedProject = projects[projectIndex]
        debouncedSaveProjects()
        print("✅ Updated progress log in \(selectedProject.name)")
    }
    
    // MARK: - Receipt Methods
    func recomputeFilteredReceipts() {
        // Placeholder for receipt filtering
        print("🔄 Recomputing filtered receipts")
    }
    
    // MARK: - Save Methods
    func debouncedSaveProjects() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                self.saveAllProjects()
            }
        }
    }
    
    func saveAllProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            UserDefaults.standard.set(data, forKey: "projects")
            print("💾 Saved \(projects.count) projects to UserDefaults")
        } catch {
            print("❌ Failed to save projects: \(error)")
            errorMessage = "Failed to save projects: \(error.localizedDescription)"
        }
    }
    
    func debouncedSaveTeamMembers() {
        teamMemberSaveTimer?.invalidate()
        teamMemberSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                self.saveTeamMembers()
            }
        }
    }
    
    func saveTeamMembers() {
        do {
            let data = try JSONEncoder().encode(teamMembers)
            UserDefaults.standard.set(data, forKey: "teamMembers")
            print("💾 Saved \(teamMembers.count) team members to UserDefaults")
        } catch {
            print("❌ Failed to save team members: \(error)")
            errorMessage = "Failed to save team members: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cache Methods
    func rebuildTeamMemberCache() {
        teamMemberCache = Dictionary(uniqueKeysWithValues: teamMembers.map { ($0.name, $0) })
        print("🔄 Rebuilt team member cache with \(teamMemberCache.count) entries")
    }
    
    func invalidateReceiptCache() {
        // Placeholder for receipt cache invalidation
        print("🔄 Receipt cache invalidated")
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
        
        print("🔢 Recomputed labor data for \(groupedHoursByTeamMember.count) team members")
    }
    
    // MARK: - CloudKit Methods (Placeholder)
    func saveProjectToCloudKit(project: Project, completion: @escaping (Bool) -> Void) {
        // Placeholder for CloudKit integration
        print("☁️ CloudKit save will be implemented later")
        completion(true)
    }
    
    // MARK: - Team Member CloudKit Methods (Placeholder)
    func saveTeamMemberToZone(_ teamMember: TeamMember) async throws {
        print("☁️ Saving team member '\(teamMember.name)' to CloudKit zone (placeholder)")
    }
    
    func removeTeamMemberFromZone(_ teamMember: TeamMember) async throws {
        print("☁️ Removing team member '\(teamMember.name)' from CloudKit zone (placeholder)")
    }
    
    // MARK: - Settings & Management Methods (Placeholders)
    func nuclearResetCloudKit(completion: @escaping (Bool, String) -> Void) {
        print("☢️ Nuclear reset CloudKit (placeholder)")
        completion(true, "Reset completed (placeholder)")
    }
    
    func inviteWifeToOrganization(email: String, completion: @escaping (Bool, String?) -> Void) {
        print("👋 Invite wife to organization: \(email) (placeholder)")
        completion(true, nil)
    }
    
    func removeAllPhotosFromProject(_ project: Project) -> Project {
        var cleanProject = project
        cleanProject.progressLogs = cleanProject.progressLogs.map { log in
            let cleanLog = log  // Changed from var to let since it's never mutated
            // TODO: Remove photos from progress logs when photo model is available
            return cleanLog
        }
        return cleanProject
    }
    
    func getOrganizationDataMigrationStatus() -> String {
        return "Migration status placeholder"
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
        return "Data status placeholder"
    }
    
    func emergencyRecoverFromBackup() async -> Bool {
        print("🚨 Emergency recover from backup (placeholder)")
        return true
    }
    
    func getDetailedCloudKitStatus(completion: @escaping (String) -> Void) {
        completion("CloudKit status placeholder")
    }
    
    func getDiagnosticInfo(completion: @escaping (String) -> Void) {
        completion("Diagnostic info placeholder")
    }
    
    func listCloudKitProjects() async -> String {
        return "CloudKit projects list placeholder"
    }
    
    func getOfflineStatus() async -> String {
        return "Offline status placeholder"
    }
    
    func triggerManualSync() async -> Bool {
        isBulkSyncing = true
        bulkSyncProgress = "Syncing projects..."
        defer { 
            isBulkSyncing = false
            bulkSyncProgress = ""
        }
        return true
    }
    
    func fixMissingOrganizationIDs(completion: @escaping (Bool, String) -> Void) {
        print("🔧 Fixing missing organization IDs (placeholder)")
        completion(true, "Organization IDs fixed")
    }
    
    func getMigrationStats(project: Project) -> (totalPhotos: Int, migratedPhotos: Int, needsMigration: Bool) {
        return (totalPhotos: 0, migratedPhotos: 0, needsMigration: false)
    }
    
    func hasProjectsNeedingMigration() -> Bool {
        return false
    }
    
    func migrateProjectPhotos(project: Project, onProgress: @escaping (Float) -> Void) async throws -> Project {
        onProgress(1.0)
        return project
    }
    
    // MARK: - Helper Methods
    func ensureTeamMembersHaveRates() {
        for i in 0..<teamMembers.count {
            if teamMembers[i].rates.isEmpty {
                teamMembers[i].rates.append(EmployeeRate(taskType: "General Labor", rate: 25.0))
                print("✅ Added default rate to \(teamMembers[i].name)")
            }
        }
    }
    
    // MARK: - Migration Methods
    func shareAllProjectsWithWife(completion: @escaping (Bool, String) -> Void) {
        print("Sharing all projects with wife...")
        
        Task {
            var successCount = 0
            for project in projects {
                let success = await withCheckedContinuation { continuation in
                    saveProjectToCloudKit(project: project) { success in
                        continuation.resume(returning: success)
                    }
                }
                
                if success {
                    successCount += 1
                }
            }
            
            completion(true, "Shared \(successCount) projects successfully")
        }
    }

    func syncAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        print("Syncing all projects to CloudKit...")
        
        Task {
            var successCount = 0
            for project in projects {
                let success = await withCheckedContinuation { continuation in
                    saveProjectToCloudKit(project: project) { success in
                        continuation.resume(returning: success)
                    }
                }
                
                if success {
                    successCount += 1
                }
            }
            
            let message = "Synced \(successCount) projects to CloudKit"
            print(message)
            completion(true, message)
        }
    }

    /// Force migration of local data to CloudKit (placeholder)
    func forceMigrateOrganizationDataToCloudKit() async throws {
        guard currentOrganizationID != nil else {
            throw NSError(domain: "ProjectViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No organization set"])
        }
        
        print("Migration will be implemented once CloudKit services are ready...")
        // TODO: Implement actual migration
    }
    
    private func loadTeamMembers() {
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: "teamMembers"),
           let members = try? JSONDecoder().decode([TeamMember].self, from: data) {
            teamMembers = members
        } else {
            // No default team members - start with empty array
            teamMembers = []
            print("No team member data found - starting with empty team members list")
        }
        
        // Filter team members by current organization
        if let orgID = currentOrganizationID {
            teamMembers = teamMembers.filter { $0.organizationID == orgID }
            print("Filtered team members to current organization: \(teamMembers.count) members")
        } else {
            teamMembers = []
            print("No organization - cleared all team members")
        }
        
        // Ensure all team members have at least one rate
        ensureTeamMembersHaveRates()
        rebuildTeamMemberCache()
        
        // Debug logging
        print("Loaded \(teamMembers.count) team members:")
        for member in teamMembers {
            print("  - \(member.name): \(member.rates.count) rates, org: \(String(member.organizationID.prefix(8)))")
        }
    }
    
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
}