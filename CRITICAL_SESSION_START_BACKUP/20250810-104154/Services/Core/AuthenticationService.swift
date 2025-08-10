import Foundation
import Combine
import CloudKit
import AuthenticationServices

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
        print("🍎 [Auth] Starting Apple Sign-In with credential: \(credential.user)")
        
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
                                print("✅ [Auth] Apple Sign-In complete - JWT stored")
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
        print("🔄 [Auth] Silent sign-in attempt for userID: \(userID)")
        
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
                            print("🔄 [Auth] Refreshing JWT during silent login")
                            return self.jwtService.createAppSpecificJWT(for: user)
                                .map { jwt in
                                    self.jwtService.storeJWT(jwt)
                                    return user
                                }
                                .eraseToAnyPublisher()
                        } else {
                            print("✅ [Auth] Using existing valid JWT")
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
        print("🚪 [Auth] Signing out user")
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
            print("✅ [Auth] Restored persisted user: \(appleID)")
        }
    }
    
    private func storeAppleUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: "appleUserID")
        print("💾 [Auth] Stored Apple ID for persistence: \(userID)")
    }
    
    private func getStoredAppleUserID() -> String? {
        return UserDefaults.standard.string(forKey: "appleUserID")
    }
    
    private func clearStoredAppleUserID() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        print("🗑 [Auth] Cleared stored Apple ID")
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