import Foundation
import OSLog

/// Team Member model (formerly Employee)
/// Represents organization team members with roles, rates, and permissions
public struct TeamMember: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var email: String
    public var phone: String
    public var jobTitle: String
    public var rates: [EmployeeRate] // Keep EmployeeRate name for now to avoid breaking changes
    public var isArchived: Bool
    public var organizationID: String
    public var role: TeamMemberRole
    public var isActive: Bool
    
    // MARK: - Employment History & Status
    public var hireDate: Date
    public var terminationDate: Date?
    public var terminationReason: String?
    public var terminationType: TerminationType?
    public var employmentStatus: EmploymentStatus
    public var notes: String
    
    // MARK: - Personal Information
    public var address: String
    public var city: String
    public var state: String
    public var zipCode: String
    public var emergencyContact: String
    public var emergencyPhone: String
    
    // MARK: - Photo Support
    public var photoID: UUID? // Reference to CloudKit photo asset
    public var hasPhoto: Bool { photoID != nil }

    // MARK: - Tax & Legal Information
    public var taxID: String // SSN or Tax ID (encrypted/hashed in production)
    public var w9OnFile: Bool
    public var i9OnFile: Bool
    public var employmentType: EmploymentType
    
    // MARK: - App Access
    public var hasAppAccess: Bool // Whether they have iPhone/app access
    public var lastAppLogin: Date?
    public var appUserID: String? // CloudKit user ID if they have app access
    
    public init(
        id: UUID = .init(),
        name: String,
        email: String = "",
        phone: String = "",
        jobTitle: String,
        rates: [EmployeeRate] = [],
        isArchived: Bool = false,
        organizationID: String,
        role: TeamMemberRole = .member,
        isActive: Bool = true,
        hireDate: Date = Date(),
        terminationDate: Date? = nil,
        terminationReason: String? = nil,
        terminationType: TerminationType? = nil,
        employmentStatus: EmploymentStatus = .active,
        notes: String = "",
        address: String = "",
        city: String = "",
        state: String = "",
        zipCode: String = "",
        emergencyContact: String = "",
        emergencyPhone: String = "",
        photoID: UUID? = nil,
        taxID: String = "",
        w9OnFile: Bool = false,
        i9OnFile: Bool = false,
        employmentType: EmploymentType = .employee,
        hasAppAccess: Bool = false,
        lastAppLogin: Date? = nil,
        appUserID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.jobTitle = jobTitle
        self.rates = rates
        self.isArchived = isArchived
        self.organizationID = organizationID
        self.role = role
        self.isActive = isActive
        self.hireDate = hireDate
        self.terminationDate = terminationDate
        self.terminationReason = terminationReason
        self.terminationType = terminationType
        self.employmentStatus = employmentStatus
        self.notes = notes
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.photoID = photoID
        self.taxID = taxID
        self.w9OnFile = w9OnFile
        self.i9OnFile = i9OnFile
        self.employmentType = employmentType
        self.hasAppAccess = hasAppAccess
        self.lastAppLogin = lastAppLogin
        self.appUserID = appUserID
    }
    
    public init(
        name: String,
        email: String = "",
        phone: String = "",
        jobTitle: String,
        organizationID: String = "RHEIR-LLC-MAIN-ORG",
        role: TeamMemberRole = .member
    ) {
        self.init(
            id: .init(),
            name: name,
            email: email,
            phone: phone,
            jobTitle: jobTitle,
            rates: [],
            isArchived: false,
            organizationID: organizationID,
            role: role,
            isActive: true
        )
    }
}

// MARK: - Employment Status & Termination Types

public enum EmploymentStatus: String, Codable, CaseIterable, Sendable {
    case active = "active"                    // Working on active projects
    case betweenProjects = "between_projects" // No active projects but available
    case completed = "completed"              // All projects finished, no new assignments
    case terminated = "terminated"            // Manually terminated/fired
    case suspended = "suspended"             // Temporarily suspended
    case onLeave = "on_leave"                // On leave/vacation
    case probation = "probation"             // Probationary period
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .betweenProjects: return "Between Projects"
        case .completed: return "Projects Completed"
        case .terminated: return "Terminated"
        case .suspended: return "Suspended"
        case .onLeave: return "On Leave"
        case .probation: return "Probation"
        }
    }
    
    public var color: String {
        switch self {
        case .active: return "green"
        case .betweenProjects: return "blue"
        case .completed: return "gray"
        case .terminated: return "red"
        case .suspended: return "orange"
        case .onLeave: return "purple"
        case .probation: return "yellow"
        }
    }
    
    public var isWorkingStatus: Bool {
        return self == .active || self == .betweenProjects || self == .probation
    }
    
    public var canBeAssignedToProjects: Bool {
        return isWorkingStatus
    }
}

public enum TerminationType: String, Codable, CaseIterable, Sendable {
    case voluntary = "voluntary"
    case involuntary = "involuntary"
    case layoff = "layoff"
    case retirement = "retirement"
    case endOfContract = "end_of_contract"
    case noShow = "no_show"
    case duplicate = "duplicate"
    
    public var displayName: String {
        switch self {
        case .voluntary: return "Voluntary Resignation"
        case .involuntary: return "Involuntary Termination"
        case .layoff: return "Layoff"
        case .retirement: return "Retirement"
        case .endOfContract: return "End of Contract"
        case .noShow: return "No Show/Abandonment"
        case .duplicate: return "Duplicate Entry"
        }
    }
}

public enum EmploymentType: String, Codable, CaseIterable, Sendable {
    case employee = "employee"
    case contractor = "contractor"
    case subcontractor = "subcontractor"
    case intern = "intern"
    case volunteer = "volunteer"
    
    public var displayName: String {
        switch self {
        case .employee: return "Employee"
        case .contractor: return "Independent Contractor"
        case .subcontractor: return "Subcontractor"
        case .intern: return "Intern"
        case .volunteer: return "Volunteer"
        }
    }
    
    public var requiresW9: Bool {
        return self == .contractor || self == .subcontractor
    }
    
    public var requiresI9: Bool {
        return self == .employee
    }
}

// MARK: - Team Member Roles
public enum TeamMemberRole: String, Codable, CaseIterable, Sendable {
    case admin = "admin"
    case member = "member"
    case viewer = "viewer"
    
    public var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
    
    public var permissions: TeamMemberPermissions {
        switch self {
        case .admin:
            return TeamMemberPermissions(
                canCreateProjects: true,
                canEditProjects: true,
                canDeleteProjects: true,
                canManageTeam: true,
                canViewReports: true,
                canEditReceipts: true,
                canLogHours: true
            )
        case .member:
            return TeamMemberPermissions(
                canCreateProjects: false,
                canEditProjects: true,
                canDeleteProjects: false,
                canManageTeam: false,
                canViewReports: true,
                canEditReceipts: true,
                canLogHours: true
            )
        case .viewer:
            return TeamMemberPermissions(
                canCreateProjects: false,
                canEditProjects: false,
                canDeleteProjects: false,
                canManageTeam: false,
                canViewReports: true,
                canEditReceipts: false,
                canLogHours: false
            )
        }
    }
}

// MARK: - Team Member Permissions
public struct TeamMemberPermissions: Codable, Sendable {
    public let canCreateProjects: Bool
    public let canEditProjects: Bool
    public let canDeleteProjects: Bool
    public let canManageTeam: Bool
    public let canViewReports: Bool
    public let canEditReceipts: Bool
    public let canLogHours: Bool
    
    public init(
        canCreateProjects: Bool,
        canEditProjects: Bool,
        canDeleteProjects: Bool,
        canManageTeam: Bool,
        canViewReports: Bool,
        canEditReceipts: Bool,
        canLogHours: Bool
    ) {
        self.canCreateProjects = canCreateProjects
        self.canEditProjects = canEditProjects
        self.canDeleteProjects = canDeleteProjects
        self.canManageTeam = canManageTeam
        self.canViewReports = canViewReports
        self.canEditReceipts = canEditReceipts
        self.canLogHours = canLogHours
    }
}

// MARK: - Backward Compatibility
public typealias Employee = TeamMember

extension TeamMember {
    /// Get the default rate for this team member
    public var defaultRate: EmployeeRate? {
        return rates.first { $0.isDefault } ?? rates.first
    }
    
    /// Set a rate as the default (only one can be default)
    public mutating func setDefaultRate(_ rateID: UUID) {
        for i in 0..<rates.count {
            rates[i].isDefault = (rates[i].id == rateID)
        }
    }
    
    /// Ensure only one rate is marked as default
    public mutating func validateDefaultRate() {
        let defaultRates = rates.filter { $0.isDefault }
        
        if defaultRates.count > 1 {
            // Multiple defaults - keep only the first one
            for i in 0..<rates.count {
                rates[i].isDefault = (i == 0 && rates[i].isDefault)
            }
        } else if defaultRates.isEmpty && !rates.isEmpty {
            // No default - make first rate the default
            rates[0].isDefault = true
        }
    }
    
    // MARK: - Employment Management
    
    /// Terminate team member with reason
    public mutating func terminate(reason: String, type: TerminationType, date: Date = Date()) {
        let teamMemberID = self.id.uuidString
        let terminationTypeName = type.displayName

        self.terminationDate = date
        self.terminationReason = reason
        self.terminationType = type
        self.employmentStatus = .terminated
        self.isActive = false
        
        // Preserve all historical data for legal/tax purposes
        // Don't delete rates, hours, or associated project data
        Logger.teamMember.notice(
            "Employee model marked team member terminated [teamMember=\(teamMemberID, privacy: .private(mask: .hash)), terminationType=\(terminationTypeName, privacy: .public)]"
        )
    }
    
    /// Check if team member can be deleted (only duplicates or never worked)
    public var canBeDeleted: Bool {
        // Only allow deletion if:
        // 1. It's a duplicate entry, OR
        // 2. They never worked (no hours logged, no projects)
        return terminationType == .duplicate || 
               (hireDate > Date().addingTimeInterval(-24*60*60) && // Hired less than 24 hours ago
                terminationDate == nil)
    }
    
    /// Get full address
    public var fullAddress: String? {
        guard !address.isEmpty, !city.isEmpty, !state.isEmpty else { return nil }
        return "\(address)\n\(city), \(state) \(zipCode)"
    }
    
    /// Check if employment documentation is complete
    public var hasCompleteDocumentation: Bool {
        switch employmentType {
        case .employee:
            return i9OnFile && !taxID.isEmpty
        case .contractor, .subcontractor:
            return w9OnFile && !taxID.isEmpty
        case .intern, .volunteer:
            return true // Usually less documentation required
        }
    }
    
    /// Get active employment duration
    public var employmentDuration: String {
        let endDate = terminationDate ?? Date()
        let duration = Calendar.current.dateComponents([.year, .month, .day], from: hireDate, to: endDate)
        
        var components: [String] = []
        if let years = duration.year, years > 0 {
            components.append("\(years) year\(years == 1 ? "" : "s")")
        }
        if let months = duration.month, months > 0 {
            components.append("\(months) month\(months == 1 ? "" : "s")")
        }
        if let days = duration.day, days > 0 && components.isEmpty {
            components.append("\(days) day\(days == 1 ? "" : "s")")
        }
        
        return components.isEmpty ? "Same day" : components.joined(separator: ", ")
    }
    
    // MARK: - Project-Based Status Management
    
    /// Calculate employment status based on current project activity
    public func calculateStatusFromProjects(_ allProjects: [Project]) -> EmploymentStatus {
        // If manually terminated, suspended, or on leave, keep that status
        if employmentStatus == .terminated || 
           employmentStatus == .suspended || 
           employmentStatus == .onLeave {
            return employmentStatus
        }
        
        // Find projects where this team member has worked or is assigned
        let memberProjects = getMemberProjects(from: allProjects)
        let activeProjects = memberProjects.filter { $0.status == .active }
        let _ = memberProjects.filter { $0.status == .completed }
        
        // Status logic based on your requirements:
        if !activeProjects.isEmpty {
            // Working on at least 1 active project = ACTIVE
            return .active
        } else if !memberProjects.isEmpty && memberProjects.allSatisfy({ $0.status == .completed }) {
            // All assigned projects are completed = NON-ACTIVE
            return .completed
        } else {
            // No projects assigned or available for new work = BETWEEN PROJECTS
            return .betweenProjects
        }
    }
    
    /// Get all projects this team member has worked on or is assigned to
    private func getMemberProjects(from allProjects: [Project]) -> [Project] {
        return allProjects.filter { project in
            isAssignedToProject(project)
        }
    }
    
    /// Check if team member is assigned to or has worked on a project
    private func isAssignedToProject(_ project: Project) -> Bool {
        // TODO: In a real implementation, this would check:
        // 1. Work hours logged on this project
        // 2. Progress reports submitted for this project  
        // 3. Tasks assigned to this team member
        // 4. Receipts submitted by this team member for this project
        
        // For now, we'll use a simple check based on organization
        return project.organizationID == self.organizationID
    }
    
    /// Update status automatically when projects change
    public mutating func updateStatusFromProjects(_ allProjects: [Project]) {
        let newStatus = calculateStatusFromProjects(allProjects)
        let teamMemberID = self.id.uuidString
        let statusName = newStatus.displayName
        
        // Only update if it's not a manual status (don't override termination, suspension, etc.)
        if employmentStatus.isWorkingStatus || employmentStatus == .completed {
            employmentStatus = newStatus
            Logger.teamMember.info(
                "Employee model updated employment status from project state [teamMember=\(teamMemberID, privacy: .private(mask: .hash)), status=\(statusName, privacy: .public)]"
            )
        }
    }
    
    /// Get detailed work status for this team member
    public func getDetailedWorkStatus(from allProjects: [Project]) -> TeamMemberWorkStatus {
        let memberProjects = getMemberProjects(from: allProjects)
        let activeProjects = memberProjects.filter { $0.status == .active }
        let completedProjects = memberProjects.filter { $0.status == .completed }
        
        return TeamMemberWorkStatus(
            activeProjects: activeProjects,
            completedProjects: completedProjects,
            currentStatus: employmentStatus,
            statusReason: getStatusReason(activeProjects: activeProjects, completedProjects: completedProjects),
            isAvailableForNewWork: employmentStatus.canBeAssignedToProjects
        )
    }
    
    private func getStatusReason(activeProjects: [Project], completedProjects: [Project]) -> String {
        switch employmentStatus {
        case .active:
            let count = activeProjects.count
            return "Working on \(count) active project\(count == 1 ? "" : "s")"
        case .betweenProjects:
            if completedProjects.isEmpty {
                return "Available for project assignment"
            } else {
                return "Completed \(completedProjects.count) project\(completedProjects.count == 1 ? "" : "s"), available for new work"
            }
        case .completed:
            return "All assigned projects completed"
        case .terminated:
            return "Employment terminated"
        case .suspended:
            return "Currently suspended"
        case .onLeave:
            return "On leave"
        case .probation:
            return "Probationary period"
        }
    }
}

// MARK: - Team Member Work Status

public struct TeamMemberWorkStatus: Codable, Sendable {
    public let activeProjects: [Project]
    public let completedProjects: [Project]
    public let currentStatus: EmploymentStatus
    public let statusReason: String
    public let isAvailableForNewWork: Bool
    
    public var totalProjectCount: Int {
        return activeProjects.count + completedProjects.count
    }
    
    public var activeProjectNames: [String] {
        return activeProjects.map(\.name)
    }
    
    public var completedProjectNames: [String] {
        return completedProjects.map(\.name)
    }
}
