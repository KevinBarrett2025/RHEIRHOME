import Foundation
import CloudKit

class CloudKitCompatibilityService {
    
    // Helper to read isActive from either STRING or INT64 field
    static func getIsActive(from record: CKRecord) -> Bool {
        // Try new INT64 field first
        if let isActiveV2 = record["isActiveV2"] as? Int64 {
            return isActiveV2 == 1
        }
        
        // Fallback to old STRING field
        if let isActiveString = record["isActive"] as? String {
            return isActiveString.lowercased() == "true" || isActiveString == "1"
        }
        
        return false // Default value
    }
    
    // Helper to read maxMembers from either STRING or INT64 field
    static func getMaxMembers(from record: CKRecord) -> Int {
        // Try new INT64 field first
        if let maxMembersV2 = record["maxMembersV2"] as? Int64 {
            return Int(maxMembersV2)
        }
        
        // Fallback to old STRING field
        if let maxMembersString = record["maxMembers"] as? String,
           let maxMembers = Int(maxMembersString) {
            return maxMembers
        }
        
        return 10 // Default value
    }
    
    // Helper to read date from either STRING or TIMESTAMP field
    static func getDate(from record: CKRecord) -> Date {
        // Try new TIMESTAMP field first
        if let dateV2 = record["dateV2"] as? Date {
            return dateV2
        }
        
        // Fallback to old STRING field
        if let dateString = record["date"] as? String {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString) ?? Date()
        }
        
        return Date() // Default value
    }
    
    // Helper to write fields in both formats for compatibility
    static func setIsActive(_ value: Bool, on record: CKRecord) {
        record["isActive"] = (value ? "true" : "false") as CKRecordValue    // Old format
        record["isActiveV2"] = (value ? 1 : 0) as CKRecordValue            // New format
    }
    
    static func setMaxMembers(_ value: Int, on record: CKRecord) {
        record["maxMembers"] = String(value) as CKRecordValue               // Old format
        record["maxMembersV2"] = Int64(value) as CKRecordValue              // New format
    }
    
    static func setDate(_ value: Date, on record: CKRecord) {
        let formatter = ISO8601DateFormatter()
        record["date"] = formatter.string(from: value) as CKRecordValue     // Old format
        record["dateV2"] = value as CKRecordValue                           // New format
    }
    
    // Helper to write project data with full backup
    static func setProjectData(_ project: Project, on record: CKRecord) {
        // Basic project fields for querying
        record["name"] = project.name as CKRecordValue
        record["client"] = project.client as CKRecordValue
        record["organizationID"] = "primary-organization" as CKRecordValue
        record["totalBudget"] = project.totalBudget as CKRecordValue
        record["startDate"] = project.startDate as CKRecordValue
        record["endDate"] = project.endDate as CKRecordValue
        record["status"] = project.status.rawValue as CKRecordValue
        
        // Store complete project as JSON backup (now that fullProjectData field exists)
        if let projectData = try? JSONEncoder().encode(project) {
            record["fullProjectData"] = projectData as CKRecordValue
        }
    }
    
    // Helper to read project from CloudKit record
    static func getProject(from record: CKRecord) -> Project? {
        // Try to decode from fullProjectData first (most complete)
        if let projectData = record["fullProjectData"] as? Data,
           let project = try? JSONDecoder().decode(Project.self, from: projectData) {
            return project
        }
        
        // Fallback: construct from individual fields (basic recovery)
        guard let name = record["name"] as? String,
              let client = record["client"] as? String,
              let totalBudget = record["totalBudget"] as? Double,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else {
            return nil
        }
        
        // Create basic project from available fields
        return Project(
            name: name,
            client: client,
            totalBudget: totalBudget,
            materialCost: 0,
            laborCost: 0,
            generalConditions: 0,
            contingency: 0,
            
            startDate: startDate,
            endDate: endDate
        )
    }
}
