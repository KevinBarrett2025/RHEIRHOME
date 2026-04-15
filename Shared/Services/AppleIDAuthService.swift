import Foundation
import Combine
import AuthenticationServices
import UIKit
import OSLog

/// AppleIDAuthService's job is to present the Sign in with Apple UI,
/// then publish a `User(id: String, email: String)` once the user completes.
/// If the user cancels or an error occurs, it publishes a failure.
public final class AppleIDAuthService: NSObject {
    private var continuation: PassthroughSubject<User, Error>? = nil

    /// Cached last-known user.
    public private(set) var currentUser: User? = nil

    public override init() {
        super.init()
        
        // Try to restore user from persistent storage
        if let storedUserID = UserDefaults.standard.string(forKey: "appleUserID") {
            let storedEmail = getStoredEmail(for: storedUserID)
            currentUser = User(id: storedUserID, email: storedEmail)
            Logger.auth.info(
                "Restored Apple ID auth user from storage [user=\(storedUserID, privacy: .private(mask: .hash))]"
            )
        }
        
        Logger.auth.info("AppleIDAuthService initialized.")
    }

    /// Launch the Sign In with Apple flow and return a publisher that emits exactly one `User`.
    public func signInWithApple() -> AnyPublisher<User, Error> {
        Logger.auth.notice("AppleIDAuthService sign-in flow started.")

        // Tear down any in-flight
        continuation?.send(completion: .finished)
        continuation = nil

        let subject = PassthroughSubject<User, Error>()
        continuation = subject

        // Build request
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        Logger.auth.debug(
            "Configured Apple ID requested scopes: \(String(describing: request.requestedScopes), privacy: .public)"
        )

        // Perform it
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        Logger.auth.info("Performing ASAuthorizationController request.")
        controller.performRequests()

        return subject
            .handleEvents(
                receiveSubscription: { _ in
                    Logger.auth.debug("Apple ID auth publisher subscriber attached.")
                },
                receiveCancel: {
                    Logger.auth.debug("Apple ID auth publisher subscription cancelled.")
                }
            )
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Email Management
    
    private func storeEmail(_ email: String, for userID: String) {
        UserDefaults.standard.set(email, forKey: "apple_user_email_\(userID)")
        Logger.auth.info(
            "Stored Apple ID email for user [user=\(userID, privacy: .private(mask: .hash))]"
        )
    }
    
    private func getStoredEmail(for userID: String) -> String {
        if let storedEmail = UserDefaults.standard.string(forKey: "apple_user_email_\(userID)"), !storedEmail.isEmpty {
            return storedEmail
        }
        
        Logger.auth.warning(
            "No stored Apple ID email found for user [user=\(userID, privacy: .private(mask: .hash))]"
        )
        return "user.email.not.available@rheir.com"
    }

    // MARK: – Stub implementations

    public func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: NSError(domain: "AppleIDAuthService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Email/Password signup not implemented."]))
            .eraseToAnyPublisher()
    }

    public func login(email: String, password: String) -> AnyPublisher<User, Error> {
        Fail(error: NSError(domain: "AppleIDAuthService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Email/Password login not implemented."]))
            .eraseToAnyPublisher()
    }

    public func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        Fail(error: NSError(domain: "AppleIDAuthService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invite not implemented in AppleIDAuthService."]))
            .eraseToAnyPublisher()
    }

    public func signOut() {
        Logger.auth.notice("AppleIDAuthService sign-out requested.")
        
        if let userID = currentUser?.id {
            // Clear email from UserDefaults
            UserDefaults.standard.removeObject(forKey: "apple_user_email_\(userID)")
        }
        
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "appleUserID")
    }
}

// MARK: – ASAuthorizationControllerDelegate

extension AppleIDAuthService: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization auth: ASAuthorization
    ) {
        Logger.auth.notice("Apple ID authorization completed successfully.")
        guard let creds = auth.credential as? ASAuthorizationAppleIDCredential else {
            let err = NSError(domain: "AppleIDAuthService",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Unexpected credential type."])
            continuation?.send(completion: .failure(err))
            continuation = nil
            return
        }

        let userID = creds.user
        
        // Handle email properly
        let email: String
        if let credentialEmail = creds.email, !credentialEmail.isEmpty {
            // First time sign in - Apple provided email
            email = credentialEmail
            storeEmail(email, for: userID)
            Logger.auth.info("Stored first-time Apple ID email from authorization callback.")
        } else {
            // Subsequent sign in - Apple doesn't provide email
            email = getStoredEmail(for: userID)
            Logger.auth.info(
                "Recovered Apple ID email from local storage for returning user [user=\(userID, privacy: .private(mask: .hash))]"
            )
        }
        
        let user = User(id: userID, email: email)
        currentUser = user
        
        Logger.auth.info(
            "Completed Apple ID auth for user [user=\(userID, privacy: .private(mask: .hash)), emailAvailable=\(!email.isEmpty, privacy: .public)]"
        )

        // Persist for silent login
        UserDefaults.standard.set(userID, forKey: "appleUserID")

        continuation?.send(user)
        continuation?.send(completion: .finished)
        continuation = nil
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Logger.auth.error("Apple ID authorization failed: \(error.localizedDescription, privacy: .public)")
        continuation?.send(completion: .failure(error))
        continuation = nil
    }
}

// MARK: – Presentation Context

extension AppleIDAuthService: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            fatalError("🍎 AppleIDAuthService: no valid window for Apple sign-in sheet.")
        }
        return window
    }
}
