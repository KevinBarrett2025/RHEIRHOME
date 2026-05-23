import Foundation
import CloudKit

public enum ProjectPriority: String, CaseIterable, Codable, Sendable {
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
    public var clientProfile: ProjectClientProfile?
    public var paymentMilestones: [ProjectPaymentMilestone]?
    public var projectDocuments: [ProjectDocument]?
    public var projectChecklists: [ProjectChecklist]?
    public var projectCalendarEvents: [ProjectCalendarEvent]?
    public var shoppingListItems: [ProjectShoppingListItem]?
    
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
        photoIDs: [String] = [],
        clientProfile: ProjectClientProfile? = nil,
        paymentMilestones: [ProjectPaymentMilestone]? = nil,
        projectDocuments: [ProjectDocument]? = nil,
        projectChecklists: [ProjectChecklist]? = nil,
        projectCalendarEvents: [ProjectCalendarEvent]? = nil,
        shoppingListItems: [ProjectShoppingListItem]? = nil
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
        self.clientProfile = clientProfile
        self.paymentMilestones = paymentMilestones
        self.projectDocuments = projectDocuments
        self.projectChecklists = projectChecklists
        self.projectCalendarEvents = projectCalendarEvents
        self.shoppingListItems = shoppingListItems
    }
    
    // MARK: - Equatable Conformance
    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.client == rhs.client &&
               lhs.totalBudget == rhs.totalBudget &&
               lhs.status == rhs.status &&
               lhs.lastModifiedDate == rhs.lastModifiedDate &&
               lhs.clientProfile == rhs.clientProfile &&
               lhs.paymentMilestones == rhs.paymentMilestones &&
               lhs.projectDocuments == rhs.projectDocuments &&
               lhs.projectChecklists == rhs.projectChecklists &&
               lhs.projectCalendarEvents == rhs.projectCalendarEvents &&
               lhs.shoppingListItems == rhs.shoppingListItems
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
        
        // Serialize child collections as JSON data without inline receipt image blobs.
        record["fullProjectData"] = try JSONEncoder().encode(persistenceSafeCopy) as CKRecordValue
        
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
        clientProfile = nil
        paymentMilestones = nil
        projectDocuments = nil
        projectChecklists = nil
        projectCalendarEvents = nil
        shoppingListItems = nil
        
        // Try to decode full project data if available
        if let data = record["fullProjectData"] as? Data {
            let fullProject = try JSONDecoder().decode(Project.self, from: data)
            tasks = fullProject.tasks
            progressLogs = fullProject.progressLogs
            receipts = fullProject.receipts
            workHours = fullProject.workHours
            communications = fullProject.communications
            changeOrders = fullProject.changeOrders
            clientProfile = fullProject.clientProfile
            paymentMilestones = fullProject.paymentMilestones
            projectDocuments = fullProject.projectDocuments
            projectChecklists = fullProject.projectChecklists
            projectCalendarEvents = fullProject.projectCalendarEvents
            shoppingListItems = fullProject.shoppingListItems
        }
    }
}

// MARK: - Helper Extensions  

extension Project {
    var inlineReceiptImageCount: Int {
        receipts.reduce(0) { count, receipt in
            count + (receipt.receiptImageData == nil ? 0 : 1)
        }
    }

    var duplicateReceiptCount: Int {
        receipts.count - Set(receipts.map(\.id)).count
    }

    var normalizedReceiptCopy: Project {
        guard duplicateReceiptCount > 0 else {
            return self
        }

        var seenReceiptIDs: Set<String> = []
        var normalizedReceipts: [Receipt] = []
        normalizedReceipts.reserveCapacity(receipts.count)

        // Preserve the most recent receipt mutation when duplicate IDs slip into state.
        for receipt in receipts.reversed() where seenReceiptIDs.insert(receipt.id).inserted {
            normalizedReceipts.append(receipt)
        }

        var copy = self
        copy.receipts = Array(normalizedReceipts.reversed())
        return copy
    }

    func upsertingReceipt(_ receipt: Receipt) -> Project {
        var copy = normalizedReceiptCopy

        if let index = copy.receipts.firstIndex(where: { $0.id == receipt.id }) {
            copy.receipts[index] = receipt
        } else {
            copy.receipts.append(receipt)
        }

        return copy
    }

    var persistenceSafeCopy: Project {
        var copy = normalizedReceiptCopy

        guard copy.inlineReceiptImageCount > 0 else {
            return copy
        }

        copy.receipts = copy.receipts.map(\.persistenceSafeCopy)
        return copy
    }

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

// MARK: - Project Operations Foundation

public struct ProjectClientProfile: Codable, Hashable, Sendable {
    public var name: String
    public var email: String?
    public var phone: String?
    public var billingAddress: String?
    public var jobSiteAddress: String?
    public var notes: String
    public var contractDocumentIDs: [UUID]

    public init(
        name: String,
        email: String? = nil,
        phone: String? = nil,
        billingAddress: String? = nil,
        jobSiteAddress: String? = nil,
        notes: String = "",
        contractDocumentIDs: [UUID] = []
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.billingAddress = billingAddress
        self.jobSiteAddress = jobSiteAddress
        self.notes = notes
        self.contractDocumentIDs = contractDocumentIDs
    }

    public static func legacy(
        name: String,
        email: String?,
        phone: String?,
        address: String?
    ) -> ProjectClientProfile {
        ProjectClientProfile(
            name: name,
            email: email,
            phone: phone,
            billingAddress: address,
            jobSiteAddress: address
        )
    }
}

public enum ProjectPaymentMilestoneTrigger: String, CaseIterable, Codable, Hashable, Sendable {
    case manual
    case date
    case taskCompletion
}

public enum ProjectPaymentMilestoneStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case planned
    case readyToInvoice
    case invoiced
    case paid
    case waived

    public var isClosed: Bool {
        self == .paid || self == .waived
    }
}

public struct ProjectPaymentMilestone: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var amount: Double
    public var dueDate: Date?
    public var trigger: ProjectPaymentMilestoneTrigger
    public var status: ProjectPaymentMilestoneStatus
    public var linkedTaskIDs: [UUID]
    public var linkedDocumentIDs: [UUID]
    public var invoiceNumber: String?
    public var paidDate: Date?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        dueDate: Date? = nil,
        trigger: ProjectPaymentMilestoneTrigger = .manual,
        status: ProjectPaymentMilestoneStatus = .planned,
        linkedTaskIDs: [UUID] = [],
        linkedDocumentIDs: [UUID] = [],
        invoiceNumber: String? = nil,
        paidDate: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.trigger = trigger
        self.status = status
        self.linkedTaskIDs = linkedTaskIDs
        self.linkedDocumentIDs = linkedDocumentIDs
        self.invoiceNumber = invoiceNumber
        self.paidDate = paidDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func isReadyForPrompt(tasks: [ProjectTask], on date: Date = Date()) -> Bool {
        guard !status.isClosed else { return false }

        if status == .readyToInvoice || status == .invoiced {
            return true
        }

        switch trigger {
        case .manual:
            return false
        case .date:
            guard let dueDate else { return false }
            return dueDate <= date
        case .taskCompletion:
            guard !linkedTaskIDs.isEmpty else { return false }
            let completedTaskIDs = Set(tasks.filter(\.isCompleted).map(\.id))
            return Set(linkedTaskIDs).isSubset(of: completedTaskIDs)
        }
    }
}

public enum ProjectDocumentCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case contract
    case budget
    case permit
    case pickupConfirmation
    case deliveryOrder
    case designIdea
    case invoice
    case receipt
    case taskPhoto
    case checklist
    case other
}

public enum ProjectDocumentStorageKind: String, CaseIterable, Codable, Hashable, Sendable {
    case localFile
    case cloudKitAsset
    case externalURL
    case generatedReport
}

public struct ProjectDocument: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var category: ProjectDocumentCategory
    public var fileName: String
    public var mimeType: String
    public var storageKind: ProjectDocumentStorageKind
    public var storageIdentifier: String
    public var sourceURLString: String?
    public var linkedTaskID: UUID?
    public var linkedReceiptID: String?
    public var linkedMilestoneID: UUID?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        category: ProjectDocumentCategory,
        fileName: String,
        mimeType: String,
        storageKind: ProjectDocumentStorageKind,
        storageIdentifier: String,
        sourceURLString: String? = nil,
        linkedTaskID: UUID? = nil,
        linkedReceiptID: String? = nil,
        linkedMilestoneID: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.fileName = fileName
        self.mimeType = mimeType
        self.storageKind = storageKind
        self.storageIdentifier = storageIdentifier
        self.sourceURLString = sourceURLString
        self.linkedTaskID = linkedTaskID
        self.linkedReceiptID = linkedReceiptID
        self.linkedMilestoneID = linkedMilestoneID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ProjectShoppingListItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var storeName: String?
    public var quantity: Double?
    public var unit: String?
    public var notes: String
    public var isPurchased: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        storeName: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        notes: String = "",
        isPurchased: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.storeName = storeName
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
        self.isPurchased = isPurchased
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ProjectChecklistCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case tools
    case materials
    case safety
    case quality
    case closeout
    case custom
}

public struct ProjectChecklistItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var quantity: Double?
    public var unit: String?
    public var isComplete: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        quantity: Double? = nil,
        unit: String? = nil,
        isComplete: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.quantity = quantity
        self.unit = unit
        self.isComplete = isComplete
        self.notes = notes
    }
}

public struct ProjectChecklist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var category: ProjectChecklistCategory
    public var linkedTaskCategory: TaskCategory?
    public var linkedTaskID: UUID?
    public var items: [ProjectChecklistItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        category: ProjectChecklistCategory,
        linkedTaskCategory: TaskCategory? = nil,
        linkedTaskID: UUID? = nil,
        items: [ProjectChecklistItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.linkedTaskCategory = linkedTaskCategory
        self.linkedTaskID = linkedTaskID
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var completionFraction: Double {
        guard !items.isEmpty else { return 0 }
        let completed = items.filter(\.isComplete).count
        return Double(completed) / Double(items.count)
    }
}

public enum ProjectCalendarEventKind: String, CaseIterable, Codable, Hashable, Sendable {
    case clientPaymentDue
    case employeePaymentDue
    case pickupOrder
    case deliveryOrder
    case taskDue
    case milestone
    case inspection
    case custom
}

public enum ProjectCalendarEventStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case planned
    case scheduled
    case done
    case cancelled
}

public struct ProjectCalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var kind: ProjectCalendarEventKind
    public var startDate: Date
    public var endDate: Date?
    public var status: ProjectCalendarEventStatus
    public var linkedTaskID: UUID?
    public var linkedMilestoneID: UUID?
    public var linkedDocumentID: UUID?
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        kind: ProjectCalendarEventKind,
        startDate: Date,
        endDate: Date? = nil,
        status: ProjectCalendarEventStatus = .planned,
        linkedTaskID: UUID? = nil,
        linkedMilestoneID: UUID? = nil,
        linkedDocumentID: UUID? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.linkedTaskID = linkedTaskID
        self.linkedMilestoneID = linkedMilestoneID
        self.linkedDocumentID = linkedDocumentID
        self.notes = notes
    }
}

public struct ProjectAssistantSnapshot: Sendable {
    public let generatedAt: Date
    public let overdueTasks: [ProjectTask]
    public let dueTodayTasks: [ProjectTask]
    public let upcomingTasks: [ProjectTask]
    public let overdueEvents: [ProjectCalendarEvent]
    public let dueTodayEvents: [ProjectCalendarEvent]
    public let upcomingEvents: [ProjectCalendarEvent]
    public let readyPaymentMilestones: [ProjectPaymentMilestone]
    public let checklistPrepItems: [ProjectAssistantChecklistPrep]
    public let markedReturnItems: [ProjectAssistantReturnItem]
    public let recentCompletedTasks: [ProjectTask]
    public let openChecklistItemCount: Int

    public var dueTodayCount: Int {
        dueTodayTasks.count + dueTodayEvents.count
    }

    public var overdueCount: Int {
        overdueTasks.count + overdueEvents.count
    }

    public var upcomingCount: Int {
        upcomingTasks.count + upcomingEvents.count
    }

    public var actionCount: Int {
        overdueCount
            + dueTodayCount
            + readyPaymentMilestones.count
            + checklistPrepItems.count
            + markedReturnItems.count
    }

    public var headline: String {
        if actionCount == 0 {
            return upcomingCount == 0
                ? "No urgent project items need attention."
                : "\(upcomingCount) upcoming item\(upcomingCount == 1 ? "" : "s") to keep on the radar."
        }

        var parts: [String] = []
        if overdueCount > 0 {
            parts.append("\(overdueCount) overdue")
        }
        if dueTodayCount > 0 {
            parts.append("\(dueTodayCount) due today")
        }
        if readyPaymentMilestones.count > 0 {
            parts.append("\(readyPaymentMilestones.count) payment prompt\(readyPaymentMilestones.count == 1 ? "" : "s")")
        }
        if markedReturnItems.count > 0 {
            parts.append("\(markedReturnItems.count) return item\(markedReturnItems.count == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }
}

public struct ProjectAssistantChecklistPrep: Identifiable, Sendable {
    public let checklist: ProjectChecklist
    public let linkedTaskCategory: TaskCategory
    public let matchingTasks: [ProjectTask]
    public let openItems: [ProjectChecklistItem]

    public var id: UUID { checklist.id }
}

public struct ProjectAssistantReturnItem: Identifiable, Sendable {
    public let receiptID: String
    public let receiptVendor: String
    public let receiptDate: Date
    public let receiptNumber: String?
    public let itemID: UUID
    public let itemName: String
    public let sku: String
    public let quantity: Double
    public let refundableQuantity: Double
    public let amount: Double

    public var id: String {
        "\(receiptID)-\(itemID.uuidString)"
    }
}

public extension Project {
    var resolvedClientProfile: ProjectClientProfile {
        clientProfile ?? .legacy(
            name: client,
            email: clientEmail,
            phone: clientPhone,
            address: clientAddress
        )
    }

    var activePaymentMilestones: [ProjectPaymentMilestone] {
        paymentMilestones ?? []
    }

    var activeProjectDocuments: [ProjectDocument] {
        projectDocuments ?? []
    }

    var activeProjectChecklists: [ProjectChecklist] {
        projectChecklists ?? []
    }

    var activeProjectCalendarEvents: [ProjectCalendarEvent] {
        projectCalendarEvents ?? []
    }

    var activeShoppingListItems: [ProjectShoppingListItem] {
        shoppingListItems ?? []
    }

    func paymentMilestonesReadyForPrompt(on date: Date = Date()) -> [ProjectPaymentMilestone] {
        activePaymentMilestones.filter { milestone in
            milestone.isReadyForPrompt(tasks: tasks, on: date)
        }
    }

    func projectTimelineEvents(on _: Date = Date()) -> [ProjectCalendarEvent] {
        let milestoneEvents = activePaymentMilestones.compactMap { milestone -> ProjectCalendarEvent? in
            guard let dueDate = milestone.dueDate else {
                return nil
            }

            return ProjectCalendarEvent(
                id: milestone.id,
                title: milestone.title,
                kind: .clientPaymentDue,
                startDate: dueDate,
                status: milestone.timelineStatus,
                linkedMilestoneID: milestone.id,
                notes: milestone.notes
            )
        }

        return (activeProjectCalendarEvents + milestoneEvents).sorted { lhs, rhs in
            lhs.startDate < rhs.startDate
        }
    }

    func relevantChecklists(for task: ProjectTask) -> [ProjectChecklist] {
        activeProjectChecklists
            .filter { checklist in
                checklist.linkedTaskID == task.id ||
                checklist.linkedTaskCategory == task.category
            }
            .sortedForAssistantChecklists()
    }

    func assistantSnapshot(
        on date: Date = Date(),
        calendar: Calendar = .current,
        upcomingDays: Int = 7
    ) -> ProjectAssistantSnapshot {
        let startOfToday = calendar.startOfDay(for: date)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(86_400)
        let upcomingEnd = calendar.date(
            byAdding: .day,
            value: max(1, upcomingDays) + 1,
            to: startOfToday
        ) ?? startOfToday.addingTimeInterval(Double(max(1, upcomingDays) + 1) * 86_400)
        let recentStart = calendar.date(byAdding: .day, value: -7, to: startOfToday)
            ?? startOfToday.addingTimeInterval(-7 * 86_400)

        let openTasks = tasks.filter { !$0.isCompleted }
        let overdueTasks = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            .sortedForAssistantTasks()
        let dueTodayTasks = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfToday && dueDate < startOfTomorrow
            }
            .sortedForAssistantTasks()
        let upcomingTasks = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfTomorrow && dueDate < upcomingEnd
            }
            .sortedForAssistantTasks()

        let openEvents = projectTimelineEvents(on: date)
            .filter { $0.status != .done && $0.status != .cancelled && $0.kind != .clientPaymentDue }
        let overdueEvents = openEvents
            .filter { $0.startDate < startOfToday }
            .sortedForAssistantEvents()
        let dueTodayEvents = openEvents
            .filter { $0.startDate >= startOfToday && $0.startDate < startOfTomorrow }
            .sortedForAssistantEvents()
        let upcomingEvents = openEvents
            .filter { $0.startDate >= startOfTomorrow && $0.startDate < upcomingEnd }
            .sortedForAssistantEvents()

        let focusTasks = (overdueTasks + dueTodayTasks + upcomingTasks).sortedForAssistantTasks()
        let checklistPrepItems = activeProjectChecklists
            .compactMap { checklist -> ProjectAssistantChecklistPrep? in
                guard let linkedTaskCategory = checklist.linkedTaskCategory else {
                    return nil
                }
                let matchingTasks = focusTasks.filter { $0.category == linkedTaskCategory }
                guard !matchingTasks.isEmpty else {
                    return nil
                }
                let openItems = checklist.items.filter { !$0.isComplete }
                guard !openItems.isEmpty else {
                    return nil
                }
                return ProjectAssistantChecklistPrep(
                    checklist: checklist,
                    linkedTaskCategory: linkedTaskCategory,
                    matchingTasks: matchingTasks,
                    openItems: openItems
                )
            }
            .sortedForAssistantPrep()

        let markedReturnItems = receipts
            .filter { !$0.isReturn && $0.hasItemsMarkedForReturn }
            .flatMap { receipt in
                receipt.itemsMarkedForReturn.compactMap { item -> ProjectAssistantReturnItem? in
                    let remainingQuantity = receipt.remainingRefundableQuantity(for: item, in: receipts)
                    guard remainingQuantity > 0 else {
                        return nil
                    }
                    let unitAmount = item.quantity > 0 ? item.totalPrice / item.quantity : item.totalPrice
                    return ProjectAssistantReturnItem(
                        receiptID: receipt.id,
                        receiptVendor: receipt.vendor,
                        receiptDate: receipt.date,
                        receiptNumber: receipt.receiptNumber,
                        itemID: item.id,
                        itemName: item.name,
                        sku: item.sku,
                        quantity: item.quantity,
                        refundableQuantity: remainingQuantity,
                        amount: max(0, unitAmount * remainingQuantity)
                    )
                }
            }
            .sortedForAssistantReturns()

        let recentCompletedTasks = tasks
            .filter { task in
                guard task.isCompleted, let completedDate = task.completedDate else {
                    return false
                }
                return completedDate >= recentStart && completedDate <= date
            }
            .sortedForAssistantCompletedTasks()

        return ProjectAssistantSnapshot(
            generatedAt: date,
            overdueTasks: overdueTasks,
            dueTodayTasks: dueTodayTasks,
            upcomingTasks: upcomingTasks,
            overdueEvents: overdueEvents,
            dueTodayEvents: dueTodayEvents,
            upcomingEvents: upcomingEvents,
            readyPaymentMilestones: paymentMilestonesReadyForPrompt(on: date).sortedForAssistantMilestones(),
            checklistPrepItems: checklistPrepItems,
            markedReturnItems: markedReturnItems,
            recentCompletedTasks: recentCompletedTasks,
            openChecklistItemCount: activeProjectChecklists.reduce(0) { total, checklist in
                total + checklist.items.filter { !$0.isComplete }.count
            }
        )
    }
}

private extension Array where Element == ProjectTask {
    func sortedForAssistantTasks() -> [ProjectTask] {
        sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                if lhs.priority.sortOrder != rhs.priority.sortOrder {
                    return lhs.priority.sortOrder < rhs.priority.sortOrder
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func sortedForAssistantCompletedTasks() -> [ProjectTask] {
        sorted { lhs, rhs in
            switch (lhs.completedDate, rhs.completedDate) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

private extension Array where Element == ProjectPaymentMilestone {
    func sortedForAssistantMilestones() -> [ProjectPaymentMilestone] {
        sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

private extension Array where Element == ProjectCalendarEvent {
    func sortedForAssistantEvents() -> [ProjectCalendarEvent] {
        sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension Array where Element == ProjectChecklist {
    func sortedForAssistantChecklists() -> [ProjectChecklist] {
        sorted { lhs, rhs in
            if lhs.linkedTaskCategory?.sortOrder != rhs.linkedTaskCategory?.sortOrder {
                return (lhs.linkedTaskCategory?.sortOrder ?? Int.max) < (rhs.linkedTaskCategory?.sortOrder ?? Int.max)
            }
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension Array where Element == ProjectAssistantChecklistPrep {
    func sortedForAssistantPrep() -> [ProjectAssistantChecklistPrep] {
        sorted { lhs, rhs in
            if lhs.linkedTaskCategory.sortOrder != rhs.linkedTaskCategory.sortOrder {
                return lhs.linkedTaskCategory.sortOrder < rhs.linkedTaskCategory.sortOrder
            }
            return lhs.checklist.title.localizedCaseInsensitiveCompare(rhs.checklist.title) == .orderedAscending
        }
    }
}

private extension Array where Element == ProjectAssistantReturnItem {
    func sortedForAssistantReturns() -> [ProjectAssistantReturnItem] {
        sorted { lhs, rhs in
            if lhs.receiptDate != rhs.receiptDate {
                return lhs.receiptDate < rhs.receiptDate
            }
            if lhs.receiptVendor != rhs.receiptVendor {
                return lhs.receiptVendor.localizedCaseInsensitiveCompare(rhs.receiptVendor) == .orderedAscending
            }
            return lhs.itemName.localizedCaseInsensitiveCompare(rhs.itemName) == .orderedAscending
        }
    }
}

private extension ProjectPaymentMilestone {
    var timelineStatus: ProjectCalendarEventStatus {
        switch status {
        case .planned, .readyToInvoice:
            return .planned
        case .invoiced:
            return .scheduled
        case .paid:
            return .done
        case .waived:
            return .cancelled
        }
    }
}

public enum EstimateProjectType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case residentialRemodel = "Residential Remodel"
    case houseFlip = "House Flip"
    case commercialBuildout = "Commercial Buildout"
    case newConstruction = "New Construction"
    case exteriorImprovement = "Exterior Improvement"
    case maintenanceRepair = "Maintenance / Repair"
    case specialtyProject = "Specialty Project"

    public var id: Self { self }
}

public enum EstimateQualityLevel: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case valueEngineered = "Value Engineered"
    case builderGrade = "Builder Grade"
    case premium = "Premium"
    case luxury = "Luxury"

    public var id: Self { self }
}

public enum EstimateLaborStrategy: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case selfPerform = "Self Perform"
    case blendedCrew = "Blended Crew"
    case subcontractHeavy = "Subcontract Heavy"

    public var id: Self { self }
}

public enum EstimateProposalStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case concise = "Concise"
    case clientFriendly = "Client Friendly"
    case investorPacket = "Investor Packet"
    case scopeFirst = "Scope First"

    public var id: Self { self }
}

public enum EstimateScheduleIntent: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case aggressive = "Aggressive"
    case standard = "Standard"
    case phased = "Phased"

    public var id: Self { self }
}

public enum EstimateSessionStatus: String, Codable, Hashable, Sendable {
    case intake
    case clarifying
    case readyForDraft
    case drafted
    case approved
}

public enum EstimateDraftStatus: String, Codable, Hashable, Sendable {
    case drafting
    case review
    case approved
}

public enum BudgetLineType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case materials
    case labor
    case subcontract
    case equipment
    case permits
    case generalConditions
    case contingency
    case overhead
    case markup
    case allowance

    public var id: Self { self }

    public var sortPriority: Int {
        switch self {
        case .permits: return 0
        case .materials: return 1
        case .labor: return 2
        case .subcontract: return 3
        case .equipment: return 4
        case .generalConditions: return 5
        case .allowance: return 6
        case .contingency: return 7
        case .overhead: return 8
        case .markup: return 9
        }
    }
}

public enum SourceEvidenceType: String, Codable, Hashable, Sendable {
    case historicalProjectData
    case organizationHistory
    case preferredVendor
    case preferredStore
    case liveResearch
    case regionalFallback
    case manualOverride
}

public enum ActualCostSourceType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case receipt
    case workHour
    case task

    public var id: Self { self }
}

public struct EstimateIntakeInput: Codable, Hashable, Sendable {
    public var projectType: EstimateProjectType
    public var zipCode: String
    public var scopePrompt: String
    public var qualityLevel: EstimateQualityLevel
    public var scheduleIntent: EstimateScheduleIntent
    public var preferredVendors: [String]
    public var preferredStores: [String]
    public var laborStrategy: EstimateLaborStrategy
    public var contingencyPercent: Double
    public var proposalStyle: EstimateProposalStyle
    public var plansSummary: String
    public var photoSummary: String
    public var priorBidSummary: String

    public init(
        projectType: EstimateProjectType = .residentialRemodel,
        zipCode: String = "",
        scopePrompt: String = "",
        qualityLevel: EstimateQualityLevel = .builderGrade,
        scheduleIntent: EstimateScheduleIntent = .standard,
        preferredVendors: [String] = [],
        preferredStores: [String] = [],
        laborStrategy: EstimateLaborStrategy = .blendedCrew,
        contingencyPercent: Double = 10,
        proposalStyle: EstimateProposalStyle = .clientFriendly,
        plansSummary: String = "",
        photoSummary: String = "",
        priorBidSummary: String = ""
    ) {
        self.projectType = projectType
        self.zipCode = zipCode
        self.scopePrompt = scopePrompt
        self.qualityLevel = qualityLevel
        self.scheduleIntent = scheduleIntent
        self.preferredVendors = preferredVendors
        self.preferredStores = preferredStores
        self.laborStrategy = laborStrategy
        self.contingencyPercent = contingencyPercent
        self.proposalStyle = proposalStyle
        self.plansSummary = plansSummary
        self.photoSummary = photoSummary
        self.priorBidSummary = priorBidSummary
    }
}

public struct EstimateClarificationItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var question: String
    public var answer: String

    public init(id: UUID = UUID(), question: String, answer: String = "") {
        self.id = id
        self.question = question
        self.answer = answer
    }

    public var isAnswered: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct SourceEvidence: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: SourceEvidenceType
    public var title: String
    public var sourceURL: URL?
    public var geographicScope: String
    public var vendorOrStore: String?
    public var collectedAt: Date
    public var freshnessDate: Date
    public var confidence: Double
    public var note: String

    public init(
        id: UUID = UUID(),
        type: SourceEvidenceType,
        title: String,
        sourceURL: URL? = nil,
        geographicScope: String,
        vendorOrStore: String? = nil,
        collectedAt: Date = Date(),
        freshnessDate: Date = Date(),
        confidence: Double,
        note: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.sourceURL = sourceURL
        self.geographicScope = geographicScope
        self.vendorOrStore = vendorOrStore
        self.collectedAt = collectedAt
        self.freshnessDate = freshnessDate
        self.confidence = confidence
        self.note = note
    }
}

public struct BudgetLine: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectType: EstimateProjectType
    public var scopeGroup: String
    public var costCode: String
    public var phase: String
    public var title: String
    public var detail: String
    public var lineType: BudgetLineType
    public var quantity: Double
    public var unit: String
    public var unitCost: Double
    public var laborHours: Double?
    public var crewRole: String?
    public var vendorPreference: String?
    public var storePreference: String?
    public var sourceEvidence: [SourceEvidence]
    public var internalOnly: Bool
    public var clientVisible: Bool

    public init(
        id: UUID = UUID(),
        projectType: EstimateProjectType,
        scopeGroup: String,
        costCode: String,
        phase: String,
        title: String,
        detail: String,
        lineType: BudgetLineType,
        quantity: Double,
        unit: String,
        unitCost: Double,
        laborHours: Double? = nil,
        crewRole: String? = nil,
        vendorPreference: String? = nil,
        storePreference: String? = nil,
        sourceEvidence: [SourceEvidence] = [],
        internalOnly: Bool = false,
        clientVisible: Bool = true
    ) {
        self.id = id
        self.projectType = projectType
        self.scopeGroup = scopeGroup
        self.costCode = costCode
        self.phase = phase
        self.title = title
        self.detail = detail
        self.lineType = lineType
        self.quantity = quantity
        self.unit = unit
        self.unitCost = unitCost
        self.laborHours = laborHours
        self.crewRole = crewRole
        self.vendorPreference = vendorPreference
        self.storePreference = storePreference
        self.sourceEvidence = sourceEvidence
        self.internalOnly = internalOnly
        self.clientVisible = clientVisible
    }

    public var totalCost: Double {
        quantity * unitCost
    }
}

public struct EstimateTotalsSummary: Codable, Hashable, Sendable {
    public var materials: Double
    public var labor: Double
    public var subcontract: Double
    public var equipment: Double
    public var permits: Double
    public var generalConditions: Double
    public var contingency: Double
    public var overhead: Double
    public var markup: Double
    public var allowance: Double

    public init(
        materials: Double = 0,
        labor: Double = 0,
        subcontract: Double = 0,
        equipment: Double = 0,
        permits: Double = 0,
        generalConditions: Double = 0,
        contingency: Double = 0,
        overhead: Double = 0,
        markup: Double = 0,
        allowance: Double = 0
    ) {
        self.materials = materials
        self.labor = labor
        self.subcontract = subcontract
        self.equipment = equipment
        self.permits = permits
        self.generalConditions = generalConditions
        self.contingency = contingency
        self.overhead = overhead
        self.markup = markup
        self.allowance = allowance
    }

    public var directTotal: Double {
        materials + labor + subcontract + equipment + permits + allowance
    }

    public var internalTotal: Double {
        directTotal + generalConditions + contingency + overhead
    }

    public var clientTotal: Double {
        internalTotal + markup
    }
}

public struct ProposalSection: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var total: Double?

    public init(id: UUID = UUID(), title: String, body: String, total: Double? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.total = total
    }
}

public struct ProposalView: Codable, Hashable, Sendable {
    public var title: String
    public var subtitle: String
    public var executiveSummary: String
    public var sections: [ProposalSection]
    public var assumptions: [String]
    public var clientVisibleLines: [BudgetLine]
    public var generatedAt: Date

    public init(
        title: String,
        subtitle: String,
        executiveSummary: String,
        sections: [ProposalSection],
        assumptions: [String],
        clientVisibleLines: [BudgetLine],
        generatedAt: Date = Date()
    ) {
        self.title = title
        self.subtitle = subtitle
        self.executiveSummary = executiveSummary
        self.sections = sections
        self.assumptions = assumptions
        self.clientVisibleLines = clientVisibleLines
        self.generatedAt = generatedAt
    }
}

public struct EstimateSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var input: EstimateIntakeInput
    public var clarifications: [EstimateClarificationItem]
    public var status: EstimateSessionStatus

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        input: EstimateIntakeInput,
        clarifications: [EstimateClarificationItem] = [],
        status: EstimateSessionStatus = .intake
    ) {
        self.id = id
        self.projectID = projectID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.input = input
        self.clarifications = clarifications
        self.status = status
    }

    public var isReadyForDraft: Bool {
        clarifications.allSatisfy(\.isAnswered)
    }
}

public struct EstimateDraft: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var sessionID: UUID
    public var projectID: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var status: EstimateDraftStatus
    public var confidence: Double
    public var assumptions: [String]
    public var alternates: [String]
    public var lines: [BudgetLine]
    public var proposalView: ProposalView

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        projectID: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: EstimateDraftStatus = .review,
        confidence: Double,
        assumptions: [String],
        alternates: [String],
        lines: [BudgetLine],
        proposalView: ProposalView
    ) {
        self.id = id
        self.sessionID = sessionID
        self.projectID = projectID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.confidence = confidence
        self.assumptions = assumptions
        self.alternates = alternates
        self.lines = lines
        self.proposalView = proposalView
    }

    public var totals: EstimateTotalsSummary {
        EstimateTotalsSummary(lines: lines)
    }
}

public struct BudgetBaseline: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var estimateVersionID: UUID
    public var projectType: EstimateProjectType
    public var zipCode: String
    public var contingencyPercent: Double
    public var lines: [BudgetLine]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        estimateVersionID: UUID,
        projectType: EstimateProjectType,
        zipCode: String,
        contingencyPercent: Double,
        lines: [BudgetLine],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.estimateVersionID = estimateVersionID
        self.projectType = projectType
        self.zipCode = zipCode
        self.contingencyPercent = contingencyPercent
        self.lines = lines
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var totals: EstimateTotalsSummary {
        EstimateTotalsSummary(lines: lines)
    }
}

public struct EstimateVersion: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var draftID: UUID
    public var approvedAt: Date
    public var approvedByUserID: String?
    public var assumptions: [String]
    public var baseline: BudgetBaseline
    public var proposalView: ProposalView

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        draftID: UUID,
        approvedAt: Date = Date(),
        approvedByUserID: String? = nil,
        assumptions: [String],
        baseline: BudgetBaseline,
        proposalView: ProposalView
    ) {
        self.id = id
        self.projectID = projectID
        self.draftID = draftID
        self.approvedAt = approvedAt
        self.approvedByUserID = approvedByUserID
        self.assumptions = assumptions
        self.baseline = baseline
        self.proposalView = proposalView
    }
}

public struct ActualCostLink: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var estimateVersionID: UUID
    public var budgetLineID: UUID
    public var sourceType: ActualCostSourceType
    public var sourceRecordID: String
    public var mappedAmount: Double
    public var mappedAt: Date
    public var note: String

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        estimateVersionID: UUID,
        budgetLineID: UUID,
        sourceType: ActualCostSourceType,
        sourceRecordID: String,
        mappedAmount: Double,
        mappedAt: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.projectID = projectID
        self.estimateVersionID = estimateVersionID
        self.budgetLineID = budgetLineID
        self.sourceType = sourceType
        self.sourceRecordID = sourceRecordID
        self.mappedAmount = mappedAmount
        self.mappedAt = mappedAt
        self.note = note
    }
}

public struct BudgetLineVariance: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var phase: String
    public var budgeted: Double
    public var committed: Double
    public var actual: Double
    public var remaining: Double
    public var forecast: Double

    public init(
        id: UUID,
        title: String,
        phase: String,
        budgeted: Double,
        committed: Double,
        actual: Double,
        remaining: Double,
        forecast: Double
    ) {
        self.id = id
        self.title = title
        self.phase = phase
        self.budgeted = budgeted
        self.committed = committed
        self.actual = actual
        self.remaining = remaining
        self.forecast = forecast
    }
}

public struct VarianceSnapshot: Codable, Hashable, Sendable {
    public var projectID: UUID
    public var baselineID: UUID
    public var generatedAt: Date
    public var lines: [BudgetLineVariance]

    public init(
        projectID: UUID,
        baselineID: UUID,
        generatedAt: Date = Date(),
        lines: [BudgetLineVariance]
    ) {
        self.projectID = projectID
        self.baselineID = baselineID
        self.generatedAt = generatedAt
        self.lines = lines
    }

    public init(
        project: Project,
        baseline: BudgetBaseline,
        actualCostLinks: [ActualCostLink],
        generatedAt: Date = Date()
    ) {
        let lines = baseline.lines.map { line in
            let relevantLinks = actualCostLinks.filter { $0.budgetLineID == line.id }
            let actual = relevantLinks
                .filter { $0.sourceType == .receipt || $0.sourceType == .workHour }
                .reduce(0) { $0 + $1.mappedAmount }
            let linkedTaskCommitment = relevantLinks
                .filter { $0.sourceType == .task }
                .reduce(0) { $0 + $1.mappedAmount }
            let directTaskCommitment = project.tasks
                .filter { $0.budgetLineID == line.id }
                .reduce(0.0) { subtotal, task in
                    subtotal + (task.estimatedHours * max(line.unitCost, 1))
                }
            let committed = actual + max(linkedTaskCommitment, directTaskCommitment)

            return BudgetLineVariance(
                id: line.id,
                title: line.title,
                phase: line.phase,
                budgeted: line.totalCost,
                committed: committed,
                actual: actual,
                remaining: max(line.totalCost - actual, 0),
                forecast: max(line.totalCost, committed)
            )
        }

        self.init(
            projectID: project.id,
            baselineID: baseline.id,
            generatedAt: generatedAt,
            lines: lines
        )
    }

    public var totalBudgeted: Double {
        lines.reduce(0) { $0 + $1.budgeted }
    }

    public var totalCommitted: Double {
        lines.reduce(0) { $0 + $1.committed }
    }

    public var totalActual: Double {
        lines.reduce(0) { $0 + $1.actual }
    }

    public var totalRemaining: Double {
        lines.reduce(0) { $0 + $1.remaining }
    }

    public var totalForecast: Double {
        lines.reduce(0) { $0 + $1.forecast }
    }
}

public extension EstimateTotalsSummary {
    init(lines: [BudgetLine]) {
        var summary = EstimateTotalsSummary()

        for line in lines {
            switch line.lineType {
            case .materials:
                summary.materials += line.totalCost
            case .labor:
                summary.labor += line.totalCost
            case .subcontract:
                summary.subcontract += line.totalCost
            case .equipment:
                summary.equipment += line.totalCost
            case .permits:
                summary.permits += line.totalCost
            case .generalConditions:
                summary.generalConditions += line.totalCost
            case .contingency:
                summary.contingency += line.totalCost
            case .overhead:
                summary.overhead += line.totalCost
            case .markup:
                summary.markup += line.totalCost
            case .allowance:
                summary.allowance += line.totalCost
            }
        }

        self = summary
    }
}

extension Project {
    func applyingBudgetBaseline(_ baseline: BudgetBaseline) -> Project {
        var copy = self
        let totals = baseline.totals

        copy.totalBudget = totals.clientTotal
        copy.materialCost = totals.materials + totals.equipment + totals.allowance
        copy.laborCost = totals.labor + totals.subcontract
        copy.generalConditions = totals.permits + totals.generalConditions + totals.overhead + totals.markup
        copy.contingency = totals.contingency
        copy.lastModifiedDate = Date()

        return copy
    }
}
