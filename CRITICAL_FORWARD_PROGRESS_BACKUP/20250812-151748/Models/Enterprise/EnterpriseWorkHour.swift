import Foundation
import CoreLocation

/// Enterprise-grade work hour model with comprehensive audit trail and edit capabilities
public struct EnterpriseWorkHour: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let originalEntryID: UUID // Links to original if this is a correction
    
    // MARK: - Core Time Data
    public var date: Date
    public var startTime: Date
    public var endTime: Date?
    public var lunchStart: Date?
    public var lunchEnd: Date?
    public var breakTime: TimeInterval // Total break time in seconds
    
    // MARK: - Team Member & Project Assignment
    public let teamMemberID: UUID
    public let projectID: String
    public var category: TaskCategory
    public var taskID: UUID? // Specific task if applicable
    public var workDescription: String
    public var notes: String
    
    // MARK: - Rate & Payment Information
    public var payRateID: UUID // Links to PayRate
    public var hourlyRate: Double
    public var regularHours: Double
    public var overtimeHours: Double
    public var doubleTimeHours: Double // For holidays/Sundays
    public var totalPay: Double // Computed but stored for history
    
    // MARK: - Location & Verification
    public var clockInLocation: LocationData?
    public var clockOutLocation: LocationData?
    public var workSiteLocation: LocationData? // Expected work site
    public var locationVerified: Bool
    public var distanceFromWorkSite: Double? // In meters
    
    // MARK: - Approval Workflow
    public var entryMethod: EntryMethod
    public var status: WorkHourStatus
    public var submittedAt: Date?
    public var approvedBy: UUID?
    public var approvedAt: Date?
    public var rejectedReason: String?
    public var requiresApproval: Bool
    
    // MARK: - Payment Tracking
    public var isPaid: Bool
    public var paymentID: UUID? // Links to Payment record
    public var paymentMethod: String?
    public var paidAt: Date?
    public var paidBy: UUID?
    public var paymentNotes: String?
    
    // MARK: - Edit & Correction Support
    public var isCorrection: Bool // True if this corrects another entry
    public var correctionReason: String?
    public var originalValues: [String: String]? // What was corrected
    public var correctedAt: Date?
    public var correctedBy: UUID?
    public var editHistory: [WorkHourEdit]
    
    // MARK: - Audit Trail
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
    public var clientTimestamp: Date // When entered on device
    public var serverTimestamp: Date // When synced to server
    
    // MARK: - Quality Assurance
    public var photoIDs: [UUID] // Work photos for verification
    public var qualityRating: Double? // 1-5 supervisor rating
    public var productivityScore: Double? // Tasks completed per hour
    public var flags: [WorkHourFlag] // Unusual patterns or issues
    
    public init(
        id: UUID = UUID(),
        originalEntryID: UUID? = nil,
        date: Date,
        startTime: Date,
        endTime: Date? = nil,
        teamMemberID: UUID,
        projectID: String,
        category: TaskCategory = .general,
        workDescription: String = "",
        payRateID: UUID,
        hourlyRate: Double,
        entryMethod: EntryMethod = .manual,
        createdBy: UUID
    ) {
        self.id = id
        self.originalEntryID = originalEntryID ?? id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.lunchStart = nil
        self.lunchEnd = nil
        self.breakTime = 0
        self.teamMemberID = teamMemberID
        self.projectID = projectID
        self.category = category
        self.taskID = nil
        self.workDescription = workDescription
        self.notes = ""
        self.payRateID = payRateID
        self.hourlyRate = hourlyRate
        self.entryMethod = entryMethod
        self.status = .submitted
        self.submittedAt = Date()
        self.requiresApproval = entryMethod == .manual || entryMethod == .correction
        self.isPaid = false
        self.isCorrection = false
        self.correctionReason = nil
        self.originalValues = nil
        self.correctedAt = nil
        self.correctedBy = nil
        self.editHistory = []
        self.createdAt = Date()
        self.createdBy = createdBy
        self.updatedAt = Date()
        self.updatedBy = createdBy
        self.clientTimestamp = Date()
        self.serverTimestamp = Date()
        self.photoIDs = []
        self.qualityRating = nil
        self.productivityScore = nil
        self.flags = []
        
        // Computed fields
        self.regularHours = self.calculateRegularHours()
        self.overtimeHours = self.calculateOvertimeHours()
        self.doubleTimeHours = self.calculateDoubleTimeHours()
        self.totalPay = self.calculateTotalPay()
        self.clockInLocation = nil
        self.clockOutLocation = nil
        self.workSiteLocation = nil
        self.locationVerified = false
        self.distanceFromWorkSite = nil
        self.approvedBy = nil
        self.approvedAt = nil
        self.rejectedReason = nil
        self.paymentID = nil
        self.paymentMethod = nil
        self.paidAt = nil
        self.paidBy = nil
        self.paymentNotes = nil
    }
    
    // MARK: - Computed Properties
    
    public var totalHours: Double {
        guard let endTime = endTime else { return 0 }
        let rawHours = endTime.timeIntervalSince(startTime) / 3600.0
        let lunchTime = lunchBreakDuration ?? 0
        let additionalBreaks = breakTime / 3600.0
        return max(0, rawHours - lunchTime - additionalBreaks)
    }
    
    public var lunchBreakDuration: Double? {
        guard let start = lunchStart, let end = lunchEnd else { return nil }
        return end.timeIntervalSince(start) / 3600.0
    }
    
    // MARK: - Business Logic
    
    private func calculateRegularHours() -> Double {
        let hours = totalHours
        
        // Check if it's a weekend or holiday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 1 || weekday == 7 { // Sunday or Saturday
            return 0 // All hours are overtime/double-time on weekends
        }
        
        return min(hours, 8.0) // Standard 8-hour day
    }
    
    private func calculateOvertimeHours() -> Double {
        let hours = totalHours
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 1 || weekday == 7 { // Sunday or Saturday
            return weekday == 1 ? 0 : hours // Saturday is overtime, Sunday is double-time
        }
        
        return max(0, min(hours - 8.0, 4.0)) // Hours 9-12 are overtime
    }
    
    private func calculateDoubleTimeHours() -> Double {
        let hours = totalHours
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 1 { // Sunday
            return hours // All Sunday hours are double-time
        }
        
        if weekday == 7 { // Saturday
            return 0 // Saturday is regular overtime
        }
        
        return max(0, hours - 12.0) // Hours beyond 12 are double-time
    }
    
    private func calculateTotalPay() -> Double {
        return (regularHours * hourlyRate) +
               (overtimeHours * hourlyRate * 1.5) +
               (doubleTimeHours * hourlyRate * 2.0)
    }
    
    // MARK: - Edit & Correction Methods
    
    /// Create a correction entry for this work hour
    public func createCorrection(
        correctedBy: UUID,
        reason: String,
        newStartTime: Date? = nil,
        newEndTime: Date? = nil,
        newHours: Double? = nil,
        newRate: Double? = nil,
        newDescription: String? = nil,
        newCategory: TaskCategory? = nil
    ) -> EnterpriseWorkHour {
        var correction = self
        correction.id = UUID()
        correction.isCorrection = true
        correction.correctionReason = reason
        correction.correctedAt = Date()
        correction.correctedBy = correctedBy
        correction.status = .pendingApproval
        correction.requiresApproval = true
        
        // Store original values
        var originalValues: [String: String] = [:]
        
        if let newStart = newStartTime {
            originalValues["startTime"] = ISO8601DateFormatter().string(from: self.startTime)
            correction.startTime = newStart
        }
        
        if let newEnd = newEndTime {
            originalValues["endTime"] = self.endTime != nil ? ISO8601DateFormatter().string(from: self.endTime!) : "nil"
            correction.endTime = newEnd
        }
        
        if let newHrs = newHours {
            // This would require adjusting endTime based on start time + new hours
            let newEndTime = Calendar.current.date(byAdding: .hour, value: Int(newHrs), to: correction.startTime)
            originalValues["totalHours"] = String(self.totalHours)
            correction.endTime = newEndTime
        }
        
        if let newRt = newRate {
            originalValues["hourlyRate"] = String(self.hourlyRate)
            correction.hourlyRate = newRt
        }
        
        if let newDesc = newDescription {
            originalValues["workDescription"] = self.workDescription
            correction.workDescription = newDesc
        }
        
        if let newCat = newCategory {
            originalValues["category"] = self.category.rawValue
            correction.category = newCat
        }
        
        correction.originalValues = originalValues
        
        // Recalculate pay amounts
        correction.regularHours = correction.calculateRegularHours()
        correction.overtimeHours = correction.calculateOvertimeHours() 
        correction.doubleTimeHours = correction.calculateDoubleTimeHours()
        correction.totalPay = correction.calculateTotalPay()
        
        // Add edit record
        let edit = WorkHourEdit(
            id: UUID(),
            editType: .correction,
            editedBy: correctedBy,
            editedAt: Date(),
            reason: reason,
            changedFields: Array(originalValues.keys)
        )
        correction.editHistory.append(edit)
        
        return correction
    }
    
    /// Add an edit record to the history
    public mutating func addEdit(
        type: WorkHourEditType,
        editedBy: UUID,
        reason: String,
        changedFields: [String]
    ) {
        let edit = WorkHourEdit(
            id: UUID(),
            editType: type,
            editedBy: editedBy,
            editedAt: Date(),
            reason: reason,
            changedFields: changedFields
        )
        
        editHistory.append(edit)
        updatedAt = Date()
        updatedBy = editedBy
        
        // Keep only last 50 edits
        if editHistory.count > 50 {
            editHistory = Array(editHistory.suffix(50))
        }
    }
    
    /// Approve this work hour entry
    public mutating func approve(by managerID: UUID, notes: String? = nil) {
        status = .approved
        approvedBy = managerID
        approvedAt = Date()
        if let notes = notes {
            self.notes = self.notes.isEmpty ? notes : "\(self.notes)\nApproval: \(notes)"
        }
        
        addEdit(
            type: .approved,
            editedBy: managerID,
            reason: "Entry approved" + (notes != nil ? " - \(notes!)" : ""),
            changedFields: ["status", "approvedBy", "approvedAt"]
        )
    }
    
    /// Reject this work hour entry
    public mutating func reject(by managerID: UUID, reason: String) {
        status = .rejected
        approvedBy = managerID
        approvedAt = Date()
        rejectedReason = reason
        
        addEdit(
            type: .rejected,
            editedBy: managerID,
            reason: "Entry rejected - \(reason)",
            changedFields: ["status", "approvedBy", "approvedAt", "rejectedReason"]
        )
    }
    
    /// Mark as paid
    public mutating func markAsPaid(
        paymentID: UUID,
        method: String,
        paidBy: UUID,
        notes: String? = nil
    ) {
        isPaid = true
        self.paymentID = paymentID
        paymentMethod = method
        paidAt = Date()
        paidBy = paidBy
        paymentNotes = notes
        
        addEdit(
            type: .paymentProcessed,
            editedBy: paidBy,
            reason: "Payment processed via \(method)" + (notes != nil ? " - \(notes!)" : ""),
            changedFields: ["isPaid", "paymentID", "paymentMethod", "paidAt", "paidBy"]
        )
    }
    
    // MARK: - Validation
    
    public var validationIssues: [WorkHourValidationIssue] {
        var issues: [WorkHourValidationIssue] = []
        
        guard let endTime = endTime else { return issues }
        
        if endTime <= startTime {
            issues.append(.invalidTimeRange)
        }
        
        if totalHours > 24 {
            issues.append(.excessiveHours)
        }
        
        if totalHours < 0.1 { // Less than 6 minutes
            issues.append(.insufficientHours)
        }
        
        if totalHours > 16 {
            issues.append(.unusuallyLongShift)
        }
        
        if let lunchStart = lunchStart, let lunchEnd = lunchEnd {
            if lunchStart >= lunchEnd {
                issues.append(.invalidLunchBreak)
            }
            
            if lunchStart < startTime || lunchEnd > endTime {
                issues.append(.lunchOutsideWorkHours)
            }
        }
        
        if locationVerified == false && clockInLocation != nil {
            issues.append(.locationNotVerified)
        }
        
        if let distance = distanceFromWorkSite, distance > 500 { // 500 meters
            issues.append(.farFromWorkSite)
        }
        
        return issues
    }
    
    public var isValid: Bool {
        return validationIssues.isEmpty
    }
}

// MARK: - Supporting Models

public struct LocationData: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let accuracy: Double
    public let timestamp: Date
    public let address: String?
    
    public init(latitude: Double, longitude: Double, accuracy: Double, timestamp: Date, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.address = address
    }
    
    public var location: CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            timestamp: timestamp
        )
    }
}

public enum EntryMethod: String, Codable, CaseIterable, Sendable {
    case liveTracking = "live_tracking"     // Clocked in/out live
    case manual = "manual"                  // Manually entered
    case imported = "imported"              // Imported from timesheet
    case correction = "correction"          // Correction of existing entry
    case bulk = "bulk"                      // Bulk entry
    
    public var displayName: String {
        switch self {
        case .liveTracking: return "Live Tracking"
        case .manual: return "Manual Entry"
        case .imported: return "Imported"
        case .correction: return "Correction"
        case .bulk: return "Bulk Entry"
        }
    }
    
    public var requiresApproval: Bool {
        switch self {
        case .liveTracking: return false
        case .manual: return true
        case .imported: return true
        case .correction: return true
        case .bulk: return true
        }
    }
}

public enum WorkHourStatus: String, Codable, CaseIterable, Sendable {
    case draft = "draft"                    // Being entered
    case submitted = "submitted"            // Submitted for approval
    case pendingApproval = "pending_approval" // Waiting for manager approval
    case approved = "approved"              // Approved by manager
    case rejected = "rejected"              // Rejected by manager
    case paid = "paid"                      // Payment processed
    
    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .submitted: return "Submitted"
        case .pendingApproval: return "Pending Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .paid: return "Paid"
        }
    }
    
    public var color: String {
        switch self {
        case .draft: return "gray"
        case .submitted: return "blue"
        case .pendingApproval: return "orange"
        case .approved: return "green"
        case .rejected: return "red"
        case .paid: return "purple"
        }
    }
}

public struct WorkHourEdit: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let editType: WorkHourEditType
    public let editedBy: UUID
    public let editedAt: Date
    public let reason: String
    public let changedFields: [String]
    
    public init(id: UUID = UUID(), editType: WorkHourEditType, editedBy: UUID, editedAt: Date, reason: String, changedFields: [String]) {
        self.id = id
        self.editType = editType
        self.editedBy = editedBy
        self.editedAt = editedAt
        self.reason = reason
        self.changedFields = changedFields
    }
}

public enum WorkHourEditType: String, Codable, CaseIterable, Sendable {
    case created = "created"
    case updated = "updated"
    case correction = "correction"
    case approved = "approved"
    case rejected = "rejected"
    case paymentProcessed = "payment_processed"
    case paymentReversed = "payment_reversed"
    
    public var displayName: String {
        switch self {
        case .created: return "Created"
        case .updated: return "Updated"
        case .correction: return "Correction"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .paymentProcessed: return "Payment Processed"
        case .paymentReversed: return "Payment Reversed"
        }
    }
}

public enum WorkHourValidationIssue: String, CaseIterable, Sendable {
    case invalidTimeRange = "invalid_time_range"
    case excessiveHours = "excessive_hours"
    case insufficientHours = "insufficient_hours"
    case unusuallyLongShift = "unusually_long_shift"
    case invalidLunchBreak = "invalid_lunch_break"
    case lunchOutsideWorkHours = "lunch_outside_work_hours"
    case locationNotVerified = "location_not_verified"
    case farFromWorkSite = "far_from_work_site"
    case missingRequiredFields = "missing_required_fields"
    
    public var displayName: String {
        switch self {
        case .invalidTimeRange: return "End time must be after start time"
        case .excessiveHours: return "Work session exceeds 24 hours"
        case .insufficientHours: return "Work session too short (minimum 6 minutes)"
        case .unusuallyLongShift: return "Unusually long shift (over 16 hours)"
        case .invalidLunchBreak: return "Invalid lunch break times"
        case .lunchOutsideWorkHours: return "Lunch break outside work hours"
        case .locationNotVerified: return "Location not verified"
        case .farFromWorkSite: return "Clocked in far from work site"
        case .missingRequiredFields: return "Missing required fields"
        }
    }
    
    public var severity: ValidationSeverity {
        switch self {
        case .invalidTimeRange, .excessiveHours, .invalidLunchBreak, .lunchOutsideWorkHours, .missingRequiredFields:
            return .error
        case .insufficientHours, .locationNotVerified, .farFromWorkSite:
            return .warning
        case .unusuallyLongShift:
            return .info
        }
    }
}

public enum ValidationSeverity {
    case error
    case warning
    case info
}

public enum WorkHourFlag: String, Codable, CaseIterable, Sendable {
    case duplicateEntry = "duplicate_entry"
    case unusualPattern = "unusual_pattern"
    case locationAnomaly = "location_anomaly"
    case rateDiscrepancy = "rate_discrepancy"
    case lateSubmission = "late_submission"
    case frequentCorrections = "frequent_corrections"
    
    public var displayName: String {
        switch self {
        case .duplicateEntry: return "Possible Duplicate Entry"
        case .unusualPattern: return "Unusual Work Pattern"
        case .locationAnomaly: return "Location Anomaly"
        case .rateDiscrepancy: return "Rate Discrepancy"
        case .lateSubmission: return "Late Submission"
        case .frequentCorrections: return "Frequent Corrections"
        }
    }
}