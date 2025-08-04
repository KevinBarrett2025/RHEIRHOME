import Foundation
import Combine
import CloudKit
import SwiftUI

/// Service to manage organization-based CloudKit zones and sharing
class CloudKitOrganizationSharingService: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // MARK: - Zone Management
    private var organizationZones: [String: CKRecordZone] = [:]
    private var organizationShares: [String: CKShare] = [:]
    
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        print("🏢 CloudKitOrganizationSharingService initialized")
    }
    
    // MARK: - Zone Creation & Management
    
    /// Creates a custom zone for an organization
    func createOrganizationZone(for organizationID: String) -> AnyPublisher<CKRecordZone, Error> {
        let zoneName = "zone_org_\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        print("🏢 Creating organization zone: \(zoneName)")
        
        return Future<CKRecordZone, Error> { promise in
            let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
            
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success(let (savedZones, _)):
                    if let savedZone = savedZones.first {
                        self.organizationZones[organizationID] = savedZone
                        print("✅ Organization zone created: \(zoneName)")
                        promise(.success(savedZone))
                    } else {
                        promise(.failure(CloudKitSharingError.zoneCreationFailed))
                    }
                case .failure(let error):
                    print("❌ Failed to create organization zone: \(error)")
                    promise(.failure(error))
                }
            }
            
            self.privateDatabase.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    /// Fetches existing organization zones
    func fetchOrganizationZones() -> AnyPublisher<[CKRecordZone], Error> {
        return Future<[CKRecordZone], Error> { promise in
            self.privateDatabase.fetchAllRecordZones { zones, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                let orgZones = zones?.filter { zone in
                    zone.zoneID.zoneName.hasPrefix("zone_org_")
                } ?? []
                
                print("🏢 Found \(orgZones.count) organization zones")
                promise(.success(orgZones))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Organization Record Management
    
    /// Creates the root Organization record in its custom zone
    func createOrganizationRecord(
        organizationID: String,
        name: String,
        adminUserID: String,
        in zone: CKRecordZone
    ) -> AnyPublisher<CKRecord, Error> {
        
        let recordID = CKRecord.ID(recordName: organizationID, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Organization", recordID: recordID)
        
        // Set organization data
        record["name"] = name as CKRecordValue
        record["adminUserID"] = adminUserID as CKRecordValue
        record["members"] = [adminUserID] as CKRecordValue
        record["isActive"] = true as CKRecordValue
        record["maxMembers"] = 50 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        
        print("🏢 Creating organization record in zone: \(zone.zoneID.zoneName)")
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("❌ Failed to create organization record: \(error)")
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("✅ Organization record created: \(name)")
                    promise(.success(savedRecord))
                } else {
                    promise(.failure(CloudKitSharingError.recordCreationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Sharing Management
    
    /// Creates a CKShare for the organization zone
    func createOrganizationShare(
        for organizationRecord: CKRecord
    ) -> AnyPublisher<CKShare, Error> {
        
        let share = CKShare(rootRecord: organizationRecord)
        
        // Configure share permissions
        share[CKShare.SystemFieldKey.title] = organizationRecord["name"] as? String
        share.publicPermission = .none // Private sharing only
        
        print("🔗 Creating organization share for: \(organizationRecord.recordID.recordName)")
        
        return Future<CKShare, Error> { promise in
            let operation = CKModifyRecordsOperation(
                recordsToSave: [organizationRecord, share],
                recordIDsToDelete: nil
            )
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success(let (savedRecords, _)):
                    if let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare {
                        let orgID = organizationRecord.recordID.recordName
                        self.organizationShares[orgID] = savedShare
                        print("✅ Organization share created successfully")
                        promise(.success(savedShare))
                    } else {
                        promise(.failure(CloudKitSharingError.shareCreationFailed))
                    }
                case .failure(let error):
                    print("❌ Failed to create organization share: \(error)")
                    promise(.failure(error))
                }
            }
            
            self.privateDatabase.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    /// Adds a participant to an organization share
    func addParticipantToOrganization(
        email: String,
        organizationID: String,
        permission: CKShare.ParticipantPermission = .readWrite
    ) -> AnyPublisher<CKShare.Participant, Error> {
        
        guard let share = organizationShares[organizationID] else {
            return Fail(error: CloudKitSharingError.shareNotFound)
                .eraseToAnyPublisher()
        }
        
        print("👥 Adding participant \(email) to organization \(organizationID)")
        
        return Future<CKShare.Participant, Error> { promise in
            let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)
            
            self.container.discoverUserIdentity(withUserRecordID: nil, userIdentityLookupInfo: lookupInfo) { identity, error in
                if let error = error {
                    print("❌ Failed to discover user identity: \(error)")
                    promise(.failure(error))
                    return
                }
                
                guard let identity = identity else {
                    promise(.failure(CloudKitSharingError.userNotFound))
                    return
                }
                
                let participant = CKShare.Participant()
                participant.userIdentity = identity
                participant.permission = permission
                participant.role = .privateUser
                
                share.addParticipant(participant)
                
                // Save the updated share
                self.privateDatabase.save(share) { savedShare, saveError in
                    if let saveError = saveError {
                        print("❌ Failed to save updated share: \(saveError)")
                        promise(.failure(saveError))
                    } else {
                        print("✅ Participant \(email) added to organization share")
                        promise(.success(participant))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Complete Organization Setup
    
    /// Creates a complete organization with zone, record, and share
    func setupCompleteOrganization(
        organizationID: String,
        name: String,
        adminUserID: String
    ) -> AnyPublisher<(organization: CKRecord, share: CKShare), Error> {
        
        return createOrganizationZone(for: organizationID)
            .flatMap { zone in
                self.createOrganizationRecord(
                    organizationID: organizationID,
                    name: name,
                    adminUserID: adminUserID,
                    in: zone
                )
            }
            .flatMap { organizationRecord in
                self.createOrganizationShare(for: organizationRecord)
                    .map { share in
                        (organization: organizationRecord, share: share)
                    }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Project Zone Management
    
    /// Saves a project record to the organization's zone
    func saveProjectToOrganizationZone(
        project: Project,
        organizationID: String
    ) -> AnyPublisher<CKRecord, Error> {
        
        guard let zone = organizationZones[organizationID] else {
            return Fail(error: CloudKitSharingError.zoneNotFound)
                .eraseToAnyPublisher()
        }
        
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        // Map project data to CloudKit record
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["startDate"] = project.startDate as CKRecordValue
        record["endDate"] = project.endDate as CKRecordValue
        record["status"] = project.status.rawValue as CKRecordValue
        record["organizationID"] = organizationID as CKRecordValue
        
        // Store full project data as backup
        if let projectData = try? JSONEncoder().encode(project) {
            record["fullProjectData"] = projectData as CKRecordValue
        }
        
        print("📋 Saving project '\(project.name)' to organization zone")
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("❌ Failed to save project: \(error)")
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("✅ Project saved to organization zone")
                    promise(.success(savedRecord))
                } else {
                    promise(.failure(CloudKitSharingError.recordCreationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Share URL Generation
    
    /// Generates a shareable URL for an organization
    func generateShareURL(for organizationID: String) -> URL? {
        guard let share = organizationShares[organizationID] else {
            print("❌ No share found for organization: \(organizationID)")
            return nil
        }
        
        print("🔗 Generated share URL for organization: \(organizationID)")
        return share.url
    }
    
    // MARK: - Acceptance of Shares
    
    /// Accepts an organization share from a URL
    func acceptOrganizationShare(from url: URL) -> AnyPublisher<CKShare.Metadata, Error> {
        return Future<CKShare.Metadata, Error> { promise in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            
            operation.perShareMetadataResultBlock = { url, result in
                switch result {
                case .success(let metadata):
                    // Accept the share
                    let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
                    
                    acceptOperation.perShareResultBlock = { metadata, result in
                        switch result {
                        case .success(let share):
                            print("✅ Successfully accepted organization share")
                            promise(.success(metadata))
                        case .failure(let error):
                            print("❌ Failed to accept share: \(error)")
                            promise(.failure(error))
                        }
                    }
                    
                    self.container.add(acceptOperation)
                    
                case .failure(let error):
                    print("❌ Failed to fetch share metadata: \(error)")
                    promise(.failure(error))
                }
            }
            
            self.container.add(operation)
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Sharing Errors
enum CloudKitSharingError: LocalizedError {
    case zoneCreationFailed
    case zoneNotFound
    case recordCreationFailed
    case shareCreationFailed
    case shareNotFound
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .zoneCreationFailed:
            return "Failed to create organization zone"
        case .zoneNotFound:
            return "Organization zone not found"
        case .recordCreationFailed:
            return "Failed to create organization record"
        case .shareCreationFailed:
            return "Failed to create organization share"
        case .shareNotFound:
            return "Organization share not found"
        case .userNotFound:
            return "User not found for sharing"
        }
    }
}