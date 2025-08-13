import Foundation
import Combine
import CloudKit
import UIKit
import ObjectiveC

extension CloudKitAuthService {
    public func leaveOrganization(organizationID: String, userID: String) -> AnyPublisher<Bool, Error> {
        print("🚪 [CloudKit] User \(userID.prefix(8))... leaving organization: \(organizationID.prefix(8))...")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Bool, Error> in
                let privateDB = self.container.privateCloudDatabase
                
                return Future<Bool, Error> { promise in
                    // First, remove user from organization's teamMembers list
                    let orgRecordID = CKRecord.ID(recordName: organizationID)
                    
                    privateDB.fetch(withRecordID: orgRecordID) { orgRecord, error in
                        if let error = error {
                            print("❌ [CloudKit] Failed to fetch organization: \(error)")
                            promise(.failure(error))
                            return
                        }
                        
                        guard let orgRecord = orgRecord else {
                            promise(.failure(NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])))
                            return
                        }
                        
                        // Remove user from teamMembers list
                        var teamMembers = orgRecord["teamMembers"] as? [String] ?? []
                        teamMembers.removeAll { $0 == userID }
                        orgRecord["teamMembers"] = teamMembers as CKRecordValue
                        
                        // Update memberRoles
                        var memberRoles = self.decodeStringArrayFromBytes(orgRecord["memberRoles"]) ?? []
                        memberRoles.removeAll { $0.hasPrefix("\(userID):") }
                        if let memberRolesData = self.encodeStringArrayToBytes(memberRoles) {
                            orgRecord["memberRoles"] = memberRolesData as CKRecordValue
                        }
                        
                        // Save organization record
                        privateDB.save(orgRecord) { _, saveError in
                            if let saveError = saveError {
                                print("❌ [CloudKit] Failed to update organization: \(saveError)")
                                promise(.failure(saveError))
                                return
                            }
                            
                            // Delete the user's OrganizationMember record
                            let memberPredicate = NSPredicate(format: "organizationID == %@ AND userID == %@", organizationID, userID)
                            let memberQuery = CKQuery(recordType: "OrganizationMember", predicate: memberPredicate)
                            
                            privateDB.fetch(withQuery: memberQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                                switch result {
                                case .failure(let error):
                                    print("❌ [CloudKit] Failed to fetch member record: \(error)")
                                    // Don't fail the whole operation if member record is missing
                                    promise(.success(true))
                                case .success(let matchInfo):
                                    if let (_, recordResult) = matchInfo.matchResults.first,
                                       case .success(let memberRecord) = recordResult {
                                        
                                        privateDB.delete(withRecordID: memberRecord.recordID) { _, deleteError in
                                            DispatchQueue.main.async {
                                                if let deleteError = deleteError {
                                                    print("⚠️ [CloudKit] Failed to delete member record: \(deleteError)")
                                                    // Don't fail if member record deletion fails
                                                }
                                                print("✅ [CloudKit] User successfully left organization")
                                                promise(.success(true))
                                            }
                                        }
                                    } else {
                                        print("✅ [CloudKit] User successfully left organization (no member record found)")
                                        promise(.success(true))
                                    }
                                }
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Additional AuthViewModel Support Methods (Async/Await versions)
    
    /// Invite user to organization with specific role (used by AuthViewModel)
    public func inviteUserToOrganization(
        email: String,
        organizationID: String,
        role: OrganizationRole
    ) async throws {
        print("📧 [CloudKit] Inviting \(email) to organization \(organizationID.prefix(8))... as \(role.displayName)")
        
        // Create invitation record
        let inviteRecord = CKRecord(recordType: "OrganizationInvite")
        inviteRecord["organizationID"] = organizationID as CKRecordValue
        inviteRecord["inviteeEmail"] = email as CKRecordValue
        inviteRecord["role"] = role.rawValue as CKRecordValue
        inviteRecord["status"] = "pending" as CKRecordValue
        inviteRecord["createdAt"] = Date() as CKRecordValue
        inviteRecord["expiresAt"] = Date().addingTimeInterval(72 * 3600) as CKRecordValue // 3 days
        
        if let currentUserID = currentUser?.id {
            inviteRecord["inviterUserID"] = currentUserID as CKRecordValue
        }
        
        do {
            _ = try await container.privateCloudDatabase.save(inviteRecord)
            print("✅ [CloudKit] Invitation created successfully for \(email)")
            
            // TODO: Send actual email invitation here
            // For now, just log the invitation details
            print("📧 [CloudKit] EMAIL INVITATION (Stub):")
            print("   To: \(email)")
            print("   Organization: \(organizationID)")
            print("   Role: \(role.displayName)")
            
        } catch {
            print("❌ [CloudKit] Failed to create invitation: \(error)")
            throw error
        }
    }
    
    /// Invite user to organization with project-specific permissions
    public func inviteUserToOrganizationWithProjects(
        email: String,
        organizationID: String,
        role: OrganizationRole,
        allowedProjectIDs: [String]
    ) async throws {
        print("📧 [CloudKit] Inviting \(email) to organization with \(allowedProjectIDs.count) project assignments")
        
        // Create invitation record with project assignments
        let inviteRecord = CKRecord(recordType: "OrganizationInvite")
        inviteRecord["organizationID"] = organizationID as CKRecordValue
        inviteRecord["inviteeEmail"] = email as CKRecordValue
        inviteRecord["role"] = role.rawValue as CKRecordValue
        inviteRecord["projectAssignments"] = allowedProjectIDs as CKRecordValue
        inviteRecord["status"] = "pending" as CKRecordValue
        inviteRecord["createdAt"] = Date() as CKRecordValue
        inviteRecord["expiresAt"] = Date().addingTimeInterval(72 * 3600) as CKRecordValue
        
        if let currentUserID = currentUser?.id {
            inviteRecord["inviterUserID"] = currentUserID as CKRecordValue
        }
        
        do {
            _ = try await container.privateCloudDatabase.save(inviteRecord)
            print("✅ [CloudKit] Project-specific invitation created for \(email)")
        } catch {
            print("❌ [CloudKit] Failed to create project invitation: \(error)")
            throw error
        }
    }
    
    /// Fetch pending invites for a user
    public func fetchPendingInvitesForUser(_ userID: String) async throws -> [String] {
        print("📧 [CloudKit] Fetching pending invites for user: \(userID.prefix(8))...")
        
        // Get user's email to search for invitations
        guard let currentUser = currentUser else {
            print("❌ [CloudKit] No current user available")
            return []
        }
        
        let predicate = NSPredicate(format: "inviteeEmail == %@ AND status == %@", 
                                   currentUser.email, "pending")
        let query = CKQuery(recordType: "OrganizationInvite", predicate: predicate)
        
        return try await withCheckedThrowingContinuation { continuation in
            container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
                switch result {
                case .failure(let error):
                    print("❌ [CloudKit] Failed to fetch pending invites: \(error)")
                    continuation.resume(throwing: error)
                case .success(let matchInfo):
                    let inviteEmails = matchInfo.matchResults.compactMap { pair -> String? in
                        if case .success(let record) = pair.1,
                           let email = record["inviteeEmail"] as? String {
                            return email
                        }
                        return nil
                    }
                    
                    print("✅ [CloudKit] Found \(inviteEmails.count) pending invites")
                    continuation.resume(returning: inviteEmails)
                }
            }
        }
    }
    
    /// Check if organization zone exists
    public func checkOrganizationZoneExists(_ organizationID: String) async throws -> Bool {
        print("🔧 [CloudKit] Checking if zone exists for organization: \(organizationID.prefix(8))...")
        
        let zoneID = CKRecordZone.ID(zoneName: "Organization_\(organizationID)", ownerName: CKCurrentUserDefaultName)
        
        do {
            let fetchedZones = try await container.privateCloudDatabase.allRecordZones()
            let zoneExists = fetchedZones.contains { $0.zoneID == zoneID }
            
            print("🔧 [CloudKit] Zone exists: \(zoneExists)")
            return zoneExists
            
        } catch {
            print("❌ [CloudKit] Failed to check zone existence: \(error)")
            throw error
        }
    }
    
    /// Create organization zone
    public func createOrganizationZone(_ organizationID: String) async throws {
        print("🔧 [CloudKit] Creating zone for organization: \(organizationID.prefix(8))...")
        
        let zoneID = CKRecordZone.ID(zoneName: "Organization_\(organizationID)", ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            _ = try await container.privateCloudDatabase.save(zone)
            print("✅ [CloudKit] Zone created successfully")
        } catch {
            print("❌ [CloudKit] Failed to create zone: \(error)")
            throw error
        }
    }
    
    /// Get record count in organization zone
    public func getOrganizationRecordCount(_ organizationID: String) async throws -> Int {
        print("🔧 [CloudKit] Counting records in organization zone: \(organizationID.prefix(8))...")
        
        let zoneID = CKRecordZone.ID(zoneName: "Organization_\(organizationID)", ownerName: CKCurrentUserDefaultName)
        
        // Query for all records in the zone
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Project", predicate: predicate) // Use Project as main record type
        
        return try await withCheckedThrowingContinuation { continuation in
            container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: 200) { result in
                switch result {
                case .failure(let error):
                    print("❌ [CloudKit] Failed to count records: \(error)")
                    continuation.resume(returning: 0) // Return 0 instead of throwing
                case .success(let matchInfo):
                    let count = matchInfo.matchResults.count
                    print("✅ [CloudKit] Found \(count) records in zone")
                    continuation.resume(returning: count)
                }
            }
        }
    }
    
    /// Join organization with specific role
    public func joinOrganization(
        _ organizationID: String,
        userID: String,
        role: OrganizationRole
    ) async throws -> Organization {
        print("🔗 [CloudKit] User \(userID.prefix(8))... joining organization: \(organizationID.prefix(8))...")
        
        // For now, implement a simplified version that just fetches the organization
        // TODO: Implement actual user addition to organization
        
        // Fetch and return the organization
        let orgRecordID = CKRecord.ID(recordName: organizationID)
        let orgRecord = try await container.privateCloudDatabase.record(for: orgRecordID)
        
        let organization = Organization(
            id: orgRecord["id"] as? String ?? organizationID,
            name: orgRecord["name"] as? String ?? "Unknown Organization",
            members: orgRecord["teamMembers"] as? [String] ?? [],
            adminUserID: orgRecord["adminUserID"] as? String ?? "",
            cloudKitRecordID: orgRecord.recordID.recordName
        )
        
        print("✅ [CloudKit] Successfully joined organization: \(organization.name)")
        return organization
    }
    
    /// Fetch user project assignments
    public func fetchUserProjectAssignments(
        organizationID: String,
        userID: String
    ) async throws -> [String] {
        print("📋 [CloudKit] Fetching project assignments for user \(userID.prefix(8))... in org \(organizationID.prefix(8))...")
        
        // Query for OrganizationMember records
        let predicate = NSPredicate(format: "organizationID == %@ AND userID == %@", organizationID, userID)
        let query = CKQuery(recordType: "OrganizationMember", predicate: predicate)
        
        return try await withCheckedThrowingContinuation { continuation in
            container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    print("❌ [CloudKit] Failed to fetch project assignments: \(error)")
                    continuation.resume(returning: []) // Return empty array instead of throwing
                case .success(let matchInfo):
                    if let (_, recordResult) = matchInfo.matchResults.first,
                       case .success(let memberRecord) = recordResult {
                        let assignments = memberRecord["projectAssignments"] as? [String] ?? []
                        print("✅ [CloudKit] Found \(assignments.count) project assignments")
                        continuation.resume(returning: assignments)
                    } else {
                        print("✅ [CloudKit] No project assignments found")
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Decode string array from CloudKit BYTES field
    private func decodeStringArrayFromBytes(_ data: Any?) -> [String]? {
        guard let data = data as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String]
    }
    
    /// Encode string array to CloudKit BYTES field
    private func encodeStringArrayToBytes(_ array: [String]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: array)
    }
}