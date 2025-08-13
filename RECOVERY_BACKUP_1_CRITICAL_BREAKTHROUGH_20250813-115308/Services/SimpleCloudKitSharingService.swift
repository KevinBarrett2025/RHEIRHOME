import CloudKit
import Foundation

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
            let operation = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
            let result = try await sharedDB.modifyRecordZones(saving: [], deleting: [], in: zoneID)
            return true
        } catch {
            print("DEBUG: CloudKit not enabled for organization \(organizationID): \(error)")
            return false
        }
    }
    
    func saveProject(_ project: Project, to organizationID: UUID) async throws {
        print("DEBUG: SimpleCloudKitSharingService.saveProject called for org: \(organizationID)")
        
        let zoneID = self.zoneID(for: organizationID)
        let record = try project.toCKRecord(organizationID: organizationID)
        record.parent = CKRecord.Reference(recordID: self.rootRecordID(for: organizationID), action: .none)
        
        do {
            let savedRecord = try await sharedDB.save(record)
            print("DEBUG: Project saved successfully with recordID: \(savedRecord.recordID.recordName)")
        } catch {
            print("DEBUG: Failed to save project to CloudKit: \(error)")
            throw error
        }
    }
    
    func fetchProjects(for organizationID: UUID) async throws -> [Project] {
        print("DEBUG: SimpleCloudKitSharingService.fetchProjects called for org: \(organizationID)")
        
        let predicate = NSPredicate(format: "organizationID == %@", organizationID.uuidString)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let results = try await sharedDB.records(matching: query)
            let projects = try results.matchResults.map { _, result in
                try Project(from: result.get())
            }
            print("DEBUG: Fetched \(projects.count) projects from CloudKit")
            return projects
        } catch {
            print("DEBUG: Failed to fetch projects from CloudKit: \(error)")
            throw error
        }
    }
    
    func deleteProject(_ project: Project, from organizationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: self.zoneID(for: organizationID))
        
        do {
            try await sharedDB.deleteRecord(withID: recordID)
            print("DEBUG: Project deleted from CloudKit: \(recordID.recordName)")
        } catch {
            print("DEBUG: Failed to delete project from CloudKit: \(error)")
            throw error
        }
    }
    
    func saveTeamMember(_ teamMember: TeamMember, to organizationID: UUID) async throws {
        let zoneID = self.zoneID(for: organizationID)
        let record = try teamMember.toCKRecord(organizationID: organizationID)
        record.parent = CKRecord.Reference(recordID: self.rootRecordID(for: organizationID), action: .none)
        
        do {
            let savedRecord = try await sharedDB.save(record)
            print("DEBUG: Team member saved successfully with recordID: \(savedRecord.recordID.recordName)")
        } catch {
            print("DEBUG: Failed to save team member to CloudKit: \(error)")
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
            print("DEBUG: Fetched \(teamMembers.count) team members from CloudKit")
            return teamMembers
        } catch {
            print("DEBUG: Failed to fetch team members from CloudKit: \(error)")
            throw error
        }
    }
    
    func deleteTeamMember(_ teamMember: TeamMember, from organizationID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: teamMember.id.uuidString, zoneID: self.zoneID(for: organizationID))
        
        do {
            try await sharedDB.deleteRecord(withID: recordID)
            print("DEBUG: Team member deleted from CloudKit: \(recordID.recordName)")
        } catch {
            print("DEBUG: Failed to delete team member from CloudKit: \(error)")
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