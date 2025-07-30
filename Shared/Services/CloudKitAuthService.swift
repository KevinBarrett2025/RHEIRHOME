import Foundation
import Combine
import CloudKit
import AuthenticationServices

/// CloudKitAuthService implements AuthService using CloudKit + Sign in with Apple.
/// Its one credential‐based entry point is:
///     func signInWithApple(using credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<User, Error>
public final class CloudKitAuthService: AuthService {
    // MARK: - Properties
    
    internal let container: CKContainer
    
    private var _currentUser: User?
    
    /// Organization ID for the current organization (default for RHEIR LLC)
    public let organizationID: String = "RHEIR-LLC-MAIN-ORG"
    
    public var currentUser: User? {
        // If we have a cached user, return it
        if let user = _currentUser {
            return user
        }
        
        // Try to restore from persistent storage
        if let storedUserID = UserDefaults.standard.string(forKey: "apple_user_id") {
            let storedEmail = getStoredEmail(for: storedUserID)
            let user = User(id: storedUserID, email: storedEmail)
            _currentUser = user
            print("🔄 [CloudKit] Restored user from storage: \(storedUserID), email: \(storedEmail)")
            return user
        }
        
        return nil
    }

    // MARK: - Init
    public init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV2") {
        // Initialize CloudKit container for extension methods
        self.container = CKContainer(identifier: containerIdentifier)
        
        print("🔧 [CloudKit] Initialized CloudKitAuthService")
        print("🔧 [CloudKit] Container: \(containerIdentifier)")
    }

    // MARK: - AuthService Protocol Implementation
    
    public func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        return Fail(error: CloudKitAuthError.emailPasswordNotSupported)
            .eraseToAnyPublisher()
    }

    public func login(email: String, password: String) -> AnyPublisher<User, Error> {
        return Fail(error: CloudKitAuthError.emailPasswordNotSupported)
            .eraseToAnyPublisher()
    }

    public func signInWithApple() -> AnyPublisher<User, Error> {
        return Fail(error: CloudKitAuthError.useCredentialBasedSignIn)
            .eraseToAnyPublisher()
    }

    public func signOut() {
        if let userID = _currentUser?.id {
            // Clear email from UserDefaults
            UserDefaults.standard.removeObject(forKey: "apple_user_email_\(userID)")
        }
        
        _currentUser = nil
        // Clear any stored JWT tokens and user ID
        UserDefaults.standard.removeObject(forKey: "rheir_jwt_token")
        UserDefaults.standard.removeObject(forKey: "apple_user_id")
        
        print("🔒 [CloudKit] User signed out and data cleared")
    }

    // MARK: - Extended Methods (Apple Sign-In)

    public func signInWithApple(
        with credential: ASAuthorizationAppleIDCredential
    ) -> AnyPublisher<User, Error> {
        let userID = credential.user
        
        // Get email from credential or retrieve from storage
        let email: String
        if let credentialEmail = credential.email, !credentialEmail.isEmpty {
            // First time sign in - Apple provided email
            email = credentialEmail
            storeEmail(email, for: userID)
            print("✅ [CloudKit] First-time Apple Sign-In - email stored")
        } else {
            // Subsequent sign in - Apple doesn't provide email
            email = getStoredEmail(for: userID)
            print("🔄 [CloudKit] Subsequent Apple Sign-In - email retrieved from storage")
        }
        
        let user = User(id: userID, email: email)
        _currentUser = user
        
        // Store user ID for persistence
        UserDefaults.standard.set(userID, forKey: "apple_user_id")
        
        print("✅ [CloudKit] Apple Sign-In successful")
        print("   • User ID: \(userID)")
        print("   • Email: \(email)")
        
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    public func signInWithApple(
        userID: String,
        email: String? = nil
    ) -> AnyPublisher<User, Error> {
        let finalEmail = email ?? getStoredEmail(for: userID)
        let user = User(id: userID, email: finalEmail)
        _currentUser = user
        
        // Store user ID for persistence
        UserDefaults.standard.set(userID, forKey: "apple_user_id")
        
        print("✅ [CloudKit] Silent Apple Sign-In successful for user: \(userID)")
        print("   • Email: \(finalEmail)")
        
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Email Management
    
    private func storeEmail(_ email: String, for userID: String) {
        UserDefaults.standard.set(email, forKey: "apple_user_email_\(userID)")
        print("🔐 [CloudKit] Email stored for user: \(userID)")
    }
    
    private func getStoredEmail(for userID: String) -> String {
        if let storedEmail = UserDefaults.standard.string(forKey: "apple_user_email_\(userID)"), !storedEmail.isEmpty {
            return storedEmail
        }
        
        print("⚠️ [CloudKit] No stored email found for user: \(userID)")
        return "user.email.not.available@rheir.com"
    }
    
    // NOTE: createOrganization, fetchOrganizations, and invite methods are defined in CloudKitAuthService+Organization.swift extension
    // NOTE: upsertUserRecord method is defined in CloudKitAuthService+User.swift extension
    
    // MARK: - JWT Access (placeholder for backward compatibility)
    
    public var storedJWT: String? {
        return UserDefaults.standard.string(forKey: "rheir_jwt_token")
    }
    
    public func refreshJWTIfNeeded() -> AnyPublisher<String?, Error> {
        // TODO: Implement JWT refresh logic
        return Just(storedJWT)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - CloudKit Auth Errors
enum CloudKitAuthError: LocalizedError {
    case emailPasswordNotSupported
    case useCredentialBasedSignIn
    
    var errorDescription: String? {
        switch self {
        case .emailPasswordNotSupported:
            return "Email/Password authentication is not supported. Use Sign in with Apple."
        case .useCredentialBasedSignIn:
            return "Use signInWithApple(with:) method instead."
        }
    }
}