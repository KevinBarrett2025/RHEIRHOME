import Foundation
import CloudKit
import Combine

/// Real CloudKit service for persisting Project records to organization-specific zones
@MainActor
class CloudKitProjectService: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncError: Error?
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(Error)
    }
    
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Project Persistence
    
    /// Save project to organization-specific CloudKit zone
    func saveProject(_ project: Project, to organizationID: String) async throws {
        print("☁️ [CloudKitProjectService] Saving project '\(project.name)' to organization zone: \(organizationID.prefix(8))...")
        
        syncStatus = .syncing
        
        do {
            // Create organization-specific zone if it doesn't exist
            let zoneID = CKRecordZone.ID(zoneName: "org-shared-\(organizationID)", ownerName: CKCurrentUserDefaultName)
            
            // Create project record
            let projectRecord = try createProjectRecord(from: project, in: zoneID)
            
            // Save to CloudKit
            let savedRecords = try await privateDatabase.modifyRecords(saving: [projectRecord], deleting: [])
            
            if let savedRecord = savedRecords.saveResults.first?.value {
                switch savedRecord {
                case .success(let record):
                    print("✅ [CloudKitProjectService] Project saved successfully: \(record.recordID.recordName)")
                    syncStatus = .success
                case .failure(let error):
                    print("❌ [CloudKitProjectService] Failed to save project: \(error)")
                    syncStatus = .error(error)
                    throw error
                }
            }
            
        } catch {
            print("❌ [CloudKitProjectService] Save operation failed: \(error)")
            syncStatus = .error(error)
            lastSyncError = error
            throw error
        }
    }
    
    /// Load all projects from organization-specific CloudKit zone
    func loadProjects(from organizationID: String) async throws -> [Project] {
        print("☁️ [CloudKitProjectService] Loading projects from organization zone: \(organizationID.prefix(8))...")
        
        syncStatus = .syncing
        
        do {
            let zoneID = CKRecordZone.ID(zoneName: "org-shared-\(organizationID)", ownerName: CKCurrentUserDefaultName)
            
            // Query for all Project records in this organization zone
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let query = CKQuery(recordType: "Project", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
            
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
            
            var projects: [Project] = []
            
            for (recordID, result) in matchResults {
                switch result {
                case .success(let record):
                    do {
                        let project = try createProject(from: record)
                        projects.append(project)
                        print("✅ [CloudKitProjectService] Loaded project: \(project.name)")
                    } catch {
                        print("⚠️ [CloudKitProjectService] Failed to parse project \(recordID.recordName): \(error)")
                    }
                case .failure(let error):
                    print("❌ [CloudKitProjectService] Failed to load project \(recordID.recordName): \(error)")
                }
            }
            
            print("✅ [CloudKitProjectService] Loaded \(projects.count) projects from CloudKit")
            syncStatus = .success
            return projects
            
        } catch {
            print("❌ [CloudKitProjectService] Load operation failed: \(error)")
            syncStatus = .error(error)
            lastSyncError = error
            throw error
        }
    }
    
    /// Delete project from CloudKit
    func deleteProject(_ projectID: UUID, from organizationID: String) async throws {
        print("🗑️ [CloudKitProjectService] Deleting project \(projectID) from organization zone: \(organizationID.prefix(8))...")
        
        syncStatus = .syncing
        
        do {
            let zoneID = CKRecordZone.ID(zoneName: "org-shared-\(organizationID)", ownerName: CKCurrentUserDefaultName)
            let recordID = CKRecord.ID(recordName: projectID.uuidString, zoneID: zoneID)
            
            let deleteResults = try await privateDatabase.modifyRecords(saving: [], deleting: [recordID])
            
            if let deleteResult = deleteResults.deleteResults[recordID] {
                switch deleteResult {
                case .success:
                    print("✅ [CloudKitProjectService] Project deleted successfully")
                    syncStatus = .success
                case .failure(let error):
                    print("❌ [CloudKitProjectService] Failed to delete project: \(error)")
                    syncStatus = .error(error)
                    throw error
                }
            }
            
        } catch {
            print("❌ [CloudKitProjectService] Delete operation failed: \(error)")
            syncStatus = .error(error)
            lastSyncError = error
            throw error
        }
    }
    
    // MARK: - Record Conversion
    
    /// Create CloudKit record from Project model
    private func createProjectRecord(from project: Project, in zoneID: CKRecordZone.ID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: project.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        // Basic project info
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["organizationID"] = project.organizationID as CKRecordValue
        record["createdTimestamp"] = project.createdTimestamp as CKRecordValue
        record["lastModified"] = project.lastModified as CKRecordValue
        
        // Contact info
        record["clientPhone"] = project.phone as CKRecordValue?
        record["clientEmail"] = project.email as CKRecordValue?
        
        // Address
        record["street"] = project.street as CKRecordValue?
        record["city"] = project.city as CKRecordValue?
        record["state"] = project.state as CKRecordValue?
        record["zip"] = project.zip as CKRecordValue?
        record["country"] = project.country as CKRecordValue?
        
        // Dates
        record["startDate"] = project.startDate as CKRecordValue?
        record["endDate"] = project.endDate as CKRecordValue?
        record["actualStartDate"] = project.actualStartDate as CKRecordValue?
        record["actualEndDate"] = project.actualEndDate as CKRecordValue?
        
        // Budget breakdown
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["materialCost"] = project.materialCost as CKRecordValue
        record["laborCost"] = project.laborCost as CKRecordValue
        record["generalConditions"] = project.generalConditions as CKRecordValue
        record["contingency"] = project.contingency as CKRecordValue
        record["profit"] = project.profit as CKRecordValue
        record["spentContingency"] = project.spentContingency as CKRecordValue
        
        // Status and metadata
        record["status"] = project.status.rawValue as CKRecordValue
        record["priority"] = project.priority?.rawValue as CKRecordValue?
        record["notes"] = project.notes as CKRecordValue?
        record["description"] = project.description as CKRecordValue?
        
        // Team assignments
        record["assignedTeamMemberIDs"] = project.assignedTeamMemberIDs as CKRecordValue
        record["assignedUserIDs"] = project.assignedUserIDs as CKRecordValue?
        
        // Permissions and sharing
        record["accessLevel"] = project.accessLevel?.rawValue as CKRecordValue?
        record["isShared"] = (project.isShared ? 1 : 0) as CKRecordValue
        record["sharedWithTeam"] = (project.sharedWithTeam ? 1 : 0) as CKRecordValue
        
        // Additional fields
        record["projectManager"] = project.projectManager as CKRecordValue?
        record["createdBy"] = project.createdBy as CKRecordValue?
        record["lastModifiedBy"] = project.lastModifiedBy as CKRecordValue?
        record["estimatedDuration"] = project.estimatedDuration as CKRecordValue?
        record["actualTotalCost"] = project.actualTotalCost as CKRecordValue?
        
        // Location data
        if let location = project.location {
            record["location"] = location as CKRecordValue
        }
        
        // Environment
        record["environment"] = "production" as CKRecordValue
        
        return record
    }
    
    /// Create Project model from CloudKit record
    private func createProject(from record: CKRecord) throws -> Project {
        guard let name = record["name"] as? String,
              let client = record["client"] as? String,
              let organizationID = record["organizationID"] as? String else {
            throw CloudKitProjectError.invalidRecord("Missing required fields")
        }
        
        // Parse project ID from record name
        guard let projectID = UUID(uuidString: record.recordID.recordName) else {
            throw CloudKitProjectError.invalidRecord("Invalid project ID")
        }
        
        var project = Project(
            id: projectID,
            name: name,
            client: client,
            phone: record["clientPhone"] as? String ?? "",
            email: record["clientEmail"] as? String ?? "",
            street: record["street"] as? String ?? "",
            city: record["city"] as? String ?? "",
            state: record["state"] as? String ?? "",
            zip: record["zip"] as? String ?? "",
            notes: record["notes"] as? String ?? "",
            totalBudget: record["totalBudget"] as? Double ?? 0.0,
            materialCost: record["materialCost"] as? Double ?? 0.0,
            laborCost: record["laborCost"] as? Double ?? 0.0,
            generalConditions: record["generalConditions"] as? Double ?? 0.0,
            contingency: record["contingency"] as? Double ?? 0.0,
            profit: record["profit"] as? Double ?? 0.0,
            startDate: record["startDate"] as? Date ?? Date(),
            endDate: record["endDate"] as? Date ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
            status: ProjectStatus(rawValue: record["status"] as? String ?? "active") ?? .active,
            organizationID: organizationID
        )
        
        // Set additional properties
        project.country = record["country"] as? String
        project.actualStartDate = record["actualStartDate"] as? Date
        project.actualEndDate = record["actualEndDate"] as? Date
        project.spentContingency = record["spentContingency"] as? Double ?? 0.0
        project.description = record["description"] as? String
        project.assignedTeamMemberIDs = record["assignedTeamMemberIDs"] as? [String] ?? []
        project.assignedUserIDs = record["assignedUserIDs"] as? [String] ?? []
        project.isShared = (record["isShared"] as? Int ?? 0) == 1
        project.sharedWithTeam = (record["sharedWithTeam"] as? Int ?? 0) == 1
        project.projectManager = record["projectManager"] as? String
        project.createdBy = record["createdBy"] as? String
        project.lastModifiedBy = record["lastModifiedBy"] as? String
        project.estimatedDuration = record["estimatedDuration"] as? Int64
        project.actualTotalCost = record["actualTotalCost"] as? Double
        project.location = record["location"] as? CLLocation
        
        // Parse timestamps
        if let createdTimestamp = record["createdTimestamp"] as? Date {
            project.createdTimestamp = createdTimestamp
        }
        if let lastModified = record["lastModified"] as? Date {
            project.lastModified = lastModified
        }
        
        // Parse priority
        if let priorityString = record["priority"] as? String {
            project.priority = ProjectPriority(rawValue: priorityString)
        }
        
        // Parse access level
        if let accessLevelString = record["accessLevel"] as? String {
            project.accessLevel = ProjectAccessLevel(rawValue: accessLevelString)
        }
        
        return project
    }
    
    // MARK: - Zone Management
    
    /// Ensure organization zone exists
    func ensureOrganizationZoneExists(_ organizationID: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: "org-shared-\(organizationID)", ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            let modifyResult = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
            
            if let saveResult = modifyResult.saveResults[zoneID] {
                switch saveResult {
                case .success(let savedZone):
                    print("✅ [CloudKitProjectService] Organization zone ready: \(savedZone.zoneID.zoneName)")
                case .failure(let error):
                    // Zone might already exist
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                        print("ℹ️ [CloudKitProjectService] Organization zone already exists")
                    } else {
                        print("❌ [CloudKitProjectService] Failed to create zone: \(error)")
                        throw error
                    }
                }
            }
        } catch {
            print("❌ [CloudKitProjectService] Zone creation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Batch Operations
    
    /// Save multiple projects to CloudKit
    func saveProjects(_ projects: [Project], to organizationID: String) async throws {
        print("☁️ [CloudKitProjectService] Batch saving \(projects.count) projects to organization zone: \(organizationID.prefix(8))...")
        
        syncStatus = .syncing
        
        do {
            // Ensure zone exists
            try await ensureOrganizationZoneExists(organizationID)
            
            let zoneID = CKRecordZone.ID(zoneName: "org-shared-\(organizationID)", ownerName: CKCurrentUserDefaultName)
            
            // Create records
            let records = try projects.map { try createProjectRecord(from: $0, in: zoneID) }
            
            // Batch save to CloudKit
            let saveResults = try await privateDatabase.modifyRecords(saving: records, deleting: [])
            
            var successCount = 0
            var errorCount = 0
            
            for (recordID, result) in saveResults.saveResults {
                switch result {
                case .success:
                    successCount += 1
                    print("✅ [CloudKitProjectService] Saved project: \(recordID.recordName.prefix(8))...")
                case .failure(let error):
                    errorCount += 1
                    print("❌ [CloudKitProjectService] Failed to save project \(recordID.recordName.prefix(8))...: \(error)")
                }
            }
            
            print("✅ [CloudKitProjectService] Batch save completed: \(successCount) success, \(errorCount) errors")
            syncStatus = .success
            
        } catch {
            print("❌ [CloudKitProjectService] Batch save failed: \(error)")
            syncStatus = .error(error)
            lastSyncError = error
            throw error
        }
    }
}

// MARK: - Errors

enum CloudKitProjectError: LocalizedError {
    case invalidRecord(String)
    case zoneNotFound
    case saveTimeout
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidRecord(let details):
            return "Invalid CloudKit record: \(details)"
        case .zoneNotFound:
            return "Organization zone not found"
        case .saveTimeout:
            return "CloudKit save operation timed out"
        case .networkUnavailable:
            return "Network unavailable for CloudKit operations"
        }
    }
}