import Foundation
import CloudKit
import Combine

/// Handles secure zone-based multi-tenant data isolation for organizations
@MainActor
class OrganizationZoneService: ObservableObject {
    
    // MARK: - Properties
    private let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    
    @Published var currentOrganizationZone: CKRecordZone?
    @Published var isZoneReady = false
    
    private var organizationZones: [String: CKRecordZone] = [:]
    
    // MARK: - Zone Management
    
    /// Create or get the zone for a specific organization
    func setupOrganizationZone(for organizationID: String) async throws -> CKRecordZone {
        print("🏗️ Setting up zone for organization: \(organizationID.prefix(8))...")
        
        // Check if we already have this zone cached
        if let existingZone = organizationZones[organizationID] {
            currentOrganizationZone = existingZone
            isZoneReady = true
            print("✅ Using cached zone for organization: \(organizationID.prefix(8))...")
            return existingZone
        }
        
        let zoneName = "org-\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        do {
            // Try to fetch existing zone first
            let existingZone = try await privateDB.recordZone(for: zoneID)
            print("✅ Found existing zone: \(zoneName)")
            
            organizationZones[organizationID] = existingZone
            currentOrganizationZone = existingZone
            isZoneReady = true
            
            return existingZone
            
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone doesn't exist, create it
            print("🆕 Creating new zone: \(zoneName)")
            
            let newZone = CKRecordZone(zoneID: zoneID)
            let savedZone = try await privateDB.save(newZone)
            
            print("✅ Created zone: \(zoneName)")
            
            organizationZones[organizationID] = savedZone
            currentOrganizationZone = savedZone
            isZoneReady = true
            
            return savedZone
            
        } catch {
            print("❌ Failed to setup zone for organization \(organizationID.prefix(8)): \(error)")
            throw error
        }
    }
    
    /// Switch to a different organization's zone
    func switchToOrganizationZone(organizationID: String) async throws {
        print("🔄 Switching to organization zone: \(organizationID.prefix(8))...")
        
        let zone = try await setupOrganizationZone(for: organizationID)
        currentOrganizationZone = zone
        isZoneReady = true
        
        print("✅ Switched to organization zone: \(organizationID.prefix(8))...")
    }
    
    /// Clear current zone (for sign out)
    func clearCurrentZone() {
        print("🧹 Clearing current organization zone")
        currentOrganizationZone = nil
        isZoneReady = false
        organizationZones.removeAll()
    }
    
    // MARK: - Zone-Scoped Operations
    
    /// Save a project to the current organization's zone
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
        
        let savedRecord = try await privateDB.save(record)
        print("✅ Saved project '\(project.name)' to zone: \(zone.zoneID.zoneName)")
    }
    
    /// Load all projects from the current organization's zone
    func loadProjectsFromCurrentZone() async throws -> [Project] {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        print("📥 Loading projects from zone: \(zone.zoneID.zoneName)")
        
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        let result = try await privateDB.records(matching: query, inZoneWith: zone.zoneID)
        
        let projects = result.matchResults.compactMap { (_, recordResult) -> Project? in
            switch recordResult {
            case .success(let record):
                return recordToProject(record)
            case .failure(let error):
                print("❌ Failed to process project record: \(error)")
                return nil
            }
        }
        
        print("✅ Loaded \(projects.count) projects from zone: \(zone.zoneID.zoneName)")
        return projects
    }
    
    /// Delete a project from the current organization's zone
    func deleteProject(_ projectID: UUID) async throws {
        guard let zone = currentOrganizationZone else {
            throw OrganizationZoneError.noZoneSet
        }
        
        let recordID = CKRecord.ID(recordName: projectID.uuidString, zoneID: zone.zoneID)
        
        try await privateDB.deleteRecord(withID: recordID)
        print("✅ Deleted project from zone: \(zone.zoneID.zoneName)")
    }
    
    // MARK: - Helper Methods
    
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
    
    /// Get diagnostic information about current zone
    func getZoneDiagnostics() -> String {
        guard let zone = currentOrganizationZone else {
            return "❌ No organization zone set"
        }
        
        return """
        🏗️ ORGANIZATION ZONE DIAGNOSTICS:
        
        Zone Name: \(zone.zoneID.zoneName)
        Zone Owner: \(zone.zoneID.ownerName)
        Zone Ready: \(isZoneReady ? "✅" : "❌")
        Cached Zones: \(organizationZones.count)
        
        This zone contains ONLY data for the current organization.
        Complete data isolation from other organizations.
        """
    }
}

// MARK: - Error Types

enum OrganizationZoneError: LocalizedError {
    case noZoneSet
    case zoneCreationFailed
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .noZoneSet:
            return "No organization zone is currently set"
        case .zoneCreationFailed:
            return "Failed to create organization zone"
        case .recordNotFound:
            return "Record not found in organization zone"
        }
    }
}