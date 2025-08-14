import Foundation

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