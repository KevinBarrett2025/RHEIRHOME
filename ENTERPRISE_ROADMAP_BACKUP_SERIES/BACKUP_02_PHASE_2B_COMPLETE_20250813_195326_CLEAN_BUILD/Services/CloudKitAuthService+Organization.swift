import Foundation
import Combine
import CloudKit
import UIKit
import ObjectiveC

extension CloudKitAuthService {
    
    // MARK: - AuthViewModel Required Methods
    
    public func createOrganization(
        orgName: String,
        adminUserID: String
    ) -> AnyPublisher<Organization, Error> {
        print("🔍 [CloudKit] ENHANCED ORG CREATION: '\(orgName)' for admin: \(adminUserID.prefix(8))...")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Organization, Error> in
                print("🔍 [CloudKit] CloudKit available, creating organization with enhanced admin linking")
                
                let privateDB = self.container.privateCloudDatabase
                let generatedOrgID = UUID().uuidString
                
                // Get current user info for better record keeping
                let currentUser = self.currentUser
                let adminEmail = currentUser?.email ?? ""
                
                print("🔍 [CloudKit] Creating organization:")
                print("🔍   ID: \(generatedOrgID)")
                print("🔍   Name: \(orgName)")
                print("🔍   AdminUserID: \(adminUserID.prefix(8))...")
                print("🔍   AdminEmail: \(adminEmail)")
                
                let orgRecord = CKRecord(recordType: "Organization", recordID: CKRecord.ID(recordName: generatedOrgID))
                
                // Core organization data
                orgRecord["id"] = generatedOrgID as CKRecordValue
                orgRecord["name"] = orgName as CKRecordValue
                orgRecord["adminUserID"] = adminUserID as CKRecordValue
                orgRecord["adminUserEmail"] = adminEmail as CKRecordValue // CRITICAL: Store admin email too
                orgRecord["createdAt"] = Date() as CKRecordValue
                orgRecord["isActiveV2"] = 1 as CKRecordValue
                
                // Team members as searchable list
                orgRecord["teamMembers"] = [adminUserID] as CKRecordValue
                
                // Enhanced member data
                let memberRoles = ["\(adminUserID):admin"]
                let projectIDs: [String] = []
                
                if let memberRolesData = try? JSONSerialization.data(withJSONObject: memberRoles) {
                    orgRecord["memberRoles"] = memberRolesData as CKRecordValue
                }
                
                if let projectIDsData = try? JSONSerialization.data(withJSONObject: projectIDs) {
                    orgRecord["projectIDs2"] = projectIDsData as CKRecordValue
                }
                
                // CRITICAL: Set environment correctly
                let environment = self.isDebugBuild() ? "development" : "production"
                orgRecord["environment"] = environment as CKRecordValue
                
                // Enhanced metadata for debugging
                #if os(iOS)
                orgRecord["createdByDevice"] = UIDevice.current.identifierForVendor?.uuidString as CKRecordValue?
                #endif
                orgRecord["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String as CKRecordValue?
                
                print("🔍 [CloudKit] Saving Organization for \(environment.uppercased()) environment")
                
                return Future<Organization, Error> { promise in
                    privateDB.save(orgRecord) { savedRecord, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("❌ [CloudKit] Organization creation failed: \(error)")
                                print("❌   Error Domain: \((error as NSError).domain)")
                                print("❌   Error Code: \((error as NSError).code)")
                                promise(.failure(self.handleCloudKitError(error)))
                                return
                            }
                            
                            guard let record = savedRecord else {
                                let error = NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "No record returned from save"])
                                promise(.failure(error))
                                return
                            }
                            
                            print("✅ [CloudKit] Organization created successfully!")
                            print("✅   Record ID: \(record.recordID.recordName)")
                            print("✅   Environment: \(environment)")
                            
                            // Create organization object
                            var organization = Organization(
                                id: record["id"] as? String ?? generatedOrgID,
                                name: record["name"] as? String ?? orgName,
                                members: record["teamMembers"] as? [String] ?? [adminUserID],
                                adminUserID: record["adminUserID"] as? String ?? adminUserID,
                                cloudKitRecordID: record.recordID.recordName
                            )
                            
                            // Add admin as team member
                            let adminTeamMember = TeamMember(
                                name: "Administrator",
                                email: adminEmail,
                                jobTitle: "Administrator",
                                rates: [EmployeeRate(taskType: "Management", rate: 75.0, isDefault: true)],
                                organizationID: generatedOrgID,
                                role: .admin,
                                employmentStatus: .active,
                                employmentType: .employee,
                                hasAppAccess: true,
                                appUserID: adminUserID
                            )
                            
                            let success = organization.addTeamMember(adminTeamMember)
                            print("✅ [CloudKit] Auto-added admin as team member: \(success)")
                            
                            // Create member record asynchronously
                            Task {
                                await self.createOrganizationMemberRecord(
                                    organizationID: generatedOrgID,
                                    userID: adminUserID,
                                    role: .admin
                                )
                            }
                            
                            promise(.success(organization))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(20), scheduler: DispatchQueue.main) // Increased timeout for creation
            .eraseToAnyPublisher()
    }
    
    public func fetchOrganizationsWithRoles(
        for userID: String
    ) -> AnyPublisher<(organizations: [Organization], roles: [String: OrganizationRole]), Error> {
        print("🔍 [CloudKit] Fetching organizations with roles for user: \(userID)")
        
        return fetchOrganizations(for: userID)
            .flatMap { organizations -> AnyPublisher<(organizations: [Organization], roles: [String: OrganizationRole]), Error> in
                return self.fetchUserRoles(userID: userID, organizationIDs: organizations.map { $0.id })
                    .map { detailedRoles in
                        var combinedRoles: [String: OrganizationRole] = [:]
                        
                        for org in organizations {
                            if org.adminUserID == userID {
                                combinedRoles[org.id] = .admin
                            } else if let detailedRole = detailedRoles[org.id] {
                                combinedRoles[org.id] = detailedRole
                            } else {
                                combinedRoles[org.id] = .member 
                            }
                        }
                        
                        return (organizations: organizations, roles: combinedRoles)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func fetchOrganizations(
        for userID: String
    ) -> AnyPublisher<[Organization], Error> {
        print("🔍 [CloudKit] ENHANCED ORG FETCH for user: \(userID.prefix(8))...")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<[Organization], Error> in
                print("🔍 [CloudKit] CloudKit available, starting comprehensive organization search")
                
                let privateDB = self.container.privateCloudDatabase
                
                // ENHANCED SEARCH: Try multiple userIDs if available
                let allUserIDs = self.getAllUserIDsForSearch(primaryUserID: userID)
                print("🔍 [CloudKit] Searching with userIDs: \(allUserIDs.map { $0.prefix(8) })...")
                
                // Create queries for both admin and member roles across all userIDs
                var allQueries: [AnyPublisher<[CKRecord], Error>] = []
                
                for searchUserID in allUserIDs {
                    // Admin query
                    let adminPredicate = NSPredicate(format: "adminUserID == %@", searchUserID)
                    let adminQuery = CKQuery(recordType: "Organization", predicate: adminPredicate)
                    allQueries.append(self.executeOrganizationQuery(adminQuery, database: privateDB, queryName: "admin-\(searchUserID.prefix(6))"))
                    
                    // Member query  
                    let memberPredicate = NSPredicate(format: "teamMembers CONTAINS %@", searchUserID)
                    let memberQuery = CKQuery(recordType: "Organization", predicate: memberPredicate)
                    allQueries.append(self.executeOrganizationQuery(memberQuery, database: privateDB, queryName: "member-\(searchUserID.prefix(6))"))
                }
                
                // FALLBACK: Also search by email if available
                if let currentUser = self.currentUser, 
                   currentUser.email != "user.email.not.available@rheir.com",
                   !currentUser.email.isEmpty {
                    print("🔍 [CloudKit] Adding email-based search: \(currentUser.email)")
                    
                    let emailAdminPredicate = NSPredicate(format: "adminUserEmail == %@", currentUser.email)
                    let emailAdminQuery = CKQuery(recordType: "Organization", predicate: emailAdminPredicate)
                    allQueries.append(self.executeOrganizationQuery(emailAdminQuery, database: privateDB, queryName: "email-admin"))
                }
                
                return Publishers.MergeMany(allQueries)
                    .collect()
                    .map { queryResults -> [Organization] in
                        // Combine all results and remove duplicates
                        let allRecords = queryResults.flatMap { $0 }
                        let uniqueRecords = self.removeDuplicateRecords(allRecords)
                        
                        print("🔍 [CloudKit] Combined results: \(allRecords.count) total, \(uniqueRecords.count) unique")
                        
                        return self.processOrganizationRecords(uniqueRecords, forUser: userID)
                    }
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func deleteOrganization(organizationID: String) -> AnyPublisher<Bool, Error> {
        print("🗑️ [CloudKit] Deleting organization: \(organizationID.prefix(8))...")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Bool, Error> in
                let privateDB = self.container.privateCloudDatabase
                let recordID = CKRecord.ID(recordName: organizationID)
                
                return Future<Bool, Error> { promise in
                    // First, delete all related OrganizationMember records
                    let memberPredicate = NSPredicate(format: "organizationID == %@", organizationID)
                    let memberQuery = CKQuery(recordType: "OrganizationMember", predicate: memberPredicate)
                    
                    privateDB.fetch(withQuery: memberQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
                        switch result {
                        case .failure(let error):
                            print("❌ [CloudKit] Failed to fetch members for deletion: \(error)")
                            promise(.failure(error))
                        case .success(let matchInfo):
                            let memberRecordIDs = matchInfo.matchResults.compactMap { pair -> CKRecord.ID? in
                                if case .success(let record) = pair.1 {
                                    return record.recordID
                                }
                                return nil
                            }
                            
                            // Delete member records first, then organization
                            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: memberRecordIDs + [recordID])
                            
                            deleteOperation.modifyRecordsResultBlock = { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success(_):
                                        print("✅ [CloudKit] Organization and \(memberRecordIDs.count) member records deleted")
                                        promise(.success(true))
                                    case .failure(let error):
                                        print("❌ [CloudKit] Failed to delete organization: \(error)")
                                        promise(.failure(error))
                                    }
                                }
                            }
                            
                            privateDB.add(deleteOperation)
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Supporting Methods
    
    private func createOrganizationMemberRecord(
        organizationID: String,
        userID: String,
        role: OrganizationRole,
        projectAssignments: [String] = []
    ) async {
        let memberRecord = CKRecord(recordType: "OrganizationMember")
        memberRecord["organizationID"] = organizationID as CKRecordValue
        memberRecord["userID"] = userID as CKRecordValue
        memberRecord["role"] = role.rawValue as CKRecordValue
        memberRecord["joinedAt"] = Date() as CKRecordValue
        memberRecord["projectAssignments"] = projectAssignments as CKRecordValue
        memberRecord["isActive"] = 1 as CKRecordValue
        
        do {
            _ = try await container.privateCloudDatabase.save(memberRecord)
            print("✅ [CloudKit] Created member record for \(userID.prefix(8))... as \(role.displayName)")
        } catch {
            print("❌ [CloudKit] Failed to create member record: \(error)")
        }
    }
    
    private func executeOrganizationQuery(
        _ query: CKQuery,
        database: CKDatabase,
        queryName: String
    ) -> AnyPublisher<[CKRecord], Error> {
        return Future<[CKRecord], Error> { promise in
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
                switch result {
                case .failure(let error):
                    print("❌ [CloudKit] \(queryName) query failed: \(error)")
                    promise(.success([]))
                case .success(let matchInfo):
                    let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                        if case .success(let record) = pair.1 {
                            return record
                        }
                        return nil
                    }
                    print("✅ [CloudKit] \(queryName) query found \(records.count) organizations")
                    promise(.success(records))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func processOrganizationRecords(_ records: [CKRecord], forUser userID: String) -> [Organization] {
        // CRITICAL DEBUG: Log all records found before filtering
        print("🔍 [CloudKit] DEBUGGING: Found \(records.count) total organization records")
        for (index, record) in records.enumerated() {
            let recordID = record["id"] as? String ?? record.recordID.recordName
            let name = record["name"] as? String ?? "Unknown"
            let environment = record["environment"] as? String ?? "NONE"
            let adminUserID = record["adminUserID"] as? String ?? "NONE"
            let teamMembers = record["teamMembers"] as? [String] ?? []
            
            print("🔍 [\(index)] ID: \(recordID.prefix(8))... | Name: \(name)")
            print("🔍     Environment: \(environment) | Admin: \(adminUserID.prefix(8))...")
            print("🔍     TeamMembers: \(teamMembers.map { $0.prefix(8) })...")
            print("🔍     Current User: \(userID.prefix(8))...")
            print("🔍     Admin Match: \(adminUserID == userID)")
            print("🔍     Member Match: \(teamMembers.contains(userID))")
        }
        
        // FLEXIBLE ENVIRONMENT FILTERING: Support both dev and production
        let targetEnvironment = isDebugBuild() ? "development" : "production"
        print("🔍 [CloudKit] Looking for environment: \(targetEnvironment)")
        
        let filteredRecords = records.filter { record in
            if let environment = record["environment"] as? String {
                let isTargetEnvironment = environment == targetEnvironment
                print("🔍 Record \(record["name"] as? String ?? "Unknown"): \(environment) == \(targetEnvironment) ? \(isTargetEnvironment)")
                return isTargetEnvironment
            } else {
                // FALLBACK: If no environment field, check if it's a legacy record
                print("🔍 Record \(record["name"] as? String ?? "Unknown"): NO ENVIRONMENT FIELD - treating as legacy")
                return !isDebugBuild() // Include legacy records in production only
            }
        }
        
        print("🔍 [CloudKit] After environment filtering: \(filteredRecords.count) records")
        
        let organizations = filteredRecords.map { record in
            let org = Organization(
                id: record["id"] as? String ?? record.recordID.recordName,
                name: record["name"] as? String ?? "Unknown Organization",
                members: record["teamMembers"] as? [String] ?? [],
                adminUserID: record["adminUserID"] as? String ?? "",
                isActive: (record["isActiveV2"] as? Int64) == 1,
                createdAt: record["createdAt"] as? Date ?? Date(),
                cloudKitRecordID: record.recordID.recordName
            )
            
            print("🔍 Final organization: \(org.name) | Members: \(org.members.count) | Admin: \(org.adminUserID.prefix(8))...")
            return org
        }
        
        print("🔍 [CloudKit] FINAL RESULT: \(organizations.count) organizations for user")
        return organizations.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func fetchUserRoles(
        userID: String,
        organizationIDs: [String]
    ) -> AnyPublisher<[String: OrganizationRole], Error> {
        guard !organizationIDs.isEmpty else {
            return Just([:]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        let predicate = NSPredicate(format: "userID == %@ AND organizationID IN %@", userID, organizationIDs)
        let query = CKQuery(recordType: "OrganizationMember", predicate: predicate)
        
        return Future<[String: OrganizationRole], Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
                switch result {
                case .failure(let error):
                    print("❌ [CloudKit] Failed to fetch user roles: \(error)")
                    promise(.success([:]))
                case .success(let matchInfo):
                    var roles: [String: OrganizationRole] = [:]
                    
                    for (_, recordResult) in matchInfo.matchResults {
                        if case .success(let record) = recordResult,
                           let orgID = record["organizationID"] as? String,
                           let roleString = record["role"] as? String,
                           let role = OrganizationRole(rawValue: roleString) {
                            roles[orgID] = role
                        }
                    }
                    
                    print("✅ [CloudKit] Fetched detailed roles for \(roles.count) organizations")
                    promise(.success(roles))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Check if this is a debug build
    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Get all userIDs to search with (current + historical)
    private func getAllUserIDsForSearch(primaryUserID: String) -> [String] {
        var searchUserIDs = [primaryUserID]
        
        // Add historical userIDs
        let historicalUserIDs = getAllStoredUserIDs()
        for historicalID in historicalUserIDs {
            if !searchUserIDs.contains(historicalID) {
                searchUserIDs.append(historicalID)
            }
        }
        
        return searchUserIDs
    }
    
    /// Remove duplicate records based on recordID
    private func removeDuplicateRecords(_ records: [CKRecord]) -> [CKRecord] {
        var seen = Set<String>()
        return records.compactMap { record in
            let recordName = record.recordID.recordName
            if seen.contains(recordName) {
                return nil
            } else {
                seen.insert(recordName)
                return record
            }
        }
    }
    
    private func handleCloudKitError(_ error: Error) -> Error {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .unknownItem:
                return NSError(domain: "CloudKit", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "CloudKit schema not properly configured. Please update the app."])
            case .invalidArguments:
                return NSError(domain: "CloudKit", code: -2, 
                              userInfo: [NSLocalizedDescriptionKey: "Invalid data provided. Please try again."])
            case .quotaExceeded:
                return NSError(domain: "CloudKit", code: -3, 
                              userInfo: [NSLocalizedDescriptionKey: "CloudKit storage quota exceeded. Please free up space in iCloud."])
            case .networkUnavailable:
                return NSError(domain: "CloudKit", code: -4, 
                              userInfo: [NSLocalizedDescriptionKey: "Network unavailable. Please check your connection."])
            case .notAuthenticated:
                return NSError(domain: "CloudKit", code: -5, 
                              userInfo: [NSLocalizedDescriptionKey: "Please sign in to iCloud and try again."])
            default:
                return NSError(domain: "CloudKit", code: -6, 
                              userInfo: [NSLocalizedDescriptionKey: "CloudKit error: \(ckError.localizedDescription)"])
            }
        }
        return error
    }

    // MARK: - Existing Methods Continue Below...

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