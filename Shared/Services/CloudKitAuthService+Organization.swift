import Foundation
import Combine
import CloudKit

extension CloudKitAuthService {
    
    /// Check CloudKit account status before attempting operations
    private func checkCloudKitAvailability() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            print(" [CloudKit] Checking account status...")
            self.container.accountStatus { status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print(" [CloudKit] Account status check failed: \(error)")
                        promise(.failure(error))
                        return
                    }
                    
                    switch status {
                    case .available:
                        print(" [CloudKit] Account available")
                        promise(.success(()))
                    case .noAccount:
                        print(" [CloudKit] No iCloud account found")
                        let error = NSError(domain: "CloudKitAuthService", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "No iCloud account found. Please sign in to iCloud in Settings → [Your Name] → iCloud and try again."])
                        promise(.failure(error))
                    case .couldNotDetermine:
                        print(" [CloudKit] Could not determine account status")
                        let error = NSError(domain: "CloudKitAuthService", code: -2, 
                                          userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud account status. Please check your internet connection and try again."])
                        promise(.failure(error))
                    case .restricted:
                        print(" [CloudKit] Account is restricted")
                        let error = NSError(domain: "CloudKitAuthService", code: -3, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud account is restricted. Please check your Screen Time or parental control settings."])
                        promise(.failure(error))
                    case .temporarilyUnavailable:
                        print(" [CloudKit] Account temporarily unavailable")
                        let error = NSError(domain: "CloudKitAuthService", code: -4, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud is temporarily unavailable. Please try again in a few minutes."])
                        promise(.failure(error))
                    @unknown default:
                        print(" [CloudKit] Unknown account status: \(status.rawValue)")
                        let error = NSError(domain: "CloudKitAuthService", code: -5, 
                                          userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud account status. Please try signing out and back into iCloud."])
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func createOrganization(
        orgName: String,
        adminUserID: String
    ) -> AnyPublisher<Organization, Error> {
        print(" [CloudKit] Creating organization: '\(orgName)' for admin: \(adminUserID)")
        
        // Check CloudKit availability first - NO timeout here, let the overall operation handle it
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Organization, Error> in
                print(" [CloudKit] CloudKit available, proceeding with organization creation")
                
                let privateDB = self.container.privateCloudDatabase
                let generatedOrgID = UUID().uuidString
                
                print(" [CloudKit] Generated organization ID: \(generatedOrgID)")
                print(" [CloudKit] Using private database: \(privateDB)")
                
                // Create organization record with proper data isolation
                let orgRecord = CKRecord(recordType: "Organization", recordID: CKRecord.ID(recordName: generatedOrgID))
                
                // Use consistent field names for data isolation
                orgRecord["id"] = generatedOrgID as CKRecordValue
                orgRecord["name"] = orgName as CKRecordValue
                orgRecord["adminUserID"] = adminUserID as CKRecordValue
                orgRecord["members"] = [adminUserID] as CKRecordValue
                orgRecord["createdAt"] = Date() as CKRecordValue
                orgRecord["isActiveV2"] = 1 as CKRecordValue

                // Add development/production environment flag
                #if DEBUG
                orgRecord["environment"] = "development" as CKRecordValue
                print(" [CloudKit] Set environment to: development")
                #else
                orgRecord["environment"] = "production" as CKRecordValue
                print(" [CloudKit] Set environment to: production")
                #endif

                // Initialize empty member roles JSON
                orgRecord["memberRoles"] = "{}" as CKRecordValue

                print(" [CloudKit] About to save Organization record with fields:")
                print("   - recordID: \(orgRecord.recordID.recordName)")
                print("   - id: \(generatedOrgID)")
                print("   - name: \(orgName)")
                print("   - adminUserID: \(adminUserID)")
                print("   - members: \([adminUserID])")
                print("   - environment: \(orgRecord["environment"] as? String ?? "unknown")")
                print("   - recordType: \(orgRecord.recordType)")

                return Future<Organization, Error> { promise in
                    print(" [CloudKit] Calling privateDB.save...")
                    
                    // Track if completion handler has been called to prevent race conditions
                    var hasCompleted = false
                    let completionLock = NSLock()
                    
                    privateDB.save(orgRecord) { savedRecord, error in
                        DispatchQueue.main.async {
                            completionLock.lock()
                            defer { completionLock.unlock() }
                            
                            // Prevent duplicate completion handler calls
                            guard !hasCompleted else {
                                print(" [CloudKit] Save completion called multiple times - ignoring")
                                return
                            }
                            hasCompleted = true
                            
                            if let error = error {
                                print(" [CloudKit] Failed to save Organization record:")
                                print("   Error: \(error)")
                                print("   Localized: \(error.localizedDescription)")
                                
                                if let ckError = error as? CKError {
                                    print("   CKError code: \(ckError.code.rawValue)")
                                    
                                    let userFriendlyError: NSError
                                    switch ckError.code {
                                    case .unknownItem:
                                        print("   → Record type 'Organization' may not exist in schema")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -1, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "CloudKit schema not set up properly. The 'Organization' record type doesn't exist. Please contact support."])
                                    case .invalidArguments:
                                        print("   → Invalid field values or types")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -2, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "Invalid organization data. Please try again."])
                                    case .quotaExceeded:
                                        print("   → CloudKit quota exceeded")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -3, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "CloudKit storage quota exceeded. Please free up space in iCloud."])
                                    case .networkUnavailable:
                                        print("   → Network unavailable")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -4, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "Network unavailable. Please check your internet connection and try again."])
                                    case .notAuthenticated:
                                        print("   → Not authenticated with iCloud")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -5, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "Please sign in to iCloud in Settings and try again."])
                                    case .permissionFailure:
                                        print("   → Permission failure")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -6, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "CloudKit permission denied. Please check iCloud settings."])
                                    case .serverRejectedRequest:
                                        print("   → Server rejected request")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -7, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "CloudKit server rejected the request. The database schema may not be configured properly."])
                                    default:
                                        print("   → Other CloudKit error: \(ckError.localizedDescription)")
                                        userFriendlyError = NSError(domain: "CloudKit", code: -8, 
                                                                  userInfo: [NSLocalizedDescriptionKey: "CloudKit error: \(ckError.localizedDescription)"])
                                    }
                                    promise(.failure(userFriendlyError))
                                } else {
                                    promise(.failure(error))
                                }
                                return
                            }
                            
                            guard let record = savedRecord else {
                                print(" [CloudKit] No record returned from save operation")
                                let error = NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "No record returned from CloudKit save operation"])
                                promise(.failure(error))
                                return
                            }

                            print(" [CloudKit] Successfully saved Organization record:")
                            print("   Record ID: \(record.recordID.recordName)")
                            print("   Name: \(record["name"] as? String ?? "nil")")
                            print("   Admin: \(record["adminUserID"] as? String ?? "nil")")
                            print("   Members: \(record["members"] as? [String] ?? [])")
                            print("   Environment: \(record["environment"] as? String ?? "nil")")
                            
                            // Create the organization object from the saved record
                            let organization = Organization(
                                id: record["id"] as? String ?? generatedOrgID,
                                name: record["name"] as? String ?? orgName,
                                members: record["members"] as? [String] ?? [adminUserID],
                                adminUserID: record["adminUserID"] as? String ?? adminUserID,
                                cloudKitRecordID: record.recordID.recordName
                            )
                            
                            print(" [CloudKit] Created Organization object: \(organization.name) (ID: \(organization.id))")
                            promise(.success(organization))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main) // Single timeout for the entire operation
            .eraseToAnyPublisher()
    }
    
    public func invite(
        email: String,
        orgID: String
    ) -> AnyPublisher<Void, Error> {
        print(" [CloudKit] Inviting \(email) to organization \(orgID)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Void, Error> in
                let privateDB = self.container.privateCloudDatabase
                
                // Create an invitation record
                let inviteRecord = CKRecord(recordType: "OrganizationInvite")
                inviteRecord["organizationID"] = orgID as CKRecordValue
                inviteRecord["inviteeEmail"] = email as CKRecordValue
                inviteRecord["status"] = "pending" as CKRecordValue
                inviteRecord["createdAt"] = Date() as CKRecordValue
                if let currentUserID = self.currentUser?.id {
                    inviteRecord["inviterUserID"] = currentUserID as CKRecordValue
                }
                
                return Future<Void, Error> { promise in
                    privateDB.save(inviteRecord) { _, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print(" [CloudKit] Failed to save invite: \(error)")
                                promise(.failure(error))
                            } else {
                                print(" [CloudKit] Invite saved successfully")
                                promise(.success(()))
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(10), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public func fetchOrganizations(
        for userID: String
    ) -> AnyPublisher<[Organization], Error> {
        print(" [CloudKit] Fetching organizations for user: \(userID)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<[Organization], Error> in
                print(" [CloudKit] CloudKit available, proceeding with fetch")
                
                let privateDB = self.container.privateCloudDatabase
                
                // Instead of compound OR predicate, we'll do two separate queries
                // Query 1: Organizations where user is admin
                let adminPredicate = NSPredicate(format: "adminUserID == %@", userID)
                let adminQuery = CKQuery(recordType: "Organization", predicate: adminPredicate)
                
                print(" [CloudKit] Admin query predicate: \(adminPredicate)")
                
                // Query 2: Organizations where user is in members list
                let memberPredicate = NSPredicate(format: "members CONTAINS %@", userID)
                let memberQuery = CKQuery(recordType: "Organization", predicate: memberPredicate)
                
                print(" [CloudKit] Member query predicate: \(memberPredicate)")

                // Execute both queries and combine results
                let adminQueryPublisher = Future<[CKRecord], Error> { promise in
                    print(" [CloudKit] Executing admin query...")
                    
                    privateDB.fetch(withQuery: adminQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 25) { result in
                        switch result {
                        case .failure(let error):
                            print(" [CloudKit] Admin query failed: \(error)")
                            promise(.failure(error))
                        case .success(let matchInfo):
                            let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                                if case .success(let record) = pair.1 {
                                    return record
                                }
                                return nil
                            }
                            print(" [CloudKit] Admin query found \(records.count) organizations")
                            promise(.success(records))
                        }
                    }
                }.eraseToAnyPublisher()
                
                let memberQueryPublisher = Future<[CKRecord], Error> { promise in
                    print(" [CloudKit] Executing member query...")
                    
                    privateDB.fetch(withQuery: memberQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 25) { result in
                        switch result {
                        case .failure(let error):
                            print(" [CloudKit] Member query failed: \(error)")
                            // Don't fail the whole operation if member query fails
                            // Just return empty array for member organizations
                            promise(.success([]))
                        case .success(let matchInfo):
                            let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                                if case .success(let record) = pair.1 {
                                    return record
                                }
                                return nil
                            }
                            print(" [CloudKit] Member query found \(records.count) organizations")
                            promise(.success(records))
                        }
                    }
                }.eraseToAnyPublisher()
                
                // Combine both query results
                return Publishers.Zip(adminQueryPublisher, memberQueryPublisher)
                    .map { adminRecords, memberRecords -> [CKRecord] in
                        print(" [CloudKit] Combining query results:")
                        print("   Admin records: \(adminRecords.count)")
                        print("   Member records: \(memberRecords.count)")
                        
                        // Combine and deduplicate by recordID
                        var allRecords = adminRecords
                        let adminRecordIDs = Set(adminRecords.map { $0.recordID.recordName })
                        
                        for memberRecord in memberRecords {
                            if !adminRecordIDs.contains(memberRecord.recordID.recordName) {
                                allRecords.append(memberRecord)
                            }
                        }
                        
                        print(" [CloudKit] Combined unique records: \(allRecords.count)")
                        return allRecords
                    }
                    .map { records -> [Organization] in
                        print(" [CloudKit] Processing \(records.count) records")
                        
                        // Filter by environment if the field exists
                        #if DEBUG
                        let targetEnvironment = "development"
                        #else
                        let targetEnvironment = "production"
                        #endif
                        
                        print(" [CloudKit] Filtering for environment: \(targetEnvironment)")
                        
                        let filteredRecords = records.filter { record in
                            print(" [CloudKit] Processing record: \(record["name"] as? String ?? "unknown")")
                            print("   Record ID: \(record.recordID.recordName)")
                            print("   Admin: \(record["adminUserID"] as? String ?? "nil")")
                            print("   Environment: \(record["environment"] as? String ?? "nil")")
                            
                            // If environment field exists, check it; otherwise include the record
                            if let environment = record["environment"] as? String {
                                let matches = environment == targetEnvironment
                                print("   Environment '\(environment)' matches target '\(targetEnvironment)': \(matches)")
                                return matches
                            } else {
                                // Include records without environment field (legacy records)
                                print("   No environment field - including (legacy record)")
                                return true
                            }
                        }
                        
                        print(" [CloudKit] After environment filtering: \(filteredRecords.count) records")
                        
                        let organizations = filteredRecords.map { record in
                            let org = Organization(
                                id: record["id"] as? String ?? record.recordID.recordName,
                                name: record["name"] as? String ?? "Unknown Organization",
                                members: record["members"] as? [String] ?? [],
                                adminUserID: record["adminUserID"] as? String ?? "",
                                isActive: (record["isActiveV2"] as? Int64) == 1,
                                createdAt: record["createdAt"] as? Date ?? Date(),
                                cloudKitRecordID: record.recordID.recordName
                            )
                            
                            print("   Created Organization:")
                            print("     Name: \(org.name)")
                            print("     ID: \(org.id)")
                            print("     Admin: \(org.adminUserID)")
                            print("     Members: \(org.members)")
                            print("     Active: \(org.isActive)")
                            
                            return org
                        }
                        
                        print(" [CloudKit] Successfully processed \(organizations.count) organizations for user \(userID.prefix(8))...")
                        
                        // Sort organizations by creation date in code instead of CloudKit
                        return organizations.sorted { $0.createdAt > $1.createdAt }
                    }
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(12), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Organization Membership Management
    
    public func addUserToOrganization(
        userID: String,
        organizationID: String
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
                            let error = NSError(domain: "CloudKit", code: -1, 
                                               userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
                            promise(.failure(error))
                            return
                        }
                        
                        print(" [CloudKit] Found organization record")
                        
                        // Add user to members list if not already present
                        var members = orgRecord["members"] as? [String] ?? []
                        if !members.contains(userID) {
                            members.append(userID)
                            orgRecord["members"] = members as CKRecordValue
                            print(" [CloudKit] Adding user to members list")
                        } else {
                            print(" [CloudKit] User already in members list")
                        }
                        
                        // Update member roles JSON
                        var memberRoles: [String: String] = [:]
                        if let existingRolesJSON = orgRecord["memberRoles"] as? String,
                           let data = existingRolesJSON.data(using: .utf8),
                           let roles = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                            memberRoles = roles
                        }
                        memberRoles[userID] = OrganizationRole.member.rawValue
                            
                        if let rolesData = try? JSONSerialization.data(withJSONObject: memberRoles),
                           let rolesJSON = String(data: rolesData, encoding: .utf8) {
                            orgRecord["memberRoles"] = rolesJSON as CKRecordValue
                            print(" [CloudKit] Updated member roles")
                        }
                        
                        // Save the updated organization record
                        privateDB.save(orgRecord) { _, saveError in
                            DispatchQueue.main.async {
                                if let saveError = saveError {
                                    print(" [CloudKit] Failed to save organization: \(saveError)")
                                    promise(.failure(saveError))
                                } else {
                                    print(" [CloudKit] Successfully added user \(userID.prefix(8))... to organization as member")
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
    
    // MARK: - Development Testing Support
    
    public func deleteOrganization(organizationID: String) -> AnyPublisher<Void, Error> {
        #if DEBUG
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Void, Error> in
                let privateDB = self.container.privateCloudDatabase
                let recordID = CKRecord.ID(recordName: organizationID)
                
                return Future<Void, Error> { promise in
                    privateDB.delete(withRecordID: recordID) { _, error in
                        if let error = error {
                            print(" [CloudKit] Failed to delete organization: \(error)")
                            promise(.failure(error))
                        } else {
                            print(" [CloudKit] Organization deleted successfully")
                            promise(.success(()))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(8), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
        #else
        return Fail(error: NSError(domain: "CloudKit", code: -1, 
                                 userInfo: [NSLocalizedDescriptionKey: "Organization deletion only available in development"]))
            .eraseToAnyPublisher()
        #endif
    }
    
    // MARK: - Organization Name Uniqueness Validation
    
    /// Check if an organization name is already taken across all organizations
    public func isOrganizationNameAvailable(_ name: String) -> AnyPublisher<Bool, Error> {
        print("🔍 [CloudKit] Checking if organization name '\(name)' is available")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Bool, Error> in
                print("🔍 [CloudKit] CloudKit available, proceeding with name check")
                
                let privateDB = self.container.privateCloudDatabase
                
                // Simple exact match query - case sensitive for now, which works fine
                let namePredicate = NSPredicate(format: "name == %@", name)
                let query = CKQuery(recordType: "Organization", predicate: namePredicate)
                
                print("🔍 [CloudKit] Name availability query: \(namePredicate)")
                
                return Future<Bool, Error> { promise in
                    print("🔍 [CloudKit] Executing name availability query...")
                    
                    privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name", "environment"], resultsLimit: 10) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .failure(let error):
                                print("❌ [CloudKit] Failed to check organization name availability: \(error)")
                                
                                // For development, assume name is available if query fails
                                #if DEBUG
                                print("⚠️ [CloudKit] Development mode - assuming name is available due to query error")
                                promise(.success(true))
                                #else
                                promise(.failure(error))
                                #endif
                                
                            case .success(let matchInfo):
                                let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                                    if case .success(let record) = pair.1 {
                                        return record
                                    }
                                    return nil
                                }
                                
                                print("✅ [CloudKit] Name availability query found \(records.count) potential matches")
                                
                                // Filter by environment if the field exists
                                #if DEBUG
                                let targetEnvironment = "development"
                                #else
                                let targetEnvironment = "production"
                                #endif
                                
                                let relevantRecords = records.filter { record in
                                    if let environment = record["environment"] as? String {
                                        return environment == targetEnvironment
                                    } else {
                                        // Include records without environment field (legacy records)
                                        return true
                                    }
                                }
                                
                                let isAvailable = relevantRecords.isEmpty
                                
                                if isAvailable {
                                    print("✅ [CloudKit] Organization name '\(name)' is available")
                                } else {
                                    print("⚠️ [CloudKit] Organization name '\(name)' is already taken")
                                }
                                
                                promise(.success(isAvailable))
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(10), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Get suggested alternative organization names if the desired name is taken
    public func suggestAlternativeOrganizationNames(_ baseName: String) -> AnyPublisher<[String], Error> {
        print(" [CloudKit] Generating alternative names for '\(baseName)'")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<[String], Error> in
                let privateDB = self.container.privateCloudDatabase
                
                // Query for organizations with similar names - use BEGINSWITH which is supported
                let namePredicate = NSPredicate(format: "name BEGINSWITH %@", baseName)
                let query = CKQuery(recordType: "Organization", predicate: namePredicate)
                
                return Future<[String], Error> { promise in
                    privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name", "environment"], resultsLimit: 20) { result in
                        switch result {
                        case .failure(let error):
                            print(" [CloudKit] Failed to fetch similar organization names: \(error)")
                            
                            // If query fails, provide basic suggestions
                            let basicSuggestions = [
                                "\(baseName) LLC",
                                "\(baseName) Inc",
                                "\(baseName) Co",
                                "\(baseName) Group",
                                "\(baseName) 2024"
                            ]
                            promise(.success(basicSuggestions))
                            
                        case .success(let matchInfo):
                            let records = matchInfo.matchResults.compactMap { pair -> CKRecord? in
                                if case .success(let record) = pair.1 {
                                    return record
                                }
                                return nil
                            }
                            
                            // Filter by environment if the field exists
                            #if DEBUG
                            let targetEnvironment = "development"
                            #else
                            let targetEnvironment = "production"
                            #endif
                            
                            let existingNames = records.compactMap { record -> String? in
                                // Filter by environment if available
                                if let environment = record["environment"] as? String {
                                    return environment == targetEnvironment ? (record["name"] as? String) : nil
                                } else {
                                    // Include legacy records without environment field
                                    return record["name"] as? String
                                }
                            }
                            
                            // Generate intelligent suggestions based on existing names
                            var suggestions: [String] = []
                            
                            // Try numeric suffixes
                            for i in 2...10 {
                                let candidate = "\(baseName) \(i)"
                                if !existingNames.contains(where: { $0.lowercased() == candidate.lowercased() }) {
                                    suggestions.append(candidate)
                                }
                            }
                            
                            // Try business suffixes
                            let businessSuffixes = ["LLC", "Inc", "Co", "Corp", "Group", "Associates", "Partners"]
                            for suffix in businessSuffixes {
                                let candidate = "\(baseName) \(suffix)"
                                if !existingNames.contains(where: { $0.lowercased() == candidate.lowercased() }) {
                                    suggestions.append(candidate)
                                }
                            }
                            
                            // Try year suffix
                            let currentYear = Calendar.current.component(.year, from: Date())
                            let yearCandidate = "\(baseName) \(currentYear)"
                            if !existingNames.contains(where: { $0.lowercased() == yearCandidate.lowercased() }) {
                                suggestions.append(yearCandidate)
                            }
                            
                            // Try location-based suffixes (common ones)
                            let locationSuffixes = ["North", "South", "East", "West", "Central", "Metro"]
                            for location in locationSuffixes {
                                let candidate = "\(baseName) \(location)"
                                if !existingNames.contains(where: { $0.lowercased() == candidate.lowercased() }) {
                                    suggestions.append(candidate)
                                }
                            }
                            
                            // Limit to top 5 suggestions
                            suggestions = Array(suggestions.prefix(5))
                            
                            print(" [CloudKit] Generated \(suggestions.count) alternative names for '\(baseName)'")
                            promise(.success(suggestions))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(8), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Role-Based Organization Membership

    public func joinOrganizationWithRole(
        orgID: String,
        userID: String,
        role: OrganizationRole
    ) -> AnyPublisher<Organization, Error> {
        print(" [CloudKit] Joining organization \(orgID) as \(role.displayName)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Organization, Error> in
                let privateDB = self.container.privateCloudDatabase
                let recordID = CKRecord.ID(recordName: orgID)
                
                return Future<Organization, Error> { promise in
                    print(" [CloudKit] Fetching organization record: \(orgID)")
                    
                    privateDB.fetch(withRecordID: recordID) { record, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print(" [CloudKit] Failed to fetch organization: \(error)")
                                promise(.failure(error))
                                return
                            }
                            
                            guard let orgRecord = record else {
                                print(" [CloudKit] Organization record not found: \(orgID)")
                                let error = NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
                                promise(.failure(error))
                                return
                            }
                            
                            print(" [CloudKit] Found organization record")
                            
                            // Add user to members list if not already present
                            var members = orgRecord["members"] as? [String] ?? []
                            if !members.contains(userID) {
                                members.append(userID)
                                orgRecord["members"] = members as CKRecordValue
                                print(" [CloudKit] Adding user to members list")
                            } else {
                                print(" [CloudKit] User already in members list")
                            }
                            
                            // Update member roles JSON with the specified role
                            var memberRoles: [String: String] = [:]
                            if let existingRolesJSON = orgRecord["memberRoles"] as? String,
                               let data = existingRolesJSON.data(using: .utf8),
                               let roles = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                                memberRoles = roles
                            }
                            
                            // Set the specified role (not default to member)
                            memberRoles[userID] = role.rawValue
                            print(" [CloudKit] Setting user role to: \(role.displayName)")
                            
                            if let rolesData = try? JSONSerialization.data(withJSONObject: memberRoles),
                               let rolesJSON = String(data: rolesData, encoding: .utf8) {
                                orgRecord["memberRoles"] = rolesJSON as CKRecordValue
                                print(" [CloudKit] Updated member roles JSON")
                            }
                            
                            // Save the updated organization record
                            privateDB.save(orgRecord) { _, saveError in
                                DispatchQueue.main.async {
                                    if let saveError = saveError {
                                        print(" [CloudKit] Failed to save organization: \(saveError)")
                                        promise(.failure(saveError))
                                    } else {
                                        print(" [CloudKit] Successfully added user \(userID.prefix(8))... to organization as \(role.displayName)")
                                        
                                        // Create organization object from updated record
                                        let organization = Organization(
                                            id: orgRecord["id"] as? String ?? orgID,
                                            name: orgRecord["name"] as? String ?? "Unknown Organization",
                                            members: members,
                                            adminUserID: orgRecord["adminUserID"] as? String ?? "",
                                            isActive: (orgRecord["isActiveV2"] as? Int64) == 1,
                                            createdAt: orgRecord["createdAt"] as? Date ?? Date(),
                                            cloudKitRecordID: orgRecord.recordID.recordName
                                        )
                                        
                                        promise(.success(organization))
                                    }
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
    
    // MARK: - Enhanced Organization Fetching with Roles

    public func fetchOrganizationsWithRoles(
        for userID: String
    ) -> AnyPublisher<(organizations: [Organization], roles: [String: OrganizationRole]), Error> {
        print(" [CloudKit] Fetching organizations with roles for user: \(userID)")
        
        return fetchOrganizations(for: userID)
            .map { organizations in
                var userRoles: [String: OrganizationRole] = [:]
                
                // Extract roles from memberRoles JSON field and admin status
                for org in organizations {
                    let isAdmin = org.adminUserID == userID
                    
                    if isAdmin {
                        userRoles[org.id] = .admin
                        print(" [CloudKit] User is admin of organization: \(org.name)")
                    } else {
                        // Try to get role from CloudKit record's memberRoles field
                        // For now, we'll fetch this separately in a real implementation
                        // Here we'll default to member for simplicity
                        userRoles[org.id] = .member
                        print(" [CloudKit] User is member of organization: \(org.name)")
                    }
                }
                
                print(" [CloudKit] Mapped roles for \(organizations.count) organizations")
                return (organizations: organizations, roles: userRoles)
            }
            .eraseToAnyPublisher()
    }
    
    /// Fetch detailed role information for a specific organization
    public func fetchUserRoleInOrganization(
        userID: String, 
        organizationID: String
    ) -> AnyPublisher<OrganizationRole, Error> {
        print(" [CloudKit] Fetching user role in organization: \(organizationID.prefix(8))...")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<OrganizationRole, Error> in
                let privateDB = self.container.privateCloudDatabase
                let recordID = CKRecord.ID(recordName: organizationID)
                
                return Future<OrganizationRole, Error> { promise in
                    privateDB.fetch(withRecordID: recordID) { record, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print(" [CloudKit] Failed to fetch organization for role check: \(error)")
                                promise(.failure(error))
                                return
                            }
                            
                            guard let orgRecord = record else {
                                let error = NSError(domain: "CloudKit", code: -1, 
                                                   userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
                                promise(.failure(error))
                                return
                            }
                            
                            // Check if user is admin
                            if let adminUserID = orgRecord["adminUserID"] as? String, adminUserID == userID {
                                print(" [CloudKit] User is admin of organization")
                                promise(.success(.admin))
                                return
                            }
                            
                            // Check member roles JSON
                            if let memberRolesJSON = orgRecord["memberRoles"] as? String,
                               let data = memberRolesJSON.data(using: .utf8),
                               let memberRoles = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                               let roleString = memberRoles[userID],
                               let role = OrganizationRole(rawValue: roleString) {
                                print(" [CloudKit] User role found: \(role.displayName)")
                                promise(.success(role))
                            } else {
                                // Default to member if found in members list
                                let members = orgRecord["members"] as? [String] ?? []
                                if members.contains(userID) {
                                    print(" [CloudKit] User found in members list, defaulting to member role")
                                    promise(.success(.member))
                                } else {
                                    let error = NSError(domain: "CloudKit", code: -2, 
                                                       userInfo: [NSLocalizedDescriptionKey: "User is not a member of this organization"])
                                    promise(.failure(error))
                                }
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(8), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}