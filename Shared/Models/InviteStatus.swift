import Foundation

public enum InviteStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case sent = "sent"
    case accepted = "accepted"
    case expired = "expired"
    case declined = "declined"
    
    public var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .sent:
            return "Invite Sent"
        case .accepted:
            return "Accepted"
        case .expired:
            return "Expired"
        case .declined:
            return "Declined"
        }
    }
    
    public var canResend: Bool {
        return self == .sent || self == .expired
    }
}

public struct PendingInvite: Identifiable, Codable {
    public let id: String
    public let email: String
    public let organizationId: String
    public let organizationName: String
    public let inviteToken: String
    public let dateSent: Date
    public var status: InviteStatus
    
    public init(email: String, organizationId: String, organizationName: String) {
        self.id = UUID().uuidString
        self.email = email
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.inviteToken = UUID().uuidString
        self.dateSent = Date()
        self.status = .pending
    }
    
    public var shouldShowResend: Bool {
        let oneMinuteAgo = Date().addingTimeInterval(-60) // 1 minute ago
        return status.canResend && dateSent < oneMinuteAgo
    }
}