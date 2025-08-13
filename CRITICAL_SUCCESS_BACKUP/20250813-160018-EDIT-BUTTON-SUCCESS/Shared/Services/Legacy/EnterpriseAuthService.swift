import Foundation
import Combine
import AuthenticationServices

/// Enterprise-level AuthService implementation that bridges to the new service architecture
/// This maintains backward compatibility while using the focused service layer
final class EnterpriseAuthService: AuthService {
    // MARK: - Dependencies
    private let authenticationService: AuthenticationServiceProtocol
    private let organizationService: OrganizationServiceProtocol
    private let jwtService: JWTServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - AuthService Protocol Implementation
    var currentUser: User? {
        return authenticationService.currentUser
    }
    
    // MARK: - Initialization
    init(
        authenticationService: AuthenticationServiceProtocol,
        organizationService: OrganizationServiceProtocol,
        jwtService: JWTServiceProtocol
    ) {
        self.authenticationService = authenticationService
        self.organizationService = organizationService
        self.jwtService = jwtService
    }
    
    // MARK: - AuthService Protocol Methods
    
    func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        return Fail(error: EnterpriseAuthError.emailPasswordNotSupported)
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<User, Error> {
        return Fail(error: EnterpriseAuthError.emailPasswordNotSupported)
            .eraseToAnyPublisher()
    }
    
    func signInWithApple() -> AnyPublisher<User, Error> {
        return Fail(error: EnterpriseAuthError.useCredentialBasedSignIn)
            .eraseToAnyPublisher()
    }
    
    func invite(email: String, orgID: String) -> AnyPublisher<Void, Error> {
        return organizationService.inviteUserToOrganization(email: email, organizationID: orgID)
    }
    
    func signOut() {
        authenticationService.signOut()
    }
    
    // MARK: - Extended Methods (maintaining backward compatibility)
    
    func signInWithApple(with credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<User, Error> {
        return authenticationService.signInWithApple(using: credential)
    }
    
    func signInWithApple(userID: String, email: String? = nil) -> AnyPublisher<User, Error> {
        return authenticationService.signInSilently(userID: userID, email: email)
    }
    
    func createOrganization(orgName: String, adminUserID: String) -> AnyPublisher<Organization, Error> {
        return organizationService.createOrganization(name: orgName, adminUserID: adminUserID)
    }
    
    func fetchOrganizations(for userID: String) -> AnyPublisher<[Organization], Error> {
        return organizationService.fetchOrganizations(for: userID)
    }
    
    // MARK: - JWT Access (for AuthViewModel)
    
    var storedJWT: String? {
        return jwtService.getStoredJWT()
    }
    
    func refreshJWTIfNeeded() -> AnyPublisher<String?, Error> {
        if jwtService.isJWTExpired() {
            return jwtService.refreshJWT()
                .map { jwt -> String? in jwt }
                .eraseToAnyPublisher()
        } else {
            return Just(jwtService.getStoredJWT())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
}

// MARK: - Enterprise Auth Errors
enum EnterpriseAuthError: LocalizedError {
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