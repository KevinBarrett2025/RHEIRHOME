import Foundation
import Combine

/// Preview-only authentication service for SwiftUI previews
/// This is NOT a mock - it's specifically for SwiftUI preview environment only
public final class PreviewAuthService: AuthService {
    
    public var currentUser: User? = User(id: "preview_user", email: "preview@example.com")
    
    public init() {
        print("🎭 PreviewAuthService initialized for SwiftUI previews only")
    }
    
    public func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        let user = User(id: "preview_signup_\(email)", email: email)
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func login(email: String, password: String) -> AnyPublisher<User, Error> {
        let user = User(id: "preview_login_\(email)", email: email)
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func signInWithApple() -> AnyPublisher<User, Error> {
        let user = User(id: "preview_apple_user", email: "apple@example.com")
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func signOut() {
        currentUser = nil
    }
}