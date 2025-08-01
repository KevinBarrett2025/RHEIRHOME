import Foundation

public struct ProgressLog: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var workDescription: String
    public var notes: String
    public var employeeIDs: [UUID]
    public var category: String
    public var photoIDs: [UUID]                 // CloudKit ProgressPhoto references
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
    
    // MARK: - Photo Management
    
    public mutating func addPhoto(_ photoID: UUID) {
        if !photoIDs.contains(photoID) {
            photoIDs.append(photoID)
        }
    }
    
    public mutating func removePhoto(_ photoID: UUID) {
        photoIDs.removeAll { $0 == photoID }
    }
    
    public var photoCount: Int {
        photoIDs.count
    }
}