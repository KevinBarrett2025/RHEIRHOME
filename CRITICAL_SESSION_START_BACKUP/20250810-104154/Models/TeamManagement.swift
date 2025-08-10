import Foundation

// MARK: - Team Member Assignment Model
public struct TeamMemberAssignment: Identifiable, Codable {
    public let id = UUID()
    public let memberID: String
    public let projectID: String
    public let role: OrganizationRole
    public let permissions: ProjectPermissions
    public let assignedDate: Date
    
    public var canCreateProjects: Bool {
        permissions.canCreateProjects
    }
    
    public var canInviteOthers: Bool {
        permissions.canInviteTeamMembers
    }
    
    public init(memberID: String, projectID: String, role: OrganizationRole, permissions: ProjectPermissions, assignedDate: Date) {
        self.memberID = memberID
        self.projectID = projectID
        self.role = role
        self.permissions = permissions
        self.assignedDate = assignedDate
    }
}

// MARK: - Project Permissions Model
public struct ProjectPermissions: Codable, Equatable {
    public let canViewProject: Bool
    public let canEditProject: Bool
    public let canAddReceipts: Bool
    public let canAddProgress: Bool
    public let canManageLabor: Bool
    public let canViewBudget: Bool
    public let canEditBudget: Bool
    public let canCreateProjects: Bool
    public let canInviteTeamMembers: Bool
    public let canRemoveTeamMembers: Bool
    
    public init(
        canViewProject: Bool,
        canEditProject: Bool,
        canAddReceipts: Bool,
        canAddProgress: Bool,
        canManageLabor: Bool,
        canViewBudget: Bool,
        canEditBudget: Bool,
        canCreateProjects: Bool,
        canInviteTeamMembers: Bool,
        canRemoveTeamMembers: Bool
    ) {
        self.canViewProject = canViewProject
        self.canEditProject = canEditProject
        self.canAddReceipts = canAddReceipts
        self.canAddProgress = canAddProgress
        self.canManageLabor = canManageLabor
        self.canViewBudget = canViewBudget
        self.canEditBudget = canEditBudget
        self.canCreateProjects = canCreateProjects
        self.canInviteTeamMembers = canInviteTeamMembers
        self.canRemoveTeamMembers = canRemoveTeamMembers
    }
    
    public static func fullAccess() -> ProjectPermissions {
        ProjectPermissions(
            canViewProject: true,
            canEditProject: true,
            canAddReceipts: true,
            canAddProgress: true,
            canManageLabor: true,
            canViewBudget: true,
            canEditBudget: true,
            canCreateProjects: true,
            canInviteTeamMembers: true,
            canRemoveTeamMembers: true
        )
    }
    
    public static func memberAccess() -> ProjectPermissions {
        ProjectPermissions(
            canViewProject: true,
            canEditProject: true,
            canAddReceipts: true,
            canAddProgress: true,
            canManageLabor: true,
            canViewBudget: true,
            canEditBudget: false,
            canCreateProjects: false,
            canInviteTeamMembers: false,
            canRemoveTeamMembers: false
        )
    }
    
    public static func contractorAccess() -> ProjectPermissions {
        ProjectPermissions(
            canViewProject: true,
            canEditProject: false,
            canAddReceipts: true,
            canAddProgress: true,
            canManageLabor: false,
            canViewBudget: false,
            canEditBudget: false,
            canCreateProjects: false,
            canInviteTeamMembers: false,
            canRemoveTeamMembers: false
        )
    }
    
    public static func viewOnlyAccess() -> ProjectPermissions {
        ProjectPermissions(
            canViewProject: true,
            canEditProject: false,
            canAddReceipts: false,
            canAddProgress: false,
            canManageLabor: false,
            canViewBudget: true,
            canEditBudget: false,
            canCreateProjects: false,
            canInviteTeamMembers: false,
            canRemoveTeamMembers: false
        )
    }
    
    public static func projectManagerAccess() -> ProjectPermissions {
        ProjectPermissions(
            canViewProject: true,
            canEditProject: true,
            canAddReceipts: true,
            canAddProgress: true,
            canManageLabor: true,
            canViewBudget: true,
            canEditBudget: true,
            canCreateProjects: true,
            canInviteTeamMembers: true,
            canRemoveTeamMembers: false
        )
    }
}

// MARK: - Team Management Extensions
extension OrganizationRole {
    public var defaultProjectPermissions: ProjectPermissions {
        switch self {
        case .admin:
            return ProjectPermissions.fullAccess()
        case .member:
            return ProjectPermissions.memberAccess()
        case .contractor:
            return ProjectPermissions.contractorAccess()
        case .viewer:
            return ProjectPermissions.viewOnlyAccess()
        }
    }
}