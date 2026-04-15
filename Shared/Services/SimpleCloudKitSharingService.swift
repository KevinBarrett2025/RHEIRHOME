import CloudKit
import Foundation
import OSLog

protocol CloudKitSharingServiceProtocol {
    func isCloudKitEnabled(for organizationID: UUID) async -> Bool
    func saveProject(_ project: Project, to organizationID: UUID) async throws
    func fetchProjects(for organizationID: UUID) async throws -> [Project]
    func deleteProject(_ project: Project, from organizationID: UUID) async throws
    func saveTeamMember(_ teamMember: TeamMember, to organizationID: UUID) async throws
    func fetchTeamMembers(for organizationID: UUID) async throws -> [TeamMember]
    func deleteTeamMember(_ teamMember: TeamMember, from organizationID: UUID) async throws
}

class SimpleCloudKitSharingService: CloudKitSharingServiceProtocol {
    private let container: CKContainer
    private let sharedDB: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        self.sharedDB = container.sharedCloudDatabase
    }
    
    func isCloudKitEnabled(for organizationID: UUID) async -> Bool {
        do {
            let zoneID = self.zoneID(for: organizationID)
            _ = try await sharedDB.modifyRecordZones(saving: [], deleting: [], in: zoneID)
            Logger.organizationSharing.info(
                "Verified shared CloudKit access for organization [organization=\(organizationID.uuidString, privacy: .private(mask: .hash))]"
            )
            return true
        } catch {
            Logger.organizationSharing.warning(
                "Shared CloudKit is not enabled for organization [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            return false
        }
    }
    
    func saveProject(_ project: Project, to organizationID: UUID) async throws {
        Logger.organizationSharing.info(
            "Saving project to shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), project=\(project.id.uuidString, privacy: .private(mask: .hash))]"
        )
        
        let zoneID = self.zoneID(for: organizationID)
        let record = try project.toCKRecord(organizationID: organizationID)
        record.parent = CKRecord.Reference(recordID: self.rootRecordID(for: organizationID), action: .none)
        
        do {
            let savedRecord = try await sharedDB.save(record)
            Logger.organizationSharing.notice(
                "Saved project to shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(savedRecord.recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.organizationSharing.error(
                "Failed to save project to shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func fetchProjects(for organizationID: UUID) async throws -> [Project] {
        Logger.organizationSharing.info(
            "Fetching shared CloudKit projects [organization=\(organizationID.uuidString, privacy: .private(mask: .hash))]"
        )
        
        let predicate = NSPredicate(format: "organizationID == %@", organizationID.uuidString)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await sharedDB.records(matching: query)
            let projects = try results.matchResults.map { _, result in
                try Project(from: result.get())
            }
            Logger.organizationSharing.notice(
                "Fetched shared CloudKit projects [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), count=\(projects.count, privacy: .public)]"
            )
            return projects
        } catch {
            Logger.organizationSharing.error(
                "Failed to fetch shared CloudKit projects [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func deleteProject(_ project: Project, from organizationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: self.zoneID(for: organizationID))
        
        do {
            try await sharedDB.deleteRecord(withID: recordID)
            Logger.organizationSharing.notice(
                "Deleted project from shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.organizationSharing.error(
                "Failed to delete project from shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func saveTeamMember(_ teamMember: TeamMember, to organizationID: UUID) async throws {
        let zoneID = self.zoneID(for: organizationID)
        let record = try teamMember.toCKRecord(organizationID: organizationID)
        record.parent = CKRecord.Reference(recordID: self.rootRecordID(for: organizationID), action: .none)
        
        do {
            let savedRecord = try await sharedDB.save(record)
            Logger.organizationSharing.notice(
                "Saved team member to shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(savedRecord.recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.organizationSharing.error(
                "Failed to save team member to shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func fetchTeamMembers(for organizationID: UUID) async throws -> [TeamMember] {
        let predicate = NSPredicate(format: "organizationID == %@", organizationID.uuidString)
        let query = CKQuery(recordType: "TeamMember", predicate: predicate)
        
        do {
            let results = try await sharedDB.records(matching: query)
            let teamMembers = try results.matchResults.map { _, result in
                try TeamMember(from: result.get())
            }
            Logger.organizationSharing.notice(
                "Fetched shared CloudKit team members [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), count=\(teamMembers.count, privacy: .public)]"
            )
            return teamMembers
        } catch {
            Logger.organizationSharing.error(
                "Failed to fetch shared CloudKit team members [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    func deleteTeamMember(_ teamMember: TeamMember, from organizationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: teamMember.id.uuidString, zoneID: self.zoneID(for: organizationID))
        
        do {
            try await sharedDB.deleteRecord(withID: recordID)
            Logger.organizationSharing.notice(
                "Deleted team member from shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), record=\(recordID.recordName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.organizationSharing.error(
                "Failed to delete team member from shared CloudKit [organization=\(organizationID.uuidString, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func zoneID(for organizationID: UUID) -> CKRecordZone.ID {
        return CKRecordZone.ID(
            zoneName: "org-shared-\(organizationID.uuidString)",
            ownerName: CKCurrentUserDefaultName
        )
    }
    
    private func rootRecordID(for organizationID: UUID) -> CKRecord.ID {
        return CKRecord.ID(
            recordName: "org-root-\(organizationID.uuidString)",
            zoneID: self.zoneID(for: organizationID)
        )
    }
}
