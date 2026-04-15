import CloudKit
import Foundation
import OSLog

extension Logger {
    static let cloudKitProject = Logger(subsystem: "com.RheirHome.RHEIR", category: "cloudKitProject")
}

class CloudKitProjectService {
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase
    
    init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
    }
    
    // MARK: - Project Operations
    
    func saveProject(_ project: Project, to organizationID: UUID) async throws {
        let record = try project.toCKRecord(organizationID: organizationID)
        
        // Save to shared database for organization sharing
        do {
            let savedRecord = try await sharedDB.save(record)
            Logger.cloudKitProject.notice(
                "Saved project to shared CloudKit zone [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(savedRecord.recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.cloudKitProject.error(
                "Failed to save project to CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func fetchProjects(for organizationID: UUID) async throws -> [Project] {
        let predicate = NSPredicate(format: "organizationID == %@", organizationID.uuidString)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        
        do {
            let records = try await sharedDB.records(matching: query).matchResults.map { try $0.get() }
            return try records.compactMap { try Project(from: $0) }
        } catch {
            Logger.cloudKitProject.error(
                "Failed to fetch CloudKit projects [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func deleteProject(_ project: Project, from organizationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: organizationZoneID(for: organizationID))
        
        do {
            try await sharedDB.deleteRecord(withID: recordID)
            Logger.cloudKitProject.notice(
                "Deleted project from shared CloudKit zone [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.cloudKitProject.error(
                "Failed to delete CloudKit project [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func organizationZoneID(for organizationID: UUID) -> CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: "org-shared-\(organizationID.uuidString)", ownerName: CKCurrentUserDefaultName)
    }
    
    func isCloudKitEnabled(for organizationID: UUID) async -> Bool {
        do {
            // Check if we can access the organization's shared zone
            let zoneID = organizationZoneID(for: organizationID)
            let zone = try await sharedDB.recordZone(zoneID)
            return zone != nil
        } catch {
            Logger.cloudKitProject.warning(
                "CloudKit shared zone unavailable for organization [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            return false
        }
    }
}
