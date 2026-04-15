import Foundation
import Combine
import CloudKit
import OSLog

/// Enhanced organization service with unique name validation and subscription management
@MainActor
public class OrganizationService: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private let zoneManager: CloudKitZoneManager?
    
    // MARK: - Published Properties
    @Published public var organizations: [Organization] = []
    @Published public var currentOrganization: Organization?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // MARK: - Initialization
    public init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3", organizationID: String? = nil) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        self.zoneManager = organizationID != nil ? CloudKitZoneManager(organizationID: organizationID!) : nil
        
        Logger.organizationService.info(
            "Initialized OrganizationService [container=\(containerIdentifier, privacy: .private(mask: .hash)) hasZoneManager=\(organizationID != nil, privacy: .public)]"
        )
        
        // Set up zone if organization ID is provided
        if let orgID = organizationID {
            Task {
                try? await zoneManager?.setupOrganizationZones()
            }
        }
    }
    
    // MARK: - Name Validation
    
    /// Check if organization name is available (unique across all organizations)
    public func validateOrganizationName(_ name: String) async throws -> NameValidationResult {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return NameValidationResult(isAvailable: false, message: "Organization name cannot be empty")
        }
        
        guard name.count >= 3 else {
            return NameValidationResult(isAvailable: false, message: "Organization name must be at least 3 characters")
        }
        
        guard name.count <= 50 else {
            return NameValidationResult(isAvailable: false, message: "Organization name cannot exceed 50 characters")
        }
        
        // Check for invalid characters
        let allowedCharacterSet = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_."))
        guard name.rangeOfCharacter(from: allowedCharacterSet.inverted) == nil else {
            return NameValidationResult(isAvailable: false, message: "Organization name contains invalid characters")
        }
        
        // Check uniqueness in public database
        let slug = generateSlug(from: name)
        return try await checkNameAvailability(name: name, slug: slug)
    }
    
    private func checkNameAvailability(name: String, slug: String) async throws -> NameValidationResult {
        // Check both exact name and slug in public database
        let namePredicate = NSPredicate(format: "name == %@", name)
        let slugPredicate = NSPredicate(format: "slug == %@", slug)
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [namePredicate, slugPredicate])
        
        let query = CKQuery(recordType: "OrganizationRegistry", predicate: compoundPredicate)
        
        do {
            let result = try await sharedDatabase.records(matching: query)
            let existingRecords = result.matchResults.compactMap { try? $0.1.get() }
            
            if !existingRecords.isEmpty {
                return NameValidationResult(isAvailable: false, message: "This organization name is already taken")
            } else {
                return NameValidationResult(isAvailable: true, message: "Organization name is available", suggestedSlug: slug)
            }
        } catch {
            throw OrganizationServiceError.validationFailed("Unable to validate name: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Organization Creation (New Async Method)
    
    /// Create a new organization with unique name validation
    public func createOrganization(
        name: String,
        adminUserID: String,
        industry: String? = nil,
        subscriptionTier: SubscriptionTier = .free
    ) async throws -> Organization {
        
        isLoading = true
        defer { isLoading = false }
        
        // First validate the name
        let validationResult = try await validateOrganizationName(name)
        guard validationResult.isAvailable else {
            throw OrganizationServiceError.nameNotAvailable(validationResult.message)
        }
        
        let organizationID = UUID().uuidString
        let slug = validationResult.suggestedSlug ?? generateSlug(from: name)
        
        // Create organization in private database
        let organization = Organization(
            id: organizationID,
            name: name,
            members: [adminUserID],
            adminUserID: adminUserID,
            industry: industry,
            subscriptionTier: subscriptionTier
        )
        
        // Save to private database
        let privateRecord = createPrivateOrganizationRecord(from: organization, slug: slug)
        let savedPrivateRecord = try await privateDatabase.save(privateRecord)
        
        // Register name in public database for uniqueness
        let registryRecord = createOrganizationRegistryRecord(
            organizationID: organizationID,
            name: name,
            slug: slug,
            adminUserID: adminUserID
        )
        try await sharedDatabase.save(registryRecord)
        
        // Update organization with CloudKit info
        var finalOrganization = organization
        finalOrganization.cloudKitRecordID = savedPrivateRecord.recordID.recordName
        
        // Add to local cache
        organizations.append(finalOrganization)
        currentOrganization = finalOrganization
        
        Logger.organizationService.notice(
            "Created organization successfully [name=\(name, privacy: .private(mask: .hash)) slug=\(slug, privacy: .private(mask: .hash))]"
        )
        return finalOrganization
    }
    
    // MARK: - Organization Management (New Async Methods)
    
    /// Fetch organizations for current user
    public func fetchUserOrganizations(userID: String) async throws -> [Organization] {
        isLoading = true
        defer { isLoading = false }
        
        let predicate = NSPredicate(format: "members CONTAINS %@", userID)
        let query = CKQuery(recordType: "Organization", predicate: predicate)
        
        let result = try await privateDatabase.records(matching: query)
        
        let fetchedOrganizations = result.matchResults.compactMap { (recordID, result) in
            switch result {
            case .success(let record):
                return parseOrganizationFromRecord(record)
            case .failure(let error):
                Logger.organizationService.error(
                    "Failed to fetch organization during user lookup [error=\(error.localizedDescription, privacy: .public)]"
                )
                return nil
            }
        }
        
        organizations = fetchedOrganizations
        if currentOrganization == nil && !organizations.isEmpty {
            currentOrganization = organizations.first
        }
        
        return fetchedOrganizations
    }
    
    /// Update organization information
    public func updateOrganization(_ organization: Organization) async throws -> Organization {
        guard let recordID = organization.cloudKitRecordID else {
            throw OrganizationServiceError.invalidOrganization("Organization missing CloudKit record ID")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let ckRecordID = CKRecord.ID(recordName: recordID)
        let record = try await privateDatabase.record(for: ckRecordID)
        
        // Update record fields
        updateRecordFromOrganization(record, organization: organization)
        
        let savedRecord = try await privateDatabase.save(record)
        let updatedOrganization = parseOrganizationFromRecord(savedRecord)
        
        // Update local cache
        if let index = organizations.firstIndex(where: { $0.id == organization.id }) {
            organizations[index] = updatedOrganization
        }
        
        if currentOrganization?.id == organization.id {
            currentOrganization = updatedOrganization
        }
        
        return updatedOrganization
    }
    
    // MARK: - Member Management
    
    /// Add member to organization
    public func addMemberToOrganization(organizationID: String, userID: String) async throws {
        guard let orgIndex = organizations.firstIndex(where: { $0.id == organizationID }) else {
            throw OrganizationServiceError.organizationNotFound
        }
        
        var organization = organizations[orgIndex]
        guard organization.canAddMoreMembers else {
            throw OrganizationServiceError.memberLimitReached
        }
        
        guard !organization.members.contains(userID) else {
            throw OrganizationServiceError.memberAlreadyExists
        }
        
        organization.members.append(userID)
        organization.lastModified = Date()
        
        let updatedOrg = try await updateOrganization(organization)
        organizations[orgIndex] = updatedOrg
    }
    
    /// Remove member from organization
    public func removeMemberFromOrganization(organizationID: String, userID: String) async throws {
        guard let orgIndex = organizations.firstIndex(where: { $0.id == organizationID }) else {
            throw OrganizationServiceError.organizationNotFound
        }
        
        var organization = organizations[orgIndex]
        guard organization.adminUserID != userID else {
            throw OrganizationServiceError.cannotRemoveAdmin
        }
        
        guard let memberIndex = organization.members.firstIndex(of: userID) else {
            throw OrganizationServiceError.memberNotFound
        }
        
        organization.members.remove(at: memberIndex)
        organization.lastModified = Date()
        
        let updatedOrg = try await updateOrganization(organization)
        organizations[orgIndex] = updatedOrg
    }
    
    // MARK: - Team Member Management (CloudKit Integration)
    
    /// Save team members to CloudKit for the current organization
    public func saveTeamMembersToCloudKit(_ teamMembers: [TeamMember]) async throws {
        guard let zoneManager = zoneManager else {
            throw OrganizationServiceError.invalidOrganization("Zone manager not initialized")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await zoneManager.saveTeamMembers(teamMembers)
        Logger.organizationService.notice(
            "Saved team members to CloudKit [count=\(teamMembers.count, privacy: .public)]"
        )
    }
    
    /// Load team members from CloudKit for the current organization
    public func loadTeamMembersFromCloudKit() async throws -> [TeamMember] {
        guard let zoneManager = zoneManager else {
            throw OrganizationServiceError.invalidOrganization("Zone manager not initialized")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let teamMembers = try await zoneManager.loadTeamMembers()
        Logger.organizationService.notice(
            "Loaded team members from CloudKit [count=\(teamMembers.count, privacy: .public)]"
        )
        return teamMembers
    }
    
    // MARK: - Project Management (CloudKit Integration)
    
    /// Save a project to CloudKit for the current organization
    public func saveProjectToCloudKit(_ project: Project) async throws {
        guard let zoneManager = zoneManager else {
            throw OrganizationServiceError.invalidOrganization("Zone manager not initialized")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await zoneManager.saveProject(project)
        Logger.organizationService.notice(
            "Saved project to CloudKit [project=\(project.name, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Load all projects from CloudKit for the current organization
    public func loadProjectsFromCloudKit() async throws -> [Project] {
        guard let zoneManager = zoneManager else {
            throw OrganizationServiceError.invalidOrganization("Zone manager not initialized")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let projects = try await zoneManager.loadProjects()
        Logger.organizationService.notice(
            "Loaded projects from CloudKit [count=\(projects.count, privacy: .public)]"
        )
        return projects
    }
    
    // MARK: - Helper Methods
    
    private func generateSlug(from name: String) -> String {
        return name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private func createPrivateOrganizationRecord(from organization: Organization, slug: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: organization.id)
        let record = CKRecord(recordType: "Organization", recordID: recordID)
        
        record["name"] = organization.name as CKRecordValue
        record["slug"] = slug as CKRecordValue
        record["members"] = organization.members as CKRecordValue
        record["adminUserID"] = organization.adminUserID as CKRecordValue
        record["industry"] = organization.industry as CKRecordValue?
        record["isActive"] = organization.isActive as CKRecordValue
        record["createdAt"] = organization.createdAt as CKRecordValue
        record["lastModified"] = organization.lastModified as CKRecordValue
        record["subscriptionTier"] = organization.subscriptionTier.rawValue as CKRecordValue
        record["maxMembers"] = organization.maxMembers as CKRecordValue
        record["storageQuotaMB"] = organization.storageQuotaMB as CKRecordValue
        
        return record
    }
    
    private func createOrganizationRegistryRecord(
        organizationID: String,
        name: String,
        slug: String,
        adminUserID: String
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "registry_\(organizationID)")
        let record = CKRecord(recordType: "OrganizationRegistry", recordID: recordID)
        
        record["organizationID"] = organizationID as CKRecordValue
        record["name"] = name as CKRecordValue
        record["slug"] = slug as CKRecordValue
        record["adminUserID"] = adminUserID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        
        return record
    }
    
    private func parseOrganizationFromRecord(_ record: CKRecord) -> Organization {
        let organization = Organization(
            id: record.recordID.recordName,
            name: record["name"] as? String ?? "",
            members: record["members"] as? [String] ?? [],
            adminUserID: record["adminUserID"] as? String ?? "",
            industry: record["industry"] as? String,
            isActive: record["isActive"] as? Bool ?? true,
            createdAt: record["createdAt"] as? Date ?? Date(),
            cloudKitRecordID: record.recordID.recordName
        )
        
        return organization
    }
    
    private func updateRecordFromOrganization(_ record: CKRecord, organization: Organization) {
        record["name"] = organization.name as CKRecordValue
        record["members"] = organization.members as CKRecordValue
        record["adminUserID"] = organization.adminUserID as CKRecordValue
        record["industry"] = organization.industry as CKRecordValue?
        record["isActive"] = organization.isActive as CKRecordValue
        record["lastModified"] = organization.lastModified as CKRecordValue
        record["subscriptionTier"] = organization.subscriptionTier.rawValue as CKRecordValue
        record["maxMembers"] = organization.maxMembers as CKRecordValue
        record["storageQuotaMB"] = organization.storageQuotaMB as CKRecordValue
    }
}

// MARK: - Legacy Combine-based Methods (for backwards compatibility)

extension OrganizationService: OrganizationServiceProtocol {
    func createOrganization(name: String, adminUserID: String) -> AnyPublisher<Organization, Error> {
        return Future<Organization, Error> { promise in
            Task {
                do {
                    let org = try await self.createOrganization(
                        name: name, 
                        adminUserID: adminUserID, 
                        industry: nil, 
                        subscriptionTier: .free
                    )
                    promise(.success(org))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchOrganizations(for userID: String) -> AnyPublisher<[Organization], Error> {
        return Future<[Organization], Error> { promise in
            Task {
                do {
                    let orgs = try await self.fetchUserOrganizations(userID: userID)
                    promise(.success(orgs))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func inviteUserToOrganization(email: String, organizationID: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // This would integrate with your email service
            // For now, just simulate success
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateOrganization(_ organization: Organization) -> AnyPublisher<Organization, Error> {
        return Future<Organization, Error> { promise in
            Task {
                do {
                    let updatedOrg = try await self.updateOrganization(organization)
                    promise(.success(updatedOrg))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteOrganization(id: String) -> AnyPublisher<Void, Error> {
        let recordID = CKRecord.ID(recordName: id)
        
        return Future<Void, Error> { promise in
            self.privateDatabase.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

public enum NameValidationStatus {
    case unknown
    case checking
    case available
    case unavailable
}

public struct NameValidationResult {
    public let isAvailable: Bool
    public let message: String
    public let suggestedSlug: String?
    
    public init(isAvailable: Bool, message: String, suggestedSlug: String? = nil) {
        self.isAvailable = isAvailable
        self.message = message
        self.suggestedSlug = suggestedSlug
    }
}

public enum OrganizationServiceError: LocalizedError {
    case nameNotAvailable(String)
    case validationFailed(String)
    case invalidOrganization(String)
    case organizationNotFound
    case memberLimitReached
    case memberAlreadyExists
    case memberNotFound
    case cannotRemoveAdmin
    
    public var errorDescription: String? {
        switch self {
        case .nameNotAvailable(let message):
            return message
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .invalidOrganization(let message):
            return "Invalid organization: \(message)"
        case .organizationNotFound:
            return "Organization not found"
        case .memberLimitReached:
            return "Member limit reached for this organization"
        case .memberAlreadyExists:
            return "User is already a member of this organization"
        case .memberNotFound:
            return "User is not a member of this organization"
        case .cannotRemoveAdmin:
            return "Cannot remove the organization administrator"
        }
    }
}

// Legacy type for backwards compatibility
typealias CloudKitOrganizationService = OrganizationService

/// Dedicated service for organization management operations
protocol OrganizationServiceProtocol {
    func createOrganization(name: String, adminUserID: String) -> AnyPublisher<Organization, Error>
    func fetchOrganizations(for userID: String) -> AnyPublisher<[Organization], Error>
    func inviteUserToOrganization(email: String, organizationID: String) -> AnyPublisher<Void, Error>
    func updateOrganization(_ organization: Organization) -> AnyPublisher<Organization, Error>
    func deleteOrganization(id: String) -> AnyPublisher<Void, Error>
}
