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
import OSLog

extension Logger {
    static let project = Logger(subsystem: "com.RheirHome.RHEIR", category: "project")
}

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
    @Published var intelligenceSnapshotVersion = UUID()
    
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
    private var receiptVendorCache: [String: Vendor] = [:]
    private var receiptPaymentMethodCache: [String: PaymentMethod] = [:]
    
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
    private let projectStore: ProjectStore
    private let projectRepository: ProjectRepository
    private let organizationProjectSyncStore: OrganizationProjectSyncStore
    private let projectAccessStore: ProjectAccessStore
    let receiptIntelligenceStore: ReceiptIntelligenceStore
    let receiptProjectStore: ReceiptProjectStore
    let laborStore: LaborStore
    let teamMemberStore: TeamMemberStore
    
    // Timers
    private var savingTimer: Timer?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private var lastUpdateTimestamp: Date?
    private let updateDebounceInterval: TimeInterval = 0.1 // 100ms debounce
    
    init(
        offlineDataManager: OfflineDataManager,
        projectStore: ProjectStore = ProjectStore(),
        projectRepository: ProjectRepository = CloudKitProjectRepository(),
        organizationProjectSyncStore: OrganizationProjectSyncStore? = nil,
        projectAccessStore: ProjectAccessStore = ProjectAccessStore(),
        receiptIntelligenceStore: ReceiptIntelligenceStore = ReceiptIntelligenceStore(),
        receiptProjectStore: ReceiptProjectStore = ReceiptProjectStore(),
        laborStore: LaborStore = LaborStore(),
        teamMemberStore: TeamMemberStore = TeamMemberStore()
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
        self.projectStore = projectStore
        self.projectRepository = projectRepository
        self.organizationProjectSyncStore = organizationProjectSyncStore
            ?? OrganizationProjectSyncStore(
                projectStore: projectStore,
                projectRepository: projectRepository
            )
        self.projectAccessStore = projectAccessStore
        self.receiptIntelligenceStore = receiptIntelligenceStore
        self.receiptProjectStore = receiptProjectStore
        self.laborStore = laborStore
        self.teamMemberStore = teamMemberStore
        
        // TODO: Re-add service assignments in Phase 2
        // self.cloudKitService = cloudKitService
        // self.sharingService = sharingService
        // self.photoService = photoService
        // self.migrationService = migrationService
        // self.vendorService = vendorService
        // self.paymentMethodService = paymentMethodService
        // self.organizationKnowledgeService = organizationKnowledgeService
        
        setupDataObservation()

        Logger.project.info("Project view model initialized.")
    }
    
    // MARK: - PHASE 1 STUB METHODS - TODO: Implement in Phase 2
    
    func addTeamMemberToOrganization(_ teamMember: TeamMember) {
        let result = teamMemberStore.upsert(teamMember, into: teamMembers)

        guard result.action != .ignoredDuplicate else {
            Logger.teamMember.info(
                "Ignored duplicate team member add [org=\(teamMember.organizationID, privacy: .private(mask: .hash)) role=\(teamMember.role.displayName, privacy: .public)]"
            )
            return
        }

        teamMembers = result.members
        updateTeamMemberCaches()
        saveOrganizationSpecificBackup()

        Logger.teamMember.notice(
            "Updated team member directory [action=\(result.action.logLabel, privacy: .public) org=\(teamMember.organizationID, privacy: .private(mask: .hash)) rates=\(teamMember.rates.count, privacy: .public)]"
        )

        if isUsingCloudKitForOrganizationData {
            Task {
                do {
                    try await saveTeamMemberToCloudKit(teamMember)
                    Logger.teamMember.info(
                        "Synced team member to CloudKit [org=\(teamMember.organizationID, privacy: .private(mask: .hash))]"
                    )
                } catch {
                    Logger.teamMember.error(
                        "Failed to sync team member to CloudKit: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        Task {
            if result.action == .inserted {
                await addTeamMember(teamMember)
            } else {
                await updateTeamMember(teamMember)
            }
        }
    }
    
    /// Save team member to CloudKit using proper schema
    func saveTeamMemberToCloudKit(_ teamMember: TeamMember) async throws {
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
        Logger.teamMember.debug(
            "Saved team member with CloudKit schema mapping [org=\(teamMember.organizationID, privacy: .private(mask: .hash))]"
        )
    }
    
    func markProjectAsCompleted(_ project: Project) {
        Logger.project.notice("Marking project as completed.")
        
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
            Logger.project.notice("Completed project status update.")
        }
    }
    
    func syncAllProjectsToCloudKit(completion: @escaping (Bool, String) -> Void) {
        Logger.project.info("Starting CloudKit sync for all projects.")
        
        Task {
            let success = await saveAllProjectsToCloudKit()
            completion(success, success ? "Sync completed successfully" : "Sync failed")
        }
    }
    
    func organizationDidChange() async {
        Logger.project.info("Starting organization data synchronization.")
        
        guard let currentOrgID = currentOrganizationID else {
            Logger.project.notice("No organization selected; clearing organization-scoped state.")
            await MainActor.run {
                organizationProjects = []
                accessibleProjects = []
                teamMembers = []
                selectedProject = nil
            }
            return
        }
        
        Logger.project.notice(
            "Switching active organization [org=\(currentOrgID, privacy: .private(mask: .hash))]"
        )
        
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
            Logger.project.info(
                "Loaded CloudKit projects during organization switch [count=\(cloudKitProjects.count, privacy: .public)]"
            )
        } catch {
            Logger.project.error(
                "CloudKit load failed during organization switch: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        Logger.project.notice(
            "Completed organization switch [org=\(currentOrgID, privacy: .private(mask: .hash)) projects=\(self.organizationProjects.count, privacy: .public) teamMembers=\(self.teamMembers.count, privacy: .public) cloudKit=\(self.isUsingCloudKitForOrganizationData, privacy: .public)]"
        )
    }
    
    /// Load team members for a specific organization
    private func loadOrganizationTeamMembers(organizationID: String) async {
        Logger.teamMember.info(
            "Loading organization team members [org=\(organizationID, privacy: .private(mask: .hash))]"
        )

        let members = projectStore.loadTeamMembers(for: organizationID)

        guard !members.isEmpty else {
            Logger.teamMember.notice(
                "No stored team members found for organization [org=\(organizationID, privacy: .private(mask: .hash))]"
            )

            await MainActor.run {
                self.teamMembers = []
                self.updateTeamMemberCaches()
            }
            return
        }
        
        await MainActor.run {
            let verification = self.teamMemberStore.verify(members, for: organizationID)
            self.teamMembers = verification.members
            self.updateTeamMemberCaches()
            Logger.teamMember.notice(
                "Loaded verified team members [org=\(organizationID, privacy: .private(mask: .hash)) count=\(verification.members.count, privacy: .public) filtered=\(verification.filteredCount, privacy: .public)]"
            )
        }
    }
    
    func emergencyRecoverFromBackup() async -> Bool {
        Logger.project.notice("Starting emergency recovery flow.")
        
        guard let currentOrgID = currentOrganizationID else {
            Logger.project.error("Cannot run emergency recovery without an active organization.")
            return false
        }
        
        var recoveredProjects: [Project] = []
        var recoveredTeamMembers: [TeamMember] = []
        var recoverySuccess = false
        
        Logger.project.info("Emergency recovery: checking organization-scoped local store.")
        let locallyStoredProjects = projectStore.loadProjects(for: currentOrgID)
        let locallyStoredTeamMembers = projectStore.loadTeamMembers(for: currentOrgID)

        if !locallyStoredProjects.isEmpty {
            recoveredProjects.append(contentsOf: locallyStoredProjects)
            Logger.project.info(
                "Recovered projects from local store [count=\(locallyStoredProjects.count, privacy: .public)]"
            )
            recoverySuccess = true
        }

        if !locallyStoredTeamMembers.isEmpty {
            recoveredTeamMembers.append(contentsOf: locallyStoredTeamMembers)
            Logger.teamMember.info(
                "Recovered team members from local store [count=\(locallyStoredTeamMembers.count, privacy: .public)]"
            )
            recoverySuccess = true
        }
        
        if recoveredProjects.isEmpty && isUsingCloudKitForOrganizationData {
            Logger.project.info("Emergency recovery: attempting CloudKit project restore.")
            
            do {
                let cloudKitProjects = try await loadProjectsFromCloudKit()
                recoveredProjects.append(contentsOf: cloudKitProjects)
                Logger.project.info(
                    "Recovered projects from CloudKit [count=\(cloudKitProjects.count, privacy: .public)]"
                )
                recoverySuccess = true
            } catch {
                Logger.project.error(
                    "CloudKit recovery failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        
        if recoveredProjects.isEmpty {
            Logger.project.info("Emergency recovery: attempting offline fallback restore.")
            
            let offlineProjects = offlineDataManager.loadProjectsOffline()
            let orgSpecificProjects = offlineProjects.filter { $0.organizationID == currentOrgID }
            
            if !orgSpecificProjects.isEmpty {
                recoveredProjects.append(contentsOf: orgSpecificProjects)
                Logger.project.info(
                    "Recovered projects from offline fallback [count=\(orgSpecificProjects.count, privacy: .public)]"
                )
                recoverySuccess = true
            }
            
            let offlineTeamMembers = offlineDataManager.teamMembers
            let orgSpecificTeamMembers = offlineTeamMembers.filter { $0.organizationID == currentOrgID }
            
            if !orgSpecificTeamMembers.isEmpty {
                recoveredTeamMembers.append(contentsOf: orgSpecificTeamMembers)
                Logger.teamMember.info(
                    "Recovered team members from offline fallback [count=\(orgSpecificTeamMembers.count, privacy: .public)]"
                )
                recoverySuccess = true
            }
        }
        
        if recoverySuccess {
            await MainActor.run {
                Logger.project.info("Applying recovered project and team-member state.")

                var uniqueProjects: [Project] = []
                var seenProjectIDs: Set<UUID> = []
                
                for project in recoveredProjects {
                    if !seenProjectIDs.contains(project.id) {
                        uniqueProjects.append(project)
                        seenProjectIDs.insert(project.id)
                    }
                }
                
                // Merge with existing projects (recovered takes precedence)
                var mergedProjects = uniqueProjects
                for existingProject in organizationProjects {
                    if !seenProjectIDs.contains(existingProject.id) {
                        mergedProjects.append(existingProject)
                    }
                }
                
                organizationProjects = mergedProjects

                teamMembers = self.teamMemberStore.mergeRecovered(recoveredTeamMembers, with: teamMembers)
                updateTeamMemberCaches()
                updateOrganizationProjects()

                Logger.project.notice(
                    "Applied recovered state [projects=\(self.organizationProjects.count, privacy: .public) teamMembers=\(self.teamMembers.count, privacy: .public)]"
                )
            }
            
            saveOrganizationSpecificBackup()
            
            if isUsingCloudKitForOrganizationData {
                let saveSuccess = await saveAllProjectsToCloudKit()
                await saveTeamMembersToCloudKit()
                Logger.project.notice(
                    "Emergency recovery CloudKit backup completed [success=\(saveSuccess, privacy: .public)]"
                )
            }
            
            Logger.project.notice(
                "Emergency recovery completed [projects=\(recoveredProjects.count, privacy: .public) teamMembers=\(recoveredTeamMembers.count, privacy: .public)]"
            )
            
            return true
        } else {
            Logger.project.error("Emergency recovery could not restore any data.")
            return false
        }
    }
    
    func select(_ project: Project) {
        selectProject(project)
    }
    
    func invalidateReceiptCache() {
        Logger.project.info("Invalidating receipt intelligence caches.")
        
        // Clear internal caches
        receiptVendorCache.removeAll()
        receiptPaymentMethodCache.removeAll()
        
        // Clear team member caches as they might affect receipt processing
        updateTeamMemberCaches()

        Logger.project.debug("Receipt intelligence caches cleared.")
    }
    
    func recomputeFilteredReceipts() {
        Logger.receiptWorkflow.info("Starting receipt cache recomputation.")
        
        guard let currentOrgID = currentOrganizationID else {
            receiptVendorCache.removeAll()
            receiptPaymentMethodCache.removeAll()
            Logger.receiptWorkflow.warning("Cleared receipt caches because no organization is active.")
            return
        }
        
        receiptVendorCache.removeAll()
        receiptPaymentMethodCache.removeAll()
        
        let startTime = Date()
        var totalReceipts = 0
        var processedReceipts = 0
        var vendorCacheHits = 0
        var paymentMethodCacheHits = 0
        
        for project in organizationProjects {
            let normalizedProject = project.normalizedReceiptCopy
            totalReceipts += normalizedProject.receipts.count
            
            for receipt in normalizedProject.receipts {
                processedReceipts += 1
                
                let vendor = vendorService.findOrCreateVendor(name: receipt.vendor)
                receiptVendorCache[receipt.vendor] = vendor
                vendorCacheHits += 1
                
                let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(name: receipt.paymentMethod)
                receiptPaymentMethodCache[receipt.paymentMethod] = paymentMethod
                paymentMethodCacheHits += 1
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)

        Logger.receiptWorkflow.notice(
            "Completed receipt cache recomputation [org=\(currentOrgID, privacy: .private(mask: .hash)) projects=\(self.organizationProjects.count, privacy: .public) receipts=\(totalReceipts, privacy: .public) processed=\(processedReceipts, privacy: .public) vendorEntries=\(self.receiptVendorCache.count, privacy: .public) paymentEntries=\(self.receiptPaymentMethodCache.count, privacy: .public) vendorLookups=\(vendorCacheHits, privacy: .public) paymentLookups=\(paymentMethodCacheHits, privacy: .public) duration=\(String(format: "%.3f", processingTime), privacy: .public)s]"
        )
    }
    
    func debouncedSaveProjects() {
        Logger.project.debug("Scheduling debounced project save.")
        
        // Cancel any existing timer to prevent duplicate saves
        savingTimer?.invalidate()
        
        guard currentOrganizationID != nil else {
            Logger.project.warning("Skipped debounced save because no organization is selected.")
            return
        }
        
        guard !organizationProjects.isEmpty else {
            Logger.project.debug("Skipped debounced save because there are no organization projects.")
            return
        }
        
        // Set up debounced save timer (500ms delay)
        savingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                await self.performBatchedProjectSave()
            }
        }
        
        Logger.project.debug("Debounced save scheduled.")
    }
    
    /// Perform the actual batched save operation
    private func performBatchedProjectSave() async {
        guard let currentOrgID = currentOrganizationID else {
            Logger.project.error("Cannot perform batched save without an organization.")
            return
        }
        
        guard !isBulkSyncing else {
            Logger.project.warning("Skipped batched save because bulk sync is already in progress.")
            return
        }
        
        let startTime = Date()
        let projectsToSave = organizationProjects
        
        Logger.project.notice(
            "Starting batched project save [org=\(currentOrgID, privacy: .private(mask: .hash)) projects=\(projectsToSave.count, privacy: .public)]"
        )
        
        // Step 1: Save to local organization-specific storage
        saveOrganizationSpecificBackup()
        
        // Step 2: Save to OfflineDataManager for cross-organization sync
        for project in projectsToSave {
            // Update the main projects array if this project exists there
            if let existingIndex = projects.firstIndex(where: { $0.id == project.id }) {
                projects[existingIndex] = project
            } else {
                // Add new project to main array
                projects.append(project)
            }
            
            // Update in OfflineDataManager
            offlineDataManager.updateProject(project)
        }
        
        // Step 3: Save to CloudKit if enabled (with error handling)
        var cloudKitSuccess = false
        if isUsingCloudKitForOrganizationData {
            Logger.project.info(
                "Syncing projects to CloudKit during batched save [count=\(projectsToSave.count, privacy: .public)]"
            )
            cloudKitSuccess = await saveAllProjectsToCloudKit()
        }
        
        // Step 4: Save team members if they've been updated
        if !teamMembers.isEmpty {
            let teamMembersToSave = teamMembers.filter { $0.organizationID == currentOrgID }
            if !teamMembersToSave.isEmpty {
                projectStore.saveTeamMembers(teamMembersToSave, for: currentOrgID)
                Logger.teamMember.info(
                    "Saved team members during batched save [org=\(currentOrgID, privacy: .private(mask: .hash)) count=\(teamMembersToSave.count, privacy: .public)]"
                )
                
                if isUsingCloudKitForOrganizationData {
                    await saveTeamMembersToCloudKit()
                }
            }
        }
        
        let saveTime = Date().timeIntervalSince(startTime)
        
        Logger.project.notice(
            "Completed batched project save [org=\(currentOrgID, privacy: .private(mask: .hash)) projects=\(projectsToSave.count, privacy: .public) cloudKit=\(cloudKitSuccess, privacy: .public) teamMembers=\(self.teamMembers.filter { $0.organizationID == currentOrgID }.count, privacy: .public) duration=\(String(format: "%.3f", saveTime), privacy: .public)s]"
        )
        
        // Clean up timer
        savingTimer?.invalidate()
        savingTimer = nil
    }
    
    // MARK: - Data Initialization
    
    func loadProjects() async {
        Logger.project.info("Loading projects from organization-scoped storage.")
        isDataLoading = true
        
        if let orgID = currentOrganizationID {
            // PHASE 2: Load from both CloudKit and local storage for persistence
            await loadOrganizationSpecificProjects(organizationID: orgID)
            
            // Try to load from CloudKit if available
            do {
                let cloudKitProjects = try await loadProjectsFromCloudKit()
                await MainActor.run {
                    mergeCloudKitProjects(cloudKitProjects)
                }
                Logger.project.info(
                    "Loaded CloudKit projects during refresh [count=\(cloudKitProjects.count, privacy: .public)]"
                )
            } catch {
                Logger.project.error(
                    "CloudKit project load failed; using local data: \(error.localizedDescription, privacy: .public)"
                )
            }
        } else {
            let loadedProjects = offlineDataManager.loadProjectsOffline()
            
            await MainActor.run {
                organizationProjects = loadedProjects
                updateOrganizationProjects()
            }
        }
        
        await MainActor.run {
            isDataLoading = false
        }
        
        Logger.project.notice(
            "Completed project load [projects=\(self.organizationProjects.count, privacy: .public)]"
        )
    }
    
    /// Load projects from CloudKit using simple CloudKit approach
    private func loadProjectsFromCloudKit() async throws -> [Project] {
        guard let currentOrganizationID = currentOrganizationID else {
            return []
        }

        let projects = try await organizationProjectSyncStore.fetchProjectsFromCloudKit(for: currentOrganizationID)
        Logger.project.debug(
            "Fetched projects from CloudKit [org=\(currentOrganizationID, privacy: .private(mask: .hash)) count=\(projects.count, privacy: .public)]"
        )
        return projects
    }
    
    /// Merge CloudKit projects with local projects, giving CloudKit precedence
    private func mergeCloudKitProjects(_ cloudKitProjects: [Project]) {
        let mergeResult = organizationProjectSyncStore.mergeCloudKitProjects(
            cloudKitProjects,
            with: organizationProjects
        )

        organizationProjects = mergeResult.projects
        updateOrganizationProjects()

        Logger.project.debug(
            "Merged CloudKit and local projects [cloudKit=\(cloudKitProjects.count, privacy: .public) localFallback=\(mergeResult.localFallbackCount, privacy: .public)]"
        )
    }
    
    /// Simple CloudKit persistence using standard CloudKit APIs
    private func saveProjectToCloudKit(_ project: Project) async throws {
        guard let currentOrganizationID = currentOrganizationID else {
            throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No organization ID"])
        }

        try await organizationProjectSyncStore.saveProjectToCloudKit(
            project,
            organizationID: currentOrganizationID
        )
        Logger.project.debug(
            "Saved project to CloudKit [org=\(currentOrganizationID, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Save all projects to CloudKit for bulk sync using simple approach
    internal func saveAllProjectsToCloudKit() async -> Bool {
        guard !organizationProjects.isEmpty else {
            Logger.project.debug("Skipped CloudKit project sync because there are no organization projects.")
            return true
        }
        
        isBulkSyncing = true
        defer { isBulkSyncing = false }
        
        let projectsToSync = organizationProjects
        bulkSyncProgress = 0.0
        
        Logger.project.notice(
            "Starting CloudKit bulk sync [count=\(projectsToSync.count, privacy: .public)]"
        )
        
        var successCount = 0
        
        for (index, project) in projectsToSync.enumerated() {
            do {
                try await saveProjectToCloudKit(project)
                successCount += 1
                bulkSyncProgress = Double(index + 1) / Double(projectsToSync.count)
                Logger.project.debug(
                    "Synced project during bulk CloudKit save [index=\(index + 1, privacy: .public) total=\(projectsToSync.count, privacy: .public)]"
                )
            } catch {
                Logger.project.error(
                    "Failed project CloudKit sync: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        
        bulkSyncProgress = 1.0
        Logger.project.notice(
            "Completed CloudKit bulk sync [saved=\(successCount, privacy: .public) total=\(projectsToSync.count, privacy: .public)]"
        )
        
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
        let previousOrganizationID = currentOrganizationID
        self.currentOrganization = organization
        self.currentOrganizationRole = role
        if let org = organization {
            self.currentOrganizationID = org.id
            Logger.project.notice(
                "Set active organization [org=\(org.id, privacy: .private(mask: .hash))]"
            )
            self.isUsingCloudKitForOrganizationData = true
        } else {
            self.currentOrganizationID = nil
            self.isUsingCloudKitForOrganizationData = false
            Logger.project.notice("Cleared active organization.")
        }

        if previousOrganizationID != currentOrganizationID,
           selectedProject?.organizationID != currentOrganizationID {
            selectedProject = nil
        }
        
        updateOrganizationProjects()
        
        if let orgID = self.currentOrganizationID {
            Task {
                await loadOrganizationSpecificProjects(organizationID: orgID)
                await MainActor.run {
                    updateOrganizationProjects()
                }
            }
        }
    }
    
    private func updateOrganizationProjects() {
        let now = Date()
        if let lastUpdate = lastUpdateTimestamp,
           now.timeIntervalSince(lastUpdate) < updateDebounceInterval {
            Logger.project.debug("Skipped redundant organization project refresh because of debounce.")
            return
        }
        lastUpdateTimestamp = now

        let previousOrganizationProjectIDs = Set(organizationProjects.map(\.id))
        let previousAccessibleProjectIDs = Set(accessibleProjects.map(\.id))
        let previousOrganizationCount = organizationProjects.count

        let refreshResult = organizationProjectSyncStore.refreshedProjects(
            allProjects: projects,
            cachedOrganizationProjects: organizationProjects,
            organizationID: currentOrganizationID
        )
        let accessState = projectAccessStore.unrestrictedState(
            organizationProjects: refreshResult.organizationProjects,
            selectedProject: selectedProject
        )

        let newOrganizationProjectIDs = Set(refreshResult.organizationProjects.map(\.id))
        let newAccessibleProjectIDs = Set(accessState.accessibleProjects.map(\.id))
        let hasChanged =
            previousOrganizationCount != refreshResult.organizationProjects.count
            || previousOrganizationProjectIDs != newOrganizationProjectIDs
            || accessibleProjects.count != accessState.accessibleProjects.count
            || previousAccessibleProjectIDs != newAccessibleProjectIDs
            || selectedProject?.id != accessState.selectedProject?.id

        guard hasChanged else {
            Logger.project.debug(
                "Organization project list unchanged [count=\(self.organizationProjects.count, privacy: .public)]"
            )
            return
        }

        if let currentOrgID = currentOrganizationID {
            organizationProjects = refreshResult.organizationProjects
            accessibleProjects = accessState.accessibleProjects
            selectedProject = accessState.selectedProject

            if accessState.duplicateCount > 0 {
                Logger.project.warning(
                    "Normalized duplicate organization projects during refresh [org=\(currentOrgID, privacy: .private(mask: .hash)) removed=\(accessState.duplicateCount, privacy: .public)]"
                )
            }

            Logger.project.notice(
                "Updated organization project list [org=\(currentOrgID, privacy: .private(mask: .hash)) current=\(self.organizationProjects.count, privacy: .public) previous=\(previousOrganizationCount, privacy: .public)]"
            )

            #if DEBUG
            Logger.project.debug("Organization project refresh completed with debug tracing enabled.")
            #endif
        } else {
            Logger.project.notice("Clearing organization-scoped projects because no organization is active.")
            organizationProjects = refreshResult.organizationProjects
            accessibleProjects = accessState.accessibleProjects
            selectedProject = accessState.selectedProject
        }
    }
    
    internal func updateAccessibleProjects() {
        let previousCount = accessibleProjects.count
        let previousSelectedProjectID = selectedProject?.id
        let accessState = projectAccessStore.unrestrictedState(
            organizationProjects: organizationProjects,
            selectedProject: selectedProject
        )
        let newAccessibleProjects = accessState.accessibleProjects
        let newAccessibleProjectIDs = Set(newAccessibleProjects.map(\.id))
        let previousAccessibleProjectIDs = Set(accessibleProjects.map(\.id))

        let hasChanged = newAccessibleProjects.count != previousCount
            || newAccessibleProjectIDs != previousAccessibleProjectIDs
            || previousSelectedProjectID != accessState.selectedProject?.id
        
        if hasChanged {
            accessibleProjects = newAccessibleProjects
            selectedProject = accessState.selectedProject

            Logger.project.notice(
                "Updated accessible projects [current=\(self.accessibleProjects.count, privacy: .public) previous=\(previousCount, privacy: .public)]"
            )

            if accessState.duplicateCount > 0 {
                Logger.project.warning(
                    "Normalized duplicate accessible projects [removed=\(accessState.duplicateCount, privacy: .public)]"
                )
            }

            if previousSelectedProjectID != nil, accessState.selectedProject == nil {
                Logger.project.notice(
                    "Deselected project because it is no longer accessible."
                )
            }
        } else {
            Logger.project.debug(
                "Accessible project list unchanged [count=\(self.accessibleProjects.count, privacy: .public)]"
            )
        }
    }
    
    // MARK: - Project Management
    
    func createNewProject(project: Project) async throws {
        guard let orgID = currentOrganizationID else {
            Logger.project.error("Cannot create a project without an active organization.")
            throw NSError(domain: "RHEIR", code: -1, userInfo: [NSLocalizedDescriptionKey: "No organization selected"])
        }
        
        var secureProject = project
        secureProject.organizationID = orgID
        
        await MainActor.run {
            organizationProjects.append(secureProject)
            projects.append(secureProject)
            selectedProject = secureProject
            updateAccessibleProjects()
        }
        
        saveOrganizationSpecificBackup()
        
        await MainActor.run {
            offlineDataManager.addProject(secureProject)
        }
        
        do {
            try await saveProjectToCloudKit(secureProject)
            Logger.project.info("Created project and saved it to CloudKit.")
        } catch {
            Logger.project.error(
                "Created project locally but failed CloudKit save: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        Logger.project.notice(
            "Created new project [org=\(orgID, privacy: .private(mask: .hash))]"
        )
    }
    
    func addProject(_ project: Project) async {
        guard let orgID = currentOrganizationID else {
            Logger.project.error("Cannot add a project without an active organization.")
            return
        }
        
        var secureProject = project
        secureProject.organizationID = orgID
        
        await MainActor.run {
            if !organizationProjects.contains(where: { $0.id == secureProject.id }) {
                organizationProjects.append(secureProject)
            }
        }
        
        saveOrganizationSpecificBackup()
        
        do {
            try await saveProjectToCloudKit(secureProject)
            Logger.project.info("Added project and saved it to CloudKit.")
        } catch {
            Logger.project.error(
                "Added project locally but failed CloudKit save: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        Logger.project.notice(
            "Added project to active organization [org=\(orgID, privacy: .private(mask: .hash))]"
        )
    }
    
    func updateProject(_ project: Project) async {
        guard let orgID = currentOrganizationID else {
            Logger.project.error("Cannot update a project without an active organization.")
            return
        }
        
        let duplicateReceiptCount = project.duplicateReceiptCount
        var secureProject = project.normalizedReceiptCopy
        secureProject.organizationID = orgID
        secureProject.lastModifiedDate = Date()

        if duplicateReceiptCount > 0 {
            Logger.project.warning(
                "Normalized duplicate receipt IDs before project save [project=\(secureProject.id.uuidString, privacy: .private(mask: .hash)) removed=\(duplicateReceiptCount, privacy: .public)]"
            )
        }
        
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
        
        saveOrganizationSpecificBackup()
        
        do {
            try await saveProjectToCloudKit(secureProject)
            Logger.project.info("Updated project and synced it to CloudKit.")
        } catch {
            Logger.project.error(
                "Updated project locally but failed CloudKit update: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        Logger.project.notice("Updated project.")
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
        Logger.project.info(
            "Setting up CloudKit zone for organization [org=\(orgID.uuidString, privacy: .private(mask: .hash))]"
        )
        
        let orgIDString = orgID.uuidString
        currentOrganizationID = orgIDString
        
        isUsingCloudKitForOrganizationData = true
        zoneSetupError = nil

        zoneSetupError = await organizationProjectSyncStore.setupCloudKitZone(for: orgIDString)
        
        Logger.project.notice(
            "Finished CloudKit zone setup [org=\(orgIDString, privacy: .private(mask: .hash))]"
        )
    }
    
    func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        Logger.project.info(
            "Setting up CloudKit zone for organization [org=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
        currentOrganizationID = organizationID
        isUsingCloudKitForOrganizationData = true
        zoneSetupError = nil

        zoneSetupError = await organizationProjectSyncStore.setupCloudKitZone(for: organizationID)
        
        Logger.project.notice(
            "Finished CloudKit zone setup [org=\(organizationID, privacy: .private(mask: .hash))]"
        )
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
        let caches = teamMemberStore.buildCaches(from: teamMembers)
        teamMembersCache = caches.byID
        teamMemberNameCache = caches.byName
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
        Logger.receiptWorkflow.info(
            "Adding receipt to project [project=\(projectID.uuidString, privacy: .private(mask: .hash))]"
        )

        guard let resolution = receiptProjectStore.resolveProject(
            projectID: projectID,
            organizationProjects: organizationProjects,
            allProjects: projects,
            currentOrganizationID: currentOrganizationID
        ) else {
            Logger.receiptWorkflow.error(
                "Failed to resolve project for receipt add [project=\(projectID.uuidString, privacy: .private(mask: .hash)) orgProjects=\(self.organizationProjects.count, privacy: .public) allProjects=\(self.projects.count, privacy: .public)]"
            )
            return 
        }

        if resolution.resynchronizedFromAllProjects {
            Logger.receiptWorkflow.notice(
                "Resynchronized receipt target from all-projects into organization projects [project=\(projectID.uuidString, privacy: .private(mask: .hash))]"
            )
        }

        let duplicateReceiptCount = resolution.project.duplicateReceiptCount
        var updatedProject = resolution.project.upsertingReceipt(receipt)
        updatedProject.lastModifiedDate = Date()

        if duplicateReceiptCount > 0 {
            Logger.receiptWorkflow.warning(
                "Normalized duplicate receipt IDs before receipt add [project=\(projectID.uuidString, privacy: .private(mask: .hash)) removed=\(duplicateReceiptCount, privacy: .public)]"
            )
        }

        await MainActor.run {
            receiptProjectStore.synchronize(
                updatedProject,
                resolution: resolution,
                organizationProjects: &organizationProjects,
                allProjects: &projects
            )

            if self.selectedProject?.id == projectID {
                self.selectedProject = updatedProject
                Logger.receiptWorkflow.debug("Updated selected project after receipt add.")
            }
        }

        saveOrganizationSpecificBackup()

        do {
            try await saveProjectToCloudKit(updatedProject)
            Logger.receiptWorkflow.info(
                "Saved receipt-bearing project to CloudKit [storage=\(resolution.storage.logLabel, privacy: .public)]"
            )
        } catch {
            Logger.receiptWorkflow.error(
                "Failed CloudKit save after receipt add: \(error.localizedDescription, privacy: .public)"
            )
        }

        Logger.receiptWorkflow.notice(
            "Completed receipt add [vendor=\(receipt.vendor, privacy: .private(mask: .hash)) amount=\(receipt.amount, privacy: .public) storage=\(resolution.storage.logLabel, privacy: .public) receiptCount=\(updatedProject.receipts.count, privacy: .public)]"
        )
    }
    
    func updateReceipt(_ receipt: Receipt, in projectID: UUID) async {
        guard let projectIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) else { return }
        
        let updatedProject = organizationProjects[projectIndex]
        if updatedProject.receipts.contains(where: { $0.id == receipt.id }) {
            let normalizedProject = updatedProject.upsertingReceipt(receipt)
            await updateProject(normalizedProject)
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
        Logger.teamMember.info("Starting team-member CloudKit sync.")
        
        guard !teamMembers.isEmpty else {
            Logger.teamMember.debug("Skipped team-member CloudKit sync because there are no members.")
            return
        }
        
        guard let currentOrgID = currentOrganizationID else {
            Logger.teamMember.error("Cannot sync team members without an active organization.")
            return
        }
        
        let teamMembersToSync = teamMembers.filter { $0.organizationID == currentOrgID }
        Logger.teamMember.notice(
            "Syncing team members to CloudKit [org=\(currentOrgID, privacy: .private(mask: .hash)) count=\(teamMembersToSync.count, privacy: .public)]"
        )
        
        var successCount = 0
        
        for teamMember in teamMembersToSync {
            do {
                try await saveTeamMemberToCloudKit(teamMember)
                successCount += 1
                Logger.teamMember.debug("Synced team member during CloudKit batch.")
            } catch {
                Logger.teamMember.error(
                    "Failed team-member CloudKit sync: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        
        projectStore.saveTeamMembers(teamMembersToSync, for: currentOrgID)
        Logger.teamMember.notice(
            "Completed team-member CloudKit sync [saved=\(successCount, privacy: .public) total=\(teamMembersToSync.count, privacy: .public)]"
        )
    }
    
    // MARK: - PHASE 2A: UUID/String Organization ID Compatibility
    
    func organizationDidChange(_ orgID: String?) async {
        await organizationDidChange()
    }
    
    func organizationDidChange(_ orgID: UUID) async {
        await organizationDidChange()
    }
    
    // MARK: - Role Management
    
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: UUID) {
        Logger.project.info(
            "Setting user role [role=\(role.displayName, privacy: .public) org=\(organizationID.uuidString, privacy: .private(mask: .hash))]"
        )
        
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
        
        currentOrganizationRole = teamMemberRole
        
        let orgIDString = organizationID.uuidString
        if currentOrganizationID != orgIDString {
            Logger.project.warning(
                "Role update did not match active organization [targetOrg=\(orgIDString, privacy: .private(mask: .hash)) activeOrg=\(self.currentOrganizationID ?? "none", privacy: .private(mask: .hash))]"
            )
        }
        
        updateAccessibleProjects()
        
        Logger.project.notice(
            "Updated project role mapping [role=\(teamMemberRole.displayName, privacy: .public) org=\(orgIDString, privacy: .private(mask: .hash))]"
        )
    }
    
    func setCurrentUserRole(_ role: OrganizationRole, forOrganization organizationID: String) {
        if let uuid = UUID(uuidString: organizationID) {
            setCurrentUserRole(role, forOrganization: uuid)
        } else {
            Logger.project.error("Invalid organization identifier format for role update.")
        }
    }
    
    // MARK: - PHASE 2A: Missing Legacy Compatibility Methods
    
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
        guard let update = teamMemberStore.update(teamMember, in: teamMembers) else {
            Logger.teamMember.error("Failed to update team member because the record was not found.")
            return
        }

        let previousName = update.previousName ?? teamMember.name
        teamMembers = update.members
        updateTeamMemberCaches()
        saveOrganizationSpecificBackup()

        if previousName != teamMember.name {
            updateWorkHourTeamMemberNames(from: previousName, to: teamMember.name)
        }

        if isUsingCloudKitForOrganizationData {
            Task {
                do {
                    try await saveTeamMemberToCloudKit(teamMember)
                    Logger.teamMember.info("Updated team member in CloudKit.")
                } catch {
                    Logger.teamMember.error(
                        "Failed to update team member in CloudKit: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        Logger.teamMember.notice("Updated team member in organization directory.")

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
    
    // MARK: - CRITICAL FIX: Organization-Specific Data Storage (From Golden Backup)
    
    /// Save data using organization-specific keys to prevent data bleeding
    internal func saveOrganizationSpecificBackup() {
        guard let orgID = currentOrganizationID else {
            Logger.project.error("Cannot save organization backup without an active organization.")
            return
        }

        organizationProjectSyncStore.saveSnapshot(
            projects: organizationProjects,
            organization: currentOrganization,
            teamMembers: teamMembers,
            for: orgID
        )

        Logger.project.debug(
            "Saved organization snapshot [org=\(orgID, privacy: .private(mask: .hash)) projects=\(self.organizationProjects.count, privacy: .public) teamMembers=\(self.teamMembers.count, privacy: .public)]"
        )
    }
    
    /// Load projects using organization-specific keys
    private func loadOrganizationSpecificProjects(organizationID: String) async {
        Logger.project.info(
            "Loading organization snapshot [org=\(organizationID, privacy: .private(mask: .hash))]"
        )

        let loadResult = organizationProjectSyncStore.loadStoredProjects(for: organizationID)

        guard !loadResult.projects.isEmpty else {
            Logger.project.notice(
                "No organization snapshot projects found [org=\(organizationID, privacy: .private(mask: .hash))]"
            )

            await MainActor.run {
                self.organizationProjects = []
            }
            return 
        }
        
        await MainActor.run {
            if loadResult.filteredCount > 0 {
                Logger.project.warning(
                    "Filtered projects that did not match active organization [org=\(organizationID, privacy: .private(mask: .hash)) filtered=\(loadResult.filteredCount, privacy: .public)]"
                )
            }
            
            self.organizationProjects = loadResult.projects
            Logger.project.notice(
                "Loaded verified organization snapshot [org=\(organizationID, privacy: .private(mask: .hash)) count=\(loadResult.projects.count, privacy: .public)]"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    var bulkSyncProgressText: String {
        if isBulkSyncing {
            return "Syncing... \(Int(bulkSyncProgress * 100))%"
        }
        return ""
    }
    
    func selectProject(_ project: Project) {
        if let currentOrganizationID, project.organizationID != currentOrganizationID {
            Logger.project.warning("Ignored project selection outside the active organization.")
            return
        }
        selectedProject = project
        Logger.project.info("Updated selected project.")
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
        Logger.project.debug(
            "Organization debug state [orgName=\(self.currentOrganization?.name ?? "None", privacy: .private(mask: .hash)) org=\(self.currentOrganizationID ?? "None", privacy: .private(mask: .hash)) projects=\(self.projects.count, privacy: .public) orgProjects=\(self.organizationProjects.count, privacy: .public) accessible=\(self.accessibleProjects.count, privacy: .public) teamMembers=\(self.teamMembers.count, privacy: .public) cloudKit=\(self.isUsingCloudKitForOrganizationData, privacy: .public) loading=\(self.isDataLoading, privacy: .public)]"
        )
        
        if let error = zoneSetupError {
            Logger.project.error("Zone setup error: \(error.localizedDescription, privacy: .public)")
        }
        
        if projects.count != organizationProjects.count {
            Logger.project.warning(
                "Project count mismatch [allProjects=\(self.projects.count, privacy: .public) orgProjects=\(self.organizationProjects.count, privacy: .public)]"
            )
        }
    }
    
    func setUserProjectAssignments(_ projectIDs: [String]) {
        guard let currentOrgID = currentOrganizationID else {
            Logger.project.error("Cannot set project assignments without an active organization.")
            return
        }

        organizationProjectSyncStore.saveProjectAssignmentsLocally(projectIDs, organizationID: currentOrgID)
        Logger.project.debug(
            "Saved project assignment snapshot [org=\(currentOrgID, privacy: .private(mask: .hash)) count=\(projectIDs.count, privacy: .public)]"
        )

        let previousSelectedProjectID = selectedProject?.id
        let assignmentResult = projectAccessStore.assignmentState(
            projectIDs: projectIDs,
            organizationProjects: organizationProjects,
            selectedProject: selectedProject
        )

        if assignmentResult.appliesRestrictions {
            if assignmentResult.restrictedCount > 0 {
                Logger.project.notice(
                    "Applied restricted project access [allowed=\(assignmentResult.accessState.accessibleProjects.count, privacy: .public) restricted=\(assignmentResult.restrictedCount, privacy: .public)]"
                )
            }
        } else {
            Logger.project.notice(
                "Applied unrestricted project access [orgProjects=\(self.organizationProjects.count, privacy: .public)]"
            )
        }

        accessibleProjects = assignmentResult.accessState.accessibleProjects

        if assignmentResult.accessState.duplicateCount > 0 {
            Logger.project.warning(
                "Normalized duplicate projects while applying access restrictions [removed=\(assignmentResult.accessState.duplicateCount, privacy: .public)]"
            )
        }

        if previousSelectedProjectID != nil, assignmentResult.accessState.selectedProject == nil {
            selectedProject = nil
            Logger.project.notice("Deselected project because it is no longer accessible.")
        } else {
            selectedProject = assignmentResult.accessState.selectedProject
        }
        
        if isUsingCloudKitForOrganizationData {
            Task {
                await saveProjectAssignmentsToCloudKit(projectIDs)
            }
        }

        Logger.project.notice(
            "Configured project access control [orgProjects=\(self.organizationProjects.count, privacy: .public) accessible=\(self.accessibleProjects.count, privacy: .public) restricted=\(assignmentResult.appliesRestrictions, privacy: .public)]"
        )
    }
    
    /// Save project assignments to CloudKit for enterprise synchronization
    private func saveProjectAssignmentsToCloudKit(_ projectIDs: [String]) async {
        guard let currentOrgID = currentOrganizationID else { return }
        
        do {
            try await organizationProjectSyncStore.saveProjectAssignmentsToCloudKit(
                projectIDs,
                organizationID: currentOrgID
            )
            Logger.project.info(
                "Synced project assignments to CloudKit [org=\(currentOrgID, privacy: .private(mask: .hash)) count=\(projectIDs.count, privacy: .public)]"
            )
        } catch {
            Logger.project.error(
                "Failed to sync project assignments to CloudKit: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Load project assignments from CloudKit
    private func loadProjectAssignmentsFromCloudKit() async -> [String] {
        guard let currentOrgID = currentOrganizationID else { return [] }

        let assignments = await organizationProjectSyncStore.loadProjectAssignmentsFromCloudKit(
            organizationID: currentOrgID
        )
        if !assignments.isEmpty {
            Logger.project.debug(
                "Loaded project assignments from CloudKit [org=\(currentOrgID, privacy: .private(mask: .hash)) count=\(assignments.count, privacy: .public)]"
            )
        }
        return assignments
    }
}

extension Logger {
    static let projectSync = Logger(subsystem: "com.RheirHome.RHEIR", category: "projectSync")
}

struct OrganizationProjectLoadResult {
    let projects: [Project]
    let filteredCount: Int
}

struct OrganizationProjectRefreshResult {
    let organizationProjects: [Project]
    let accessibleProjects: [Project]
}

struct OrganizationProjectMergeResult {
    let projects: [Project]
    let localFallbackCount: Int
}

struct ProjectAccessState {
    let accessibleProjects: [Project]
    let selectedProject: Project?
    let duplicateCount: Int
}

struct ProjectAssignmentAccessState {
    let accessState: ProjectAccessState
    let restrictedCount: Int
    let appliesRestrictions: Bool
}

struct CompanyTeamBuckets {
    let active: [TeamMember]
    let betweenProjects: [TeamMember]
    let completed: [TeamMember]
    let inactive: [TeamMember]

    var appUsers: Int {
        active.filter(\.hasAppAccess).count
    }
}

struct CompanySummary {
    let totalMembers: Int
    let activeProjects: Int
    let cloudKitMembers: Int
    let currentProjects: Int
    let currentTeamMembers: Int
}

final class CompanyStore {
    func teamBuckets(teamMembers: [TeamMember], projects: [Project]) -> CompanyTeamBuckets {
        let active = teamMembers.filter { isTeamMemberActiveOnAnyProject($0, projects: projects) }
        let betweenProjects = teamMembers.filter { member in
            member.employmentStatus.canBeAssignedToProjects &&
            !isTeamMemberActiveOnAnyProject(member, projects: projects) &&
            !hasCompletedAllAssignedProjects(member, projects: projects) &&
            member.employmentStatus != .terminated &&
            member.employmentStatus != .suspended &&
            member.employmentStatus != .onLeave
        }
        let completed = teamMembers.filter { member in
            member.employmentStatus == .active &&
            !isTeamMemberActiveOnAnyProject(member, projects: projects) &&
            hasCompletedAllAssignedProjects(member, projects: projects)
        }
        let inactive = teamMembers.filter {
            $0.employmentStatus == .terminated ||
            $0.employmentStatus == .suspended ||
            $0.employmentStatus == .onLeave
        }

        return CompanyTeamBuckets(
            active: active,
            betweenProjects: betweenProjects,
            completed: completed,
            inactive: inactive
        )
    }

    func assignedProjects(for member: TeamMember, in projects: [Project]) -> [Project] {
        projects.filter { isTeamMemberAssigned(member, to: $0) }
    }

    func availableProjects(for member: TeamMember, in projects: [Project]) -> [Project] {
        projects.filter { project in
            project.status == .active &&
            !project.assignedTeamMemberIDs.contains(member.id.uuidString) &&
            !hasWorkedOnProject(member, project)
        }
    }

    func summary(organization: Organization, projects: [Project], teamMembers: [TeamMember]) -> CompanySummary {
        CompanySummary(
            totalMembers: teamMembers.count,
            activeProjects: projects.filter { $0.status == .active }.count,
            cloudKitMembers: organization.members.count + 1,
            currentProjects: projects.count,
            currentTeamMembers: teamMembers.count + 1
        )
    }

    private func isTeamMemberActiveOnAnyProject(_ member: TeamMember, projects: [Project]) -> Bool {
        projects.filter { $0.status == .active }.contains { isTeamMemberAssigned(member, to: $0) }
    }

    private func hasCompletedAllAssignedProjects(_ member: TeamMember, projects: [Project]) -> Bool {
        let assigned = assignedProjects(for: member, in: projects)
        guard !assigned.isEmpty else {
            return false
        }

        return assigned.allSatisfy { $0.status == .completed }
    }

    private func isTeamMemberAssigned(_ member: TeamMember, to project: Project) -> Bool {
        if project.assignedTeamMemberIDs.contains(member.id.uuidString) {
            return true
        }

        return hasWorkedOnProject(member, project)
    }

    private func hasWorkedOnProject(_ member: TeamMember, _ project: Project) -> Bool {
        let hasReceipts = project.receipts.contains { $0.teamMemberID == member.id }
        let hasProgress = project.progressReports.contains { $0.employeeIDs.contains(member.id) }
        let hasLoggedHours = project.loggedHours.contains {
            $0.employeeID == member.id || $0.employee.lowercased() == member.name.lowercased()
        }

        return hasReceipts || hasProgress || hasLoggedHours
    }
}

final class ProjectAccessStore {
    func unrestrictedState(
        organizationProjects: [Project],
        selectedProject: Project?
    ) -> ProjectAccessState {
        let normalizedProjects = normalizedProjects(from: organizationProjects)

        return ProjectAccessState(
            accessibleProjects: normalizedProjects,
            selectedProject: resolvedSelectedProject(
                selectedProject,
                accessibleProjects: normalizedProjects
            ),
            duplicateCount: organizationProjects.count - normalizedProjects.count
        )
    }

    func assignmentState(
        projectIDs: [String],
        organizationProjects: [Project],
        selectedProject: Project?
    ) -> ProjectAssignmentAccessState {
        let unrestrictedState = unrestrictedState(
            organizationProjects: organizationProjects,
            selectedProject: selectedProject
        )
        let assignedUUIDs = projectIDs.compactMap(UUID.init(uuidString:))
        let appliesRestrictions = !assignedUUIDs.isEmpty
        let accessibleProjects: [Project]

        if appliesRestrictions {
            accessibleProjects = unrestrictedState.accessibleProjects.filter { assignedUUIDs.contains($0.id) }
        } else {
            accessibleProjects = unrestrictedState.accessibleProjects
        }

        return ProjectAssignmentAccessState(
            accessState: ProjectAccessState(
                accessibleProjects: accessibleProjects,
                selectedProject: resolvedSelectedProject(
                    unrestrictedState.selectedProject,
                    accessibleProjects: accessibleProjects
                ),
                duplicateCount: unrestrictedState.duplicateCount
            ),
            restrictedCount: unrestrictedState.accessibleProjects.count - accessibleProjects.count,
            appliesRestrictions: appliesRestrictions
        )
    }

    private func resolvedSelectedProject(
        _ selectedProject: Project?,
        accessibleProjects: [Project]
    ) -> Project? {
        guard let selectedProject else {
            return nil
        }

        return accessibleProjects.contains(where: { $0.id == selectedProject.id })
            ? selectedProject
            : nil
    }

    private func normalizedProjects(from projects: [Project]) -> [Project] {
        var normalizedProjects: [Project] = []
        var seenIDs: Set<UUID> = []

        for project in projects where seenIDs.insert(project.id).inserted {
            normalizedProjects.append(project)
        }

        return normalizedProjects
    }
}

final class OrganizationProjectSyncStore {
    private let projectStore: ProjectStore
    private let projectRepository: ProjectRepository
    private let container: CKContainer

    init(
        projectStore: ProjectStore,
        projectRepository: ProjectRepository,
        container: CKContainer = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
    ) {
        self.projectStore = projectStore
        self.projectRepository = projectRepository
        self.container = container
    }

    func saveSnapshot(
        projects: [Project],
        organization: Organization?,
        teamMembers: [TeamMember],
        for organizationID: String
    ) {
        projectStore.saveSnapshot(
            projects: projects,
            organization: organization,
            teamMembers: teamMembers,
            for: organizationID
        )
    }

    func loadStoredProjects(for organizationID: String) -> OrganizationProjectLoadResult {
        let projects = projectStore.loadProjects(for: organizationID)
        let verifiedProjects = projects.filter { $0.organizationID == organizationID }

        return OrganizationProjectLoadResult(
            projects: verifiedProjects,
            filteredCount: projects.count - verifiedProjects.count
        )
    }

    func refreshedProjects(
        allProjects: [Project],
        cachedOrganizationProjects: [Project],
        organizationID: String?
    ) -> OrganizationProjectRefreshResult {
        guard let organizationID else {
            return OrganizationProjectRefreshResult(
                organizationProjects: [],
                accessibleProjects: []
            )
        }

        let uniqueProjects = uniqueOrganizationProjects(
            organizationID: organizationID,
            primary: allProjects,
            secondary: cachedOrganizationProjects
        )

        return OrganizationProjectRefreshResult(
            organizationProjects: uniqueProjects,
            accessibleProjects: uniqueProjects
        )
    }

    func mergeCloudKitProjects(_ cloudKitProjects: [Project], with localProjects: [Project]) -> OrganizationProjectMergeResult {
        var mergedProjects: [Project] = []
        var processedIDs: Set<UUID> = []

        for cloudProject in cloudKitProjects where processedIDs.insert(cloudProject.id).inserted {
            mergedProjects.append(cloudProject)
        }

        for localProject in localProjects where processedIDs.insert(localProject.id).inserted {
            mergedProjects.append(localProject)
        }

        return OrganizationProjectMergeResult(
            projects: mergedProjects,
            localFallbackCount: mergedProjects.count - cloudKitProjects.count
        )
    }

    func saveProjectAssignmentsLocally(_ projectIDs: [String], organizationID: String) {
        projectStore.saveProjectAssignments(projectIDs, for: organizationID)
    }

    func fetchProjectsFromCloudKit(for organizationID: String) async throws -> [Project] {
        try await projectRepository.fetchProjects(for: organizationID)
    }

    func saveProjectToCloudKit(_ project: Project, organizationID: String) async throws {
        try await projectRepository.saveProject(project, organizationID: organizationID)
    }

    func saveProjectAssignmentsToCloudKit(_ projectIDs: [String], organizationID: String) async throws {
        try await projectRepository.saveProjectAssignments(projectIDs, organizationID: organizationID)
    }

    func loadProjectAssignmentsFromCloudKit(organizationID: String) async -> [String] {
        await projectRepository.loadProjectAssignments(organizationID: organizationID)
    }

    func setupCloudKitZone(for organizationID: String) async -> Error? {
        do {
            let privateDatabase = container.privateCloudDatabase
            let zoneID = CKRecordZone.ID(
                zoneName: "Org-\(organizationID)",
                ownerName: CKCurrentUserDefaultName
            )
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await privateDatabase.save(zone)
            Logger.projectSync.notice(
                "Created CloudKit zone [zone=\(zoneID.zoneName, privacy: .private(mask: .hash))]"
            )
            return nil
        } catch let error as CKError where error.code == .serverRecordChanged {
            Logger.projectSync.debug(
                "CloudKit zone already exists [org=\(organizationID, privacy: .private(mask: .hash))]"
            )
            return nil
        } catch {
            Logger.projectSync.error(
                "Failed to create CloudKit zone: \(error.localizedDescription, privacy: .public)"
            )
            return error
        }
    }

    private func uniqueOrganizationProjects(
        organizationID: String,
        primary: [Project],
        secondary: [Project]
    ) -> [Project] {
        var uniqueProjects: [Project] = []
        var projectIDs: Set<UUID> = []

        for project in primary where project.organizationID == organizationID {
            if projectIDs.insert(project.id).inserted {
                uniqueProjects.append(project)
            }
        }

        for project in secondary where project.organizationID == organizationID {
            if projectIDs.insert(project.id).inserted {
                uniqueProjects.append(project)
            }
        }

        return uniqueProjects
    }
}

extension Logger {
    static let projectStore = Logger(subsystem: "com.RheirHome.RHEIR", category: "projectStore")
}

final class ProjectStore {
    private enum Key {
        static let projectsPrefix = "projects_"
        static let organizationPrefix = "organization_"
        static let teamMembersPrefix = "team_members_"
        static let projectAssignmentsPrefix = "project_assignments_"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadProjects(for organizationID: String) -> [Project] {
        load([Project].self, forKey: Key.projectsPrefix + organizationID, fallback: []).filter {
            $0.organizationID == organizationID
        }
    }

    func saveProjects(_ projects: [Project], for organizationID: String) {
        let scopedProjects = projects.filter { $0.organizationID == organizationID }
        let strippedInlineReceiptImages = scopedProjects.reduce(0) { count, project in
            count + project.inlineReceiptImageCount
        }
        let persistenceSafeProjects = scopedProjects.map(\.persistenceSafeCopy)

        save(persistenceSafeProjects, forKey: Key.projectsPrefix + organizationID)

        if strippedInlineReceiptImages > 0 {
            Logger.projectStore.debug(
                "Stripped inline receipt images from stored project snapshot [organization=\(organizationID, privacy: .private(mask: .hash)) images=\(strippedInlineReceiptImages, privacy: .public)]"
            )
        }

        Logger.projectStore.debug(
            "Saved \(scopedProjects.count, privacy: .public) projects for organization \(organizationID, privacy: .private(mask: .hash))"
        )
    }

    func loadOrganization(for organizationID: String) -> Organization? {
        loadOptional(Organization.self, forKey: Key.organizationPrefix + organizationID)
    }

    func saveOrganization(_ organization: Organization?, for organizationID: String) {
        guard let organization else {
            userDefaults.removeObject(forKey: Key.organizationPrefix + organizationID)
            return
        }

        save(organization, forKey: Key.organizationPrefix + organizationID)
    }

    func loadTeamMembers(for organizationID: String) -> [TeamMember] {
        load([TeamMember].self, forKey: Key.teamMembersPrefix + organizationID, fallback: []).filter {
            $0.organizationID == organizationID
        }
    }

    func saveTeamMembers(_ teamMembers: [TeamMember], for organizationID: String) {
        let scopedTeamMembers = teamMembers.filter { $0.organizationID == organizationID }
        save(scopedTeamMembers, forKey: Key.teamMembersPrefix + organizationID)
        Logger.projectStore.debug(
            "Saved \(scopedTeamMembers.count, privacy: .public) team members for organization \(organizationID, privacy: .private(mask: .hash))"
        )
    }

    func loadProjectAssignments(for organizationID: String) -> [String] {
        load([String].self, forKey: Key.projectAssignmentsPrefix + organizationID, fallback: [])
    }

    func saveProjectAssignments(_ projectIDs: [String], for organizationID: String) {
        save(projectIDs, forKey: Key.projectAssignmentsPrefix + organizationID)
    }

    func saveSnapshot(
        projects: [Project],
        organization: Organization?,
        teamMembers: [TeamMember],
        for organizationID: String
    ) {
        saveProjects(projects, for: organizationID)
        saveOrganization(organization, for: organizationID)
        saveTeamMembers(teamMembers, for: organizationID)
    }

    private func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            Logger.projectStore.error("Failed to encode value for key \(key, privacy: .private(mask: .hash))")
            return
        }

        userDefaults.set(data, forKey: key)
    }

    private func load<Value: Decodable>(_ type: Value.Type, forKey key: String, fallback: Value) -> Value {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return fallback
        }

        return decoded
    }

    private func loadOptional<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }
}

extension Logger {
    static let projectRepository = Logger(subsystem: "com.RheirHome.RHEIR", category: "projectRepository")
}

protocol ProjectRepository {
    func fetchProjects(for organizationID: String) async throws -> [Project]
    func saveProject(_ project: Project, organizationID: String) async throws
    func saveProjectAssignments(_ projectIDs: [String], organizationID: String) async throws
    func loadProjectAssignments(organizationID: String) async -> [String]
}

protocol CloudKitProjectDatabase {
    func records(matching query: CKQuery) async throws -> [CKRecord]
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    func save(_ record: CKRecord) async throws -> CKRecord
}

private struct CKDatabaseProjectAdapter: CloudKitProjectDatabase {
    let database: CKDatabase

    func records(matching query: CKQuery) async throws -> [CKRecord] {
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { (_, matchResult) in
            switch matchResult {
            case .success(let record):
                return record
            case .failure(let error):
                Logger.projectRepository.error(
                    "Project fetch failed: \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }
    }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        try await database.record(for: recordID)
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        try await database.save(record)
    }
}

final class CloudKitProjectRepository: ProjectRepository {
    private let database: any CloudKitProjectDatabase

    init(container: CKContainer = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")) {
        self.database = CKDatabaseProjectAdapter(database: container.privateCloudDatabase)
    }

    init(database: any CloudKitProjectDatabase) {
        self.database = database
    }

    func fetchProjects(for organizationID: String) async throws -> [Project] {
        let predicate = NSPredicate(format: "organizationID == %@", organizationID)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        let records = try await database.records(matching: query)

        let projects = records.compactMap { record -> Project? in
            if let projectData = record["fullProjectData"] as? Data,
               let project = try? JSONDecoder().decode(Project.self, from: projectData) {
                return project.normalizedReceiptCopy
            }

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
                organizationID: organizationID
            )
        }

        Logger.projectRepository.debug(
            "Fetched \(projects.count, privacy: .public) projects for organization \(organizationID, privacy: .private(mask: .hash))"
        )

        return projects
    }

    func saveProject(_ project: Project, organizationID: String) async throws {
        let recordID = CKRecord.ID(recordName: "project_\(project.id.uuidString)")
        let persistenceSafeProject = project.persistenceSafeCopy

        try await upsertRecord(recordType: "Project", recordID: recordID) { record in
            record["name"] = project.name as CKRecordValue
            record["client"] = project.client as CKRecordValue
            record["totalBudget"] = project.totalBudget as CKRecordValue
            record["startDate"] = project.startDate as CKRecordValue
            record["endDate"] = project.endDate as CKRecordValue
            record["status"] = project.status.rawValue as CKRecordValue
            record["organizationID"] = organizationID as CKRecordValue

            if let projectData = try? JSONEncoder().encode(persistenceSafeProject) {
                record["fullProjectData"] = projectData as CKRecordValue

                if project.inlineReceiptImageCount > 0 {
                    Logger.projectRepository.debug(
                        "Prepared CloudKit project payload without inline receipt images [organization=\(organizationID, privacy: .private(mask: .hash)) images=\(project.inlineReceiptImageCount, privacy: .public) bytes=\(projectData.count, privacy: .public)]"
                    )
                }
            }
        }
    }

    func saveProjectAssignments(_ projectIDs: [String], organizationID: String) async throws {
        let recordID = CKRecord.ID(recordName: "project_assignments_\(organizationID)")
        try await upsertRecord(recordType: "ProjectAssignments", recordID: recordID) { record in
            record["organizationID"] = organizationID as CKRecordValue
            record["assignedProjectIDs"] = projectIDs as CKRecordValue
            record["lastModified"] = Date() as CKRecordValue
            record["environment"] = "production" as CKRecordValue
        }
    }

    func loadProjectAssignments(organizationID: String) async -> [String] {
        do {
            let recordID = CKRecord.ID(recordName: "project_assignments_\(organizationID)")
            let record = try await database.record(for: recordID)
            return record["assignedProjectIDs"] as? [String] ?? []
        } catch {
            Logger.projectRepository.error(
                "Project assignment load failed for organization \(organizationID, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    private func upsertRecord(
        recordType: String,
        recordID: CKRecord.ID,
        configure: (CKRecord) -> Void
    ) async throws {
        let record: CKRecord

        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        configure(record)
        _ = try await database.save(record)
    }
}
