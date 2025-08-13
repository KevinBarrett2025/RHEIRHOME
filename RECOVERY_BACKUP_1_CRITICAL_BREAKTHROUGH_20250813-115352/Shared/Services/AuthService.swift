import Foundation
import Combine

public protocol AuthService {
    /// The currently signed-in user, or `nil`.
    var currentUser: User? { get }

    func signUp(email: String, password: String) -> AnyPublisher<User, Error>
    func login(email: String, password: String) -> AnyPublisher<User, Error>
    func signInWithApple() -> AnyPublisher<User, Error>
    func invite(email: String, orgID: String) -> AnyPublisher<Void, Error>
    func signOut()
}

public extension AuthService {
    // default stub for Apple Sign In
    func signInWithApple() -> AnyPublisher<User, Error> {
        Fail(error: NSError(
            domain: "AuthService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not supported"]
        ))
        .eraseToAnyPublisher()
    }
}
