import Foundation

public struct Project: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var client: String
    public var phone: String
    public var email: String

    // Address broken out
    public var street: String
    public var city: String
    public var state: String
    public var zip: String

    public var notes: String

    public var totalBudget: Double
    public var materialCost: Double
    public var laborCost: Double
    public var generalConditions: Double
    public var contingency: Double
    public var spentContingency: Double
    public var profit: Double

    public var startDate: Date
    public var endDate: Date

    public var loggedHours: [WorkHour]
    public var tasks: [ProjectTask]
    public var communications: [Communication]
    public var progressLogs: [ProgressLog]
    public var changeOrders: [ChangeOrder]
    public var receipts: [Receipt]
    public var taskTemplates: [TaskTemplate]

    public var status: ProjectStatus

    public var organizationID: String?
    
    // MARK: - Role-Based Access Control
    /// Users with specific access to this project (contractors, external consultants)
    public var assignedUserIDs: [String] = []
    /// Project access level (public to all org members vs restricted)
    public var accessLevel: ProjectAccessLevel = .organization
    /// Project owner/manager (defaults to creator)
    public var projectManagerID: String?

    // MARK: – Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, client, phone, email
        case street, city, state, zip
        case notes
        case totalBudget, materialCost, laborCost, generalConditions, contingency, spentContingency, profit
        case startDate, endDate
        case loggedHours, tasks, communications, progressLogs, changeOrders, receipts, taskTemplates
        case status
        case organizationID
        case assignedUserIDs, accessLevel, projectManagerID
    }

    public init(
        id: UUID = UUID(),
        name: String,
        client: String,
        phone: String = "",
        email: String = "",
        street: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        notes: String = "",
        totalBudget: Double,
        materialCost: Double,
        laborCost: Double,
        generalConditions: Double,
        contingency: Double,
        spentContingency: Double = 0,
        profit: Double,
        startDate: Date,
        endDate: Date,
        loggedHours: [WorkHour] = [],
        tasks: [ProjectTask] = [],
        communications: [Communication] = [],
        progressLogs: [ProgressLog] = [],
        changeOrders: [ChangeOrder] = [],
        receipts: [Receipt] = [],
        taskTemplates: [TaskTemplate] = [],
        status: ProjectStatus = .active,
        organizationID: String? = nil,
        assignedUserIDs: [String] = [],
        accessLevel: ProjectAccessLevel = .organization,
        projectManagerID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.client = client
        self.phone = phone
        self.email = email
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.notes = notes
        self.totalBudget = totalBudget
        self.materialCost = materialCost
        self.laborCost = laborCost
        self.generalConditions = generalConditions
        self.contingency = contingency
        self.spentContingency = spentContingency
        self.profit = profit
        self.startDate = startDate
        self.endDate = endDate
        self.loggedHours = loggedHours
        self.tasks = tasks
        self.communications = communications
        self.progressLogs = progressLogs
        self.changeOrders = changeOrders
        self.receipts = receipts
        self.taskTemplates = taskTemplates
        self.status = status
        self.organizationID = organizationID
        self.assignedUserIDs = assignedUserIDs
        self.accessLevel = accessLevel
        self.projectManagerID = projectManagerID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Role-Based Access Methods
    
    /// Check if a user has access to this project based on their role and assignments
    public func userHasAccess(userID: String, userRole: OrganizationRole) -> Bool {
        // Admins always have access to all projects
        if userRole == .admin {
            return true
        }
        
        // Project manager always has access
        if projectManagerID == userID {
            return true
        }
        
        // Organization members have access to organization-level projects
        if userRole == .member && accessLevel == .organization {
            return true
        }
        
        // Contractors only have access to specifically assigned projects
        if userRole == .contractor && assignedUserIDs.contains(userID) {
            return true
        }
        
        // Viewers have read-only access to organization projects
        if userRole == .viewer && accessLevel == .organization {
            return true
        }
        
        return false
    }
    
    /// Check if user can edit this project
    public func userCanEdit(userID: String, userRole: OrganizationRole) -> Bool {
        // Admins can always edit
        if userRole == .admin {
            return true
        }
        
        // Project manager can edit
        if projectManagerID == userID {
            return true
        }
        
        // Members can edit organization projects
        if userRole == .member && accessLevel == .organization {
            return true
        }
        
        // Contractors can edit their assigned projects
        if userRole == .contractor && assignedUserIDs.contains(userID) {
            return true
        }
        
        // Viewers cannot edit
        return false
    }
    
    /// Assign a user to this project (for contractors)
    public mutating func assignUser(_ userID: String) {
        if !assignedUserIDs.contains(userID) {
            assignedUserIDs.append(userID)
        }
    }
    
    /// Remove user assignment from this project
    public mutating func removeUserAssignment(_ userID: String) {
        assignedUserIDs.removeAll { $0 == userID }
    }
    
    /// Set project manager
    public mutating func setProjectManager(_ userID: String) {
        projectManagerID = userID
    }
}

// MARK: - Project Access Level

public enum ProjectAccessLevel: String, Codable, CaseIterable, Sendable {
    case organization = "organization"  // All org members can see
    case restricted = "restricted"      // Only assigned users can see
    
    public var displayName: String {
        switch self {
        case .organization:
            return "Organization Wide"
        case .restricted:
            return "Restricted Access"
        }
    }
    
    public var description: String {
        switch self {
        case .organization:
            return "All team members can access this project"
        case .restricted:
            return "Only assigned users can access this project"
        }
    }
}