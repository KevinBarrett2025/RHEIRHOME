import Foundation
import CloudKit

public enum ProjectPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
}

public struct Project: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var client: String
    public var clientEmail: String?
    public var clientPhone: String?
    public var clientAddress: String?
    public var description: String
    public var totalBudget: Double
    public var materialCost: Double
    public var laborCost: Double
    public var generalConditions: Double
    public var contingency: Double
    public var startDate: Date
    public var endDate: Date
    public var status: ProjectStatus
    public var priority: ProjectPriority
    public var assignedUserIDs: [String] // Team member IDs
    public var organizationID: String
    public var creationDate: Date
    public var lastModifiedDate: Date
    public var photoIDs: [String] // CloudKit photo record IDs
    
    // Child collections
    public var tasks: [ProjectTask] = []
    public var progressLogs: [ProgressLog] = []
    public var receipts: [Receipt] = []
    public var workHours: [WorkHour] = []
    public var communications: [Communication] = []
    public var changeOrders: [ChangeOrder] = []
    
    public init(
        id: UUID = UUID(),
        name: String,
        client: String,
        clientEmail: String? = nil,
        clientPhone: String? = nil,
        clientAddress: String? = nil,
        description: String = "",
        totalBudget: Double,
        materialCost: Double = 0,
        laborCost: Double = 0,
        generalConditions: Double = 0,
        contingency: Double = 0,
        startDate: Date,
        endDate: Date,
        status: ProjectStatus = .active,
        priority: ProjectPriority = .medium,
        assignedUserIDs: [String] = [],
        organizationID: String,
        creationDate: Date = Date(),
        lastModifiedDate: Date = Date(),
        photoIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.client = client
        self.clientEmail = clientEmail
        self.clientPhone = clientPhone
        self.clientAddress = clientAddress
        self.description = description
        self.totalBudget = totalBudget
        self.materialCost = materialCost
        self.laborCost = laborCost
        self.generalConditions = generalConditions
        self.contingency = contingency
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.priority = priority
        self.assignedUserIDs = assignedUserIDs
        self.organizationID = organizationID
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.photoIDs = photoIDs
    }
    
    // MARK: - Equatable Conformance
    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.client == rhs.client &&
               lhs.totalBudget == rhs.totalBudget &&
               lhs.status == rhs.status &&
               lhs.lastModifiedDate == rhs.lastModifiedDate
    }
    
    // MARK: - CloudKit Conversion
    
    public func toCKRecord(organizationID: UUID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Project", recordID: recordID)
        
        record["name"] = name as CKRecordValue
        record["client"] = client as CKRecordValue
        record["clientEmail"] = clientEmail as CKRecordValue?
        record["clientPhone"] = clientPhone as CKRecordValue?
        record["clientAddress"] = clientAddress as CKRecordValue?
        record["description"] = description as CKRecordValue
        record["totalBudget"] = totalBudget as CKRecordValue
        record["materialCost"] = materialCost as CKRecordValue
        record["laborCost"] = laborCost as CKRecordValue
        record["generalConditions"] = generalConditions as CKRecordValue
        record["contingency"] = contingency as CKRecordValue
        record["startDate"] = startDate as CKRecordValue
        record["endDate"] = endDate as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        record["priority"] = priority.rawValue as CKRecordValue
        record["assignedUserIDs"] = assignedUserIDs as CKRecordValue
        record["organizationID"] = organizationID.uuidString as CKRecordValue
        record["creationDate"] = creationDate as CKRecordValue
        record["lastModifiedDate"] = lastModifiedDate as CKRecordValue
        record["photoIDs"] = photoIDs as CKRecordValue
        
        // Serialize child collections as JSON data
        record["fullProjectData"] = try JSONEncoder().encode(self) as CKRecordValue
        
        return record
    }
    
    public init(from record: CKRecord) throws {
        id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        name = record["name"] as? String ?? ""
        client = record["client"] as? String ?? ""
        clientEmail = record["clientEmail"] as? String
        clientPhone = record["clientPhone"] as? String
        clientAddress = record["clientAddress"] as? String
        description = record["description"] as? String ?? ""
        totalBudget = record["totalBudget"] as? Double ?? 0
        materialCost = record["materialCost"] as? Double ?? 0
        laborCost = record["laborCost"] as? Double ?? 0
        generalConditions = record["generalConditions"] as? Double ?? 0
        contingency = record["contingency"] as? Double ?? 0
        startDate = record["startDate"] as? Date ?? Date()
        endDate = record["endDate"] as? Date ?? Date()
        status = ProjectStatus(rawValue: record["status"] as? String ?? "Active") ?? .active
        priority = ProjectPriority(rawValue: record["priority"] as? String ?? "Medium") ?? .medium
        assignedUserIDs = record["assignedUserIDs"] as? [String] ?? []
        organizationID = record["organizationID"] as? String ?? ""
        creationDate = record["creationDate"] as? Date ?? Date()
        lastModifiedDate = record["lastModifiedDate"] as? Date ?? Date()
        photoIDs = record["photoIDs"] as? [String] ?? []
        
        // Try to decode full project data if available
        if let data = record["fullProjectData"] as? Data {
            let fullProject = try JSONDecoder().decode(Project.self, from: data)
            tasks = fullProject.tasks
            progressLogs = fullProject.progressLogs
            receipts = fullProject.receipts
            workHours = fullProject.workHours
            communications = fullProject.communications
            changeOrders = fullProject.changeOrders
        }
    }
}

// MARK: - Helper Extensions  

extension Project {
    public var totalSpent: Double {
        return materialCost + laborCost + generalConditions
    }
    
    public var remainingBudget: Double {
        return totalBudget - totalSpent
    }
    
    public var budgetUtilization: Double {
        guard totalBudget > 0 else { return 0 }
        return totalSpent / totalBudget
    }
    
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day ?? 0
    }
    
    public var isPastDue: Bool {
        return endDate < Date() && status == .active
    }
    
    // PHASE 1 COMPATIBILITY - Map existing properties for backwards compatibility
    public var loggedHours: [WorkHour] {
        get { return workHours }
        set { workHours = newValue }
    }
    
    public var assignedTeamMemberIDs: [String] {
        return assignedUserIDs
    }
    
    public var progressReports: [ProgressLog] {
        return progressLogs
    }
    
    // PHASE 1 COMPATIBILITY - Map client properties
    public var phone: String {
        return clientPhone ?? ""
    }
    
    public var email: String {
        return clientEmail ?? ""
    }
    
    public var street: String {
        // Extract street from clientAddress if available
        return clientAddress?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    public var city: String {
        // Extract city from clientAddress if available (assuming format: "street, city, state zip")
        let components = clientAddress?.components(separatedBy: ",") ?? []
        return components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : ""
    }
    
    public var state: String {
        // Extract state from clientAddress if available
        let components = clientAddress?.components(separatedBy: ",") ?? []
        if components.count > 2 {
            let stateZip = components[2].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
            return stateZip.first ?? ""
        }
        return ""
    }
    
    public var zip: String {
        // Extract zip from clientAddress if available
        let components = clientAddress?.components(separatedBy: ",") ?? []
        if components.count > 2 {
            let stateZip = components[2].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
            return stateZip.count > 1 ? stateZip[1] : ""
        }
        return ""
    }
    
    // PHASE 1 STUB METHODS - TODO: Implement in Phase 2
    public mutating func assignTeamMember(_ teamMemberID: String) {
        if !assignedUserIDs.contains(teamMemberID) {
            assignedUserIDs.append(teamMemberID)
        }
    }
    
    // MARK: - User Assignment Methods
    public mutating func assignUser(_ userID: String) {
        if !assignedUserIDs.contains(userID) {
            assignedUserIDs.append(userID)
            lastModifiedDate = Date()
        }
    }
    
    public mutating func unassignUser(_ userID: String) {
        assignedUserIDs.removeAll { $0 == userID }
        lastModifiedDate = Date()
    }
}