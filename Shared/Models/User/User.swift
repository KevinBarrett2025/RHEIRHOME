import Foundation

public struct User: Identifiable, Codable, Equatable {
    public let id: String    // The Apple “userID”
    public let email: String // The user’s email (may be empty on subsequent logins)

    public init(id: String, email: String) {
        self.id = id
        self.email = email
    }
}
