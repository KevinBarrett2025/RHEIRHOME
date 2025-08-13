import Foundation
import CloudKit

/// Enterprise-grade team member model with comprehensive workforce management
/// This becomes the single source of truth for all team member data across the organization
public struct EnterpriseTeamMember: Identifiable, Codable, Hashable, Sendable {
    // MARK: - Core Identity
    public let id: UUID
    public var name: String
    public var email: String
    public var phone: String
    public var organizationID: String
    
    // MARK: - Employment Details
    public var jobTitle: String
    public var employmentType: EmploymentType
    public var employmentStatus: EmploymentStatus
    public var role: TeamMemberRole
    public var hireDate: Date
    public var terminationDate: Date?
    public var terminationReason: String?
    public var terminationType: TerminationType?
    
    // MARK: - Compensation & Rates
    public var payRates: [PayRate]
    public var defaultPayRateID: UUID?
    public var isHourlyEmployee: Bool // vs salaried
    public var overtimeEligible: Bool
    public var payFrequency: PayFrequency
    
    // MARK: - Skills & Certifications (Enterprise Feature)
    public var skillCategories: [SkillCategory]
    public var certifications: [Certification]
    public var safetyTraining: [SafetyTraining]
    public var performanceRating: Double // 1-5 rating
    public var lastPerformanceReview: Date?
    
    // MARK: - Project Assignment Tracking
    public var currentProjectIDs: [String] // Active project assignments
    public var pastProjectIDs: [String] // Historical project assignments
    public var preferredWorkTypes: [TaskCategory] // What they're best at
    public var availabilityStatus: AvailabilityStatus
    
    // MARK: - Equipment & Tools Assigned
    public var assignedEquipmentIDs: [UUID]
    public var toolAllowance: Double?
    public var uniformSize: String?
    
    // MARK: - Performance Metrics (Analytics)
    public var totalHoursWorked: Double
    public var totalAmountEarned: Double
    public var totalAmountPaid: Double
    public var averageHourlyEarnings: Double
    public var taskCompletionRate: Double // %
    public var qualityRating: Double // 1-5
    public var safetyScore: Double // 1-5
    public var lastWorkedDate: Date?
    
    // MARK: - Contact & Personal Information
    public var address: String
    public var city: String
    public var state: String
    public var zipCode: String
    public var emergencyContact: String
    public var emergencyPhone: String
    public var photoID: UUID?
    
    // MARK: - Legal & Tax Documentation
    public var taxID: String // Encrypted/Hashed in production
    public var w9OnFile: Bool
    public var i9OnFile: Bool
    public var backgroundCheckComplete: Bool
    public var driversLicenseNumber: String?
    public var driversLicenseExpiry: Date?
    
    // MARK: - App Access & Integration
    public var hasAppAccess: Bool
    public var appUserID: String?
    public var lastAppLogin: Date?
    public var notificationPreferences: NotificationPreferences
    
    // MARK: - Audit Trail
    public var createdAt: Date
    public var updatedAt: Date
    public var lastModifiedBy: String
    public var changeHistory: [TeamMemberChange]
    
    // MARK: - CloudKit Integration
    public var cloudKitRecordID: String?
    public var isActive: Bool
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        phone: String = "",
        organizationID: String,
        jobTitle: String,
        employmentType: EmploymentType = .employee,
        employmentStatus: EmploymentStatus = .active,
        role: TeamMemberRole = .member,
        hireDate: Date = Date(),
        payRates: [PayRate] = [],
        isHourlyEmployee: Bool = true,
        overtimeEligible: Bool = true,
        payFrequency: PayFrequency = .weekly,
        skillCategories: [SkillCategory] = [],
        certifications: [Certification] = [],
        performanceRating: Double = 3.0,
        availabilityStatus: AvailabilityStatus = .available,
        address: String = "",
        city: String = "",
        state: String = "",
        zipCode: String = "",
        emergencyContact: String = "",
        emergencyPhone: String = "",
        taxID: String = "",
        w9OnFile: Bool = false,
        i9OnFile: Bool = false,
        hasAppAccess: Bool = false,
        appUserID: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.organizationID = organizationID
        self.jobTitle = jobTitle
        self.employmentType = employmentType
        self.employmentStatus = employmentStatus
        self.role = role
        self.hireDate = hireDate
        self.payRates = payRates
        self.isHourlyEmployee = isHourlyEmployee
        self.overtimeEligible = overtimeEligible
        self.payFrequency = payFrequency
        self.skillCategories = skillCategories
        self.certifications = certifications
        self.performanceRating = performanceRating
        self.availabilityStatus = availabilityStatus
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.taxID = taxID
        self.w9OnFile = w9OnFile
        self.i9OnFile = i9OnFile
        self.hasAppAccess = hasAppAccess
        self.appUserID = appUserID
        self.notes = notes
        
        // Initialize computed fields
        self.terminationDate = nil
        self.terminationReason = nil
        self.terminationType = nil
        self.defaultPayRateID = payRates.first?.id
        self.safetyTraining = []
        self.lastPerformanceReview = nil
        self.currentProjectIDs = []
        self.pastProjectIDs = []
        self.preferredWorkTypes = []
        self.assignedEquipmentIDs = []
        self.toolAllowance = nil
        self.uniformSize = nil
        self.totalHoursWorked = 0
        self.totalAmountEarned = 0
        self.totalAmountPaid = 0
        self.averageHourlyEarnings = 0
        self.taskCompletionRate = 0
        self.qualityRating = 3.0
        self.safetyScore = 5.0
        self.lastWorkedDate = nil
        self.photoID = nil
        self.backgroundCheckComplete = false
        self.driversLicenseNumber = nil
        self.driversLicenseExpiry = nil
        self.lastAppLogin = nil
        self.notificationPreferences = NotificationPreferences()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastModifiedBy = "system"
        self.changeHistory = []
        self.cloudKitRecordID = nil
        self.isActive = true
    }
    
    // MARK: - Business Logic
    
    /// Get the current default pay rate
    public var defaultPayRate: PayRate? {
        if let defaultID = defaultPayRateID {
            return payRates.first { $0.id == defaultID }
        }
        return payRates.first { $0.isDefault } ?? payRates.first
    }
    
    /// Calculate total outstanding pay across all projects
    public var totalOutstandingPay: Double {
        return totalAmountEarned - totalAmountPaid
    }
    
    /// Check if team member is available for new assignments
    public var isAvailableForAssignment: Bool {
        return employmentStatus.canBeAssignedToProjects && 
               availabilityStatus == .available
    }
    
    /// Get skills for a specific category
    public func getSkills(for category: TaskCategory) -> [Skill] {
        return skillCategories
            .first { $0.category == category }?
            .skills ?? []
    }
    
    /// Check if team member has required certification
    public func hasCertification(_ certType: CertificationType) -> Bool {
        return certifications.contains { 
            $0.type == certType && 
            $0.isValid && 
            !$0.isExpired 
        }
    }
    
    /// Add a change to the audit trail
    public mutating func addChange(
        type: ChangeType,
        field: String,
        oldValue: String?,
        newValue: String?,
        changedBy: String,
        reason: String? = nil
    ) {
        let change = TeamMemberChange(
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
        lastModifiedBy = changedBy
        
        // Keep only last 100 changes to avoid CloudKit size limits
        if changeHistory.count > 100 {
            changeHistory = Array(changeHistory.suffix(100))
        }
    }
    
    /// Update performance metrics (called by analytics service)
    public mutating func updatePerformanceMetrics(
        totalHours: Double,
        totalEarned: Double,
        totalPaid: Double,
        completionRate: Double,
        qualityRating: Double,
        lastWorked: Date?
    ) {
        self.totalHoursWorked = totalHours
        self.totalAmountEarned = totalEarned
        self.totalAmountPaid = totalPaid
        self.averageHourlyEarnings = totalHours > 0 ? totalEarned / totalHours : 0
        self.taskCompletionRate = completionRate
        self.qualityRating = qualityRating
        self.lastWorkedDate = lastWorked
        self.updatedAt = Date()
    }
}

// MARK: - Supporting Enums and Structs

public enum PayFrequency: String, Codable, CaseIterable, Sendable {
    case weekly = "weekly"
    case biweekly = "biweekly" 
    case monthly = "monthly"
    case projectBased = "project_based"
    
    public var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .projectBased: return "Per Project"
        }
    }
}

public enum AvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available = "available"
    case assigned = "assigned"
    case onLeave = "on_leave"
    case injured = "injured"
    case training = "training"
    case unavailable = "unavailable"
    
    public var displayName: String {
        switch self {
        case .available: return "Available"
        case .assigned: return "Assigned"
        case .onLeave: return "On Leave"
        case .injured: return "Injured"
        case .training: return "In Training"
        case .unavailable: return "Unavailable"
        }
    }
    
    public var color: String {
        switch self {
        case .available: return "green"
        case .assigned: return "blue"
        case .onLeave: return "orange"
        case .injured: return "red"
        case .training: return "purple"
        case .unavailable: return "gray"
        }
    }
}

public struct PayRate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var taskType: String
    public var category: TaskCategory
    public var rate: Double
    public var isDefault: Bool
    public var effectiveDate: Date
    public var endDate: Date?
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        taskType: String,
        category: TaskCategory = .general,
        rate: Double,
        isDefault: Bool = false,
        effectiveDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.taskType = taskType
        self.category = category
        self.rate = rate
        self.isDefault = isDefault
        self.effectiveDate = effectiveDate
        self.endDate = endDate
        self.notes = notes
    }
    
    public var isActive: Bool {
        guard let endDate = endDate else { return true }
        return Date() <= endDate
    }
}

public struct SkillCategory: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let category: TaskCategory
    public var skills: [Skill]
    
    public init(id: UUID = UUID(), category: TaskCategory, skills: [Skill] = []) {
        self.id = id
        self.category = category
        self.skills = skills
    }
}

public struct Skill: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var proficiencyLevel: ProficiencyLevel
    public var yearsExperience: Int
    public var lastUsed: Date?
    public var certificationRequired: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        proficiencyLevel: ProficiencyLevel = .intermediate,
        yearsExperience: Int = 0,
        lastUsed: Date? = nil,
        certificationRequired: Bool = false
    ) {
        self.id = id
        self.name = name
        self.proficiencyLevel = proficiencyLevel
        self.yearsExperience = yearsExperience
        self.lastUsed = lastUsed
        self.certificationRequired = certificationRequired
    }
}

public enum ProficiencyLevel: String, Codable, CaseIterable, Sendable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
    
    public var color: String {
        switch self {
        case .beginner: return "red"
        case .intermediate: return "orange"
        case .advanced: return "green"
        case .expert: return "blue"
        }
    }
}

public struct Certification: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: CertificationType
    public var number: String
    public var issuedBy: String
    public var issuedDate: Date
    public var expiryDate: Date?
    public var isValid: Bool
    
    public init(
        id: UUID = UUID(),
        type: CertificationType,
        number: String,
        issuedBy: String,
        issuedDate: Date,
        expiryDate: Date? = nil,
        isValid: Bool = true
    ) {
        self.id = id
        self.type = type
        self.number = number
        self.issuedBy = issuedBy
        self.issuedDate = issuedDate
        self.expiryDate = expiryDate
        self.isValid = isValid
    }
    
    public var isExpired: Bool {
        guard let expiryDate = expiryDate else { return false }
        return Date() > expiryDate
    }
}

public enum CertificationType: String, Codable, CaseIterable, Sendable {
    case osha10 = "osha_10"
    case osha30 = "osha_30"
    case electricianLicense = "electrician_license"
    case plumbingLicense = "plumbing_license"
    case hvacCertification = "hvac_certification"
    case cdlLicense = "cdl_license"
    case operatorLicense = "operator_license"
    case firstAid = "first_aid"
    case cpr = "cpr"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .osha10: return "OSHA 10"
        case .osha30: return "OSHA 30"
        case .electricianLicense: return "Electrician License"
        case .plumbingLicense: return "Plumbing License"
        case .hvacCertification: return "HVAC Certification"
        case .cdlLicense: return "CDL License"
        case .operatorLicense: return "Equipment Operator License"
        case .firstAid: return "First Aid"
        case .cpr: return "CPR"
        case .other: return "Other"
        }
    }
}

public struct SafetyTraining: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: SafetyTrainingType
    public var completedDate: Date
    public var expiryDate: Date?
    public var instructor: String
    public var certificateNumber: String?
    
    public var isExpired: Bool {
        guard let expiryDate = expiryDate else { return false }
        return Date() > expiryDate
    }
}

public enum SafetyTrainingType: String, Codable, CaseIterable, Sendable {
    case scaffoldSafety = "scaffold_safety"
    case fallProtection = "fall_protection"
    case confinedSpace = "confined_space"
    case hazmat = "hazmat"
    case respirator = "respirator"
    case lockoutTagout = "lockout_tagout"
    case forkliftOperator = "forklift_operator"
    case craneOperator = "crane_operator"
}

public struct NotificationPreferences: Codable, Hashable, Sendable {
    public var emailNotifications: Bool = true
    public var pushNotifications: Bool = true
    public var smsNotifications: Bool = false
    public var paymentNotifications: Bool = true
    public var taskAssignmentNotifications: Bool = true
    public var scheduleChangeNotifications: Bool = true
    
    public init() {}
}

public struct TeamMemberChange: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let type: ChangeType
    public let field: String
    public let oldValue: String?
    public let newValue: String?
    public let changedBy: String
    public let changedAt: Date
    public let reason: String?
    
    public init(
        id: UUID = UUID(),
        type: ChangeType,
        field: String,
        oldValue: String?,
        newValue: String?,
        changedBy: String,
        changedAt: Date,
        reason: String?
    ) {
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

public enum ChangeType: String, Codable, CaseIterable, Sendable {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case terminated = "terminated"
    case reactivated = "reactivated"
    case rateChanged = "rate_changed"
    case roleChanged = "role_changed"
    case projectAssigned = "project_assigned"
    case projectRemoved = "project_removed"
    case correctionMade = "correction_made"
    
    public var displayName: String {
        switch self {
        case .created: return "Created"
        case .updated: return "Updated"
        case .deleted: return "Deleted"
        case .terminated: return "Terminated"
        case .reactivated: return "Reactivated"
        case .rateChanged: return "Rate Changed"
        case .roleChanged: return "Role Changed"
        case .projectAssigned: return "Assigned to Project"
        case .projectRemoved: return "Removed from Project"
        case .correctionMade: return "Correction Made"
        }
    }
}