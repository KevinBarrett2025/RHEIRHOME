// Organization.swift

import Foundation
import SwiftUI

// MARK: - Type Aliases to resolve ambiguity
public typealias OrgVendor = Vendor  // Use the Vendor from Receipt.swift
public typealias OrgPaymentMethod = PaymentMethod  // Use the PaymentMethod from Receipt.swift

// MARK: - Organization Role Management

public enum OrganizationRole: String, Codable, CaseIterable {
    case admin = "admin"           // Full access, can invite others
    case member = "member"         // Full access to org projects
    case contractor = "contractor" // Limited access to specific projects
    case viewer = "viewer"         // Read-only access
    
    public var displayName: String {
        switch self {
        case .admin: return "Administrator"
        case .member: return "Team Member"
        case .contractor: return "Contractor"
        case .viewer: return "Viewer"
        }
    }
    
    public var canInviteOthers: Bool {
        return self == .admin
    }
    
    public var canCreateProjects: Bool {
        return self == .admin || self == .member
    }
    
    public var canViewAllProjects: Bool {
        return self == .admin || self == .member
    }
}

public struct Organization: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var members: [String]
    
    public var adminUserID: String = ""
    public var industry: String?
    public var settings: OrganizationSettings?
    public var isActive: Bool = true
    public var createdAt: Date = Date()
    public var lastModified: Date = Date()
    public var dataResidency: String = "US"
    public var tenantIsolationLevel: String = "ZONE_ISOLATED"
    public var maxMembers: Int = 50
    public var storageQuotaMB: Double = 10000 // 10GB default
    public var subscriptionTier: SubscriptionTier = .builder // Updated from .enterprise to .builder
    
    // CloudKit integration
    public var cloudKitRecordID: String?
    public var cloudKitZoneID: String?
    public var shareURL: String?
    public var vendors: [OrgVendor] = []
    public var paymentMethods: [OrgPaymentMethod] = []
    
    // MARK: - Team Members (Single Source of Truth)
    public var teamMembers: [TeamMember] = []
    
    // MARK: - Initializers
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        members: [String] = [],
        adminUserID: String = "",
        industry: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.adminUserID = adminUserID
        self.industry = industry
        self.isActive = isActive
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID
        
        // ENTERPRISE DEFAULT: Set enterprise-level limits by default
        self.maxMembers = Int.max
        self.storageQuotaMB = 50000 // 50GB
        
        // Generate CloudKit zone ID based on organization ID
        self.cloudKitZoneID = "org_\(id)_\(isDebugMode() ? "dev" : "prod")"
    }
    
    // MARK: - Computed Properties
    
    public var isCurrentUserAdmin: Bool {
        guard let currentUserID = getCurrentUserID() else { return false }
        return adminUserID == currentUserID
    }
    
    public var memberCount: Int {
        return members.count
    }
    
    public var canAddMoreMembers: Bool {
        return members.count < maxMembers
    }
    
    public var storageUsagePercentage: Double {
        // This would be calculated from actual usage
        return 0.0 // Placeholder
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
    
    private func isDebugMode() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Organization Management
    
    public mutating func addMember(_ userID: String) -> Bool {
        guard canAddMoreMembers && !members.contains(userID) else {
            return false
        }
        members.append(userID)
        lastModified = Date()
        return true
    }
    
    public mutating func removeMember(_ userID: String) -> Bool {
        guard userID != adminUserID else { return false } // Can't remove admin
        
        if let index = members.firstIndex(of: userID) {
            members.remove(at: index)
            lastModified = Date()
            return true
        }
        return false
    }
    
    public mutating func transferOwnership(to newAdminUserID: String) -> Bool {
        guard members.contains(newAdminUserID) else { return false }
        
        adminUserID = newAdminUserID
        lastModified = Date()
        return true
    }
    
    public mutating func updateSettings(_ newSettings: OrganizationSettings) {
        settings = newSettings
        lastModified = Date()
    }
    
    public mutating func upgradeSubscription(to tier: SubscriptionTier) {
        subscriptionTier = tier
        
        // Update limits based on subscription tier
        let isBuilderTier = tier == .builder || tier == .free || tier == .starter
        let isProfessionalTier = tier == .professional || tier == .standard
        let isEnterpriseTier = tier == .enterprise || tier == .premium
        
        if isBuilderTier {
            maxMembers = 2
            storageQuotaMB = 500 // 500MB
        } else if isProfessionalTier {
            maxMembers = 10
            storageQuotaMB = 5000 // 5GB
        } else if isEnterpriseTier {
            maxMembers = Int.max
            storageQuotaMB = 50000 // 50GB
        }
        
        lastModified = Date()
    }
    
    // MARK: - Team Member Management (Enterprise Features)
    
    /// Add a new team member to the organization
    public mutating func addTeamMember(_ teamMember: TeamMember) -> Bool {
        guard canAddMoreMembers else { return false }
        
        // Ensure the team member belongs to this organization
        var member = teamMember
        member.organizationID = self.id
        
        // Add to team members array
        teamMembers.append(member)
        
        // Add to basic members list if they have app access
        if member.hasAppAccess, let appUserID = member.appUserID, !members.contains(appUserID) {
            members.append(appUserID)
        }
        
        lastModified = Date()
        return true
    }
    
    /// Remove a team member from the organization
    public mutating func removeTeamMember(_ teamMemberID: UUID) -> Bool {
        guard let index = teamMembers.firstIndex(where: { $0.id == teamMemberID }) else {
            return false
        }
        
        let member = teamMembers[index]
        
        // Remove from basic members list if they had app access
        if let appUserID = member.appUserID {
            members.removeAll { $0 == appUserID }
        }
        
        // Remove from team members
        teamMembers.remove(at: index)
        
        lastModified = Date()
        return true
    }
    
    /// Update a team member
    public mutating func updateTeamMember(_ updatedMember: TeamMember) -> Bool {
        guard let index = teamMembers.firstIndex(where: { $0.id == updatedMember.id }) else {
            return false
        }
        
        // Ensure they still belong to this organization
        var member = updatedMember
        member.organizationID = self.id
        
        teamMembers[index] = member
        lastModified = Date()
        return true
    }
    
    /// Get team member by ID
    public func getTeamMember(by id: UUID) -> TeamMember? {
        return teamMembers.first { $0.id == id }
    }
    
    /// Get active team members
    public var activeTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.employmentStatus.isWorkingStatus }
    }
    
    /// Get team members available for project assignment
    public var availableTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }
    }
    
    /// Get team members by employment type
    public func getTeamMembers(by type: EmploymentType) -> [TeamMember] {
        return teamMembers.filter { $0.employmentType == type }
    }
    
    /// Update team member statuses based on project activity
    public mutating func updateTeamMemberStatuses(basedOn projects: [Project]) {
        for i in 0..<teamMembers.count {
            teamMembers[i].updateStatusFromProjects(projects)
        }
        lastModified = Date()
    }
    
    /// Get payroll summary for all team members
    public func getPayrollSummary() -> OrganizationPayrollSummary {
        let employees = teamMembers.filter { $0.employmentType == .employee }
        let contractors = teamMembers.filter { 
            $0.employmentType == .contractor || $0.employmentType == .subcontractor 
        }
        
        return OrganizationPayrollSummary(
            totalEmployees: employees.count,
            totalContractors: contractors.count,
            activeEmployees: employees.filter { $0.employmentStatus.isWorkingStatus }.count,
            activeContractors: contractors.filter { $0.employmentStatus.isWorkingStatus }.count,
            needsW9: teamMembers.filter { $0.employmentType.requiresW9 && !$0.w9OnFile }.count,
            needsI9: teamMembers.filter { $0.employmentType.requiresI9 && !$0.i9OnFile }.count
        )
    }
}

// MARK: - Subscription Tiers

public enum SubscriptionTier: String, Codable, CaseIterable {
    case builder = "builder"      // Renamed from "free" to match badges
    case professional = "professional"
    case enterprise = "enterprise"
    
    // Legacy support - map old tiers to new ones
    case free = "free"         // Maps to builder
    case starter = "starter"   // Maps to builder
    case standard = "standard" // Maps to professional
    case premium = "premium"   // Maps to enterprise
    
    public static var modernTiers: [SubscriptionTier] {
        return [.builder, .professional, .enterprise]
    }
    
    public var displayName: String {
        switch self {
        case .builder, .free, .starter: return "Builder"
        case .professional, .standard: return "Professional"
        case .enterprise, .premium: return "Enterprise"
        }
    }
    
    public var monthlyPrice: Double {
        switch self {
        case .builder, .free, .starter: return 0.0
        case .professional, .standard: return 29.0
        case .enterprise, .premium: return 99.0
        }
    }
    
    public var maxProjects: Int {
        switch self {
        case .builder, .free, .starter: return 3
        case .professional, .standard: return 25
        case .enterprise, .premium: return Int.max
        }
    }
    
    public var maxTeamMembers: Int {
        switch self {
        case .builder, .free, .starter: return 2
        case .professional, .standard: return 10
        case .enterprise, .premium: return Int.max
        }
    }
    
    public var features: [String] {
        switch self {
        case .builder, .free, .starter:
            return [
                "Up to 3 projects",
                "Up to 2 team members",
                "Basic project management",
                "30-day data retention",
                "Mobile app access"
            ]
        case .professional, .standard:
            return [
                "Up to 25 projects",
                "Up to 10 team members", 
                "Advanced reporting",
                "1-year data retention",
                "Priority email support",
                "Custom categories",
                "Export capabilities"
            ]
        case .enterprise, .premium:
            return [
                "Unlimited projects",
                "Unlimited team members",
                "Advanced analytics",
                "Unlimited data retention",
                "Dedicated support",
                "Custom integrations",
                "API access",
                "Multiple organizations"
            ]
        }
    }
    
    // MARK: - Badge and Visual Properties
    
    /// Returns the system image name for the tier badge
    public var badgeIcon: String {
        switch self {
        case .builder, .free, .starter: return "hammer.fill"
        case .professional, .standard: return "shield.fill"
        case .enterprise, .premium: return "crown.fill"
        }
    }
    
    /// Returns the badge color
    public var badgeColor: Color {
        switch self {
        case .builder, .free, .starter: return .orange
        case .professional, .standard: return .blue
        case .enterprise, .premium: return .purple
        }
    }
    
    /// Returns the gradient colors for enhanced badges
    public var badgeGradient: LinearGradient {
        switch self {
        case .builder, .free, .starter:
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .professional, .standard:
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .enterprise, .premium:
            return LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    public var isFreeTier: Bool {
        return self == .builder || self == .free || self == .starter
    }
    
    public var hasFreeTrialAvailable: Bool {
        return !isFreeTier
    }
    
    public var freeTrialDays: Int {
        return 7 // 7-day free trial for paid tiers
    }
}

// MARK: - Enhanced Organization Settings

public struct OrganizationSettings: Codable, Hashable, Equatable {
    // Regional settings
    public var timeZone: String = "America/New_York"
    public var currency: String = "USD"
    public var locale: String = "en_US"
    
    // Data management
    public var dataRetentionDays: Int = 2555 // 7 years default
    public var autoArchiveInactiveProjects: Bool = true
    public var autoDeleteArchivedProjectsAfterDays: Int = 365
    
    // Collaboration settings
    public var requirePhotoApproval: Bool = false
    public var allowGuestAccess: Bool = false
    public var enableRealTimeSync: Bool = true
    public var maxProjectsPerUser: Int = 100
    
    // Security settings
    public var requireTwoFactorAuth: Bool = false
    public var passwordPolicy: PasswordPolicy = .standard
    public var sessionTimeoutMinutes: Int = 480 // 8 hours
    public var allowDataExport: Bool = true
    
    // Notification settings
    public var emailNotifications: Bool = true
    public var pushNotifications: Bool = true
    public var weeklyReports: Bool = true
    public var budgetAlerts: Bool = true
    
    // Integration settings
    public var enableAPIAccess: Bool = false
    public var webhookURL: String?
    public var customFields: [String: String] = [:]
    
    // Compliance settings
    public var dataProcessingRegion: String = "US"
    public var gdprCompliant: Bool = true
    public var auditLogRetentionDays: Int = 90
}

public enum PasswordPolicy: String, Codable, Hashable, Equatable {
    case basic = "basic"
    case standard = "standard"
    case strict = "strict"
    
    public var requirements: String {
        switch self {
        case .basic:
            return "Minimum 8 characters"
        case .standard:
            return "Minimum 8 characters, including uppercase, lowercase, and numbers"
        case .strict:
            return "Minimum 12 characters, including uppercase, lowercase, numbers, and special characters"
        }
    }
}

// MARK: - Enhanced Business Details Support

extension Organization {
    // Business contact information
    public var businessPhone: String? {
        return settings?.customFields["businessPhone"]
    }
    
    public var businessEmail: String? {
        return settings?.customFields["businessEmail"]
    }
    
    public var businessAddress: String? {
        return settings?.customFields["businessAddress"]
    }
    
    public var businessCity: String? {
        return settings?.customFields["businessCity"]
    }
    
    public var businessState: String? {
        return settings?.customFields["businessState"]
    }
    
    public var businessZip: String? {
        return settings?.customFields["businessZip"]
    }
    
    public var businessEIN: String? {
        return settings?.customFields["businessEIN"]
    }
    
    public var businessLicense: String? {
        return settings?.customFields["businessLicense"]
    }
    
    public var website: String? {
        return settings?.customFields["website"]
    }
    
    // Computed properties for business information completeness
    public var hasCompleteBusinessInfo: Bool {
        return businessPhone != nil && 
               businessEmail != nil && 
               businessAddress != nil &&
               businessCity != nil &&
               businessState != nil &&
               businessZip != nil
    }
    
    public var businessInfoCompletionPercentage: Double {
        let fields = [businessPhone, businessEmail, businessAddress, businessCity, businessState, businessZip, businessEIN, businessLicense, website]
        let completedFields = fields.compactMap { $0 }.filter { !$0.isEmpty }
        return Double(completedFields.count) / Double(fields.count)
    }
    
    // Full business address formatted
    public var formattedBusinessAddress: String? {
        guard let address = businessAddress,
              let city = businessCity,
              let state = businessState,
              let zip = businessZip else {
            return nil
        }
        
        return "\(address)\n\(city), \(state) \(zip)"
    }
    
    // Update business details
    public mutating func updateBusinessDetails(
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        ein: String? = nil,
        license: String? = nil,
        website: String? = nil
    ) {
        if settings == nil {
            settings = OrganizationSettings()
        }
        
        if let phone = phone { settings?.customFields["businessPhone"] = phone }
        if let email = email { settings?.customFields["businessEmail"] = email }
        if let address = address { settings?.customFields["businessAddress"] = address }
        if let city = city { settings?.customFields["businessCity"] = city }
        if let state = state { settings?.customFields["businessState"] = state }
        if let zip = zip { settings?.customFields["businessZip"] = zip }
        if let ein = ein { settings?.customFields["businessEIN"] = ein }
        if let license = license { settings?.customFields["businessLicense"] = license }
        if let website = website { settings?.customFields["website"] = website }
        
        lastModified = Date()
    }
}

// MARK: - Organization Payroll Summary

public struct OrganizationPayrollSummary: Codable, Sendable {
    public let totalEmployees: Int
    public let totalContractors: Int
    public let activeEmployees: Int
    public let activeContractors: Int
    public let needsW9: Int
    public let needsI9: Int
    
    public var totalTeamMembers: Int {
        return totalEmployees + totalContractors
    }
    
    public var totalActive: Int {
        return activeEmployees + activeContractors
    }
    
    public var documentationCompletionRate: Double {
        let totalRequiringDocs = totalEmployees + totalContractors
        guard totalRequiringDocs > 0 else { return 1.0 }
        
        let missingDocs = needsW9 + needsI9
        return Double(totalRequiringDocs - missingDocs) / Double(totalRequiringDocs)
    }
}

// MARK: - Subscription Display Helpers

extension SubscriptionTier {
    /// Returns a formatted string for project limits display
    public var projectLimitDisplay: String {
        switch maxProjects {
        case Int.max:
            return "∞"
        default:
            return "\(maxProjects)"
        }
    }
    
    /// Returns a formatted string for team member limits display
    public var teamMemberLimitDisplay: String {
        switch maxTeamMembers {
        case Int.max:
            return "∞"
        default:
            return "\(maxTeamMembers)"
        }
    }
    
    /// Returns a usage display string like "2 / 25" or "5 / ∞"
    public func projectUsageDisplay(current: Int) -> String {
        if maxProjects == Int.max {
            return "\(current) / ∞"
        } else {
            return "\(current) / \(maxProjects)"
        }
    }
    
    /// Returns a usage display string like "3 / 10" or "8 / ∞"
    public func teamMemberUsageDisplay(current: Int) -> String {
        if maxTeamMembers == Int.max {
            return "\(current) / ∞"
        } else {
            return "\(current) / \(maxTeamMembers)"
        }
    }
}