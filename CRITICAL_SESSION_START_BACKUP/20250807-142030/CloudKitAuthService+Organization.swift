import Foundation
import Combine
import CloudKit
import UIKit

extension CloudKitAuthService {
    
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
            print(" [CloudKit] Created member record for \(userID.prefix(8))... as \(role.displayName)")
        } catch {
            print(" [CloudKit] Failed to create member record: \(error)")
        }
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
    
    private func executeOrganizationQuery(
        _ query: CKQuery,
        database: CKDatabase,
        queryName: String
    ) -> AnyPublisher<[CKRecord], Error> {
        return Future<[CKRecord], Error> { promise in
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
                switch result {
                case .failure(let error):
                    print(" [CloudKit] \(queryName) query failed: \(error)")
                    promise(.success([]))
                case .success(let matchInfo):
                    let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                        if case .success(let record) = pair.1 {
                            return record
                        }
                        return nil
                    }
                    print(" [CloudKit] \(queryName) query found \(records.count) organizations")
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
    
    /// Check if this is a debug build
    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    public func addUserToOrganization(
        userID: String,
        organizationID: String,
        role: OrganizationRole = .member,
        projectAssignments: [String] = []
    ) -> AnyPublisher<Void, Error> {
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Void, Error> in
                let privateDB = self.container.privateCloudDatabase
                let recordID = CKRecord.ID(recordName: organizationID)
                
                return Future<Void, Error> { promise in
                    privateDB.fetch(withRecordID: recordID) { record, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        
                        guard let orgRecord = record else {
                            promise(.failure(NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])))
                            return
                        }
                        
                        // Update teamMembers (List<String> field)
                        var teamMembers = orgRecord["teamMembers"] as? [String] ?? []
                        if !teamMembers.contains(userID) {
                            teamMembers.append(userID)
                            orgRecord["teamMembers"] = teamMembers as CKRecordValue
                        }
                        
                        // Update memberRoles (BYTES field)
                        var memberRoles = self.decodeStringArrayFromBytes(orgRecord["memberRoles"]) ?? []
                        let roleEntry = "\(userID):\(role.rawValue)"
                        
                        memberRoles.removeAll { $0.hasPrefix("\(userID):") }
                        memberRoles.append(roleEntry)
                        if let memberRolesData = self.encodeStringArrayToBytes(memberRoles) {
                            orgRecord["memberRoles"] = memberRolesData as CKRecordValue
                        }
                        
                        privateDB.save(orgRecord) { _, saveError in
                            if let saveError = saveError {
                                promise(.failure(saveError))
                                return
                            }
                            
                            Task {
                                await self.createOrganizationMemberRecord(
                                    organizationID: organizationID,
                                    userID: userID,
                                    role: role,
                                    projectAssignments: projectAssignments
                                )
                                
                                DispatchQueue.main.async {
                                    promise(.success(()))
                                }
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(10), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func fetchOrganizationsWithRoles(
        for userID: String
    ) -> AnyPublisher<(organizations: [Organization], roles: [String: OrganizationRole]), Error> {
        print(" [CloudKit] Fetching organizations with roles for user: \(userID)")
        
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
                    print(" [CloudKit] Failed to fetch user roles: \(error)")
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
                    
                    print(" [CloudKit] Fetched detailed roles for \(roles.count) organizations")
                    promise(.success(roles))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func joinOrganizationWithRole(
        orgID: String,
        userID: String,
        role: OrganizationRole
    ) -> AnyPublisher<Organization, Error> {
        print(" [CloudKit] Joining organization \(orgID) as \(role.displayName)")
        
        return addUserToOrganization(userID: userID, organizationID: orgID, role: role)
            .flatMap { _ -> AnyPublisher<Organization, Error> in
                let recordID = CKRecord.ID(recordName: orgID)
                return Future<Organization, Error> { promise in
                    self.container.privateCloudDatabase.fetch(withRecordID: recordID) { record, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        
                        guard let orgRecord = record else {
                            promise(.failure(NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])))
                            return
                        }
                        
                        let organization = Organization(
                            id: orgRecord["id"] as? String ?? orgRecord.recordID.recordName,
                            name: orgRecord["name"] as? String ?? "Unknown Organization",
                            members: orgRecord["teamMembers"] as? [String] ?? [],
                            adminUserID: orgRecord["adminUserID"] as? String ?? "",
                            cloudKitRecordID: orgRecord.recordID.recordName
                        )
                        
                        promise(.success(organization))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func assignMemberToProjects(
        userID: String,
        organizationID: String,
        projectIDs: [String]
    ) -> AnyPublisher<Void, Error> {
        print(" [CloudKit] Assigning member \(userID.prefix(8))... to \(projectIDs.count) projects")
        
        let predicate = NSPredicate(format: "userID == %@ AND organizationID == %@", userID, organizationID)
        let query = CKQuery(recordType: "OrganizationMember", predicate: predicate)
        
        return Future<Void, Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let matchInfo):
                    if let (_, recordResult) = matchInfo.matchResults.first,
                       case .success(let memberRecord) = recordResult {
                        memberRecord["projectAssignments"] = projectIDs as CKRecordValue
                        
                        self.container.privateCloudDatabase.save(memberRecord) { _, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    promise(.failure(error))
                                } else {
                                    print(" [CloudKit] Updated project assignments for member")
                                    promise(.success(()))
                                }
                            }
                        }
                    } else {
                        promise(.failure(NSError(domain: "CloudKit", code: -1, 
                                               userInfo: [NSLocalizedDescriptionKey: "Member record not found"])))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func fetchProjectAssignments(
        for userID: String,
        organizationID: String
    ) -> AnyPublisher<[String], Error> {
        let predicate = NSPredicate(format: "userID == %@ AND organizationID == %@", userID, organizationID)
        let query = CKQuery(recordType: "OrganizationMember", predicate: predicate)
        
        return Future<[String], Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    print(" [CloudKit] Failed to fetch project assignments: \(error)")
                    promise(.success([])) 
                case .success(let matchInfo):
                    if let (_, recordResult) = matchInfo.matchResults.first,
                       case .success(let memberRecord) = recordResult {
                        let assignments = memberRecord["projectAssignments"] as? [String] ?? []
                        promise(.success(assignments))
                    } else {
                        promise(.success([])) 
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func fetchAllProjectAssignments(
        for organizationID: String
    ) -> AnyPublisher<[String: [String]], Error> {
        let predicate = NSPredicate(format: "organizationID == %@", organizationID)
        let query = CKQuery(recordType: "OrganizationMember", predicate: predicate)
        
        return Future<[String: [String]], Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
                switch result {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let matchInfo):
                    var assignments: [String: [String]] = [:]
                    
                    for (_, recordResult) in matchInfo.matchResults {
                        if case .success(let record) = recordResult,
                           let userID = record["userID"] as? String {
                            let projectIDs = record["projectAssignments"] as? [String] ?? []
                            assignments[userID] = projectIDs
                        }
                    }
                    
                    promise(.success(assignments))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func createSecureInvite(
        organizationID: String,
        inviteEmail: String,
        role: OrganizationRole,
        allowedProjectIDs: [String] = [],
        expiresInHours: Int = 72
    ) -> AnyPublisher<String, Error> {
        let inviteToken = "invite_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresInHours * 3600))
        
        let inviteRecord = CKRecord(recordType: "OrganizationInvite")
        inviteRecord["organizationID"] = organizationID as CKRecordValue
        inviteRecord["inviteToken"] = inviteToken as CKRecordValue
        inviteRecord["inviteeEmail"] = inviteEmail as CKRecordValue
        inviteRecord["role"] = role.rawValue as CKRecordValue
        inviteRecord["expiresAt"] = expiresAt as CKRecordValue
        inviteRecord["createdAt"] = Date() as CKRecordValue
        inviteRecord["projectAssignments"] = allowedProjectIDs as CKRecordValue
        inviteRecord["status"] = "pending" as CKRecordValue
        
        return Future<String, Error> { promise in
            self.container.privateCloudDatabase.save(inviteRecord) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        print(" [CloudKit] Created secure invite: \(inviteToken)")
                        promise(.success(inviteToken))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func processInviteToken(
        _ token: String,
        userID: String
    ) -> AnyPublisher<(Organization, OrganizationRole, [String]), Error> {
        let predicate = NSPredicate(format: "inviteToken == %@ AND status == %@", token, "pending")
        let query = CKQuery(recordType: "OrganizationInvite", predicate: predicate)
        
        return Future<(Organization, OrganizationRole, [String]), Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let matchInfo):
                    guard let (_, recordResult) = matchInfo.matchResults.first,
                          case .success(let inviteRecord) = recordResult else {
                        promise(.failure(NSError(domain: "CloudKit", code: -1, 
                                               userInfo: [NSLocalizedDescriptionKey: "Invalid or expired invite token"])))
                        return
                    }
                    
                    if let expiresAt = inviteRecord["expiresAt"] as? Date,
                       expiresAt < Date() {
                        promise(.failure(NSError(domain: "CloudKit", code: -2, 
                                               userInfo: [NSLocalizedDescriptionKey: "Invite token has expired"])))
                        return
                    }
                    
                    guard let organizationID = inviteRecord["organizationID"] as? String,
                          let roleString = inviteRecord["role"] as? String,
                          let role = OrganizationRole(rawValue: roleString) else {
                        promise(.failure(NSError(domain: "CloudKit", code: -3, 
                                               userInfo: [NSLocalizedDescriptionKey: "Invalid invite data"])))
                        return
                    }
                    
                    let projectAssignments = inviteRecord["projectAssignments"] as? [String] ?? []
                    
                    inviteRecord["status"] = "accepted" as CKRecordValue
                    self.container.privateCloudDatabase.save(inviteRecord) { _, _ in
                    }
                    
                    let orgRecordID = CKRecord.ID(recordName: organizationID)
                    self.container.privateCloudDatabase.fetch(withRecordID: orgRecordID) { orgRecord, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        
                        guard let orgRecord = orgRecord else {
                            promise(.failure(NSError(domain: "CloudKit", code: -4, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])))
                            return
                        }
                        
                        let organization = Organization(
                            id: orgRecord["id"] as? String ?? organizationID,
                            name: orgRecord["name"] as? String ?? "Unknown Organization",
                            members: orgRecord["teamMembers"] as? [String] ?? [],
                            adminUserID: orgRecord["adminUserID"] as? String ?? "",
                            cloudKitRecordID: orgRecord.recordID.recordName
                        )
                        
                        promise(.success((organization, role, projectAssignments)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func createSecureInviteWithProjects(
        organizationID: String,
        inviteEmail: String,
        role: OrganizationRole,
        assignedProjectIDs: [String],
        expiresInHours: Int = 72
    ) -> AnyPublisher<String, Error> {
        return createSecureInvite(
            organizationID: organizationID,
            inviteEmail: inviteEmail,
            role: role,
            allowedProjectIDs: assignedProjectIDs,
            expiresInHours: expiresInHours
        )
    }
    
    public func isOrganizationNameAvailable(_ name: String) -> AnyPublisher<Bool, Error> {
        let predicate = NSPredicate(format: "name == %@", name)
        let query = CKQuery(recordType: "Organization", predicate: predicate)
        
        return Future<Bool, Error> { promise in
            self.container.privateCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name"], resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    print(" [CloudKit] Name availability check failed: \(error)")
                    promise(.success(true)) 
                case .success(let matchInfo):
                    let isAvailable = matchInfo.matchResults.isEmpty
                    print(" [CloudKit] Name '\(name)' availability: \(isAvailable)")
                    promise(.success(isAvailable))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func suggestAlternativeOrganizationNames(_ baseName: String) -> AnyPublisher<[String], Error> {
        let suggestions = [
            "\(baseName) LLC",
            "\(baseName) Inc",
            "\(baseName) Co",
            "\(baseName) Group",
            "\(baseName) Solutions",
            "\(baseName) Enterprises"
        ]
        
        let availabilityChecks = suggestions.map { suggestion in
            isOrganizationNameAvailable(suggestion)
                .map { isAvailable in (suggestion, isAvailable) }
        }
        
        return Publishers.MergeMany(availabilityChecks)
            .collect()
            .map { results in
                results.compactMap { suggestion, isAvailable in
                    isAvailable ? suggestion : nil
                }
            }
            .eraseToAnyPublisher()
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
    
    private func decodeStringArrayFromBytes(_ data: Any?) -> [String]? {
        guard let data = data as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String]
    }
    
    private func encodeStringArrayToBytes(_ array: [String]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: array)
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
    
    // MARK: - Organization Management Methods
    
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
                            
                            deleteOperation.modifyRecordsCompletionBlock = { _, deletedRecordIDs, error in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        print("❌ [CloudKit] Failed to delete organization: \(error)")
                                        promise(.failure(error))
                                    } else {
                                        print("✅ [CloudKit] Organization and \(memberRecordIDs.count) member records deleted")
                                        promise(.success(true))
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
}