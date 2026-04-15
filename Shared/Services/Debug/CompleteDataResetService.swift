import Foundation
import CloudKit
import OSLog

/// Complete data reset service for debugging
/// Clears both local and CloudKit data
@MainActor
class CompleteDataResetService: ObservableObject {
    
    @Published var isResetting = false
    @Published var resetProgress = ""
    @Published var resetComplete = false
    
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
    }
    
    /// Complete reset of all app data
    func performCompleteReset() async throws {
        isResetting = true
        resetProgress = "Starting complete data reset..."
        
        do {
            // 1. Clear local UserDefaults data first
            resetProgress = "Clearing local data..."
            clearAllLocalData()
            
            // 2. Clear custom zones (this deletes all records in the zones)
            resetProgress = "Clearing custom zones..."
            try await clearCustomZones()
            
            // 3. Clear any remaining records in default zone only if needed
            resetProgress = "Clearing default zone records..."
            try await clearDefaultZoneRecords()
            
            resetProgress = "✅ Complete reset finished!"
            Logger.settingsSupport.notice("Complete data reset finished successfully.")
            
        } catch {
            resetProgress = "❌ Reset failed: \(error.localizedDescription)"
            throw error
        }
        
        isResetting = false
        resetComplete = true
    }
    
    /// Clear all local UserDefaults data
    func clearAllLocalData() {
        let defaults = UserDefaults.standard
        
        // Remove all app-specific keys
        let keysToRemove = [
            "projects",
            "teamMembers", 
            "selectedProjectID",
            "currentOrganizationID",
            "lastSyncTimestamp",
            "cachedUserData",
            "pending_invite_orgID",
            "pending_invite_orgName",
            "pending_invite_token",
            "pending_invite_role",
            "DevelopmentDataHasBeenReset",
            "CloudKitAuthService.userRecord",
            "CloudKitAuthService.userEmail",
            "preferredMapProvider"
        ]
        
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        
        // Remove organization-specific vendor and payment method data
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        for key in allKeys {
            if key.hasPrefix("vendors_") || 
               key.hasPrefix("paymentMethods_") ||
               key.hasPrefix("org_") ||
               key.hasPrefix("teamMembers_") ||
               key.hasPrefix("employees_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        // Clear any legacy team member storage locations
        clearLegacyTeamMemberData()
        
        // Clear caches
        clearCaches()
        
        Logger.settingsSupport.notice("Cleared local UserDefaults data, organization caches, and ghost team-member data.")
    }
    
    /// Clear legacy team member data from all possible storage locations
    private func clearLegacyTeamMemberData() {
        let defaults = UserDefaults.standard
        
        // Clear all possible team member storage keys
        let teamMemberKeys = [
            "teamMembers",
            "employees", 
            "staff",
            "workers", 
            "projectTeam",
            "organizationMembers",
            "defaultTeamMembers",
            "cachedTeamMembers"
        ]
        
        for key in teamMemberKeys {
            defaults.removeObject(forKey: key)
        }
        
        // Clear any organization-specific team member data
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        for key in allKeys {
            if key.contains("teamMember") || 
               key.contains("employee") || 
               key.contains("staff") ||
               key.contains("Member") {
                defaults.removeObject(forKey: key)
            }
        }
        
        Logger.settingsSupport.notice("Cleared legacy team-member data from local storage.")
    }
    
    /// Clear custom CloudKit zones
    func clearCustomZones() async throws {
        // Get all custom zones
        let zones = try await privateDB.allRecordZones()
        
        for zone in zones {
            if zone.zoneID.zoneName != "_defaultZone" {
                resetProgress = "Deleting zone: \(zone.zoneID.zoneName)"
                try await privateDB.deleteRecordZone(withID: zone.zoneID)
                Logger.settingsSupport.notice(
                    "Deleted custom CloudKit zone [zone=\(zone.zoneID.zoneName, privacy: .private)]"
                )
            }
        }
    }
    
    /// Clear records from default zone using existing queryable fields
    private func clearDefaultZoneRecords() async throws {
        let recordTypes = [
            "Organization",
            "Project", 
            "TeamMember",
            "Receipt",
            "Vendor",
            "PaymentMethod"
        ]
        
        for recordType in recordTypes {
            resetProgress = "Clearing \(recordType) from default zone..."
            
            do {
                // Use organizationID which is QUERYABLE in your schema
                // This will clear records for all organizations
                let predicate = NSPredicate(format: "organizationID != %@", "")
                let query = CKQuery(recordType: recordType, predicate: predicate)
                
                let (matchResults, _) = try await privateDB.records(matching: query)
                
                let recordIDs = matchResults.compactMap { (recordID, result) in
                    switch result {
                    case .success:
                        return recordID
                    case .failure:
                        return nil
                    }
                }
                
                if !recordIDs.isEmpty {
                    // Delete in batches of 400 (CloudKit limit)
                    let batchSize = 400
                    for i in stride(from: 0, to: recordIDs.count, by: batchSize) {
                        let endIndex = min(i + batchSize, recordIDs.count)
                        let batch = Array(recordIDs[i..<endIndex])
                        
                        let _ = try await privateDB.modifyRecords(saving: [], deleting: batch)
                        Logger.settingsSupport.notice(
                            "Deleted default-zone records [type=\(recordType, privacy: .public), batch=\(batch.count, privacy: .public)]"
                        )
                    }
                    Logger.settingsSupport.notice(
                        "Completed default-zone deletion [type=\(recordType, privacy: .public), total=\(recordIDs.count, privacy: .public)]"
                    )
                }
                
            } catch {
                // If querying fails, try a different approach
                Logger.settingsSupport.warning(
                    "Could not query default-zone records by organization identifier [type=\(recordType, privacy: .public), error=\(error.localizedDescription, privacy: .public)]"
                )
                
                // Try using a simpler predicate for record types without organizationID
                if recordType == "Organization" {
                    do {
                        // For Organization records, use 'name' field which is QUERYABLE
                        let predicate = NSPredicate(format: "name != %@", "")
                        let query = CKQuery(recordType: recordType, predicate: predicate)
                        
                        let (matchResults, _) = try await privateDB.records(matching: query)
                        let recordIDs = matchResults.compactMap { (recordID, result) in
                            switch result {
                            case .success: return recordID
                            case .failure: return nil
                            }
                        }
                        
                        if !recordIDs.isEmpty {
                            let _ = try await privateDB.modifyRecords(saving: [], deleting: recordIDs)
                            Logger.settingsSupport.notice(
                                "Deleted organization records using name fallback [total=\(recordIDs.count, privacy: .public)]"
                            )
                        }
                    } catch {
                        Logger.settingsSupport.warning(
                            "Could not delete organization records with name fallback [error=\(error.localizedDescription, privacy: .public)]"
                        )
                    }
                }
            }
        }
        
        // Clear any remaining record types that might not have organizationID
        let systemRecordTypes = ["RHEIRUser", "Users", "OrganizationInvite", "OrganizationMember"]
        for recordType in systemRecordTypes {
            do {
                resetProgress = "Clearing \(recordType)..."
                
                // Use userID or email fields which are QUERYABLE
                var predicate: NSPredicate
                if recordType.contains("User") {
                    predicate = NSPredicate(format: "userID != %@", "")
                } else {
                    predicate = NSPredicate(format: "email != %@", "")
                }
                
                let query = CKQuery(recordType: recordType, predicate: predicate)
                let (matchResults, _) = try await privateDB.records(matching: query)
                let recordIDs = matchResults.compactMap { (recordID, result) in
                    switch result {
                    case .success: return recordID
                    case .failure: return nil
                    }
                }
                
                if !recordIDs.isEmpty {
                    let _ = try await privateDB.modifyRecords(saving: [], deleting: recordIDs)
                    Logger.settingsSupport.notice(
                        "Deleted system record set [type=\(recordType, privacy: .public), total=\(recordIDs.count, privacy: .public)]"
                    )
                }
            } catch {
                Logger.settingsSupport.warning(
                    "Could not delete system record set [type=\(recordType, privacy: .public), error=\(error.localizedDescription, privacy: .public)]"
                )
            }
        }
    }
    
    /// Clear file caches
    private func clearCaches() {
        let fileManager = FileManager.default
        
        // Clear app caches
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: cacheDir.appendingPathComponent("AppCache"))
            try? fileManager.removeItem(at: cacheDir.appendingPathComponent("CloudKitCache"))
        }
        
        // Clear temporary files
        if let tempDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: tempDir.appendingPathComponent("Temp"))
        }
    }
    
    /// Get current data status for debugging
    func getCurrentDataStatus() async -> String {
        var status = "📊 CURRENT DATA STATUS:\n\n"
        
        // Local data
        let defaults = UserDefaults.standard
        status += "LOCAL DATA:\n"
        status += "- Projects: \((try? JSONDecoder().decode([Project].self, from: defaults.data(forKey: "projects") ?? Data()))?.count ?? 0)\n"
        status += "- Team Members: \((try? JSONDecoder().decode([TeamMember].self, from: defaults.data(forKey: "teamMembers") ?? Data()))?.count ?? 0)\n"
        
        let allKeys = defaults.dictionaryRepresentation().keys
        let vendorKeys = allKeys.filter { $0.hasPrefix("vendors_") }
        let paymentKeys = allKeys.filter { $0.hasPrefix("paymentMethods_") }
        status += "- Vendor Keys: \(vendorKeys.count)\n"
        status += "- Payment Method Keys: \(paymentKeys.count)\n"
        
        // CloudKit data - use queryable fields from schema
        status += "\nCLOUDKIT DATA:\n"
        
        let recordTypesWithQueries: [(String, String, String)] = [
            ("Organization", "name", ""),
            ("Project", "organizationID", ""),
            ("TeamMember", "organizationID", ""),
            ("Vendor", "organizationID", ""),
            ("PaymentMethod", "organizationID", "")
        ]
        
        for (recordType, field, emptyValue) in recordTypesWithQueries {
            do {
                let predicate = NSPredicate(format: "%K != %@", field, emptyValue)
                let query = CKQuery(recordType: recordType, predicate: predicate)
                
                let (results, _) = try await privateDB.records(matching: query)
                status += "- \(recordType): \(results.count)\n"
            } catch {
                status += "- \(recordType): Query failed (\(field) not queryable?)\n"
            }
        }
        
        // Custom zones
        status += "\nCUSTOM ZONES:\n"
        do {
            let zones = try await privateDB.allRecordZones()
            let customZones = zones.filter { $0.zoneID.zoneName != "_defaultZone" }
            if customZones.isEmpty {
                status += "- No custom zones\n"
            } else {
                for zone in customZones {
                    status += "- \(zone.zoneID.zoneName)\n"
                }
            }
        } catch {
            status += "- Error getting zones: \(error.localizedDescription)\n"
        }
        
        return status
    }
}
