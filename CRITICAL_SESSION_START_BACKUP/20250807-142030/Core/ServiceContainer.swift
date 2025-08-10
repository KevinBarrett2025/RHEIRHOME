import Foundation

/// Dependency injection container for managing service instances
final class ServiceContainer {
    static let shared = ServiceContainer()
    
    // MARK: - Core Services
    private lazy var _cloudKitService: CloudKitServiceProtocol = {
        CloudKitService()
    }()
    
    private lazy var _jwtService: JWTServiceProtocol = {
        RHEIRJWTService()
    }()
    
    private lazy var _userService: UserServiceProtocol = {
        CloudKitUserService(cloudKitService: _cloudKitService)
    }()
    
    private lazy var _authenticationService: AuthenticationServiceProtocol = {
        AuthenticationService(
            cloudKitService: _cloudKitService,
            userService: _userService,
            jwtService: _jwtService
        )
    }()
    
    private lazy var _organizationService: OrganizationServiceProtocol = {
        CloudKitOrganizationService()
    }()
    
    // MARK: - Public Accessors
    
    var cloudKitService: CloudKitServiceProtocol {
        return _cloudKitService
    }
    
    var jwtService: JWTServiceProtocol {
        return _jwtService
    }
    
    var userService: UserServiceProtocol {
        return _userService
    }
    
    var authenticationService: AuthenticationServiceProtocol {
        return _authenticationService
    }
    
    var organizationService: OrganizationServiceProtocol {
        return _organizationService
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Testing Support
    func resetServices() {
        // Reset all lazy services for testing
        _cloudKitService = CloudKitService()
        _jwtService = RHEIRJWTService()
        _userService = CloudKitUserService(cloudKitService: _cloudKitService)
        _authenticationService = AuthenticationService(
            cloudKitService: _cloudKitService,
            userService: _userService,
            jwtService: _jwtService
        )
        _organizationService = CloudKitOrganizationService()
    }
}

// MARK: - Service Container Extensions for Easy Access
extension ServiceContainer {
    /// Create a configured CloudKitAuthService using the new service architecture
    /// This maintains backward compatibility while using the new service layer
    func createLegacyAuthService() -> AuthService {
        return EnterpriseAuthService(
            authenticationService: authenticationService,
            organizationService: organizationService,
            jwtService: jwtService
        )
    }
}