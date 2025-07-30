import Foundation

public struct ProgressLog: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var workDescription: String
    public var notes: String
    public var employeeIDs: [UUID]
    public var category: String
    public var photoIDs: [UUID]                 // Links to ProgressPhoto records
    public var hasPhotos: Bool { !photoIDs.isEmpty }
    // Link back to original task (if created from task completion)
    public var taskID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        workDescription: String,
        notes: String = "",
        employeeIDs: [UUID] = [],
        category: String = "general",
        taskID: UUID? = nil,
        photoIDs: [UUID] = []
    ) {
        self.id = id
        self.date = date
        self.workDescription = workDescription
        self.notes = notes
        self.employeeIDs = employeeIDs
        self.category = category
        self.taskID = taskID
        self.photoIDs = photoIDs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ProgressLog, rhs: ProgressLog) -> Bool {
        lhs.id == rhs.id
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
}