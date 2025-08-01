import Foundation
import Combine
import CloudKit

/// Zone-based CloudKit service for organization data isolation
/// Each organization gets its own private zone for complete data separation
class SimpleCloudKitSharingService: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let privateDB: CKDatabase
    
    // Organization-specific zone management
    private var currentOrganizationID: String?
    private var currentZone: CKRecordZone?
    private var isZoneSetup = false
    private var zoneSetupTask: Task<Void, Error>?
    
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV2") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDB = container.privateCloudDatabase
        print("🔧 SimpleCloudKitSharingService initialized with zone-based isolation")
    }
    
    // MARK: - Organization Setup with Proper Waiting
    
    /// Set the current organization and initialize its zone
    @MainActor
    func setCurrentOrganization(_ organizationID: String) async {
        guard organizationID != currentOrganizationID else { return }
        
        print("🏢 Setting current organization: \(organizationID.prefix(8))...")
        currentOrganizationID = organizationID
        
        // Cancel any existing setup task
        zoneSetupTask?.cancel()
        
        // Setup zone for this organization and wait for completion
        zoneSetupTask = Task { @MainActor in
            await setupOrganizationZone()
        }
        
        do {
            try await zoneSetupTask?.value
            print("✅ Organization zone setup completed for \(organizationID.prefix(8))...")
        } catch {
            print("❌ Failed to complete zone setup for \(organizationID.prefix(8))...: \(error)")
        }
    }
    
    /// Setup the organization-specific zone with proper error handling
    @MainActor
    private func setupOrganizationZone() async {
        guard let organizationID = currentOrganizationID else { return }
        
        let zoneID = CKRecordZone.ID(zoneName: "Org-\(organizationID)", ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            // First try to fetch existing zone
            let existingZones = try await privateDB.allRecordZones()
            if let existingZone = existingZones.first(where: { $0.zoneID.zoneName == zoneID.zoneName }) {
                currentZone = existingZone
                isZoneSetup = true
                print("✅ Found existing organization zone for \(organizationID.prefix(8))...")
                return
            }
            
            // Create new zone if it doesn't exist
            let savedZone = try await privateDB.save(zone)
            currentZone = savedZone
            isZoneSetup = true
            print("✅ Created new organization zone for \(organizationID.prefix(8))...")
            
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, which is fine
            currentZone = zone
            isZoneSetup = true
            print("✅ Organization zone already exists for \(organizationID.prefix(8))...")
        } catch {
            print("❌ Failed to setup zone for organization \(organizationID.prefix(8))...: \(error)")
            isZoneSetup = false
            currentZone = nil
        }
    }
    
    // MARK: - Zone Readiness Check
    
    private func ensureZoneReady() async throws {
        guard let organizationID = currentOrganizationID else {
            throw SharingError.organizationNotSet
        }
        
        // If zone setup is in progress, wait for it
        if let setupTask = zoneSetupTask {
            try await setupTask.value
        }
        
        // Double check that zone is ready
        if !isZoneSetup || currentZone == nil {
            print("⚠️ Zone not ready, attempting setup...")
            await setCurrentOrganization(organizationID)
            
            guard isZoneSetup, currentZone != nil else {
                throw SharingError.zoneNotSetup
            }
        }
    }
    
    // MARK: - Organization Sharing Setup
    
    func setupOrganizationSharing() -> AnyPublisher<String, Error> {
        return Future<String, Error> { [weak self] promise in
            guard let self = self,
                  let organizationID = self.currentOrganizationID else {
                promise(.failure(SharingError.organizationNotSet))
                return
            }
            
            Task { @MainActor in
                do {
                    // Ensure zone is ready before proceeding
                    try await self.ensureZoneReady()
                    
                    // Return success URL since zone-based isolation doesn't require shares
                    let url = "rheirhome://org/\(organizationID)"
                    print("✅ Organization zone isolation active for \(organizationID.prefix(8))...")
                    promise(.success(url))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Project Operations with Proper Zone Waiting
    
    func saveProjectToSharedZone(_ project: Project) -> AnyPublisher<CKRecord, Error> {
        return Future<CKRecord, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(SharingError.zoneNotSetup))
                return
            }
            
            Task {
                do {
                    try await self.ensureZoneReady()
                    
                    guard let zone = self.currentZone else {
                        throw SharingError.zoneNotSetup
                    }
                    
                    let record = try await self.saveProjectToZone(project, zone: zone)
                    promise(.success(record))
                } catch {
                    print("❌ Failed to save project to zone: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func loadProjectsFromSharedZone() -> AnyPublisher<[Project], Error> {
        return Future<[Project], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(SharingError.zoneNotSetup))
                return
            }
            
            Task {
                do {
                    try await self.ensureZoneReady()
                    
                    guard let zone = self.currentZone else {
                        throw SharingError.zoneNotSetup
                    }
                    
                    let projects = try await self.loadProjectsFromZone(zone: zone)
                    promise(.success(projects))
                } catch {
                    print("❌ Failed to load projects from zone: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Internal Zone Operations with Better Error Handling
    
    private func saveProjectToZone(_ project: Project, zone: CKRecordZone) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zone.zoneID)
        let projectRecord = CKRecord(recordType: "Project", recordID: recordID)
        
        // Set project data with organization isolation
        projectRecord["name"] = project.name as CKRecordValue
        projectRecord["client"] = project.client as CKRecordValue
        projectRecord["totalBudget"] = project.totalBudget as CKRecordValue
        projectRecord["startDate"] = project.startDate as CKRecordValue
        projectRecord["endDate"] = project.endDate as CKRecordValue
        projectRecord["status"] = project.status.rawValue as CKRecordValue
        projectRecord["organizationID"] = (currentOrganizationID ?? "") as CKRecordValue
        projectRecord["createdAt"] = Date() as CKRecordValue
        
        // Store complete project data as JSON for data integrity
        if let projectData = try? JSONEncoder().encode(project) {
            projectRecord["fullProjectData"] = projectData as CKRecordValue
        }
        
        let savedRecord = try await privateDB.save(projectRecord)
        
        print("✅ Project '\(project.name)' saved to organization zone \(zone.zoneID.zoneName)")
        
        return savedRecord
    }
    
    private func loadProjectsFromZone(zone: CKRecordZone) async throws -> [Project] {
        print("🔍 Loading projects from zone: \(zone.zoneID.zoneName)")
        
        // Create query with better filtering
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let result = try await privateDB.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 100)
        
        let projects = result.matchResults.compactMap { (_, result) -> Project? in
            switch result {
            case .success(let record):
                if let project = decodeProject(from: record) {
                    print("✅ Decoded project: \(project.name)")
                    return project
                } else {
                    print("⚠️ Failed to decode project from record")
                    return nil
                }
            case .failure(let error):
                print("❌ Failed to fetch project record: \(error)")
                return nil
            }
        }
        
        print("✅ Loaded \(projects.count) projects from organization zone")
        return projects
    }
    
    private func decodeProject(from record: CKRecord) -> Project? {
        // Try to decode from full project data first (most reliable)
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
            print("⚠️ Missing required fields for project reconstruction")
            return nil
        }
        
        let statusString = record["status"] as? String ?? "Active"
        let status = ProjectStatus(rawValue: statusString) ?? .active
        
        return Project(
            name: name,
            client: client,
            totalBudget: totalBudget,
            materialCost: 0,
            laborCost: 0,
            generalConditions: 0,
            contingency: 0,
            profit: 0,
            startDate: startDate,
            endDate: endDate,
            status: status
        )
    }
    
    // MARK: - Enhanced Utility Methods
    
    func isOrganizationSharingActive() -> Bool {
        return isZoneSetup && currentZone != nil && currentOrganizationID != nil
    }
    
    func getOrganizationSharingStatus() -> String {
        guard let organizationID = currentOrganizationID else {
            return "❌ No organization set - cannot provide status"
        }
        
        var status = "📊 ZONE-BASED ISOLATION STATUS:\n\n"
        status += "Organization: \(organizationID.prefix(8))...\n"
        status += "Zone: \(currentZone?.zoneID.zoneName ?? "Not Set")\n"
        status += "Zone Setup: \(isZoneSetup ? "✅ Complete" : "❌ Not Complete")\n"
        status += "Zone Ready: \(isOrganizationSharingActive() ? "✅ Active" : "❌ Not Active")\n\n"
        
        if isZoneSetup {
            status += "ISOLATION:\n"
            status += "• Data stored in organization-specific private zone\n"
            status += "• Complete isolation from other organizations\n"
            status += "• No cross-organization data leakage possible\n"
        }
        
        return status
    }
    
    func getCurrentOrganizationID() -> String? {
        return currentOrganizationID
    }
    
    // MARK: - Enhanced Zone Diagnostics
    
    func getZoneDiagnostics() async -> String {
        guard let organizationID = currentOrganizationID else {
            return "❌ No organization set - cannot provide diagnostics"
        }
        
        var diagnostics = "🏗️ ZONE-BASED ISOLATION DIAGNOSTICS:\n\n"
        diagnostics += "Organization: \(organizationID.prefix(8))...\n"
        diagnostics += "Zone: \(currentZone?.zoneID.zoneName ?? "Not Set")\n"
        diagnostics += "Setup Complete: \(isZoneSetup ? "✅" : "❌")\n"
        diagnostics += "Zone Active: \(isOrganizationSharingActive() ? "✅" : "❌")\n\n"
        
        if isOrganizationSharingActive(), let zone = currentZone {
            do {
                try await ensureZoneReady()
                
                let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
                let result = try await privateDB.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 100)
                let projectCount = result.matchResults.count
                
                diagnostics += "DATA IN ZONE:\n"
                diagnostics += "• Projects: \(projectCount)\n"
                diagnostics += "• Zone ID: \(zone.zoneID.zoneName)\n"
                diagnostics += "• Owner: \(zone.zoneID.ownerName)\n"
            } catch {
                diagnostics += "DATA IN ZONE:\n"
                diagnostics += "• Projects: Error loading (\(error.localizedDescription))\n"
            }
        } else {
            diagnostics += "DATA IN ZONE:\n"
            diagnostics += "• Status: Zone not active - cannot query data\n"
        }
        
        return diagnostics
    }
    
    // MARK: - Legacy Support (Deprecated)
    
    func inviteUserToOrganization(email: String) -> AnyPublisher<Void, Error> {
        print("📧 Note: Zone-based isolation doesn't require traditional invites")
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getOrganizationShareURL() -> String? {
        if let orgID = currentOrganizationID {
            return "rheirhome://org/\(orgID)"
        }
        return nil
    }
    
    func acceptOrganizationShare(from urlString: String) -> AnyPublisher<Void, Error> {
        print("📧 Note: Zone-based isolation handles access through organization membership")
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Nuclear Reset Methods (Enhanced)
    
    /// Delete all projects from the current organization's zone
    func deleteAllProjectsFromZone() async {
        do {
            try await ensureZoneReady()
            
            guard let zone = currentZone else {
                print("⚠️ No zone available - cannot delete projects")
                return
            }
            
            print("🗑️ Deleting all projects from organization zone...")
            
            // Query all projects in the zone
            let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
            let result = try await privateDB.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 100)
            
            // Collect record IDs to delete
            let recordIDs = result.matchResults.compactMap { (recordID, result) -> CKRecord.ID? in
                switch result {
                case .success:
                    return recordID
                case .failure:
                    return nil
                }
            }
            
            if !recordIDs.isEmpty {
                // Delete all project records
                let _ = try await privateDB.modifyRecords(saving: [], deleting: recordIDs)
                print("✅ Deleted \(recordIDs.count) projects from organization zone")
            } else {
                print("✅ No projects found in zone to delete")
            }
            
        } catch {
            print("❌ Failed to delete projects from zone: \(error)")
        }
    }
    
    /// Reset the organization zone (delete and recreate)
    func resetOrganizationZone() async {
        guard let organizationID = currentOrganizationID else {
            print("⚠️ No organization set - cannot reset zone")
            return
        }
        
        do {
            print("🔄 Resetting organization zone...")
            
            // Delete the existing zone if it exists
            if let zone = currentZone {
                try await privateDB.deleteRecordZone(withID: zone.zoneID)
                print("🗑️ Deleted existing organization zone")
            }
            
            // Clear current zone state
            currentZone = nil
            isZoneSetup = false
            zoneSetupTask?.cancel()
            zoneSetupTask = nil
            
            // Recreate the zone
            await setCurrentOrganization(organizationID)
            
            if isZoneSetup {
                print("✅ Organization zone reset complete")
            } else {
                print("❌ Failed to recreate organization zone")
            }
            
        } catch {
            print("❌ Failed to reset organization zone: \(error)")
            
            // Try to recreate zone anyway
            currentZone = nil
            isZoneSetup = false
            zoneSetupTask?.cancel()
            zoneSetupTask = nil
            await setCurrentOrganization(organizationID)
        }
    }
    
    /// Get a clean diagnostic status for nuclear reset operations
    func getNuclearResetStatus() async -> String {
        guard let organizationID = currentOrganizationID else {
            return "❌ No organization set - cannot provide reset status"
        }
        
        var status = "💥 NUCLEAR RESET STATUS:\n\n"
        status += "Organization: \(organizationID.prefix(8))...\n"
        status += "Zone: \(currentZone?.zoneID.zoneName ?? "Not Set")\n"
        status += "Zone Setup: \(isZoneSetup ? "✅ Ready" : "❌ Not Ready")\n"
        status += "Zone Active: \(isOrganizationSharingActive() ? "✅ Active" : "❌ Inactive")\n\n"
        
        if isOrganizationSharingActive(), let zone = currentZone {
            do {
                try await ensureZoneReady()
                
                let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
                let result = try await privateDB.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 1)
                let hasProjects = !result.matchResults.isEmpty
                
                status += "ZONE STATE:\n"
                status += "• Contains Data: \(hasProjects ? "✅ Yes" : "❌ Clean")\n"
                status += "• Ready for Reset: ✅ Yes\n"
            } catch {
                status += "ZONE STATE:\n"
                status += "• Status: ⚠️ Error checking (\(error.localizedDescription))\n"
            }
        } else {
            status += "ZONE STATE:\n"
            status += "• Status: ❌ Zone not initialized\n"
        }
        
        return status
    }
}

// MARK: - Enhanced Sharing Errors
enum SharingError: LocalizedError {
    case zoneCreationFailed
    case zoneNotFound
    case zoneNotSetup
    case recordCreationFailed
    case shareCreationFailed
    case shareNotFound
    case userNotFound
    case invalidURL
    case organizationNotSet
    case zoneSetupTimeout
    
    var errorDescription: String? {
        switch self {
        case .zoneCreationFailed:
            return "Failed to create organization zone"
        case .zoneNotFound:
            return "Organization zone not found"
        case .zoneNotSetup:
            return "Organization zone not set up - call setCurrentOrganization first"
        case .recordCreationFailed:
            return "Failed to create record"
        case .shareCreationFailed:
            return "Failed to create share"
        case .shareNotFound:
            return "Share not found"
        case .userNotFound:
            return "User not found"
        case .invalidURL:
            return "Invalid share URL"
        case .organizationNotSet:
            return "No organization set - cannot perform operation"
        case .zoneSetupTimeout:
            return "Zone setup timed out - please try again"
        }
    }
}