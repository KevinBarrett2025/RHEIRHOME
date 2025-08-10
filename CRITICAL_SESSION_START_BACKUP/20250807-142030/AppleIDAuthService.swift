import Foundation
import Combine
import AuthenticationServices
import UIKit

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
            print("🔄 AppleIDAuthService - restored user from storage: \(storedUserID)")
        }
        
        print("🔧 AppleIDAuthService initialized")
    }

    /// Launch the Sign In with Apple flow and return a publisher that emits exactly one `User`.
    public func signInWithApple() -> AnyPublisher<User, Error> {
        print("🔔 AppleIDAuthService.signInWithApple() called")

        // Tear down any in-flight
        continuation?.send(completion: .finished)
        continuation = nil

        let subject = PassthroughSubject<User, Error>()
        continuation = subject

        // Build request
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        print("   • requestedScopes = \(String(describing: request.requestedScopes))")

        // Perform it
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        print("   • performing ASAuthorizationController.performRequests()…")
        controller.performRequests()

        return subject
            .handleEvents(
                receiveSubscription: { _ in print("   ↪️ Combine: subscriber attached") },
                receiveCancel:    { print("   ↩️ Combine: subscription cancelled") }
            )
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Email Management
    
    private func storeEmail(_ email: String, for userID: String) {
        UserDefaults.standard.set(email, forKey: "apple_user_email_\(userID)")
        print("🔐 AppleIDAuthService - Email stored for user: \(userID)")
    }
    
    private func getStoredEmail(for userID: String) -> String {
        if let storedEmail = UserDefaults.standard.string(forKey: "apple_user_email_\(userID)"), !storedEmail.isEmpty {
            return storedEmail
        }
        
        print("⚠️ AppleIDAuthService - No stored email found for user: \(userID)")
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
        print("🔒 AppleIDAuthService.signOut() called")
        
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
        print("✅ ASAuthorizationControllerDelegate.didCompleteWithAuthorization")
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
            print("✅ First-time Apple Sign-In - email stored")
        } else {
            // Subsequent sign in - Apple doesn't provide email
            email = getStoredEmail(for: userID)
            print("🔄 Subsequent Apple Sign-In - email retrieved from storage")
        }
        
        let user = User(id: userID, email: email)
        currentUser = user
        
        print("   • Credential.user = \(userID)")
        print("   • Using email = \(email)")

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
        print("❌ ASAuthorizationControllerDelegate.didCompleteWithError: \(error.localizedDescription)")
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