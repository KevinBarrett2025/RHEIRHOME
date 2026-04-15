import Foundation
import Combine
import CloudKit
import AuthenticationServices
import OSLog

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
        
        Logger.auth.notice("Signed out current CloudKit user and cleared local auth state.")
    }
    
    // MARK: - AuthService Protocol Implementation - Invite Method
    
    public func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        Logger.auth.notice(
            "Creating basic organization invite [org=\(orgID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash))]"
        )
        
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
                                Logger.auth.error(
                                    "Failed to save basic organization invite [org=\(orgID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash)), error=\(error.localizedDescription, privacy: .public)]"
                                )
                                promise(.failure(error))
                            } else {
                                Logger.auth.notice(
                                    "Saved basic organization invite [org=\(orgID, privacy: .private(mask: .hash)), invitee=\(email, privacy: .private(mask: .hash))]"
                                )
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
            Logger.auth.info("Checking CloudKit account status before performing auth work.")
            self.container.accountStatus { status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.auth.error(
                            "CloudKit account status check failed [error=\(error.localizedDescription, privacy: .public)]"
                        )
                        promise(.failure(error))
                        return
                    }
                    
                    switch status {
                    case .available:
                        Logger.auth.info("CloudKit account is available.")
                        promise(.success(()))
                    case .noAccount:
                        Logger.auth.warning("No iCloud account is available for CloudKit auth.")
                        let error = NSError(domain: "CloudKitAuthService", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "No iCloud account found. Please sign in to iCloud in Settings → [Your Name] → iCloud and try again."])
                        promise(.failure(error))
                    case .couldNotDetermine:
                        Logger.auth.warning("Could not determine CloudKit account status.")
                        let error = NSError(domain: "CloudKitAuthService", code: -2, 
                                          userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud account status. Please check your internet connection and try again."])
                        promise(.failure(error))
                    case .restricted:
                        Logger.auth.warning("CloudKit account is restricted.")
                        let error = NSError(domain: "CloudKitAuthService", code: -3, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud account is restricted. Please check your Screen Time or parental control settings."])
                        promise(.failure(error))
                    case .temporarilyUnavailable:
                        Logger.auth.warning("CloudKit account is temporarily unavailable.")
                        let error = NSError(domain: "CloudKitAuthService", code: -4, 
                                          userInfo: [NSLocalizedDescriptionKey: "iCloud is temporarily unavailable. Please try again in a few minutes."])
                        promise(.failure(error))
                    @unknown default:
                        Logger.auth.error(
                            "Encountered unknown CloudKit account status [raw=\(status.rawValue, privacy: .public)]"
                        )
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
        
        Logger.auth.info(
            "Processing credential-based Apple Sign-In [user=\(userID, privacy: .private(mask: .hash)), idLength=\(userID.count, privacy: .public), hasEmail=\(credential.email != nil, privacy: .public)]"
        )
        
        // Check for stored previous userIDs (handle Apple ID changes)
        let previousUserIDs = getAllStoredUserIDs()
        Logger.auth.debug(
            "Loaded stored Apple user identifier history [count=\(previousUserIDs.count, privacy: .public)]"
        )
        
        // Get email from credential or retrieve from storage
        let email: String
        if let credentialEmail = credential.email, !credentialEmail.isEmpty {
            // First time sign in - Apple provided email
            email = credentialEmail
            storeEmail(email, for: userID)
            Logger.auth.notice(
                "Stored Apple Sign-In email from credential [user=\(userID, privacy: .private(mask: .hash))]"
            )
        } else {
            // Subsequent sign in - Apple doesn't provide email
            email = getStoredEmail(for: userID)
            let hasStoredEmail = email != "user.email.not.available@rheir.com"
            Logger.auth.info(
                "Resolved Apple Sign-In email from local storage [user=\(userID, privacy: .private(mask: .hash)), hasStoredEmail=\(hasStoredEmail, privacy: .public)]"
            )
            
            // If no email found for this userID, try to find it from previous sessions
            if email == "user.email.not.available@rheir.com" {
                if let recoveredEmail = findEmailFromPreviousUserIDs(previousUserIDs) {
                    storeEmail(recoveredEmail, for: userID) // Store for this new userID
                    Logger.auth.notice(
                        "Recovered Apple Sign-In email from prior user identifier history [user=\(userID, privacy: .private(mask: .hash))]"
                    )
                }
            }
        }
        
        let user = User(id: userID, email: email)
        _currentUser = user
        
        // Store user ID for persistence and track multiple userIDs
        UserDefaults.standard.set(userID, forKey: "apple_user_id")
        addToUserIDHistory(userID)
        
        let hasEmail = email != "user.email.not.available@rheir.com"
        Logger.auth.notice(
            "Completed Apple Sign-In [user=\(userID, privacy: .private(mask: .hash)), hasEmail=\(hasEmail, privacy: .public)]"
        )
        
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
        
        let hasEmail = finalEmail != "user.email.not.available@rheir.com"
        Logger.auth.notice(
            "Completed silent Apple Sign-In [user=\(userID, privacy: .private(mask: .hash)), hasEmail=\(hasEmail, privacy: .public)]"
        )
        
        return Just(user)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Email Management
    
    private func storeEmail(_ email: String, for userID: String) {
        UserDefaults.standard.set(email, forKey: "apple_user_email_\(userID)")
        Logger.auth.debug(
            "Stored Apple Sign-In email locally [user=\(userID, privacy: .private(mask: .hash))]"
        )
    }
    
    private func getStoredEmail(for userID: String) -> String {
        if let storedEmail = UserDefaults.standard.string(forKey: "apple_user_email_\(userID)"), !storedEmail.isEmpty {
            return storedEmail
        }
        
        Logger.auth.warning(
            "No stored Apple Sign-In email found [user=\(userID, privacy: .private(mask: .hash))]"
        )
        return "user.email.not.available@rheir.com"
    }
    
    // MARK: - Enhanced Email & UserID Management
    
    /// Get all previously stored userIDs for this device
    internal func getAllStoredUserIDs() -> [String] { // Changed from private to internal
        return UserDefaults.standard.stringArray(forKey: "apple_user_id_history") ?? []
    }
    
    /// Add userID to history for tracking changes
    private func addToUserIDHistory(_ userID: String) {
        var history = getAllStoredUserIDs()
        if !history.contains(userID) {
            history.append(userID)
            // Keep only last 5 userIDs
            if history.count > 5 {
                history = Array(history.suffix(5))
            }
            UserDefaults.standard.set(history, forKey: "apple_user_id_history")
            Logger.auth.debug(
                "Added Apple user identifier to local history [user=\(userID, privacy: .private(mask: .hash)), count=\(history.count, privacy: .public)]"
            )
        }
    }
    
    /// Try to find email from previous userID sessions
    private func findEmailFromPreviousUserIDs(_ userIDs: [String]) -> String? {
        for previousUserID in userIDs {
            let email = UserDefaults.standard.string(forKey: "apple_user_email_\(previousUserID)")
            if let email = email, !email.isEmpty, email != "user.email.not.available@rheir.com" {
                Logger.auth.debug(
                    "Recovered Apple Sign-In email from prior user identifier [user=\(previousUserID, privacy: .private(mask: .hash))]"
                )
                return email
            }
        }
        return nil
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
            let hasEmail = storedEmail != "user.email.not.available@rheir.com"
            Logger.auth.notice(
                "Restored CloudKit user from local storage [user=\(storedUserID, privacy: .private(mask: .hash)), hasEmail=\(hasEmail, privacy: .public)]"
            )
            return user
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            Logger.auth.info(
                "Loaded CloudKit account status [raw=\(status.rawValue, privacy: .public)]"
            )
        } catch {
            Logger.auth.error(
                "Failed to load CloudKit account status [error=\(error.localizedDescription, privacy: .public)]"
            )
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
