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
