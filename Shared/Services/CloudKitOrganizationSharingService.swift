import Foundation
import Combine
import CloudKit
import OSLog
import SwiftUI

extension Logger {
    static let organizationSharing = Logger(subsystem: "com.RheirHome.RHEIR", category: "organizationSharing")
}

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
        Logger.organizationSharing.info("Initialized organization sharing service.")
    }
    
    // MARK: - Zone Creation & Management
    
    /// Creates a custom zone for an organization
    func createOrganizationZone(for organizationID: String) -> AnyPublisher<CKRecordZone, Error> {
        let zoneName = "zone_org_\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        Logger.organizationSharing.info(
            "Creating organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKRecordZone, Error> { promise in
            let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
            
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success(let (savedZones, _)):
                    if let savedZone = savedZones.first {
                        self.organizationZones[organizationID] = savedZone
                        Logger.organizationSharing.notice(
                            "Created organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
                        )
                        promise(.success(savedZone))
                    } else {
                        promise(.failure(CloudKitSharingError.zoneCreationFailed))
                    }
                case .failure(let error):
                    Logger.organizationSharing.error(
                        "Failed to create organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
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
                
                Logger.organizationSharing.notice(
                    "Fetched organization sharing zones [count=\(orgZones.count, privacy: .public)]"
                )
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
        
        Logger.organizationSharing.info(
            "Creating organization record in sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    Logger.organizationSharing.error(
                        "Failed to create organization record in sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    Logger.organizationSharing.notice(
                        "Created organization record in sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), name=\(name, privacy: .private(mask: .hash))]"
                    )
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
        
        Logger.organizationSharing.info(
            "Creating organization share [organization=\(organizationRecord.recordID.recordName, privacy: .private(mask: .hash))]"
        )
        
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
                        Logger.organizationSharing.notice(
                            "Created organization share [organization=\(orgID, privacy: .private(mask: .hash))]"
                        )
                        promise(.success(savedShare))
                    } else {
                        promise(.failure(CloudKitSharingError.shareCreationFailed))
                    }
                case .failure(let error):
                    Logger.organizationSharing.error(
                        "Failed to create organization share [organization=\(organizationRecord.recordID.recordName, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
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
        
        Logger.organizationSharing.info(
            "Adding participant to organization share [organization=\(organizationID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKShare.Participant, Error> { promise in
            let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)
            
            self.container.discoverUserIdentity(withUserRecordID: nil, userIdentityLookupInfo: lookupInfo) { identity, error in
                if let error = error {
                    Logger.organizationSharing.error(
                        "Failed to discover identity for organization participant [organization=\(organizationID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
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
                        Logger.organizationSharing.error(
                            "Failed to save updated organization share [organization=\(organizationID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash)), error=\(saveError.localizedDescription, privacy: .public)]"
                        )
                        promise(.failure(saveError))
                    } else {
                        Logger.organizationSharing.notice(
                            "Added participant to organization share [organization=\(organizationID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash))]"
                        )
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
        
        Logger.organizationSharing.info(
            "Saving project to organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    Logger.organizationSharing.error(
                        "Failed to save project to organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    Logger.organizationSharing.notice(
                        "Saved project to organization sharing zone [organization=\(organizationID, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
                    )
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
            Logger.organizationSharing.error(
                "No organization share found when generating URL [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
            return nil
        }
        
        Logger.organizationSharing.notice(
            "Generated share URL for organization [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
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
                        case .success:
                            Logger.organizationSharing.notice("Accepted organization share successfully.")
                            promise(.success(metadata))
                        case .failure(let error):
                            Logger.organizationSharing.error(
                                "Failed to accept organization share [error=\(error.localizedDescription, privacy: .public)]"
                            )
                            promise(.failure(error))
                        }
                    }
                    
                    self.container.add(acceptOperation)
                    
                case .failure(let error):
                    Logger.organizationSharing.error(
                        "Failed to fetch organization share metadata [error=\(error.localizedDescription, privacy: .public)]"
                    )
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
