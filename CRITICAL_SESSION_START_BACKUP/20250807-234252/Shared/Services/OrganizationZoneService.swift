import Foundation
import CloudKit
import Combine

/// Handles secure SHARED zone-based multi-tenant data isolation for organizations
/// Each organization gets its own shared zone for team collaboration
@MainActor
public class OrganizationZoneService: ObservableObject {
    
    // MARK: - Properties
    private let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
    private var privateDatabase: CKDatabase {
        return container.privateCloudDatabase
    }
    
    @Published var currentOrganizationZone: CKRecordZone?
    @Published var currentShare: CKShare?
    @Published var isZoneReady = false
    
    private var organizationZones: [String: (zone: CKRecordZone, share: CKShare?)] = [:]
    
    // MARK: - Shared Zone Management
    
    /// Create or get the SHARED zone for a specific organization
    func setupOrganizationSharedZone(for organizationID: String) async throws -> (zone: CKRecordZone, share: CKShare?) {
        print("🏗️ Setting up SHARED zone for organization: \(organizationID.prefix(8))...")
        
        // Check if we already have this zone cached
        if let existingZoneData = organizationZones[organizationID] {
            currentOrganizationZone = existingZoneData.zone
            currentShare = existingZoneData.share
            isZoneReady = true
            print("✅ Using cached SHARED zone for organization: \(organizationID.prefix(8))...")
            return existingZoneData
        }
        
        let zoneName = "org-shared-\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        do {
            // STEP 1: Check if zone exists in PRIVATE database (where zone owner keeps it)
            print("🔍 Checking for existing zone in private database...")
            let existingZones = try await privateDatabase.allRecordZones()
            if let existingZone = existingZones.first(where: { $0.zoneID.zoneName == zoneName }) {
                print("✅ Found existing zone in private DB: \(zoneName)")
                
                // Try to find the root record and its share
                let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: existingZone.zoneID)
                
                do {
                    let existingRootRecord = try await privateDatabase.record(for: rootRecordID)
                    print("✅ Found existing organization root record")
                    
                    // Try to fetch share metadata for this record
                    let existingShare = try await fetchShareForRootRecord(existingRootRecord)
                    
                    let zoneData = (zone: existingZone, share: existingShare)
                    organizationZones[organizationID] = zoneData
                    currentOrganizationZone = existingZone
                    currentShare = existingShare
                    isZoneReady = true
                    
                    if existingShare != nil {
                        print("✅ Zone is properly shared with collaboration enabled")
                    } else {
                        print("⚠️ Zone exists but no share found - zone is not shared yet")
                        print("ℹ️ Zone setup completed but sharing not enabled")
                    }
                    
                    return zoneData
                    
                } catch let error as CKError where error.code == .unknownItem {
                    print("⚠️ Root record not found, but zone exists - will recreate root record and share")
                    // Fall through to create new root record and share
                } catch {
                    print("⚠️ Error fetching root record: \(error)")
                    throw error
                }
            }
            
            // STEP 2: Zone doesn't exist or root record missing - create everything
            print("🆕 Creating new SHARED zone: \(zoneName)")
            
            // Create zone first
            let newZone = CKRecordZone(zoneID: zoneID)
            let savedZone = try await privateDatabase.save(newZone)
            print("✅ Created zone in private DB: \(zoneName)")
            
            // Create root record and share atomically
            let (rootRecord, share) = try await createRootRecordAndShareAtomically(
                organizationID: organizationID, 
                zone: savedZone
            )
            
            let zoneData = (zone: savedZone, share: share)
            organizationZones[organizationID] = zoneData
            currentOrganizationZone = savedZone
            currentShare = share
            isZoneReady = true
            
            print("✅ Created SHARED zone with collaboration: \(zoneName)")
            
            return zoneData
            
        } catch let error as CKError {
            print("❌ CloudKit error during zone setup: \(error.localizedDescription)")
            if error.code == .zoneNotFound {
                // This shouldn't happen in the private DB check, but handle it
                print("🆕 Zone not found error - creating new zone...")
                
                let newZone = CKRecordZone(zoneID: zoneID)
                let savedZone = try await privateDatabase.save(newZone)
                
                let (rootRecord, share) = try await createRootRecordAndShareAtomically(
                    organizationID: organizationID,
                    zone: savedZone
                )
                
                let zoneData = (zone: savedZone, share: share)
                organizationZones[organizationID] = zoneData
                currentOrganizationZone = savedZone
                currentShare = share
                isZoneReady = true
                
                print("✅ Created SHARED zone after zone not found: \(zoneName)")
                
                return zoneData
            } else {
                throw error
            }
        } catch {
            print("❌ Failed to setup SHARED zone for organization \(organizationID.prefix(8)): \(error)")
            throw error
        }
    }
    
    /// Create root record and share in a single atomic operation
    private func createRootRecordAndShareAtomically(organizationID: String, zone: CKRecordZone) async throws -> (CKRecord, CKShare) {
        print("🔄 Creating root record and share atomically for organization: \(organizationID.prefix(8))")
        
        // Create root record
        let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: zone.zoneID)
        let rootRecord = CKRecord(recordType: "OrganizationRoot", recordID: rootRecordID)
        rootRecord["organizationID"] = organizationID as CKRecordValue
        rootRecord["name"] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
        rootRecord["createdAt"] = Date() as CKRecordValue
        
        // Create share for the root record
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "RHEIR Organization \(organizationID.prefix(8))" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.rheirhome.organization" as CKRecordValue
        share.publicPermission = .none
        
        // CRITICAL FIX: Save both in SINGLE ATOMIC OPERATION using proper CloudKit API
        print("💾 Saving root record and share atomically...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share], 
                recordIDsToDelete: nil
            )
            modifyRecordsOperation.savePolicy = .ifServerRecordUnchanged
            modifyRecordsOperation.isAtomic = true
            
            modifyRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                if let error = error {
                    print("❌ Failed to save root record and share atomically: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Successfully saved root record and share atomically")
                    
                    // Find the saved records
                    guard let savedRecords = savedRecords,
                          let savedRootRecord = savedRecords.first(where: { !($0 is CKShare) }),
                          let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare else {
                        print("❌ Could not find saved root record or share in results")
                        continuation.resume(throwing: OrganizationZoneError.shareCreationFailed)
                        return
                    }
                    
                    print("✅ Created organization root record and share successfully")
                    continuation.resume(returning: (savedRootRecord, savedShare))
                }
            }
            
            privateDatabase.add(modifyRecordsOperation)
        }
    }
    
    /// Fetch share for a root record using CloudKit sharing APIs
    private func fetchShareForRootRecord(_ rootRecord: CKRecord) async throws -> CKShare? {
        print("🔍 Checking if root record has an associated share...")
        
        do {
            // Try to fetch share metadata for this record
            // This is the proper way to check for existing shares
            let shareMetadata = try await container.shareMetadata(for: rootRecord)
            
            if let shareRecordID = shareMetadata.share?.recordID {
                // Fetch the actual share record
                let shareRecord = try await privateDatabase.record(for: shareRecordID)
                if let share = shareRecord as? CKShare {
                    print("✅ Found existing share for root record")
                    return share
                }
            }
        } catch let error as CKError {
            if error.code == .unknownItem || error.code == .recordNotFound {
                print("ℹ️ No share found for root record - this is normal for new zones")
                return nil
            } else {
                print("⚠️ Error checking for share: \(error)")
                // Don't throw here - missing share is not a fatal error
                return nil
            }
        } catch {
            print("⚠️ Unexpected error checking for share: \(error)")
            return nil
        }
        
        return nil
    }
    
    /// Switch to a different organization's shared zone
    func switchToOrganizationSharedZone(organizationID: String) async throws {
        print("🔄 Switching to organization SHARED zone: \(organizationID.prefix(8))...")
        
        let zoneData = try await setupOrganizationSharedZone(for: organizationID)
        currentOrganizationZone = zoneData.zone
        currentShare = zoneData.share
        isZoneReady = true
        
        print("✅ Switched to organization SHARED zone: \(organizationID.prefix(8))...")
    }
    
    /// Clear current zone (for sign out)
    func clearCurrentZone() {
        print("🧹 Clearing current organization SHARED zone")
        currentOrganizationZone = nil
        currentShare = nil
        isZoneReady = false
        organizationZones.removeAll()
    }
    
    // MARK: - Team Collaboration Methods
    
    /// Invite a user to the organization's shared zone
    func inviteUserToOrganization(_ email: String) async throws -> String {
        guard let share = currentShare else {
            throw OrganizationZoneError.noShareFound
        }
        
        print("📧 Inviting user \(email) to organization shared zone")
        
        // Get share URL directly from the CKShare object
        guard let shareURL = share.url else {
            throw OrganizationZoneError.invitationFailed
        }
        
        print("✅ Generated invitation URL for \(email)")
        return shareURL.absoluteString
    }
    
    /// Accept an organization invitation
    func acceptOrganizationInvitation(from url: URL) async throws {
        print("🤝 Accepting organization invitation from URL")
        
        do {
            let metadata = try await container.shareMetadata(for: url)
            let acceptedShare = try await container.accept(metadata)
            print("✅ Successfully accepted organization invitation")
            
            // Update current zone info if this is for the current organization
            currentShare = acceptedShare
            print("✅ Updated current share with accepted share")
        } catch {
            print("❌ Failed to accept organization invitation: \(error)")
            throw error
        }
    }
    
    /// Get the current organization's share URL for invitations
    func getOrganizationInviteURL() -> String? {
        return currentShare?.url?.absoluteString
    }
    
    // MARK: - Zone-Scoped Operations (Enhanced for Shared Zones)
    
    /// Save a project to the current organization's shared zone
    func saveProject(_ project: Project) async throws {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        // Set project data
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["materialCost"] = project.materialCost as CKRecordValue
        record["laborCost"] = project.laborCost as CKRecordValue
        record["startDate"] = project.startDate as CKRecordValue
        record["endDate"] = project.endDate as CKRecordValue
        record["organizationID"] = project.organizationID as CKRecordValue?
        
        // Store full project as JSON for complete data preservation
        if let projectData = try? JSONEncoder().encode(project) {
            record["fullProjectData"] = projectData as CKRecordValue
        }
        
        // Save to private DB (zone owner) or shared DB (zone participant)
        let database = await getDatabaseForCurrentZone()
        let savedRecord = try await database.save(record)
        print("✅ Saved project '\(project.name)' to SHARED zone: \(zone.zoneID.zoneName)")
    }
    
    /// Load all projects from the current organization's shared zone
    func loadProjectsFromCurrentSharedZone() async throws -> [Project] {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        print("📥 Loading projects from SHARED zone: \(zone.zoneID.zoneName)")
        
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        let database = await getDatabaseForCurrentZone()
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: zone.zoneID)
        
        let projects = matchResults.compactMap { (_, recordResult) -> Project? in
            switch recordResult {
            case .success(let record):
                return recordToProject(record)
            case .failure(let error):
                print("❌ Failed to process project record: \(error)")
                return nil
            }
        }
        
        print("✅ Loaded \(projects.count) projects from SHARED zone: \(zone.zoneID.zoneName)")
        return projects
    }
    
    /// Delete a project from the current organization's shared zone
    func deleteProject(_ projectID: UUID) async throws {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        let recordID = CKRecord.ID(recordName: projectID.uuidString, zoneID: zone.zoneID)
        
        let database = await getDatabaseForCurrentZone()
        try await database.deleteRecord(withID: recordID)
        print("✅ Deleted project from SHARED zone: \(zone.zoneID.zoneName)")
    }
    
    /// Save organization team members to CloudKit shared zone
    func saveOrganizationTeamMembers(_ teamMembers: [TeamMember]) async throws {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        // Create or update organization record with team members
        let recordID = CKRecord.ID(recordName: "organization_\(zone.zoneID.zoneName)", zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Organization", recordID: recordID)
        
        // Set organization data
        record["teamMembersData"] = try? JSONEncoder().encode(teamMembers) as CKRecordValue
        
        // Save to appropriate database
        let database = await getDatabaseForCurrentZone()
        let savedRecord = try await database.save(record)
        print("✅ Saved \(teamMembers.count) team members to organization in SHARED zone")
    }
    
    /// Load organization team members from CloudKit shared zone
    func loadOrganizationTeamMembers() async throws -> (teamMembers: [TeamMember], lastModified: Date) {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        print("📥 Loading organization team members from SHARED zone: \(zone.zoneID.zoneName)")
        
        let recordID = CKRecord.ID(recordName: "organization_\(zone.zoneID.zoneName)", zoneID: zone.zoneID)
        let database = await getDatabaseForCurrentZone()
        let record = try await database.record(for: recordID)
        
        if let teamMembersData = record["teamMembersData"] as? Data,
           let teamMembers = try? JSONDecoder().decode([TeamMember].self, from: teamMembersData) {
            let lastModified = record.modificationDate ?? Date()
            print("✅ Loaded \(teamMembers.count) team members from organization SHARED zone")
            return (teamMembers: teamMembers, lastModified: lastModified)
        }
        
        print("⚠️ No team members found in organization record")
        return (teamMembers: [], lastModified: Date())
    }
    
    // MARK: - Helper Methods
    
    /// Determine which database to use based on zone ownership
    private func getDatabaseForCurrentZone() async -> CKDatabase {
        // If we have a share, we're a participant, use shared DB
        if currentShare != nil {
            return sharedDB
        }
        // Otherwise, we're the owner, use private DB
        return privateDB
    }
    
    private func recordToProject(_ record: CKRecord) -> Project? {
        // Try to decode from full project data first
        if let projectData = record["fullProjectData"] as? Data,
           let project = try? JSONDecoder().decode(Project.self, from: projectData) {
            return project
        }
        
        // Fallback to basic project construction
        guard let name = record["name"] as? String,
              let client = record["client"] as? String,
              let totalBudget = record["totalBudget"] as? Double,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else {
            return nil
        }
        
        let materialCost = record["materialCost"] as? Double ?? 0
        let laborCost = record["laborCost"] as? Double ?? 0
        let organizationID = record["organizationID"] as? String
        
        return Project(
            name: name,
            client: client,
            totalBudget: totalBudget,
            materialCost: materialCost,
            laborCost: laborCost,
            generalConditions: 0,
            contingency: 0,
            profit: 0,
            startDate: startDate,
            endDate: endDate,
            organizationID: organizationID
        )
    }
    
    /// Get diagnostic information about current shared zone
    func getSharedZoneDiagnostics() -> String {
        guard let zone = currentOrganizationZone else {
            return "❌ No organization SHARED zone set"
        }
        
        return """
        🏗️ ORGANIZATION SHARED ZONE DIAGNOSTICS:
        
        Zone Name: \(zone.zoneID.zoneName)
        Zone Owner: \(zone.zoneID.ownerName)
        Zone Ready: \(isZoneReady ? "✅" : "❌")
        Share Available: \(currentShare != nil ? "✅" : "❌")
        Share URL: \(currentShare?.url?.absoluteString ?? "None")
        Cached Zones: \(organizationZones.count)
        
        This SHARED zone enables team collaboration:
        • Kevin and Rachel can both access data
        • Team members can be invited
        • Independent contractors can be added
        • Complete data isolation from other organizations
        """
    }
}

// MARK: - Enhanced Error Types

enum OrganizationZoneError: LocalizedError {
    case noZoneSet
    case noShareFound
    case zoneCreationFailed
    case shareCreationFailed
    case recordNotFound
    case invitationFailed
    
    var errorDescription: String? {
        switch self {
        case .noZoneSet:
            return "No organization shared zone is currently set"
        case .noShareFound:
            return "No share found for current organization zone"
        case .zoneCreationFailed:
            return "Failed to create organization shared zone"
        case .shareCreationFailed:
            return "Failed to create share for organization zone"
        case .recordNotFound:
            return "Record not found in organization shared zone"
        case .invitationFailed:
            return "Failed to send organization invitation"
        }
    }
}