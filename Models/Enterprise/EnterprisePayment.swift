import Foundation

/// Enterprise-grade payment system with comprehensive tracking and audit trail
public struct EnterprisePayment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let organizationID: String
    
    // MARK: - Payment Details
    public let teamMemberID: UUID
    public var paymentType: PaymentType
    public var paymentMethod: PaymentMethod
    public var amount: Double
    public var paymentDate: Date
    public var payPeriodStart: Date
    public var payPeriodEnd: Date
    public var checkNumber: String?
    public var transactionReference: String?
    
    // MARK: - Work Hours Included
    public var workHourIDs: [UUID] // All work hours paid in this payment
    public var regularHours: Double
    public var overtimeHours: Double
    public var doubleTimeHours: Double
    public var totalHours: Double
    
    // MARK: - Pay Breakdown
    public var regularPay: Double
    public var overtimePay: Double
    public var doubleTimePay: Double
    public var bonusPay: Double
    public var deductions: [PayDeduction]
    public var grossPay: Double
    public var netPay: Double
    
    // MARK: - Tax Information
    public var federalWithholding: Double
    public var stateWithholding: Double
    public var socialSecurityWithholding: Double
    public var medicareWithholding: Double
    public var otherDeductions: Double
    public var taxableIncome: Double
    
    // MARK: - Status & Approval
    public var status: PaymentStatus
    public var processedBy: UUID
    public var processedAt: Date
    public var approvedBy: UUID?
    public var approvedAt: Date?
    public var notes: String
    
    // MARK: - Delivery Information
    public var deliveryMethod: PaymentDeliveryMethod
    public var deliveryAddress: String?
    public var deliveryDate: Date?
    public var pickupLocation: String?
    public var isDelivered: Bool
    public var deliveredAt: Date?
    public var recipientSignature: String? // Base64 encoded signature
    
    // MARK: - Corrections & Adjustments
    public var isCorrection: Bool
    public var originalPaymentID: UUID?
    public var correctionReason: String?
    public var adjustmentAmount: Double // Positive or negative adjustment
    public var adjustmentReason: String?
    
    // MARK: - Integration & Export
    public var quickBooksTransactionID: String?
    public var bankTransactionID: String?
    public var exportedToPayroll: Bool
    public var exportedAt: Date?
    public var w2IncludeAmount: Double // Amount to include in W2
    public var form1099Amount: Double? // For contractors
    
    // MARK: - Audit Trail
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
    public var changeHistory: [PaymentChange]
    
    public init(
        id: UUID = UUID(),
        organizationID: String,
        teamMemberID: UUID,
        paymentType: PaymentType,
        paymentMethod: PaymentMethod,
        amount: Double,
        paymentDate: Date,
        payPeriodStart: Date,
        payPeriodEnd: Date,
        workHourIDs: [UUID],
        processedBy: UUID
    ) {
        self.id = id
        self.organizationID = organizationID
        self.teamMemberID = teamMemberID
        self.paymentType = paymentType
        self.paymentMethod = paymentMethod
        self.amount = amount
        self.paymentDate = paymentDate
        self.payPeriodStart = payPeriodStart
        self.payPeriodEnd = payPeriodEnd
        self.workHourIDs = workHourIDs
        self.processedBy = processedBy
        self.processedAt = Date()
        
        // Initialize computed values
        self.checkNumber = nil
        self.transactionReference = nil
        self.regularHours = 0
        self.overtimeHours = 0
        self.doubleTimeHours = 0
        self.totalHours = 0
        self.regularPay = 0
        self.overtimePay = 0
        self.doubleTimePay = 0
        self.bonusPay = 0
        self.deductions = []
        self.grossPay = amount
        self.netPay = amount
        self.federalWithholding = 0
        self.stateWithholding = 0
        self.socialSecurityWithholding = 0
        self.medicareWithholding = 0
        self.otherDeductions = 0
        self.taxableIncome = amount
        self.status = .pending
        self.approvedBy = nil
        self.approvedAt = nil
        self.notes = ""
        self.deliveryMethod = .inPerson
        self.deliveryAddress = nil
        self.deliveryDate = nil
        self.pickupLocation = nil
        self.isDelivered = false
        self.deliveredAt = nil
        self.recipientSignature = nil
        self.isCorrection = false
        self.originalPaymentID = nil
        self.correctionReason = nil
        self.adjustmentAmount = 0
        self.adjustmentReason = nil
        self.quickBooksTransactionID = nil
        self.bankTransactionID = nil
        self.exportedToPayroll = false
        self.exportedAt = nil
        self.w2IncludeAmount = amount
        self.form1099Amount = paymentType == .contractorPayment ? amount : nil
        self.createdAt = Date()
        self.createdBy = processedBy
        self.updatedAt = Date()
        self.updatedBy = processedBy
        self.changeHistory = []
    }
    
    // MARK: - Business Logic
    
    /// Calculate tax withholdings based on team member type
    public mutating func calculateWithholdings(teamMember: EnterpriseTeamMember, taxSettings: TaxSettings) {
        // Only calculate for employees, not contractors
        guard teamMember.employmentType == .employee else {
            federalWithholding = 0
            stateWithholding = 0
            socialSecurityWithholding = 0
            medicareWithholding = 0
            return
        }
        
        // Federal withholding (simplified - real implementation would use IRS tables)
        federalWithholding = grossPay * taxSettings.federalWithholdingRate
        
        // State withholding
        stateWithholding = grossPay * taxSettings.stateWithholdingRate
        
        // Social Security (up to wage base)
        let ssWageBase = taxSettings.socialSecurityWageBase
        socialSecurityWithholding = min(grossPay, ssWageBase) * taxSettings.socialSecurityRate
        
        // Medicare (no wage base limit)
        medicareWithholding = grossPay * taxSettings.medicareRate
        
        // Calculate net pay
        let totalWithholdings = federalWithholding + stateWithholding + socialSecurityWithholding + medicareWithholding + otherDeductions
        netPay = grossPay - totalWithholdings
        
        addChange(
            type: .withholdingsCalculated,
            field: "withholdings",
            oldValue: nil,
            newValue: "Total: \(totalWithholdings.formatAsCurrency())",
            changedBy: updatedBy,
            reason: "Tax withholdings calculated"
        )
    }
    
    /// Add hours to this payment from work hour records
    public mutating func addWorkHours(_ workHours: [EnterpriseWorkHour]) {
        let newHourIDs = workHours.map(\.id)
        workHourIDs.append(contentsOf: newHourIDs)
        
        // Recalculate totals
        regularHours = workHours.reduce(0) { $0 + $1.regularHours }
        overtimeHours = workHours.reduce(0) { $0 + $1.overtimeHours }
        doubleTimeHours = workHours.reduce(0) { $0 + $1.doubleTimeHours }
        totalHours = regularHours + overtimeHours + doubleTimeHours
        
        regularPay = workHours.reduce(0) { $0 + $1.regularHours * $1.hourlyRate }
        overtimePay = workHours.reduce(0) { $0 + $1.overtimeHours * $1.hourlyRate * 1.5 }
        doubleTimePay = workHours.reduce(0) { $0 + $1.doubleTimeHours * $1.hourlyRate * 2.0 }
        
        grossPay = regularPay + overtimePay + doubleTimePay + bonusPay
        amount = grossPay // Update total amount
        
        addChange(
            type: .hoursAdded,
            field: "workHours",
            oldValue: nil,
            newValue: "\(newHourIDs.count) hours added",
            changedBy: updatedBy,
            reason: "Work hours added to payment"
        )
    }
    
    /// Add a deduction to this payment
    public mutating func addDeduction(_ deduction: PayDeduction, by userID: UUID) {
        deductions.append(deduction)
        otherDeductions += deduction.amount
        netPay = grossPay - (federalWithholding + stateWithholding + socialSecurityWithholding + medicareWithholding + otherDeductions)
        
        addChange(
            type: .deductionAdded,
            field: "deductions",
            oldValue: nil,
            newValue: "\(deduction.type.displayName): \(deduction.amount.formatAsCurrency())",
            changedBy: userID,
            reason: deduction.reason ?? "Deduction added"
        )
    }
    
    /// Approve this payment
    public mutating func approve(by managerID: UUID, notes: String? = nil) {
        status = .approved
        approvedBy = managerID
        approvedAt = Date()
        
        if let notes = notes {
            self.notes = self.notes.isEmpty ? notes : "\(self.notes)\nApproval: \(notes)"
        }
        
        addChange(
            type: .approved,
            field: "status",
            oldValue: "pending",
            newValue: "approved",
            changedBy: managerID,
            reason: "Payment approved" + (notes != nil ? " - \(notes!)" : "")
        )
    }
    
    /// Process the payment (mark as paid)
    public mutating func process(by userID: UUID, transactionRef: String? = nil) {
        status = .processed
        processedAt = Date()
        processedBy = userID
        transactionReference = transactionRef
        
        addChange(
            type: .processed,
            field: "status",
            oldValue: "approved",
            newValue: "processed",
            changedBy: userID,
            reason: "Payment processed" + (transactionRef != nil ? " - Ref: \(transactionRef!)" : "")
        )
    }
    
    /// Mark as delivered
    public mutating func markDelivered(
        by userID: UUID,
        deliveredAt: Date = Date(),
        signature: String? = nil,
        location: String? = nil
    ) {
        isDelivered = true
        self.deliveredAt = deliveredAt
        recipientSignature = signature
        
        if let location = location {
            pickupLocation = location
        }
        
        addChange(
            type: .delivered,
            field: "delivery",
            oldValue: "not delivered",
            newValue: "delivered",
            changedBy: userID,
            reason: "Payment delivered" + (location != nil ? " at \(location!)" : "")
        )
    }
    
    /// Create a correction payment
    public func createCorrection(
        correctionAmount: Double,
        reason: String,
        correctedBy: UUID
    ) -> EnterprisePayment {
        var correction = self
        correction.id = UUID()
        correction.isCorrection = true
        correction.originalPaymentID = self.id
        correction.correctionReason = reason
        correction.adjustmentAmount = correctionAmount
        correction.amount = correctionAmount
        correction.grossPay = correctionAmount
        correction.netPay = correctionAmount
        correction.status = .pending
        correction.createdAt = Date()
        correction.createdBy = correctedBy
        correction.updatedAt = Date()
        correction.updatedBy = correctedBy
        correction.changeHistory = []
        
        correction.addChange(
            type: .correctionCreated,
            field: "amount",
            oldValue: self.amount.formatAsCurrency(),
            newValue: correctionAmount.formatAsCurrency(),
            changedBy: correctedBy,
            reason: reason
        )
        
        return correction
    }
    
    /// Add a change to the audit trail
    public mutating func addChange(
        type: PaymentChangeType,
        field: String,
        oldValue: String?,
        newValue: String?,
        changedBy: UUID,
        reason: String?
    ) {
        let change = PaymentChange(
            id: UUID(),
            type: type,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            changedBy: changedBy,
            changedAt: Date(),
            reason: reason
        )
        
        changeHistory.append(change)
        updatedAt = Date()
        updatedBy = changedBy
        
        // Keep only last 100 changes
        if changeHistory.count > 100 {
            changeHistory = Array(changeHistory.suffix(100))
        }
    }
    
    /// Generate payment stub/receipt text
    public func generatePayStub(teamMember: EnterpriseTeamMember, organization: Organization) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var stub = """
        \(organization.name)
        Payment Stub
        
        Employee: \(teamMember.name)
        Pay Period: \(formatter.string(from: payPeriodStart)) - \(formatter.string(from: payPeriodEnd))
        Payment Date: \(formatter.string(from: paymentDate))
        Payment Method: \(paymentMethod.displayName)
        \(checkNumber != nil ? "Check #: \(checkNumber!)" : "")
        
        HOURS:
        Regular Hours: \(regularHours.formatAsHours()) @ \(regularPay/regularHours, specifier: "%.2f")/hr = \(regularPay.formatAsCurrency())
        Overtime Hours: \(overtimeHours.formatAsHours()) @ \((overtimePay/overtimeHours)/1.5, specifier: "%.2f")/hr (1.5x) = \(overtimePay.formatAsCurrency())
        Double Time Hours: \(doubleTimeHours.formatAsHours()) @ \((doubleTimePay/doubleTimeHours)/2.0, specifier: "%.2f")/hr (2x) = \(doubleTimePay.formatAsCurrency())
        
        EARNINGS:
        Gross Pay: \(grossPay.formatAsCurrency())
        Bonus Pay: \(bonusPay.formatAsCurrency())
        Total Gross: \(grossPay.formatAsCurrency())
        
        DEDUCTIONS:
        Federal Tax: \(federalWithholding.formatAsCurrency())
        State Tax: \(stateWithholding.formatAsCurrency())
        Social Security: \(socialSecurityWithholding.formatAsCurrency())
        Medicare: \(medicareWithholding.formatAsCurrency())
        Other Deductions: \(otherDeductions.formatAsCurrency())
        
        NET PAY: \(netPay.formatAsCurrency())
        """
        
        return stub
    }
}

// MARK: - Supporting Models

public enum PaymentType: String, Codable, CaseIterable, Sendable {
    case regularPayroll = "regular_payroll"
    case bonusPayment = "bonus_payment"
    case contractorPayment = "contractor_payment"
    case expenseReimbursement = "expense_reimbursement"
    case finalPaycheck = "final_paycheck"
    case correctionPayment = "correction_payment"
    case advancePayment = "advance_payment"
    
    public var displayName: String {
        switch self {
        case .regularPayroll: return "Regular Payroll"
        case .bonusPayment: return "Bonus Payment"
        case .contractorPayment: return "Contractor Payment"
        case .expenseReimbursement: return "Expense Reimbursement"
        case .finalPaycheck: return "Final Paycheck"
        case .correctionPayment: return "Correction Payment"
        case .advancePayment: return "Advance Payment"
        }
    }
}

public enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case check = "check"
    case cash = "cash"
    case directDeposit = "direct_deposit"
    case paycard = "paycard"
    case venmo = "venmo"
    case cashApp = "cash_app"
    case zelle = "zelle"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .check: return "Check"
        case .cash: return "Cash"
        case .directDeposit: return "Direct Deposit"
        case .paycard: return "Pay Card"
        case .venmo: return "Venmo"
        case .cashApp: return "Cash App"
        case .zelle: return "Zelle"
        case .other: return "Other"
        }
    }
}

public enum PaymentStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case approved = "approved"
    case processed = "processed"
    case delivered = "delivered"
    case cancelled = "cancelled"
    case reversed = "reversed"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .processed: return "Processed"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        case .reversed: return "Reversed"
        }
    }
    
    public var color: String {
        switch self {
        case .pending: return "orange"
        case .approved: return "blue"
        case .processed: return "green"
        case .delivered: return "purple"
        case .cancelled: return "red"
        case .reversed: return "red"
        }
    }
}

public enum PaymentDeliveryMethod: String, Codable, CaseIterable, Sendable {
    case inPerson = "in_person"
    case mail = "mail"
    case pickup = "pickup"
    case electronic = "electronic"
    
    public var displayName: String {
        switch self {
        case .inPerson: return "In Person"
        case .mail: return "Mail"
        case .pickup: return "Pickup"
        case .electronic: return "Electronic"
        }
    }
}

public struct PayDeduction: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let type: DeductionType
    public let amount: Double
    public let reason: String?
    public let isPreTax: Bool
    
    public init(id: UUID = UUID(), type: DeductionType, amount: Double, reason: String? = nil, isPreTax: Bool = false) {
        self.id = id
        self.type = type
        self.amount = amount
        self.reason = reason
        self.isPreTax = isPreTax
    }
}

public enum DeductionType: String, Codable, CaseIterable, Sendable {
    case toolRental = "tool_rental"
    case uniformCost = "uniform_cost"
    case advanceRepayment = "advance_repayment"
    case damageRepair = "damage_repair"
    case loanRepayment = "loan_repayment"
    case healthInsurance = "health_insurance"
    case retirement401k = "retirement_401k"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .toolRental: return "Tool Rental"
        case .uniformCost: return "Uniform Cost"
        case .advanceRepayment: return "Advance Repayment"
        case .damageRepair: return "Damage Repair"
        case .loanRepayment: return "Loan Repayment"
        case .healthInsurance: return "Health Insurance"
        case .retirement401k: return "401(k) Contribution"
        case .other: return "Other"
        }
    }
}

public struct PaymentChange: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let type: PaymentChangeType
    public let field: String
    public let oldValue: String?
    public let newValue: String?
    public let changedBy: UUID
    public let changedAt: Date
    public let reason: String?
    
    public init(id: UUID = UUID(), type: PaymentChangeType, field: String, oldValue: String?, newValue: String?, changedBy: UUID, changedAt: Date, reason: String?) {
        self.id = id
        self.type = type
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.changedBy = changedBy
        self.changedAt = changedAt
        self.reason = reason
    }
}

public enum PaymentChangeType: String, Codable, CaseIterable, Sendable {
    case created = "created"
    case approved = "approved"
    case processed = "processed"
    case delivered = "delivered"
    case cancelled = "cancelled"
    case reversed = "reversed"
    case correctionCreated = "correction_created"
    case hoursAdded = "hours_added"
    case hoursRemoved = "hours_removed"
    case deductionAdded = "deduction_added"
    case deductionRemoved = "deduction_removed"
    case withholdingsCalculated = "withholdings_calculated"
    case exported = "exported"
    
    public var displayName: String {
        switch self {
        case .created: return "Created"
        case .approved: return "Approved"
        case .processed: return "Processed"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        case .reversed: return "Reversed"
        case .correctionCreated: return "Correction Created"
        case .hoursAdded: return "Hours Added"
        case .hoursRemoved: return "Hours Removed"
        case .deductionAdded: return "Deduction Added"
        case .deductionRemoved: return "Deduction Removed"
        case .withholdingsCalculated: return "Withholdings Calculated"
        case .exported: return "Exported"
        }
    }
}

public struct TaxSettings: Codable, Sendable {
    public let federalWithholdingRate: Double
    public let stateWithholdingRate: Double
    public let socialSecurityRate: Double
    public let medicareRate: Double
    public let socialSecurityWageBase: Double
    
    public init(
        federalWithholdingRate: Double = 0.12,
        stateWithholdingRate: Double = 0.05,
        socialSecurityRate: Double = 0.062,
        medicareRate: Double = 0.0145,
        socialSecurityWageBase: Double = 160200 // 2023 wage base
    ) {
        self.federalWithholdingRate = federalWithholdingRate
        self.stateWithholdingRate = stateWithholdingRate
        self.socialSecurityRate = socialSecurityRate
        self.medicareRate = medicareRate
        self.socialSecurityWageBase = socialSecurityWageBase
    }
}

// MARK: - Extensions for Formatting

extension Double {
    func formatAsCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    func formatAsHours() -> String {
        return String(format: "%.1f", self)
    }
}