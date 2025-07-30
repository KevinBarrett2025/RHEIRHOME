import Foundation
import Combine
import CloudKit

/// Enhanced organization service with unique name validation and subscription management
@MainActor
public class OrganizationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isLoading = false
    @Published public var validationStatus: NameValidationStatus = .unknown
    @Published public var organizations: [Organization] = []
    @Published public var currentOrganization: Organization?
    
    // MARK: - Private Properties
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase // For unique name validation
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV2") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
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
            let result = try await publicDB.records(matching: query)
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
        let savedPrivateRecord = try await privateDB.save(privateRecord)
        
        // Register name in public database for uniqueness
        let registryRecord = createOrganizationRegistryRecord(
            organizationID: organizationID,
            name: name,
            slug: slug,
            adminUserID: adminUserID
        )
        try await publicDB.save(registryRecord)
        
        // Update organization with CloudKit info
        var finalOrganization = organization
        finalOrganization.cloudKitRecordID = savedPrivateRecord.recordID.recordName
        
        // Add to local cache
        organizations.append(finalOrganization)
        currentOrganization = finalOrganization
        
        print("✅ Organization created successfully: \(name) (\(slug))")
        return finalOrganization
    }
    
    // MARK: - Organization Management (New Async Methods)
    
    /// Fetch organizations for current user
    public func fetchUserOrganizations(userID: String) async throws -> [Organization] {
        isLoading = true
        defer { isLoading = false }
        
        let predicate = NSPredicate(format: "members CONTAINS %@", userID)
        let query = CKQuery(recordType: "Organization", predicate: predicate)
        
        let result = try await privateDB.records(matching: query)
        
        let fetchedOrganizations = result.matchResults.compactMap { (recordID, result) in
            switch result {
            case .success(let record):
                return parseOrganizationFromRecord(record)
            case .failure(let error):
                print("❌ Error fetching organization: \(error)")
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
        let record = try await privateDB.record(for: ckRecordID)
        
        // Update record fields
        updateRecordFromOrganization(record, organization: organization)
        
        let savedRecord = try await privateDB.save(record)
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
            self.privateDB.delete(withRecordID: recordID) { _, error in
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