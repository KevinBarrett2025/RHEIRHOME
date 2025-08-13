import Foundation

public enum ProjectStatus: String, CaseIterable, Codable, Sendable {
    case active = "Active"
    case completed = "Completed"
    case onHold = "On Hold"
    case cancelled = "Cancelled"
    case planning = "Planning"
    
    public var displayName: String {
        return rawValue
    }
    
    public var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .planning: return "doc.text.fill"
        }
    }
    
    public var color: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .onHold: return "orange"
        case .cancelled: return "red"
        case .planning: return "gray"
        }
    }
}