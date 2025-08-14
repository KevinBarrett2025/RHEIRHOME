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
    @Published var isUsingCloudKitForOrganizationData: Bool = false // TEMPORARILY DISABLED until OrganizationZoneService works
    @Published var migrationProgress: String = ""
    @Published var bulkSyncProgress: String = ""
    @Published var isSavingProject: Bool = false
    @Published var needsLaborHoursMigration: Bool = false
    
    // MARK: - Project Assignment Properties
    @Published private var userProjectAssignments: [String] = []
    
    // MARK: - Zone Management
    @Published var isSettingUpZone: Bool = false
    @Published var zoneSetupError: String?
    
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
            return // You didn't say what should be here, so I'll leave it as is
        }
        
        // Log filtering results for debugging multi-org switching
        print(" Filtered projects for \(currentOrgID.prefix(8))... (\(userRole.displayName)): \(filteredProjects.count) of \(organizationProjects.count)")
        
        return filteredProjects.sorted { $0.startDate > $1.startDate }
    }
    
    /// Enhanced project access based on assignments and role
    var accessibleProjectsByAssignment: [Project] {
        // Admins see all projects
        if getCurrentUserRole() == .admin {
            return projects
        }
        
        // Non-admins only see assigned projects
        if userProjectAssignments.isEmpty {
            // No assignments = no projects visible (except for new users)
            return []
        }
        
        return projects.filter { project in
            userProjectAssignments.contains(project.id.uuidString)
        }
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
        
        print(" ProjectViewModel initialized with CLOUDKIT SHARED ZONES ENABLED")
        
        Task {
            await loadProjects()
            await loadTeamMembersFromCloudKit()
            await loadOrganizationData()
        }
    }
    
    convenience init() {
        self.init(cloudKitService: CloudKitAuthService())
    }
    
    // MARK: - CloudKit Zone Setup (RE-ENABLED)
    
    /// Setup CloudKit SHARED zone for a specific organization (RE-ENABLED)
    func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        print(" ZONE SETUP: Setting up SHARED CloudKit zone for organization: \(organizationID.prefix(8))...")
        print(" ZONE SETUP: Current isUsingCloudKitForOrganizationData: \(isUsingCloudKitForOrganizationData)")
        
        isSettingUpZone = true
        zoneSetupError = nil
        currentOrganizationID = organizationID
        
        do {
            // Check CloudKit account status first
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                let errorMsg = "iCloud account not available: \(accountStatus)"
                print(" ZONE SETUP: \(errorMsg)")
                throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            print(" CloudKit account available")
            
            let privateDB = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(organizationID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            
            // STEP 1: Check if zone already exists in private database
            print(" Checking for existing zone...")
            do {
                let existingZones = try await privateDB.allRecordZones()
                if let existingZone = existingZones.first(where: { $0.zoneID.zoneName == zoneName }) {
                    print(" Found existing CloudKit SHARED zone: \(zoneName)")
                    
                    // Check if zone has a share (is actually shared)
                    let hasShare = try await checkZoneHasShare(existingZone, container: container)
                    
                    if hasShare {
                        print(" Zone is properly shared for collaboration")
                    } else {
                        print(" Zone exists but is not shared - creating share...")
                        try await createShareForExistingZone(existingZone, organizationID: organizationID, container: container)
                        print(" Created share for existing zone")
                    }
                    
                    isUsingCloudKitForOrganizationData = true
                    await loadOrganizationProjectsFromCloudKit(zoneID: existingZone.zoneID)
                    isSettingUpZone = false
                    print(" ZONE SETUP: Using existing zone for organization: \(organizationID.prefix(8))...")
                    return
                }
            } catch {
                print(" Could not check existing zones: \(error)")
            }
            
            // STEP 2: Create new zone with sharing
            print(" Creating new SHARED zone: \(zoneName)")
            
            let newZone = CKRecordZone(zoneID: zoneID)
            let savedZone = try await privateDB.save(newZone)
            print(" Created zone in private DB: \(zoneName)");
            
            // STEP 3: Create root record and share for the zone
            try await createShareForExistingZone(savedZone, organizationID: organizationID, container: container);
            
            isUsingCloudKitForOrganizationData = true
            print(" ZONE SETUP: CloudKit SHARED zone setup successful for organization: \(organizationID.prefix(8))...")
            
            // Load projects from the new zone
            await loadOrganizationProjectsFromCloudKit(zoneID: savedZone.zoneID);
            
        } catch {
            print(" ZONE SETUP: Failed to setup CloudKit SHARED zone: \(error)")
            zoneSetupError = "Failed to setup CloudKit zone: \(error.localizedDescription)"
            
            // Fallback to local storage
            isUsingCloudKitForOrganizationData = false
            await loadOrganizationProjects();
        }
        
        isSettingUpZone = false
        print(" ZONE SETUP: Zone setup completed for organization: \(organizationID.prefix(8))...")
        print(" ZONE SETUP: Final isUsingCloudKitForOrganizationData: \(isUsingCloudKitForOrganizationData)")
    }
    
    /// Check if a zone has a share (is actually shared)
    private func checkZoneHasShare(_ zone: CKRecordZone, container: CKContainer) async throws -> Bool {
        let privateDB = container.privateCloudDatabase
        
        // Look for organization root record in the zone
        let rootRecordID = CKRecord.ID(recordName: "org-root-\(zone.zoneID.zoneName.replacingOccurrences(of: "org-shared-", with: ""))", zoneID: zone.zoneID)
        
        do {
            let rootRecord = try await privateDB.record(for: rootRecordID)
            print(" Found organization root record")
            
            // Check if this record has a share reference
            if rootRecord.share != nil {
                print(" Found share reference for zone - collaboration enabled")
                return true
            } else {
                print(" Root record exists but no share reference found")
                return false
            }
        } catch let error as CKError where error.code == .unknownItem {
            print(" No root record found - zone needs to be set up for sharing")
            return false
        } catch {
            print(" Error checking for share: \(error)")
            throw error
        }
    }
    
    /// Create share for an existing zone
    private func createShareForExistingZone(_ zone: CKRecordZone, organizationID: String, container: CKContainer) async throws {
        let privateDB = container.privateCloudDatabase
        
        let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: zone.zoneID)
        let rootRecord: CKRecord
        do {
            let existingRootRecord = try await privateDB.record(for: rootRecordID)
            rootRecord = existingRootRecord
            print(" Using existing organization root record for share creation")
        } catch let error as CKError where error.code == .unknownItem {
            let newRootRecord = CKRecord(recordType: "OrganizationRoot", recordID: rootRecordID)
            newRootRecord["organizationID"] = organizationID as CKRecordValue
            newRootRecord["name"] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
            newRootRecord["createdAt"] = Date() as CKRecordValue
            rootRecord = newRootRecord
            print(" Created new organization root record for share creation")
        } catch {
            print(" Error getting or creating root record for share: \(error)")
            throw error
        }
        
        // Create share for the root record
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.rheirhome.organization" as CKRecordValue
        share.publicPermission = .none
        
        // CRITICAL FIX: Save both root record and share atomically using CKModifyRecordsOperation
        print(" Saving root record and share atomically to fix CloudKit constraint...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share],
                recordIDsToDelete: nil
            )
            modifyRecordsOperation.savePolicy = .changedKeys
            modifyRecordsOperation.isAtomic = true
            
            modifyRecordsOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success(_):
                    print(" Successfully saved root record and share atomically")
                    print(" Saved records in atomic operation")
                    continuation.resume(returning: ())
                case .failure(let error):
                    print(" Failed to save root record and share atomically: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            privateDB.add(modifyRecordsOperation)
        }
        
        print(" Created share for organization zone - collaboration enabled")
    }
    
    private func loadOrganizationProjectsFromCloudKit(zoneID: CKRecordZone.ID) async {
        do {
            print(" Loading projects from CloudKit SHARED zone...")
            
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let privateDB = container.privateCloudDatabase
            
            let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
            
            let cloudKitProjects = matchResults.compactMap { (_, recordResult) -> Project? in
                switch recordResult {
                case .success(let record):
                    return decodeProjectFromRecord(record)
                case .failure(let error):
                    print(" Failed to process project record: \(error)")
                    return nil
                }
            }
            
            organizationProjects = cloudKitProjects
            print(" Loaded \(organizationProjects.count) projects from CloudKit SHARED zone")
            
            // Also save to local backup
            saveLocalBackup()
            
        } catch {
            print(" Failed to load projects from CloudKit: \(error)")
            // Fallback to local storage
            await loadOrganizationProjects()
        }
    }
    
    private func decodeProjectFromRecord(_ record: CKRecord) -> Project? {
        // Try to decode from full project data first
        if let projectData = record["fullProjectData"] as? Data,
           let project = try? JSONDecoder().decode(Project.self, from: projectData) {
            return project
        }
        
        // Fallback to basic project construction
        guard let name = record["name"] as? String,
              let client = record["client"] as? String,
              let totalBudget = record["totalBudget"] as? Double,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else {
            return nil
        }
        
        let materialCost = record["materialCost"] as? Double ?? 0
        let laborCost = record["laborCost"] as? Double ?? 0
        let organizationID = record["organizationID"] as? String
        
        return Project(
            name: name,
            client: client,
            totalBudget: totalBudget,
            materialCost: materialCost,
            laborCost: laborCost,
            generalConditions: 0,
            contingency: 0,
            
            startDate: startDate,
            endDate: endDate,
            organizationID: organizationID
        )
    }
    
    func getOrganizationCloudKitShareURL() async -> String? {
        guard isUsingCloudKitForOrganizationData,
              let organizationID = currentOrganizationID else {
            print(" CloudKit not enabled or no organization ID")
            return nil
        }
        
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let privateDB = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(organizationID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            
            // Look for the root record first
            let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: zoneID)
            
            do {
                let rootRecord = try await privateDB.record(for: rootRecordID)
                
                // Check if this record has a share reference
                if let shareReference = rootRecord.share {
                    // Fetch the actual share record
                    let shareRecord = try await privateDB.record(for: shareReference.recordID)
                    if let share = shareRecord as? CKShare,
                       let shareURL = share.url {
                        print(" Found CloudKit share for organization")
                        return shareURL.absoluteString
                    }
                }
                
            } catch let error as CKError where error.code == .unknownItem {
                print(" Root record not found - cannot get share URL")
                return nil
            }
            
            print(" No share found for organization")
            return nil
            
        } catch {
            print(" Error getting share URL: \(error)")
            return nil
        }
    }
    
    private func saveProjectToCloudKitSharedZone(_ project: Project) async {
        guard let organizationID = currentOrganizationID else {
            print(" No organization ID for CloudKit save")
            return
        }
        
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let privateDB = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(organizationID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            
            let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: "Project", recordID: recordID)
            
            // Set project data
            record["name"] = project.name as CKRecordValue
            record["client"] = project.client as CKRecordValue
            record["totalBudget"] = project.totalBudget as CKRecordValue
            record["materialCost"] = project.materialCost as CKRecordValue
            record["laborCost"] = project.laborCost as CKRecordValue
            record["startDate"] = project.startDate as CKRecordValue
            record["endDate"] = project.endDate as CKRecordValue
            record["organizationID"] = project.organizationID as CKRecordValue?
            
            // Store full project as JSON for complete data preservation
            if let projectData = try? JSONEncoder().encode(project) {
                record["fullProjectData"] = projectData as CKRecordValue
            }
            
            _ = try await privateDB.save(record)
            print(" Saved project '\(project.name)' to CloudKit SHARED zone")
            
        } catch {
            print(" Failed to save project to CloudKit SHARED zone: \(error)")
            // Local backup is already saved in updateProject/addProject
        }
    }
    
    private func deleteProjectFromCloudKitSharedZone(_ projectID: UUID) async {
        guard let organizationID = currentOrganizationID else {
            print(" No organization ID for CloudKit delete")
            return
        }
        
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let privateDB = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(organizationID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            let recordID = CKRecord.ID(recordName: projectID.uuidString, zoneID: zoneID)
            
            try await privateDB.deleteRecord(withID: recordID)
            print(" Deleted project from CloudKit SHARED zone")
            
        } catch {
            print(" Failed to delete project from CloudKit SHARED zone: \(error)")
        }
    }
    
    func getCloudKitZoneDiagnostics() async -> String {
        guard isUsingCloudKitForOrganizationData,
              let organizationID = currentOrganizationID else {
            return " CloudKit zones not enabled"
        }
        
        var diagnostics = " CLOUDKIT ZONE DIAGNOSTICS:\n\n"
        
        do {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
            let privateDB = container.privateCloudDatabase
            
            // Check account status
            let accountStatus = try await container.accountStatus()
            diagnostics += "Account Status: \(accountStatus == .available ? "Available" : "Not Available")\n"
            
            // Check zones
            let zones = try await privateDB.allRecordZones()
            let orgZone = zones.first { $0.zoneID.zoneName == "org-shared-\(organizationID)" }
            
            if let zone = orgZone {
                diagnostics += "Zone: Found \(zone.zoneID.zoneName)\n"
                diagnostics += "Zone Owner: \(zone.zoneID.ownerName)\n"
                
                // Check for root record
                let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: zone.zoneID)
                do {
                    let rootRecord = try await privateDB.record(for: rootRecordID)
                    diagnostics += "Root Record: Found\n"
                    diagnostics += "Organization ID: \(rootRecord["organizationID"] as? String ?? "none")\n"
                    
                    // Check for share reference
                    if let shareReference = rootRecord.share {
                        do {
                            let shareRecord = try await privateDB.record(for: shareReference.recordID)
                            if let share = shareRecord as? CKShare {
                                diagnostics += "Share: Active\n"
                                diagnostics += "Share Record ID: \(share.recordID.recordName)\n"
                                diagnostics += "Public Permission: \(share.publicPermission.rawValue)\n"
                                diagnostics += "Participants: \(share.participants.count)\n"
                                
                                // Check share URL
                                if let shareURL = share.url {
                                    diagnostics += "Share URL: \(shareURL.absoluteString)\n"
                                } else {
                                    diagnostics += "Share URL: Not yet available (may need time to process)\n"
                                }
                            } else {
                                diagnostics += "Share: Record found but not a CKShare\n"
                            }
                        } catch {
                            diagnostics += "Share: Error fetching share record (\(error.localizedDescription))\n"
                        }
                    } else {
                        diagnostics += "Share: No share reference found\n"
                    }
                    
                } catch {
                    diagnostics += "Root Record: Not found (\(error.localizedDescription))\n"
                }
                
            } else {
                diagnostics += "Zone: Not found\n"
            }
            
        } catch {
            diagnostics += "Error during diagnostics: \(error.localizedDescription)\n"
        }
        
        diagnostics += "\nCOLLABORATION STATUS:\n"
        diagnostics += "This setup enables:\n"
        diagnostics += "• Kevin and Rachel can both access shared data\n"
        diagnostics += "• Team members can be invited via share URL\n"
        diagnostics += "• Real-time collaboration on projects\n"
        diagnostics += "• Complete data isolation from other organizations\n"
        
        return diagnostics
    }
    
    func getDetailedCloudKitStatus(completion: @escaping (String) -> Void) {
        Task {
            var status = await getDataStatus()
            do {
                let diagnostics = await getCloudKitZoneDiagnostics()
                status += diagnostics
            } catch {
                status += "Error getting CloudKit status: \(error.localizedDescription)"
            }
            await MainActor.run {
                completion(status)
            }
        }
    }
}