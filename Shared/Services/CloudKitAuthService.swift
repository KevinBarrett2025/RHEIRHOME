import Foundation
import Combine
import CloudKit
import AuthenticationServices

/// CloudKitAuthService implements AuthService using CloudKit + Sign in with Apple.
/// Its one credential‐based entry point is:
///     func signInWithApple(using credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<User, Error>
public class CloudKitAuthService: ObservableObject, AuthService {
    // MARK: - Properties
    internal let container: CKContainer  // Changed from private to internal
    internal let privateDatabase: CKDatabase  // Changed from private to internal
    internal let publicDatabase: CKDatabase   // Changed from private to internal

    // MARK: - Published Properties
    @Published public var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published public var userRecord: CKRecord?
    @Published public var isSignedIn: Bool = false
    @Published public var errorMessage: String?

    // MARK: - Initialization
    public init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        Task {
            await checkAccountStatus()
        }
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
    
    // MARK: - AuthService Protocol Implementation - Invite Method
    
    public func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        print(" [CloudKit] Inviting \(email) to organization \(orgID)")
        
        return checkCloudKitAvailability()
            .flatMap { _ -> AnyPublisher<Void, Error> in
                let privateDB = self.container.privateCloudDatabase
                
                // Create an invitation record
                let inviteRecord = CKRecord(recordType: "OrganizationInvite")
                inviteRecord["organizationID"] = orgID as CKRecordValue
                inviteRecord["inviteeEmail"] = email as CKRecordValue
                inviteRecord["status"] = "pending" as CKRecordValue
                inviteRecord["createdAt"] = Date() as CKRecordValue
                if let currentUserID = self.currentUser?.id {
                    inviteRecord["inviterUserID"] = currentUserID as CKRecordValue
                }
                
                return Future<Void, Error> { promise in
                    privateDB.save(inviteRecord) { _, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print(" [CloudKit] Failed to save invite: \(error)")
                                promise(.failure(error))
                            } else {
                                print(" [CloudKit] Invite saved successfully")
                                promise(.success(()))
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .timeout(.seconds(10), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Check CloudKit account status before attempting operations
    internal func checkCloudKitAvailability() -> AnyPublisher<Void, Error> {  // Changed to internal
        return Future<Void, Error> { promise in
            print(" [CloudKit] Checking account status...")
            self.container.accountStatus { status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print(" [CloudKit] Account status check failed: \(error)")
                        promise(.failure(error))
                        return
                    }
                    
                    switch status {
                    case .available:
                        print(" [CloudKit] Account available")
                        promise(.success(()))
                    case .noAccount:
                        print(" [CloudKit] No iCloud account found")
                        let error = NSError(domain: "CloudKitAuthService", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "No iCloud account found. Please sign in to iCloud in Settings → [Your Name] → iCloud and try again."])
                        promise(.failure(error))
                    case .couldNotDetermine:
                        print(" [CloudKit] Could not determine account status")
                        let error = NSError(domain: "CloudKitAuthService", code: -2, 
                                          userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud account status. Please check your internet connection and try again."])
                        promise(.failure(error))
                    case .restricted:
                        print(" [CloudKit] Account is restricted")
                        let error = NSError(domain: "CloudKitAuthService", code: -3, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud account is restricted. Please check your Screen Time or parental control settings."])
                        promise(.failure(error))
                    case .temporarilyUnavailable:
                        print(" [CloudKit] Account temporarily unavailable")
                        let error = NSError(domain: "CloudKitAuthService", code: -4, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud is temporarily unavailable. Please try again in a few minutes."])
                        promise(.failure(error))
                    @unknown default:
                        print(" [CloudKit] Unknown account status: \(status.rawValue)")
                        let error = NSError(domain: "CloudKitAuthService", code: -5, 
                                          userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud account status. Please try signing out and back into iCloud."])
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
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
    // NOTE: The invite(email:orgID:) method required by AuthService protocol is implemented in the Organization extension
    
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
    
    // MARK: - Private Properties
    
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
    
    // MARK: - Private Methods
    
    private func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            print(" [CloudKit] Account status: \(status)")
        } catch {
            print(" [CloudKit] Failed to check account status: \(error)")
            errorMessage = "Failed to check account status. Please try again later."
        }
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