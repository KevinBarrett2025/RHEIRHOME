import Foundation
import CloudKit
import Combine
import OSLog

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
        Logger.cloudKitZone.info(
            "Setting up shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
        // Check if we already have this zone cached
        if let existingZoneData = organizationZones[organizationID] {
            currentOrganizationZone = existingZoneData.zone
            currentShare = existingZoneData.share
            isZoneReady = true
            Logger.cloudKitZone.info(
                "Using cached shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
            return existingZoneData
        }
        
        let zoneName = "org-shared-\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        do {
            // STEP 1: Check if zone exists in PRIVATE database (where zone owner keeps it)
            Logger.cloudKitZone.info(
                "Checking private database for existing shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
            let existingZones = try await privateDatabase.allRecordZones()
            if let existingZone = existingZones.first(where: { $0.zoneID.zoneName == zoneName }) {
                Logger.cloudKitZone.notice(
                    "Found existing shared organization zone in private database [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
                )
                
                // Try to find the root record and its share
                let rootRecordID = CKRecord.ID(recordName: "org-root-\(organizationID)", zoneID: existingZone.zoneID)
                
                do {
                    let existingRootRecord = try await privateDatabase.record(for: rootRecordID)
                    Logger.cloudKitZone.info(
                        "Found organization root record for shared zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
                    )
                    
                    // Try to fetch share metadata for this record
                    let existingShare = try await fetchShareForRootRecord(existingRootRecord)
                    
                    let zoneData = (zone: existingZone, share: existingShare)
                    organizationZones[organizationID] = zoneData
                    currentOrganizationZone = existingZone
                    currentShare = existingShare
                    isZoneReady = true
                    
                    if existingShare != nil {
                        Logger.cloudKitZone.notice(
                            "Shared organization zone already has collaboration enabled [organization=\(organizationID, privacy: .private(mask: .hash))]"
                        )
                    } else {
                        Logger.cloudKitZone.warning(
                            "Shared organization zone exists without a share record [organization=\(organizationID, privacy: .private(mask: .hash))]"
                        )
                        Logger.cloudKitZone.info(
                            "Completed shared zone setup without collaboration share [organization=\(organizationID, privacy: .private(mask: .hash))]"
                        )
                    }
                    
                    return zoneData
                    
                } catch let error as CKError where error.code == .unknownItem {
                    Logger.cloudKitZone.warning(
                        "Shared organization zone exists without a root record; recreating collaboration records [organization=\(organizationID, privacy: .private(mask: .hash))]"
                    )
                    // Fall through to create new root record and share
                } catch {
                    Logger.cloudKitZone.error(
                        "Failed to fetch shared zone root record [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    throw error
                }
            }
            
            // STEP 2: Zone doesn't exist or root record missing - create everything
            Logger.cloudKitZone.notice(
                "Creating new shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
            )
            
            // Create zone first
            let newZone = CKRecordZone(zoneID: zoneID)
            let savedZone = try await privateDatabase.save(newZone)
            Logger.cloudKitZone.notice(
                "Created shared organization zone in private database [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
            )
            
            // Create root record and share atomically
            let (_, share) = try await createRootRecordAndShareAtomically(
                organizationID: organizationID, 
                zone: savedZone
            )
            
            let zoneData = (zone: savedZone, share: share)
            organizationZones[organizationID] = zoneData
            currentOrganizationZone = savedZone
            currentShare = share
            isZoneReady = true
            
            Logger.cloudKitZone.notice(
                "Created shared organization zone with collaboration enabled [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
            )
            
            return zoneData
            
        } catch let error as CKError {
            Logger.cloudKitZone.error(
                "CloudKit error during shared organization zone setup [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            if error.code == .zoneNotFound {
                // This shouldn't happen in the private DB check, but handle it
                Logger.cloudKitZone.warning(
                    "Shared organization zone was not found during setup; recreating it [organization=\(organizationID, privacy: .private(mask: .hash))]"
                )
                
                let newZone = CKRecordZone(zoneID: zoneID)
                let savedZone = try await privateDatabase.save(newZone)
                
                let (_, share) = try await createRootRecordAndShareAtomically(
                    organizationID: organizationID,
                    zone: savedZone
                )
                
                let zoneData = (zone: savedZone, share: share)
                organizationZones[organizationID] = zoneData
                currentOrganizationZone = savedZone
                currentShare = share
                isZoneReady = true
                
                Logger.cloudKitZone.notice(
                    "Recreated shared organization zone after zone-not-found error [organization=\(organizationID, privacy: .private(mask: .hash)), zone=\(zoneName, privacy: .private(mask: .hash))]"
                )
                
                return zoneData
            } else {
                throw error
            }
        } catch {
            Logger.cloudKitZone.error(
                "Failed to set up shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
            )
            throw error
        }
    }
    
    /// Create root record and share in a single atomic operation
    private func createRootRecordAndShareAtomically(organizationID: String, zone: CKRecordZone) async throws -> (CKRecord, CKShare) {
        Logger.cloudKitZone.info(
            "Creating root record and share atomically for shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
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
        Logger.cloudKitZone.info(
            "Saving root record and share atomically for shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let modifyRecordsOperation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share], 
                recordIDsToDelete: nil
            )
            modifyRecordsOperation.savePolicy = .ifServerRecordUnchanged
            modifyRecordsOperation.isAtomic = true
            
            modifyRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                if let error = error {
                    Logger.cloudKitZone.error(
                        "Failed atomic save for shared organization root/share records [organization=\(organizationID, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                    )
                    continuation.resume(throwing: error)
                } else {
                    Logger.cloudKitZone.notice(
                        "Completed atomic save for shared organization root/share records [organization=\(organizationID, privacy: .private(mask: .hash))]"
                    )
                    
                    // Find the saved records
                    guard let savedRecords = savedRecords,
                          let savedRootRecord = savedRecords.first(where: { !($0 is CKShare) }),
                          let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare else {
                        Logger.cloudKitZone.error(
                            "Atomic save did not return both root record and share [organization=\(organizationID, privacy: .private(mask: .hash))]"
                        )
                        continuation.resume(throwing: OrganizationZoneError.shareCreationFailed)
                        return
                    }
                    
                    Logger.cloudKitZone.notice(
                        "Created organization root record and share successfully [organization=\(organizationID, privacy: .private(mask: .hash))]"
                    )
                    continuation.resume(returning: (savedRootRecord, savedShare))
                }
            }
            
            privateDatabase.add(modifyRecordsOperation)
        }
    }
    
    /// Fetch share for a root record using CloudKit sharing APIs
    private func fetchShareForRootRecord(_ rootRecord: CKRecord) async throws -> CKShare? {
        Logger.cloudKitZone.info("Checking whether organization root record has an associated share.")
        
        do {
            // Try to fetch share metadata for this record
            // This is the proper way to check for existing shares
            let shareMetadata = try await container.shareMetadata(for: rootRecord)
            
            if let shareRecordID = shareMetadata.share?.recordID {
                // Fetch the actual share record
                let shareRecord = try await privateDatabase.record(for: shareRecordID)
                if let share = shareRecord as? CKShare {
                    Logger.cloudKitZone.notice("Found existing share for organization root record.")
                    return share
                }
            }
        } catch let error as CKError {
            if error.code == .unknownItem || error.code == .recordNotFound {
                Logger.cloudKitZone.info("No share is attached to the organization root record yet.")
                return nil
            } else {
                Logger.cloudKitZone.warning(
                    "Error while checking for organization root share [error=\(error.localizedDescription, privacy: .public)]"
                )
                // Don't throw here - missing share is not a fatal error
                return nil
            }
        } catch {
            Logger.cloudKitZone.warning(
                "Unexpected error while checking for organization root share [error=\(error.localizedDescription, privacy: .public)]"
            )
            return nil
        }
        
        return nil
    }
    
    /// Switch to a different organization's shared zone
    func switchToOrganizationSharedZone(organizationID: String) async throws {
        Logger.cloudKitZone.info(
            "Switching active shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
        
        let zoneData = try await setupOrganizationSharedZone(for: organizationID)
        currentOrganizationZone = zoneData.zone
        currentShare = zoneData.share
        isZoneReady = true
        
        Logger.cloudKitZone.notice(
            "Switched active shared organization zone [organization=\(organizationID, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Clear current zone (for sign out)
    func clearCurrentZone() {
        Logger.cloudKitZone.notice("Cleared current shared organization zone and cache.")
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
        
        Logger.cloudKitZone.info(
            "Generating organization share invitation URL [invitee=\(email, privacy: .private(mask: .hash))]"
        )
        
        // Get share URL directly from the CKShare object
        guard let shareURL = share.url else {
            throw OrganizationZoneError.invitationFailed
        }
        
        Logger.cloudKitZone.notice(
            "Generated organization share invitation URL [invitee=\(email, privacy: .private(mask: .hash))]"
        )
        return shareURL.absoluteString
    }
    
    /// Accept an organization invitation
    func acceptOrganizationInvitation(from url: URL) async throws {
        Logger.cloudKitZone.info("Accepting organization share invitation from URL.")
        
        do {
            let metadata = try await container.shareMetadata(for: url)
            let acceptedShare = try await container.accept(metadata)
            Logger.cloudKitZone.notice("Accepted organization share invitation.")
            
            // Update current zone info if this is for the current organization
            currentShare = acceptedShare
            Logger.cloudKitZone.notice("Updated current organization share after invitation acceptance.")
        } catch {
            Logger.cloudKitZone.error(
                "Failed to accept organization share invitation [error=\(error.localizedDescription, privacy: .public)]"
            )
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
        _ = try await database.save(record)
        Logger.cloudKitZone.notice(
            "Saved project to shared organization zone [project=\(project.name, privacy: .private(mask: .hash)), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Load all projects from the current organization's shared zone
    func loadProjectsFromCurrentSharedZone() async throws -> [Project] {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        Logger.cloudKitZone.info(
            "Loading projects from shared organization zone [zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
        
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        let database = await getDatabaseForCurrentZone()
        let (matchResults, _) = try await database.records(matching: query, inZoneWith: zone.zoneID)
        
        let projects = matchResults.compactMap { (_, recordResult) -> Project? in
            switch recordResult {
            case .success(let record):
                return recordToProject(record)
            case .failure(let error):
                Logger.cloudKitZone.error(
                    "Failed to process project record from shared organization zone [zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                )
                return nil
            }
        }
        
        Logger.cloudKitZone.notice(
            "Loaded projects from shared organization zone [zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash)), count=\(projects.count, privacy: .public)]"
        )
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
        Logger.cloudKitZone.notice(
            "Deleted project from shared organization zone [project=\(projectID.uuidString, privacy: .private(mask: .hash)), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
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
        _ = try await database.save(record)
        Logger.cloudKitZone.notice(
            "Saved organization team members to shared zone [count=\(teamMembers.count, privacy: .public), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
    }
    
    /// Load organization team members from CloudKit shared zone
    func loadOrganizationTeamMembers() async throws -> (teamMembers: [TeamMember], lastModified: Date) {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        Logger.cloudKitZone.info(
            "Loading organization team members from shared zone [zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
        
        let recordID = CKRecord.ID(recordName: "organization_\(zone.zoneID.zoneName)", zoneID: zone.zoneID)
        let database = await getDatabaseForCurrentZone()
        let record = try await database.record(for: recordID)
        
        if let teamMembersData = record["teamMembersData"] as? Data,
           let teamMembers = try? JSONDecoder().decode([TeamMember].self, from: teamMembersData) {
            let lastModified = record.modificationDate ?? Date()
            Logger.cloudKitZone.notice(
                "Loaded organization team members from shared zone [count=\(teamMembers.count, privacy: .public), zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
            )
            return (teamMembers: teamMembers, lastModified: lastModified)
        }
        
        Logger.cloudKitZone.warning(
            "Organization shared zone record did not contain team members [zone=\(zone.zoneID.zoneName, privacy: .private(mask: .hash))]"
        )
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
