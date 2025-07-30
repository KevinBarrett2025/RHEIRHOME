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
        organizationID: String? = nil
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
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}