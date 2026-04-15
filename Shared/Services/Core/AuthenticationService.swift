import Foundation
import Combine
import CloudKit
import AuthenticationServices
import OSLog

/// Core authentication service responsible for Apple Sign-In and session management
protocol AuthenticationServiceProtocol {
    var currentUser: User? { get }
    func signInWithApple(using credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<User, Error>
    func signInSilently(userID: String, email: String?) -> AnyPublisher<User, Error>
    func signOut()
    func checkAuthenticationStatus() -> AnyPublisher<Bool, Never>
}

final class AuthenticationService: AuthenticationServiceProtocol {
    // MARK: - Dependencies
    private let cloudKitService: CloudKitServiceProtocol
    private let userService: UserServiceProtocol
    private let jwtService: JWTServiceProtocol
    
    // MARK: - State
    @Published private(set) var currentUser: User?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        cloudKitService: CloudKitServiceProtocol,
        userService: UserServiceProtocol,
        jwtService: JWTServiceProtocol
    ) {
        self.cloudKitService = cloudKitService
        self.userService = userService
        self.jwtService = jwtService
        
        // Initialize with persisted user if available
        initializePersistedUser()
    }
    
    // MARK: - Public Methods
    
    func signInWithApple(using credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<User, Error> {
        Logger.auth.info(
            "Starting Apple Sign-In in AuthenticationService [user=\(credential.user, privacy: .private(mask: .hash))]"
        )
        
        return cloudKitService.checkAccountStatus()
            .flatMap { [weak self] _ -> AnyPublisher<User, Error> in
                guard let self = self else {
                    return Fail(error: AuthenticationError.serviceUnavailable).eraseToAnyPublisher()
                }
                
                let appleUser = User(
                    id: credential.user,
                    email: credential.email ?? ""
                )
                
                // Store Apple ID for persistence
                self.storeAppleUserID(credential.user)
                
                return self.userService.upsertUser(appleUser)
                    .flatMap { user -> AnyPublisher<User, Error> in
                        // Create JWT after successful user creation/fetch
                        return self.jwtService.createAppSpecificJWT(for: user)
                            .map { jwt in
                                self.jwtService.storeJWT(jwt)
                                Logger.auth.notice(
                                    "Completed Apple Sign-In in AuthenticationService and stored JWT [user=\(user.id, privacy: .private(mask: .hash))]"
                                )
                                return user
                            }
                            .eraseToAnyPublisher()
                    }
                    .handleEvents(receiveOutput: { [weak self] user in
                        self?.currentUser = user
                    })
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func signInSilently(userID: String, email: String?) -> AnyPublisher<User, Error> {
        Logger.auth.info(
            "Starting silent AuthenticationService sign-in [user=\(userID, privacy: .private(mask: .hash)), hasEmail=\(email != nil, privacy: .public)]"
        )
        
        return cloudKitService.checkAccountStatus()
            .flatMap { [weak self] _ -> AnyPublisher<User, Error> in
                guard let self = self else {
                    return Fail(error: AuthenticationError.serviceUnavailable).eraseToAnyPublisher()
                }
                
                let appleUser = User(id: userID, email: email ?? "")
                
                return self.userService.upsertUser(appleUser)
                    .flatMap { user -> AnyPublisher<User, Error> in
                        // Check if we need to refresh JWT
                        if !self.jwtService.hasValidJWT() {
                            Logger.auth.info(
                                "Refreshing missing JWT during silent AuthenticationService sign-in [user=\(user.id, privacy: .private(mask: .hash))]"
                            )
                            return self.jwtService.createAppSpecificJWT(for: user)
                                .map { jwt in
                                    self.jwtService.storeJWT(jwt)
                                    return user
                                }
                                .eraseToAnyPublisher()
                        } else {
                            Logger.auth.debug(
                                "Reusing existing valid JWT during silent AuthenticationService sign-in [user=\(user.id, privacy: .private(mask: .hash))]"
                            )
                            return Just(user)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        }
                    }
                    .handleEvents(receiveOutput: { [weak self] user in
                        self?.currentUser = user
                    })
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func signOut() {
        if let currentUser {
            Logger.auth.notice(
                "Signing out AuthenticationService user [user=\(currentUser.id, privacy: .private(mask: .hash))]"
            )
        } else {
            Logger.auth.notice("Signing out AuthenticationService with no current user.")
        }
        currentUser = nil
        clearStoredAppleUserID()
        jwtService.clearJWT()
    }
    
    func checkAuthenticationStatus() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            guard let self = self else {
                promise(.success(false))
                return
            }
            
            let hasAppleID = self.getStoredAppleUserID() != nil
            let hasJWT = self.jwtService.hasValidJWT()
            
            promise(.success(hasAppleID && hasJWT))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func initializePersistedUser() {
        if let appleID = getStoredAppleUserID(),
           jwtService.hasValidJWT() {
            currentUser = User(id: appleID, email: "")
            Logger.auth.notice(
                "Restored persisted AuthenticationService user [user=\(appleID, privacy: .private(mask: .hash))]"
            )
        }
    }
    
    private func storeAppleUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: "appleUserID")
        Logger.auth.info(
            "Stored Apple user identifier for AuthenticationService persistence [user=\(userID, privacy: .private(mask: .hash))]"
        )
    }
    
    private func getStoredAppleUserID() -> String? {
        return UserDefaults.standard.string(forKey: "appleUserID")
    }
    
    private func clearStoredAppleUserID() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        Logger.auth.info("Cleared persisted Apple user identifier for AuthenticationService.")
    }
}

// MARK: - Authentication Errors
enum AuthenticationError: LocalizedError {
    case serviceUnavailable
    case invalidCredentials
    case cloudKitUnavailable
    case userCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Authentication service is unavailable"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .cloudKitUnavailable:
            return "CloudKit is not available"
        case .userCreationFailed:
            return "Failed to create user account"
        }
    }
}
