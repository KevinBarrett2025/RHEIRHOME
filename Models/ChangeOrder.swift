import Foundation

public struct ChangeOrder: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var number: String          // Change order number (e.g., "CO-001")
    public var title: String
    public var description: String
    public var reason: String          // Why the change is needed
    public var date: Date
    public var requestedBy: String     // Client, contractor, etc.
    public var approvedBy: String?     // Who approved it
    public var status: ChangeOrderStatus
    public var priority: ChangeOrderPriority
    
    // Financial impact
    public var originalAmount: Double  // Original contract amount
    public var changeAmount: Double    // Positive for additions, negative for deductions
    public var newTotalAmount: Double  // New contract total
    
    // Time impact  
    public var originalEndDate: Date?
    public var newEndDate: Date?
    public var timeExtensionDays: Int
    
    // Approval workflow
    public var submittedDate: Date?
    public var approvedDate: Date?
    public var rejectedDate: Date?
    public var rejectionReason: String?
    
    // Documentation
    public var attachments: [String]   // Document references
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        number: String,
        title: String,
        description: String,
        reason: String = "",
        date: Date = Date(),
        requestedBy: String,
        approvedBy: String? = nil,
        status: ChangeOrderStatus = .draft,
        priority: ChangeOrderPriority = .normal,
        originalAmount: Double,
        changeAmount: Double,
        newTotalAmount: Double? = nil,
        originalEndDate: Date? = nil,
        newEndDate: Date? = nil,
        timeExtensionDays: Int = 0,
        submittedDate: Date? = nil,
        approvedDate: Date? = nil,
        rejectedDate: Date? = nil,
        rejectionReason: String? = nil,
        attachments: [String] = [],
        notes: String = ""
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.description = description
        self.reason = reason
        self.date = date
        self.requestedBy = requestedBy
        self.approvedBy = approvedBy
        self.status = status
        self.priority = priority
        self.originalAmount = originalAmount
        self.changeAmount = changeAmount
        self.newTotalAmount = newTotalAmount ?? (originalAmount + changeAmount)
        self.originalEndDate = originalEndDate
        self.newEndDate = newEndDate
        self.timeExtensionDays = timeExtensionDays
        self.submittedDate = submittedDate
        self.approvedDate = approvedDate
        self.rejectedDate = rejectedDate
        self.rejectionReason = rejectionReason
        self.attachments = attachments
        self.notes = notes
    }
}

public enum ChangeOrderStatus: String, CaseIterable, Codable, Sendable {
    case draft = "Draft"
    case submitted = "Submitted"
    case underReview = "Under Review"
    case approved = "Approved"
    case rejected = "Rejected"
    case implemented = "Implemented"
    case cancelled = "Cancelled"
    
    public var color: String {
        switch self {
        case .draft: return "gray"
        case .submitted: return "blue"
        case .underReview: return "orange"
        case .approved: return "green"
        case .rejected: return "red"
        case .implemented: return "purple"
        case .cancelled: return "gray"
        }
    }
    
    public var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .submitted: return "paperplane"
        case .underReview: return "magnifyingglass"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .implemented: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

public enum ChangeOrderPriority: String, CaseIterable, Codable, Sendable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case critical = "Critical"
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .normal: return "blue"  
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

// MARK: - Extensions
extension ChangeOrder {
    /// Financial impact description
    public var impactDescription: String {
        if changeAmount > 0 {
            return "Increase: $\(String(format: "%.2f", changeAmount))"
        } else if changeAmount < 0 {
            return "Decrease: $\(String(format: "%.2f", abs(changeAmount)))"
        } else {
            return "No cost impact"
        }
    }
    
    /// Time impact description
    public var timeImpactDescription: String {
        if timeExtensionDays > 0 {
            return "Extends timeline by \(timeExtensionDays) days"
        } else if timeExtensionDays < 0 {
            return "Accelerates timeline by \(abs(timeExtensionDays)) days"
        } else {
            return "No schedule impact"
        }
    }
    
    /// Whether this change order can be edited
    public var canEdit: Bool {
        return status == .draft || status == .submitted
    }
    
    /// Whether this change order can be approved
    public var canApprove: Bool {
        return status == .submitted || status == .underReview
    }
}