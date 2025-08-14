// Shared/Services/RemoteAuthService.swift

import Foundation
import Combine

#if canImport(os)
import os.log
#endif

/// A real email/password backend conforming to `AuthService`.
/// Note: We’ve added a no‐op `signInWithApple()` stub so that this class
/// fully satisfies the `AuthService` protocol.
public final class RemoteAuthService: AuthService {
    public private(set) var currentUser: User? = nil
    private let baseURL: URL

    public init(baseURL: URL = URL(string: "https://api.yourserver.com")!) {
        self.baseURL = baseURL
    }

    // MARK: — Email/Password Signup
    public func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        // — your real signup endpoint goes here —
        let url = baseURL.appendingPathComponent("/signup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        req.httpBody = try? JSONEncoder().encode(body)

        return URLSession.shared
            .dataTaskPublisher(for: req)
            .tryMap { data, resp in
                guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                    throw NSError(domain: "RemoteAuthService", code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "Signup failed"])
                }
                return try JSONDecoder().decode(User.self, from: data)
            }
            .handleEvents(receiveOutput: { [weak self] u in self?.currentUser = u })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: — Email/Password Login
    public func login(email: String, password: String) -> AnyPublisher<User, Error> {
        let url = baseURL.appendingPathComponent("/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        req.httpBody = try? JSONEncoder().encode(body)

        return URLSession.shared
            .dataTaskPublisher(for: req)
            .tryMap { data, resp in
                guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                    throw NSError(domain: "RemoteAuthService", code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "Login failed"])
                }
                return try JSONDecoder().decode(User.self, from: data)
            }
            .handleEvents(receiveOutput: { [weak self] u in self?.currentUser = u })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: — Sign in with Apple (Stub)
    public func signInWithApple() -> AnyPublisher<User, Error> {
        // If you eventually support Apple Sign-In on your backend, replace this stub.
        return Fail(error: NSError(
            domain: "RemoteAuthService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple not implemented on RemoteAuthService"]
        ))
        .eraseToAnyPublisher()
    }

    // MARK: — Invite a user by email into an existing org
    public func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        #if DEBUG_STUB_REMOTE_AUTH
        // stubbed for faster local dev
        return Just(())
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        #else
        let url = baseURL.appendingPathComponent("/orgs/\(orgID)/invite")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email]
        req.httpBody = try? JSONEncoder().encode(body)

        return URLSession.shared
            .dataTaskPublisher(for: req)
            .map { _ in () }
            .mapError { $0 as Error }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        #endif
    }

    // MARK: — Sign Out
    public func signOut() {
        currentUser = nil
        // clear any tokens/keychain here if you have them
    }
}
