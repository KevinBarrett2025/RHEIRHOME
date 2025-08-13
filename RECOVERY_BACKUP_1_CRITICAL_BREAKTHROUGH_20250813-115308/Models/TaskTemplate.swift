import Foundation

public struct TaskTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: TaskCategory
    public var priority: TaskPriority
    public var estimatedDuration: Double   // In hours
    public var requiredSkills: [String]
    public var tools: [String]
    public var materials: [String]
    public var safetyRequirements: [String]
    public var instructions: [String]
    public var isActive: Bool
    public var organizationID: String
    public var createdBy: String
    public var createdAt: Date
    public var lastUsed: Date?
    public var useCount: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: TaskCategory,
        priority: TaskPriority = .medium,
        estimatedDuration: Double = 1.0,
        requiredSkills: [String] = [],
        tools: [String] = [],
        materials: [String] = [],
        safetyRequirements: [String] = [],
        instructions: [String] = [],
        isActive: Bool = true,
        organizationID: String,
        createdBy: String,
        createdAt: Date = Date(),
        lastUsed: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.requiredSkills = requiredSkills
        self.tools = tools
        self.materials = materials
        self.safetyRequirements = safetyRequirements
        self.instructions = instructions
        self.isActive = isActive
        self.organizationID = organizationID
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.useCount = useCount
    }
    
    /// Create a ProjectTask from this template
    public func createTask(projectID: UUID, dueDate: Date, assignedTo: [UUID] = []) -> ProjectTask {
        return ProjectTask(
            title: name,
            description: description,
            dueDate: dueDate,
            priority: priority,
            category: category,
            estimatedHours: estimatedDuration,
            projectID: projectID,
            assignedEmployeeIDs: assignedTo
        )
    }
    
    /// Mark this template as used
    public mutating func markAsUsed() {
        lastUsed = Date()
        useCount += 1
    }
}

// MARK: - Common Task Templates
extension TaskTemplate {
    /// Common construction task templates
    public static func commonTemplates(organizationID: String, createdBy: String) -> [TaskTemplate] {
        return [
            TaskTemplate(
                name: "Electrical Rough-In",
                description: "Install electrical wiring and outlets before drywall",
                category: .electrical,
                priority: .high,
                estimatedDuration: 8.0,
                requiredSkills: ["Electrical", "Code Knowledge"],
                tools: ["Wire strippers", "Drill", "Fish tape", "Voltage tester"],
                materials: ["Romex wire", "Outlets", "Wire nuts", "Electrical boxes"],
                safetyRequirements: ["Turn off main breaker", "Test circuits", "Proper PPE"],
                instructions: [
                    "Plan circuit layout",
                    "Install electrical boxes",
                    "Run wire between boxes",
                    "Connect outlets and switches",
                    "Test all circuits"
                ],
                organizationID: organizationID,
                createdBy: createdBy
            ),
            
            TaskTemplate(
                name: "Drywall Installation",
                description: "Install and finish drywall surfaces",
                category: .general,
                priority: .medium,
                estimatedDuration: 12.0,
                requiredSkills: ["Drywall", "Finishing"],
                tools: ["Screw gun", "Knife", "Sanding block", "T-square"],
                materials: ["Drywall sheets", "Screws", "Joint compound", "Tape"],
                safetyRequirements: ["Dust protection", "Proper lifting technique"],
                instructions: [
                    "Measure and cut drywall",
                    "Install sheets with screws",
                    "Apply joint compound and tape",
                    "Sand smooth when dry",
                    "Prime before painting"
                ],
                organizationID: organizationID,
                createdBy: createdBy
            ),
            
            TaskTemplate(
                name: "Plumbing Rough-In", 
                description: "Install water supply and drain lines",
                category: .plumbing,
                priority: .high,
                estimatedDuration: 6.0,
                requiredSkills: ["Plumbing", "Soldering"],
                tools: ["Torch", "Pipe cutter", "Reamer", "Level"],
                materials: ["Copper pipe", "Fittings", "Solder", "Flux"],
                safetyRequirements: ["Fire safety", "Proper ventilation", "Eye protection"],
                instructions: [
                    "Plan pipe routes",
                    "Cut and fit pipes",
                    "Solder joints",
                    "Test for leaks",
                    "Insulate pipes"
                ],
                organizationID: organizationID,
                createdBy: createdBy
            ),
            
            TaskTemplate(
                name: "Interior Painting",
                description: "Prepare and paint interior surfaces",
                category: .painting,
                priority: .medium,
                estimatedDuration: 16.0,
                requiredSkills: ["Painting", "Color coordination"],
                tools: ["Brushes", "Rollers", "Drop cloths", "Ladder"],
                materials: ["Primer", "Paint", "Roller covers", "Painter's tape"],
                safetyRequirements: ["Proper ventilation", "Non-slip surfaces"],
                instructions: [
                    "Prepare surfaces",
                    "Apply primer if needed",
                    "Cut in edges with brush",
                    "Roll main areas",
                    "Apply second coat if needed"
                ],
                organizationID: organizationID,
                createdBy: createdBy
            ),
            
            TaskTemplate(
                name: "Flooring Installation",
                description: "Install hardwood, laminate, or tile flooring",
                category: .flooring,
                priority: .medium,
                estimatedDuration: 10.0,
                requiredSkills: ["Flooring", "Precision cutting"],
                tools: ["Saw", "Spacers", "Hammer", "Level"],
                materials: ["Flooring material", "Underlayment", "Transition strips", "Molding"],
                safetyRequirements: ["Knee protection", "Eye protection", "Dust control"],
                instructions: [
                    "Prepare subfloor",
                    "Install underlayment",
                    "Layout first row",
                    "Install flooring systematically",
                    "Install trim and transitions"
                ],
                organizationID: organizationID,
                createdBy: createdBy
            )
        ]
    }
}