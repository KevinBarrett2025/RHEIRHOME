import Foundation
import Combine
import CloudKit
import OSLog

extension Logger {
    static let scalableCloudKit = Logger(subsystem: "com.RheirHome.RHEIR", category: "scalableCloudKit")
}

// MARK: - Scalable Multi-Tenant CloudKit Architecture

/// Enterprise-grade CloudKit architecture for multi-tenant SaaS
/// Supports thousands of organizations with complete data isolation
class ScalableCloudKitArchitecture: ObservableObject {
    
    // MARK: - Architecture Overview
    /*
     ORGANIZATION-BASED MULTI-TENANCY ARCHITECTURE:
     
     1. ORGANIZATION ZONES (Custom CloudKit Zones)
        - Each organization gets its own CloudKit zone
        - Zone name: "org_{organizationId}_{environment}"
        - Complete data isolation between organizations
        - Automatic zone creation on organization setup
     
     2. HIERARCHICAL DATA STRUCTURE:
        Organization (Root Record in Private DB)
        ├── OrganizationZone (Custom Zone)
        │   ├── OrganizationData (Company info, settings)
        │   ├── Employees (Shared across org projects)
        │   ├── Vendors (Company-wide vendor directory)
        │   ├── PaymentMethods (Company payment methods)
        │   ├── Clients (Company client directory)
        │   └── Projects (Organization projects)
        │       ├── ProjectData (Project details)
        │       ├── Receipts (Project receipts)
        │       ├── ProgressLogs (Project progress)
        │       ├── WorkHours (Logged hours)
        │       ├── Tasks (Project tasks)
        │       └── Photos (Project photos as CKAssets)
     
     3. SHARING MODEL:
        - Organization Admin creates organization + zone
        - Admin invites team members via CloudKit sharing
        - All team members get read/write access to organization zone
        - Real-time sync within organization
        - Zero access to other organizations' data
     
     4. SCALING CONSIDERATIONS:
        - Supports thousands of organizations
        - Each organization isolated in separate zones
        - Efficient querying with zone-specific operations
        - Automatic cleanup and archiving for inactive orgs
        - Performance monitoring and optimization
     */
    
    // MARK: - Core Properties
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Organization management
    @Published var currentOrganization: Organization?
    @Published var currentOrganizationZone: CKRecordZone?
    @Published var organizationShare: CKShare?
    
    // Tenant isolation
    private var organizationZones: [String: CKRecordZone] = [:]
    private var organizationShares: [String: CKShare] = [:]
    
    // Environment management
    private var environment: CloudKitEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        
        Logger.scalableCloudKit.info("Initialized scalable multi-tenant CloudKit architecture.")
    }
    
    // MARK: - 1. Organization Zone Management
    
    /// Creates a new organization with dedicated zone and sharing
    func createOrganization(
        name: String,
        adminUserID: String,
        industry: String? = nil,
        settings: OrganizationSettings? = nil
    ) -> AnyPublisher<(organization: Organization, zone: CKRecordZone, share: CKShare), Error> {
        
        let organizationId = UUID().uuidString
        Logger.scalableCloudKit.info(
            "Creating organization in scalable CloudKit architecture [organization=\(organizationId, privacy: .private(mask: .hash)), name=\(name, privacy: .private(mask: .hash))]"
        )
        
        return createOrganizationZone(for: organizationId)
            .flatMap { zone in
                self.createOrganizationRecord(
                    id: organizationId,
                    name: name,
                    adminUserID: adminUserID,
                    industry: industry,
                    settings: settings,
                    in: zone
                )
                .map { orgRecord in (orgRecord, zone) }
            }
            .flatMap { (orgRecord, zone) in
                self.createOrganizationShare(for: orgRecord, in: zone)
                    .map { share in
                        let organization = self.recordToOrganization(orgRecord)
                        return (organization: organization, zone: zone, share: share)
                    }
            }
            .handleEvents(receiveOutput: { [weak self] result in
                // Cache the organization data locally
                self?.currentOrganization = result.organization
                self?.currentOrganizationZone = result.zone
                self?.organizationShare = result.share
                self?.organizationZones[organizationId] = result.zone
                self?.organizationShares[organizationId] = result.share
            })
            .eraseToAnyPublisher()
    }
    
    private func createOrganizationZone(for organizationId: String) -> AnyPublisher<CKRecordZone, Error> {
        let zoneName = "org_\(organizationId)_\(environment.rawValue)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        Logger.scalableCloudKit.info(
            "Creating scalable organization zone [organization=\(organizationId, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash)), environment=\(environment.rawValue, privacy: .public)]"
        )
        
        return Future<CKRecordZone, Error> { promise in
            // Check if zone already exists
            self.privateDatabase.fetch(withRecordZoneID: zoneID) { existingZone, error in
                if let existingZone = existingZone {
                    Logger.scalableCloudKit.notice(
                        "Scalable organization zone already exists [organization=\(organizationId, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
                    )
                    promise(.success(existingZone))
                    return
                }
                
                // Create new zone
                let operation = CKModifyRecordZonesOperation(
                    recordZonesToSave: [zone],
                    recordZoneIDsToDelete: nil
                )
                
                operation.modifyRecordZonesResultBlock = { result in
                    switch result {
                    case .success(let (savedZones, _)):
                        if let savedZone = savedZones.first {
                            Logger.scalableCloudKit.notice(
                                "Created scalable organization zone [organization=\(organizationId, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
                            )
                            promise(.success(savedZone))
                        } else {
                            promise(.failure(CloudKitArchitectureError.zoneCreationFailed))
                        }
                    case .failure(let error):
                        Logger.scalableCloudKit.error(
                            "Failed to create scalable organization zone [organization=\(organizationId, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                        )
                        promise(.failure(error))
                    }
                }
                
                self.privateDatabase.add(operation)
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func createOrganizationRecord(
        id: String,
        name: String,
        adminUserID: String,
        industry: String?,
        settings: OrganizationSettings?,
        in zone: CKRecordZone
    ) -> AnyPublisher<CKRecord, Error> {
        
        let recordID = CKRecord.ID(recordName: id, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Organization", recordID: recordID)
        
        // Organization metadata
        record["name"] = name as CKRecordValue
        record["adminUserID"] = adminUserID as CKRecordValue
        record["industry"] = industry as CKRecordValue?
        record["environment"] = environment.rawValue as CKRecordValue
        record["isActive"] = true as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        // Organization settings
        if let settings = settings,
           let settingsData = try? JSONEncoder().encode(settings) {
            record["settings"] = settingsData as CKRecordValue
        }
        
        // Tenant isolation metadata
        record["tenantIsolationLevel"] = "ZONE_ISOLATED" as CKRecordValue
        record["dataResidency"] = "US" as CKRecordValue // Configurable
        
        Logger.scalableCloudKit.info(
            "Creating organization record in scalable CloudKit zone [organization=\(id, privacy: .private(mask: .hash)), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    Logger.scalableCloudKit.error(
                        "Failed to create scalable organization record [organization=\(id, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    Logger.scalableCloudKit.notice(
                        "Created scalable organization record [organization=\(id, privacy: .private(mask: .hash))]"
                    )
                    promise(.success(savedRecord))
                } else {
                    promise(.failure(CloudKitArchitectureError.recordCreationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func createOrganizationShare(
        for orgRecord: CKRecord,
        in zone: CKRecordZone
    ) -> AnyPublisher<CKShare, Error> {
        
        let share = CKShare(rootRecord: orgRecord)
        
        // Configure enterprise sharing settings
        share[CKShare.SystemFieldKey.title] = orgRecord["name"] as? String
        share[CKShare.SystemFieldKey.shareTitle] = "Join \(orgRecord["name"] as? String ?? "Organization")"
        share.publicPermission = .none // Private sharing only
        
        Logger.scalableCloudKit.info(
            "Creating scalable organization share [organization=\(orgRecord.recordID.recordName, privacy: .private(mask: .hash)), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKShare, Error> { promise in
            let operation = CKModifyRecordsOperation(
                recordsToSave: [orgRecord, share],
                recordIDsToDelete: nil
            )
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success(let (savedRecords, _)):
                    if let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare {
                        Logger.scalableCloudKit.notice(
                            "Created scalable organization share [organization=\(orgRecord.recordID.recordName, privacy: .private(mask: .hash))]"
                        )
                        promise(.success(savedShare))
                    } else {
                        promise(.failure(CloudKitArchitectureError.shareCreationFailed))
                    }
                case .failure(let error):
                    Logger.scalableCloudKit.error(
                        "Failed to create scalable organization share [organization=\(orgRecord.recordID.recordName, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                }
            }
            
            self.privateDatabase.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 2. Organization Data Management
    
    /// Saves organization-wide data (employees, vendors, clients, payment methods)
    func saveOrganizationData<T: Codable>(
        _ data: T,
        recordType: String,
        recordName: String? = nil
    ) -> AnyPublisher<CKRecord, Error> {
        
        guard let zone = currentOrganizationZone,
              let orgId = currentOrganization?.id else {
            return Fail(error: CloudKitArchitectureError.organizationNotSet)
                .eraseToAnyPublisher()
        }
        
        let finalRecordName = recordName ?? UUID().uuidString
        let recordID = CKRecord.ID(recordName: finalRecordName, zoneID: zone.zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        // Set organization reference
        record["organizationId"] = orgId as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        // Encode data as JSON for flexibility
        if let dataJson = try? JSONEncoder().encode(data) {
            record["data"] = dataJson as CKRecordValue
        }
        
        Logger.scalableCloudKit.info(
            "Saving organization-scoped record to scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public)]"
        )
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    Logger.scalableCloudKit.error(
                        "Failed to save organization-scoped record in scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    Logger.scalableCloudKit.notice(
                        "Saved organization-scoped record in scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public)]"
                    )
                    promise(.success(savedRecord))
                } else {
                    promise(.failure(CloudKitArchitectureError.recordCreationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Loads organization-wide data by type
    func loadOrganizationData<T: Codable>(
        recordType: String,
        dataType: T.Type
    ) -> AnyPublisher<[T], Error> {
        
        guard let zone = currentOrganizationZone,
              let orgId = currentOrganization?.id else {
            return Fail(error: CloudKitArchitectureError.organizationNotSet)
                .eraseToAnyPublisher()
        }
        
        let predicate = NSPredicate(format: "organizationId == %@", orgId)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        Logger.scalableCloudKit.info(
            "Loading organization-scoped records from scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public)]"
        )
        
        return Future<[T], Error> { promise in
            self.privateDatabase.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: ["data"], resultsLimit: 1000) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    let decodedData = records.compactMap { record -> T? in
                        guard let dataJson = record["data"] as? Data,
                              let decoded = try? JSONDecoder().decode(dataType, from: dataJson) else {
                            return nil
                        }
                        return decoded
                    }
                    
                    Logger.scalableCloudKit.notice(
                        "Loaded organization-scoped records from scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public), count=\(decodedData.count, privacy: .public)]"
                    )
                    promise(.success(decodedData))
                    
                case .failure(let error):
                    Logger.scalableCloudKit.error(
                        "Failed to load organization-scoped records from scalable zone [organization=\(orgId, privacy: .private(mask: .hash)), recordType=\(recordType, privacy: .public), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 3. Project Data Management
    
    /// Saves project data to organization zone
    func saveProject(_ project: Project) -> AnyPublisher<CKRecord, Error> {
        guard let zone = currentOrganizationZone,
              let orgId = currentOrganization?.id else {
            return Fail(error: CloudKitArchitectureError.organizationNotSet)
                .eraseToAnyPublisher()
        }
        
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        // Project metadata
        record["organizationId"] = orgId as CKRecordValue
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["status"] = project.status.rawValue as CKRecordValue
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["startDate"] = project.startDate as CKRecordValue
        record["endDate"] = project.endDate as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        // Full project data as JSON backup
        if let projectData = try? JSONEncoder().encode(project) {
            record["fullProjectData"] = projectData as CKRecordValue
        }
        
        Logger.scalableCloudKit.info(
            "Saving project in scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKRecord, Error> { promise in
            self.privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    Logger.scalableCloudKit.error(
                        "Failed to save project in scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                } else if let savedRecord = savedRecord {
                    Logger.scalableCloudKit.notice(
                        "Saved project in scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash)), project=\(project.name, privacy: .private(mask: .hash))]"
                    )
                    promise(.success(savedRecord))
                } else {
                    promise(.failure(CloudKitArchitectureError.recordCreationFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Loads all projects for current organization
    func loadOrganizationProjects() -> AnyPublisher<[Project], Error> {
        guard let zone = currentOrganizationZone,
              let orgId = currentOrganization?.id else {
            return Fail(error: CloudKitArchitectureError.organizationNotSet)
                .eraseToAnyPublisher()
        }
        
        let predicate = NSPredicate(format: "organizationId == %@", orgId)
        let query = CKQuery(recordType: "Project", predicate: predicate)
        
        Logger.scalableCloudKit.info(
            "Loading projects from scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash))]"
        )
        
        return Future<[Project], Error> { promise in
            self.privateDatabase.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: 1000) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    let projects = records.compactMap { record -> Project? in
                        // Try to decode from full project data first
                        if let projectData = record["fullProjectData"] as? Data,
                           let project = try? JSONDecoder().decode(Project.self, from: projectData) {
                            return project
                        }
                        
                        // Fallback to basic project construction
                        return self.recordToProject(record)
                    }
                    
                    Logger.scalableCloudKit.notice(
                        "Loaded projects from scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash)), count=\(projects.count, privacy: .public)]"
                    )
                    promise(.success(projects))
                    
                case .failure(let error):
                    Logger.scalableCloudKit.error(
                        "Failed to load projects from scalable organization zone [organization=\(orgId, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 4. Team Management & Sharing
    
    /// Invites a user to join the organization
    func inviteUserToOrganization(email: String) -> AnyPublisher<CKShare.Participant, Error> {
        guard let share = organizationShare else {
            return Fail(error: CloudKitArchitectureError.shareNotFound)
                .eraseToAnyPublisher()
        }
        
        Logger.scalableCloudKit.info(
            "Inviting user to scalable organization share [invitee=\(email, privacy: .private(mask: .hash))]"
        )
        
        return Future<CKShare.Participant, Error> { promise in
            let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)
            
            self.container.discoverUserIdentity(
                withUserRecordID: nil,
                userIdentityLookupInfo: lookupInfo
            ) { identity, error in
                if let error = error {
                    Logger.scalableCloudKit.error(
                        "Failed to discover CloudKit identity for organization invite [invitee=\(email, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                    return
                }
                
                guard let identity = identity else {
                    promise(.failure(CloudKitArchitectureError.userNotFound))
                    return
                }
                
                let participant = CKShare.Participant()
                participant.userIdentity = identity
                participant.permission = .readWrite
                participant.role = .privateUser
                
                share.addParticipant(participant)
                
                // Save updated share
                self.privateDatabase.save(share) { savedShare, saveError in
                    if let saveError = saveError {
                        Logger.scalableCloudKit.error(
                            "Failed to add participant to scalable organization share [invitee=\(email, privacy: .private(mask: .hash)), error=\(saveError.localizedDescription, privacy: .public)]"
                        )
                        promise(.failure(saveError))
                    } else {
                        Logger.scalableCloudKit.notice(
                            "Invited user to scalable organization share [invitee=\(email, privacy: .private(mask: .hash))]"
                        )
                        promise(.success(participant))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Accepts an organization share invitation
    func acceptOrganizationInvitation(from url: URL) -> AnyPublisher<Organization, Error> {
        Logger.scalableCloudKit.info("Accepting scalable organization share invitation.")
        
        return Future<Organization, Error> { promise in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            
            operation.perShareMetadataResultBlock = { url, result in
                switch result {
                case .success(let metadata):
                    let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
                    
                    acceptOperation.perShareResultBlock = { metadata, acceptResult in
                        switch acceptResult {
                        case .success(let share):
                            // Extract organization info from accepted share
                            if let rootRecord = share.rootRecord {
                                let organization = self.recordToOrganization(rootRecord)
                                self.currentOrganization = organization
                                self.organizationShare = share
                                
                                // Set up organization zone reference
                                self.currentOrganizationZone = CKRecordZone(zoneID: rootRecord.recordID.zoneID)
                                
                                Logger.scalableCloudKit.notice(
                                    "Accepted scalable organization share invitation [organization=\(organization.id, privacy: .private(mask: .hash)), name=\(organization.name, privacy: .private(mask: .hash))]"
                                )
                                promise(.success(organization))
                            } else {
                                promise(.failure(CloudKitArchitectureError.invalidShare))
                            }
                            
                        case .failure(let error):
                            Logger.scalableCloudKit.error(
                                "Failed to accept scalable organization share invitation [error=\(error.localizedDescription, privacy: .public)]"
                            )
                            promise(.failure(error))
                        }
                    }
                    
                    self.container.add(acceptOperation)
                    
                case .failure(let error):
                    Logger.scalableCloudKit.error(
                        "Failed to fetch scalable organization share metadata [error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                }
            }
            
            self.container.add(operation)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 5. Performance & Monitoring
    
    /// Gets organization performance metrics
    func getOrganizationMetrics() -> AnyPublisher<OrganizationMetrics, Error> {
        guard let zone = currentOrganizationZone,
              let orgId = currentOrganization?.id else {
            return Fail(error: CloudKitArchitectureError.organizationNotSet)
                .eraseToAnyPublisher()
        }
        
        Logger.scalableCloudKit.info(
            "Gathering scalable organization metrics [organization=\(orgId, privacy: .private(mask: .hash))]"
        )
        
        return Future<OrganizationMetrics, Error> { promise in
            var metrics = OrganizationMetrics(organizationId: orgId)
            let group = DispatchGroup()
            
            // Count projects
            group.enter()
            let projectQuery = CKQuery(recordType: "Project", predicate: NSPredicate(format: "organizationId == %@", orgId))
            self.privateDatabase.fetch(withQuery: projectQuery, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: 1000) { result in
                switch result {
                case .success(let (matchResults, _)):
                    metrics.totalProjects = matchResults.count
                case .failure:
                    metrics.totalProjects = 0
                }
                group.leave()
            }
            
            // Count employees
            group.enter()
            let employeeQuery = CKQuery(recordType: "Employee", predicate: NSPredicate(format: "organizationId == %@", orgId))
            self.privateDatabase.fetch(withQuery: employeeQuery, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: 100) { result in
                switch result {
                case .success(let (matchResults, _)):
                    metrics.totalEmployees = matchResults.count
                case .failure:
                    metrics.totalEmployees = 0
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                metrics.lastUpdated = Date()
                Logger.scalableCloudKit.notice(
                    "Gathered scalable organization metrics [organization=\(orgId, privacy: .private(mask: .hash)), projects=\(metrics.totalProjects, privacy: .public), employees=\(metrics.totalEmployees, privacy: .public)]"
                )
                promise(.success(metrics))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 6. Utility Methods
    
    private func recordToOrganization(_ record: CKRecord) -> Organization {
        let id = record.recordID.recordName
        let name = record["name"] as? String ?? "Unknown Organization"
        let adminUserID = record["adminUserID"] as? String ?? ""
        let industry = record["industry"] as? String
        let isActive = record["isActive"] as? Bool ?? true
        let createdAt = record["createdAt"] as? Date ?? Date()
        
        return Organization(
            id: id,
            name: name,
            adminUserID: adminUserID,
            industry: industry,
            isActive: isActive,
            createdAt: createdAt,
            cloudKitRecordID: id
        )
    }
    
    private func recordToProject(_ record: CKRecord) -> Project? {
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
    
    /// Gets the organization share URL for invitations
    func getOrganizationShareURL() -> URL? {
        return organizationShare?.url
    }
    
    /// Checks if user is organization admin
    func isCurrentUserAdmin() -> Bool {
        guard let org = currentOrganization,
              let currentUserID = getCurrentUserID() else {
            return false
        }
        return org.adminUserID == currentUserID
    }
    
    private func getCurrentUserID() -> String? {
        // This would integrate with your authentication system
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
}

// MARK: - Supporting Types

enum CloudKitEnvironment: String {
    case development = "dev"
    case production = "prod"
}

struct OrganizationSettings: Codable {
    var timeZone: String = "America/New_York"
    var currency: String = "USD"
    var dataRetentionDays: Int = 2555 // 7 years
    var autoArchiveInactiveProjects: Bool = true
    var requirePhotoApproval: Bool = false
    var allowGuestAccess: Bool = false
}

struct OrganizationMetrics: Codable {
    let organizationId: String
    var totalProjects: Int = 0
    var totalEmployees: Int = 0
    var totalReceipts: Int = 0
    var totalProgressLogs: Int = 0
    var totalWorkHours: Double = 0
    var totalBudget: Double = 0
    var storageUsedMB: Double = 0
    var lastUpdated: Date = Date()
}

enum CloudKitArchitectureError: LocalizedError {
    case organizationNotSet
    case zoneCreationFailed
    case recordCreationFailed
    case shareCreationFailed
    case shareNotFound
    case userNotFound
    case invalidShare
    
    var errorDescription: String? {
        switch self {
        case .organizationNotSet:
            return "No organization is currently set"
        case .zoneCreationFailed:
            return "Failed to create organization zone"
        case .recordCreationFailed:
            return "Failed to create record"
        case .shareCreationFailed:
            return "Failed to create share"
        case .shareNotFound:
            return "Organization share not found"
        case .userNotFound:
            return "User not found for invitation"
        case .invalidShare:
            return "Invalid share data"
        }
    }
}
