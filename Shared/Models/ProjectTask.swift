import Foundation

public struct ProjectTask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var dueDate: Date?
    public var isCompleted: Bool
    public var completedDate: Date?
    public var priority: TaskPriority
    public var category: TaskCategory
    
    public var estimatedHours: Double
    public var actualHours: Double
    public var projectID: UUID
    
    // Visual documentation - migrated to photo system
    public var photoIDs: [UUID]
    
    // Completion tracking
    public var assignedEmployeeIDs: [UUID]
    public var completedByEmployeeIDs: [UUID]
    public var completionNotes: String
    
    // Timestamps
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = .init(),
        title: String,
        description: String = "",
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory = .general,
        estimatedHours: Double = 1.0,
        actualHours: Double = 0.0,
        projectID: UUID,
        photoIDs: [UUID] = [],
        assignedEmployeeIDs: [UUID] = [],
        completedByEmployeeIDs: [UUID] = [],
        completionNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.priority = priority
        self.category = category
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.projectID = projectID
        self.photoIDs = photoIDs
        self.assignedEmployeeIDs = assignedEmployeeIDs
        self.completedByEmployeeIDs = completedByEmployeeIDs
        self.completionNotes = completionNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Backward Compatibility
    
    /// Legacy property for backward compatibility during migration
    @available(*, deprecated, message: "Use photoIDs instead")
    public var imageDatas: [Data] {
        get { [] } // Return empty array for legacy access
        set { 
            // Convert legacy imageDatas to photoIDs if needed during migration
            // This is handled by migration service
        }
    }
    
    public var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    public mutating func markCompleted(by employeeIDs: [UUID], notes: String) {
        isCompleted = true
        completedDate = Date()
        completedByEmployeeIDs = employeeIDs
        completionNotes = notes
        updatedAt = Date()
    }
    
    // MARK: - Photo Management
    
    public mutating func addPhoto(_ photoID: UUID) {
        if !photoIDs.contains(photoID) {
            photoIDs.append(photoID)
            updatedAt = Date() 
        }
    }
    
    public mutating func removePhoto(_ photoID: UUID) {
        photoIDs.removeAll { $0 == photoID }
        updatedAt = Date()
    }
    
    public var hasPhotos: Bool {
        !photoIDs.isEmpty
    }
    
    public var photoCount: Int {
        photoIDs.count
    }
}

// MARK: - Task Priority and Category

public enum TaskPriority: String, CaseIterable, Codable, Sendable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    case urgent = "urgent"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

public enum TaskCategory: String, CaseIterable, Codable, Sendable {
    case general = "general"
    case plumbing = "plumbing"
    case electrical = "electrical"
    case hvac = "hvac"
    case flooring = "flooring"
    case painting = "painting"
    case roofing = "roofing"
    case landscaping = "landscaping"
    case cleanup = "cleanup"
    case inspection = "inspection"
    case permits = "permits"
    case materials = "materials"
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .plumbing: return "Plumbing"
        case .electrical: return "Electrical"
        case .hvac: return "HVAC"
        case .flooring: return "Flooring"
        case .painting: return "Painting"
        case .roofing: return "Roofing"
        case .landscaping: return "Landscaping"
        case .cleanup: return "Cleanup"
        case .inspection: return "Inspection"
        case .permits: return "Permits"
        case .materials: return "Materials"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "hammer.fill"
        case .plumbing: return "drop.fill"
        case .electrical: return "bolt.fill"
        case .hvac: return "air.conditioner.horizontal.fill"
        case .flooring: return "square.grid.3x3.fill"
        case .painting: return "paintbrush.fill"
        case .roofing: return "house.fill"
        case .landscaping: return "leaf.fill"
        case .cleanup: return "trash.fill"
        case .inspection: return "magnifyingglass"
        case .permits: return "doc.text.fill"
        case .materials: return "shippingbox.fill"
        }
    }
}