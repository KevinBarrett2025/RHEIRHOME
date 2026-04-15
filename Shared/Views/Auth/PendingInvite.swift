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
        self == .sent || self == .expired
    }
}

public enum PendingInviteSource: String, Codable {
    case customScheme
    case universalLink
    case legacyStorage
}

public struct PendingInvite: Identifiable, Codable, Equatable {
    public let id: String
    public let email: String?
    public let organizationId: String?
    public let organizationName: String
    public let inviteToken: String
    public let dateSent: Date
    public var status: InviteStatus
    public let role: OrganizationRole
    public let source: PendingInviteSource

    public init(email: String, organizationId: String, organizationName: String) {
        self.id = UUID().uuidString
        self.email = email
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.inviteToken = UUID().uuidString
        self.dateSent = Date()
        self.status = .pending
        self.role = .member
        self.source = .legacyStorage
    }

    public init(
        organizationId: String?,
        organizationName: String,
        inviteToken: String,
        role: OrganizationRole = .member,
        source: PendingInviteSource,
        email: String? = nil,
        dateSent: Date = Date(),
        status: InviteStatus = .pending
    ) {
        self.id = UUID().uuidString
        self.email = email
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.inviteToken = inviteToken
        self.dateSent = dateSent
        self.status = status
        self.role = role
        self.source = source
    }

    public var shouldShowResend: Bool {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        return status.canResend && dateSent < oneMinuteAgo
    }

    public static func parse(from url: URL) -> PendingInvite? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        let host = url.host ?? ""
        let isCustomSchemeInvite = url.scheme == "rheirhome" && host == "invite"
        let isUniversalInvite = host == "app.rheirhome.com" && url.path.hasPrefix("/invite")

        guard isCustomSchemeInvite || isUniversalInvite else {
            return nil
        }

        let organizationId = queryItems.first(where: { $0.name == "orgID" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let inviteToken = queryItems.first(where: { $0.name == "token" })?.value ?? UUID().uuidString
        let organizationName = queryItems.first(where: { $0.name == "name" })?.value ?? "Organization"
        let roleString = queryItems.first(where: { $0.name == "role" })?.value
        let role = OrganizationRole(rawValue: roleString ?? OrganizationRole.member.rawValue) ?? .member

        guard let organizationId, !organizationId.isEmpty else {
            return nil
        }

        return PendingInvite(
            organizationId: organizationId,
            organizationName: organizationName,
            inviteToken: inviteToken,
            role: role,
            source: isCustomSchemeInvite ? .customScheme : .universalLink
        )
    }
}
