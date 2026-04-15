import Foundation
import CloudKit
import OSLog

extension Logger {
    static let cloudKitZone = Logger(subsystem: "com.RheirHome.RHEIR", category: "cloudKitZone")
}

/// Manages CloudKit zones for scalable RHEIR architecture with proper organization data isolation
/// Each organization gets its own private zone for complete data isolation
@MainActor
class CloudKitZoneManager: ObservableObject {
    
    // MARK: - Zone Configuration
    private let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
    private let organizationID: String
    
    // Organization-specific zone ID for complete data isolation
    private var organizationZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "Org-\(organizationID)", ownerName: CKCurrentUserDefaultName)
    }
    
    private lazy var privateDatabase = container.privateCloudDatabase
    private lazy var sharedDatabase = container.sharedCloudDatabase
    
    // MARK: - Published Properties
    @Published var isSetupComplete = false
    @Published var setupProgress: Double = 0.0
    @Published var setupStatus = ""
    @Published var currentZone: CKRecordZone?
    
    // MARK: - Initialization
    init(organizationID: String) {
        self.organizationID = organizationID
        Logger.cloudKitZone.info(
            "Initialized organization zone manager [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
    }
    
    // MARK: - Zone Setup
    
    /// Sets up the organization-specific zone for complete data isolation
    func setupOrganizationZones() async throws {
        setupStatus = "Setting up organization zone..."
        setupProgress = 0.1
        
        Logger.cloudKitZone.info(
            "Creating organization-specific CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
        // Create organization-specific zone in private database for security
        try await createOrganizationZone()
        setupProgress = 1.0
        
        isSetupComplete = true
        setupStatus = "Zone setup complete"
        
        Logger.cloudKitZone.notice(
            "Completed organization zone setup [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Creates the private organization-specific zone for complete data isolation
    private func createOrganizationZone() async throws {
        setupStatus = "Creating organization zone..."
        
        let zone = CKRecordZone(zoneID: organizationZoneID)
        
        do {
            let savedZone = try await container.privateCloudDatabase.save(zone)
            currentZone = savedZone
            Logger.cloudKitZone.notice(
                "Created organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, which is fine
            currentZone = zone
            Logger.cloudKitZone.info(
                "Organization CloudKit zone already exists [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.cloudKitZone.error(
                "Failed to create organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    // MARK: - Zone Access
    
    /// Gets the private database for organization data (ensures complete isolation)
    var organizationDatabase: CKDatabase {
        container.privateCloudDatabase
    }
    
    /// Get the organization zone ID for queries
    var currentZoneID: CKRecordZone.ID {
        organizationZoneID
    }
    
    // MARK: - Record Management with Organization Isolation
    
    /// Saves a record to the organization-specific zone
    func saveRecord<T: CKRecord>(_ record: T) async throws -> T {
        let database = container.privateCloudDatabase
        
        // Ensure record is in this organization's zone
        record.recordID = CKRecord.ID(recordName: record.recordID.recordName, zoneID: organizationZoneID)
        
        let savedRecord = try await database.save(record)
        Logger.cloudKitZone.notice(
            "Saved record to organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), recordType=\(record.recordType, privacy: .public)]"
        )
        
        guard let typedRecord = savedRecord as? T else {
            throw CloudKitZoneError.recordTypeMismatch
        }
        
        return typedRecord
    }
    
    /// Fetches records from the organization-specific zone only
    func fetchRecords<T: CKRecord>(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor] = [],
        resultsLimit: Int = 100
    ) async throws -> [T] {
        let database = container.privateCloudDatabase
        
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        
        let result = try await database.records(matching: query, inZoneWith: organizationZoneID, resultsLimit: resultsLimit)
        
        return result.matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return record as? T
            case .failure(let error):
                Logger.cloudKitZone.error(
                    "Failed to fetch zone record [organization=\(organizationID, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public), error=\(error.localizedDescription, privacy: .public)]"
                )
                return nil
            }
        }
    }
    
    /// Delete a record from the organization zone
    func deleteRecord(recordID: CKRecord.ID) async throws {
        let database = container.privateCloudDatabase
        
        // Ensure we're deleting from this organization's zone
        let scopedRecordID = CKRecord.ID(recordName: recordID.recordName, zoneID: organizationZoneID)
        
        try await database.deleteRecord(withID: scopedRecordID)
        Logger.cloudKitZone.notice(
            "Deleted record from organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), record=\(recordID.recordName, privacy: .private(mask: .hash))]"
        )
    }
    
    // MARK: - Project-Specific Methods
    
    /// Save a project to this organization's zone
    func saveProject(_ project: Project) async throws -> CKRecord {
        let projectRecord = CKRecord(recordType: "Project", recordID: CKRecord.ID(recordName: project.id.uuidString, zoneID: organizationZoneID))
        
        // Set project data with organization isolation
        projectRecord["name"] = project.name as CKRecordValue
        projectRecord["client"] = project.client as CKRecordValue
        projectRecord["totalBudget"] = project.totalBudget as CKRecordValue
        projectRecord["startDate"] = project.startDate as CKRecordValue
        projectRecord["endDate"] = project.endDate as CKRecordValue
        projectRecord["status"] = project.status.rawValue as CKRecordValue
        projectRecord["organizationID"] = organizationID as CKRecordValue
        
        // Store complete project data as JSON
        if let projectData = try? JSONEncoder().encode(project) {
            projectRecord["fullProjectData"] = projectData as CKRecordValue
        }
        
        let savedRecord = try await saveRecord(projectRecord)
        Logger.cloudKitZone.notice(
            "Saved project to organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
        )
        
        return savedRecord
    }
    
    /// Load all projects from this organization's zone only
    func loadProjects() async throws -> [Project] {
        let records: [CKRecord] = try await fetchRecords(
            recordType: "Project",
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
        )
        
        let projects = records.compactMap { record -> Project? in
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
                endDate: endDate
            )
        }
        
        Logger.cloudKitZone.info(
            "Loaded projects from organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), count=\(projects.count, privacy: .public)]"
        )
        return projects
    }
    
    /// Delete a project from this organization's zone
    func deleteProject(_ project: Project) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: organizationZoneID)
        try await deleteRecord(recordID: recordID)
        Logger.cloudKitZone.notice(
            "Deleted project from organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
        )
    }
    
    // MARK: - Team Member-Specific Methods
    
    /// Save team members to this organization's zone
    func saveTeamMembers(_ teamMembers: [TeamMember]) async throws -> CKRecord {
        let orgRecordID = CKRecord.ID(recordName: "organization_\(organizationID)", zoneID: organizationZoneID)
        let orgRecord = CKRecord(recordType: "Organization", recordID: orgRecordID)
        
        // Store organization metadata
        orgRecord["organizationID"] = organizationID as CKRecordValue
        orgRecord["lastUpdated"] = Date() as CKRecordValue
        
        // Store team members as JSON data
        if let teamMembersData = try? JSONEncoder().encode(teamMembers) {
            orgRecord["teamMembersData"] = teamMembersData as CKRecordValue
        }
        
        let savedRecord = try await saveRecord(orgRecord)
        Logger.cloudKitZone.notice(
            "Saved team members to organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), count=\(teamMembers.count, privacy: .public)]"
        )
        
        return savedRecord
    }
    
    /// Load team members from this organization's zone
    func loadTeamMembers() async throws -> [TeamMember] {
        let recordID = CKRecord.ID(recordName: "organization_\(organizationID)", zoneID: organizationZoneID)
        
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            
            // Try to decode team members from JSON data
            if let teamMembersData = record["teamMembersData"] as? Data,
               let teamMembers = try? JSONDecoder().decode([TeamMember].self, from: teamMembersData) {
                Logger.cloudKitZone.info(
                    "Loaded team members from organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), count=\(teamMembers.count, privacy: .public)]"
                )
                return teamMembers
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Organization record doesn't exist yet, return empty array
            Logger.cloudKitZone.info(
                "No organization record found when loading team members [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
            return []
        } catch {
            Logger.cloudKitZone.error(
                "Failed to load team members from organization CloudKit zone [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
        
        return []
    }
    
    // MARK: - Zone Diagnostics
    
    /// Gets diagnostic information about the zone setup
    func getZoneDiagnostics() async -> String {
        var diagnostics = "🏗️ CLOUDKIT ZONE DIAGNOSTICS:\n\n"
        
        diagnostics += "ORGANIZATION: \(organizationID.prefix(8))...\n"
        diagnostics += "ZONE ARCHITECTURE: Organization-Specific Isolation\n\n"
        
        diagnostics += "ZONE:\n"
        diagnostics += "• Organization Zone: \(organizationZoneID.zoneName) (Private)\n"
        diagnostics += "• Database: Private (Complete Isolation)\n\n"
        
        diagnostics += "SETUP STATUS:\n"
        diagnostics += "• Complete: \(isSetupComplete ? "✅" : "❌")\n"
        diagnostics += "• Progress: \(Int(setupProgress * 100))%\n"
        diagnostics += "• Status: \(setupStatus)\n\n"
        
        // Count records in zone
        do {
            let projects: [CKRecord] = try await fetchRecords(recordType: "Project")
            diagnostics += "DATA:\n"
            diagnostics += "• Projects in zone: \(projects.count)\n"
        } catch {
            diagnostics += "DATA:\n"
            diagnostics += "• Projects: Error loading (\(error.localizedDescription))\n"
        }
        
        return diagnostics
    }
    
    // MARK: - Legacy Support Methods
    
    func setupOrganizationZones(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await setupOrganizationZones()
                completion(true)
            } catch {
                Logger.cloudKitZone.error(
                    "Legacy zone setup callback failed [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                )
                completion(false)
            }
        }
    }
    
    // MARK: - Zone Status Checks
    
    func publicZoneExists() -> Bool {
        // Not using public zone for organization data
        return false
    }
    
    func privateZoneExists() -> Bool {
        return currentZone != nil
    }
    
    func sharedZoneExists() -> Bool {
        // Not using shared zones for organization data isolation
        return false
    }
}

// MARK: - CloudKit Zone Errors

enum CloudKitZoneError: LocalizedError {
    case recordTypeMismatch
    case organizationMismatch
    case zoneNotSetup
    
    var errorDescription: String? {
        switch self {
        case .recordTypeMismatch:
            return "Record type mismatch during save operation"
        case .organizationMismatch:
            return "Record does not belong to this organization"
        case .zoneNotSetup:
            return "Organization zone has not been set up yet"
        }
    }
}
