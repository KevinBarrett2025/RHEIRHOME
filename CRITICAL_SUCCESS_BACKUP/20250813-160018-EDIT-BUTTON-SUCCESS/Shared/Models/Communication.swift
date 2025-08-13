import Foundation

public struct Communication: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var type: CommunicationType
    public var subject: String
    public var content: String
    public var participants: [String]  // Email addresses or names
    public var attachments: [String]   // File names or paths
    public var isRead: Bool
    public var priority: CommunicationPriority
    public var projectID: UUID?        // Link to specific project
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: CommunicationType,
        subject: String,
        content: String,
        participants: [String] = [],
        attachments: [String] = [],
        isRead: Bool = false,
        priority: CommunicationPriority = .normal,
        projectID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.subject = subject
        self.content = content
        self.participants = participants
        self.attachments = attachments
        self.isRead = isRead
        self.priority = priority
        self.projectID = projectID
    }
}

public enum CommunicationType: String, CaseIterable, Codable, Sendable {
    case email = "Email"
    case phone = "Phone Call"
    case meeting = "Meeting"
    case text = "Text Message"
    case note = "Internal Note"
    
    public var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .meeting: return "person.3.fill"
        case .text: return "message.fill"
        case .note: return "note.text"
        }
    }
}

public enum CommunicationPriority: String, CaseIterable, Codable, Sendable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case urgent = "Urgent"
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}