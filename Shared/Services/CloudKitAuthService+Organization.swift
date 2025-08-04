import Foundation
import Combine
import CloudKit

extension CloudKitAuthService {
    
    public func createOrganization(
        orgName: String,
        adminUserID: String
    ) -> AnyPublisher<Organization, Error> {
        print(" [CloudKit] Creating organization: '\(orgName)' for admin: \(adminUserID)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Organization, Error> in
                print(" [CloudKit] CloudKit available, proceeding with organization creation")
                
                let privateDB = self.container.privateCloudDatabase
                let generatedOrgID = UUID().uuidString
                
                print(" [CloudKit] Generated organization ID: \(generatedOrgID)")
                
                let orgRecord = CKRecord(recordType: "Organization", recordID: CKRecord.ID(recordName: generatedOrgID))
                
                orgRecord["id"] = generatedOrgID as CKRecordValue
                orgRecord["name"] = orgName as CKRecordValue
                orgRecord["adminUserID"] = adminUserID as CKRecordValue
                orgRecord["createdAt"] = Date() as CKRecordValue
                orgRecord["isActiveV2"] = 1 as CKRecordValue
                
                // Keep teamMembers as List<String> for searchability, encode others as BYTES
                orgRecord["teamMembers"] = [adminUserID] as CKRecordValue
                
                // Encode complex arrays as JSON data for BYTES fields
                let memberRoles = ["\(adminUserID):admin"]
                let projectIDs: [String] = []
                
                if let memberRolesData = try? JSONSerialization.data(withJSONObject: memberRoles) {
                    orgRecord["memberRoles"] = memberRolesData as CKRecordValue
                }
                
                if let projectIDsData = try? JSONSerialization.data(withJSONObject: projectIDs) {
                    orgRecord["projectIDs2"] = projectIDsData as CKRecordValue
                }
                
                // Set environment to production for live deployment
                orgRecord["environment"] = "production" as CKRecordValue
                
                print(" [CloudKit] Saving Organization for PRODUCTION environment:")
                print("   - teamMembers: \([adminUserID]) (List<String>)")
                print("   - memberRoles: \(memberRoles) (BYTES)")
                print("   - projectIDs2: \(projectIDs) (BYTES)")
                print("   - environment: production")
                
                return Future<Organization, Error> { promise in
                    privateDB.save(orgRecord) { savedRecord, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print(" [CloudKit] Organization creation failed: \(error)")
                                promise(.failure(self.handleCloudKitError(error)))
                                return
                            }
                            
                            guard let record = savedRecord else {
                                let error = NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "No record returned from save"])
                                promise(.failure(error))
                                return
                            }
                            
                            print(" [CloudKit] Organization created successfully for PRODUCTION")
                            
                            let organization = Organization(
                                id: record["id"] as? String ?? generatedOrgID,
                                name: record["name"] as? String ?? orgName,
                                members: record["teamMembers"] as? [String] ?? [adminUserID],
                                adminUserID: record["adminUserID"] as? String ?? adminUserID,
                                cloudKitRecordID: record.recordID.recordName
                            )
                            
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
            .timeout(.seconds(15), scheduler: DispatchQueue.main)
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
        print(" [CloudKit] Fetching organizations for user: \(userID)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<[Organization], Error> in
                let privateDB = self.container.privateCloudDatabase
                
                let adminPredicate = NSPredicate(format: "adminUserID == %@", userID)
                let adminQuery = CKQuery(recordType: "Organization", predicate: adminPredicate)
                
                let memberPredicate = NSPredicate(format: "teamMembers CONTAINS %@", userID)
                let memberQuery = CKQuery(recordType: "Organization", predicate: memberPredicate)
                
                print(" [CloudKit] Using production queries with List<String> fields")

                let adminQueryPublisher = self.executeOrganizationQuery(adminQuery, database: privateDB, queryName: "admin")
                let memberQueryPublisher = self.executeOrganizationQuery(memberQuery, database: privateDB, queryName: "member")
                
                return Publishers.Zip(adminQueryPublisher, memberQueryPublisher)
                    .map { adminRecords, memberRecords -> [Organization] in
                        print(" [CloudKit] Combining results: \(adminRecords.count) admin + \(memberRecords.count) member")
                        
                        var allRecords = adminRecords
                        let adminRecordIDs = Set(adminRecords.map { $0.recordID.recordName })
                        
                        for memberRecord in memberRecords {
                            if !adminRecordIDs.contains(memberRecord.recordID.recordName) {
                                allRecords.append(memberRecord)
                            }
                        }
                        
                        return self.processOrganizationRecords(allRecords, forUser: userID)
                    }
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(12), scheduler: DispatchQueue.main)
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
        // Filter for production environment only
        let targetEnvironment = "production"
        
        let filteredRecords = records.filter { record in
            if let environment = record["environment"] as? String {
                return environment == targetEnvironment
            }
            return false // Exclude records without environment field for production safety
        }
        
        let organizations = filteredRecords.map { record in
            Organization(
                id: record["id"] as? String ?? record.recordID.recordName,
                name: record["name"] as? String ?? "Unknown Organization",
                members: record["teamMembers"] as? [String] ?? [],
                adminUserID: record["adminUserID"] as? String ?? "",
                isActive: (record["isActiveV2"] as? Int64) == 1,
                createdAt: record["createdAt"] as? Date ?? Date(),
                cloudKitRecordID: record.recordID.recordName
            )
        }
        
        print(" [CloudKit] Processed \(organizations.count) PRODUCTION organizations")
        return organizations.sorted { $0.createdAt > $1.createdAt }
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
}