import Foundation
import Combine
import CloudKit
import OSLog

extension Logger {
    static let cloudKitManager = Logger(subsystem: "com.RheirHome.RHEIR", category: "cloudKitManager")
}

/// Centralized CloudKit manager for the RHEIR app
/// Handles the complete lifecycle from 2-phone setup to thousands of organizations
class RHEIRCloudKitManager: ObservableObject {
    
    // MARK: - Architecture Strategy
    /*
     SCALING STRATEGY:
     
     Phase 1: Two-Phone Setup (Current)
     - Single organization with shared zone
     - Real-time sync between Kevin & Wife
     - Simple invitation system
     
     Phase 2: App Store Launch (10-100 organizations)
     - Multi-tenant architecture with custom zones
     - Organization-based data isolation
     - Subscription tiers and limits
     
     Phase 3: Enterprise Scale (1000+ organizations)
     - Advanced monitoring and analytics
     - Regional data residency
     - Enterprise SSO integration
     - Performance optimization
     */
    
    // MARK: - Services
    
    @Published var organizationZoneService = OrganizationZoneService()
    
    // MARK: - State Management
    
    @Published var deploymentMode: DeploymentMode = .twoPhone
    @Published var currentOrganization: Organization?
    @Published var isSetupComplete = false
    @Published var setupProgress: SetupProgress = .notStarted
    
    // MARK: - Operational Mode
    
    var shouldUseScalableArchitecture: Bool {
        switch deploymentMode {
        case .twoPhone:
            return false // Use simple sharing for now
        case .appStore, .enterprise:
            return true // Use full scalable architecture
        }
    }
    
    // MARK: - Lifecycle Management

    init() {
        Logger.cloudKitManager.info("Initializing top-level CloudKit manager.")
        
        // Determine deployment mode based on environment and configuration
        detectDeploymentMode()
        
        // Initialize appropriate architecture
        if shouldUseScalableArchitecture {
            Logger.cloudKitManager.notice(
                "Using scalable CloudKit architecture [mode=\(deploymentMode.rawValue, privacy: .public)]"
            )
            initializeScalableArchitecture()
        } else {
            Logger.cloudKitManager.notice("Using simple-sharing CloudKit architecture.")
            initializeSimpleSharing()
        }
    }
    
    private func detectDeploymentMode() {
        // Check if we're in production with subscription model
        let isProduction = !isDebugMode()
        let hasSubscriptionModel = UserDefaults.standard.bool(forKey: "subscription_model_enabled")
        
        if isProduction && hasSubscriptionModel {
            deploymentMode = .appStore
        } else if isProduction {
            deploymentMode = .enterprise
        } else {
            deploymentMode = .twoPhone
        }
        
        Logger.cloudKitManager.info(
            "Detected CloudKit deployment mode [mode=\(deploymentMode.rawValue, privacy: .public)]"
        )
    }
    
    private func initializeScalableArchitecture() {
        setupProgress = .initializingScalableArchitecture
        
        // The scalable architecture will handle organization setup
        // when createOrganization is called
        setupProgress = .waitingForOrganization
    }
    
    private func initializeSimpleSharing() {
        setupProgress = .initializingSimpleSharing
        
        // Auto-setup organization zone for two-phone mode
        Task { @MainActor in
            do {
                // Setup the organization zone (will create shared zone)
                guard let currentUserID = getCurrentUserID() else {
                    Logger.cloudKitManager.error("Cannot initialize simple-sharing CloudKit setup without a current user ID.")
                    setupProgress = .failed(RHEIRCloudKitError.noCurrentOrganization)
                    return
                }
                
                // Setup organization zone for current user
                let _ = try await organizationZoneService.setupOrganizationSharedZone(for: currentUserID)
                
                Logger.cloudKitManager.notice("Completed simple-sharing CloudKit setup.")
                setupProgress = .complete
                isSetupComplete = true
            } catch {
                Logger.cloudKitManager.error(
                    "Simple-sharing CloudKit setup failed [error=\(error.localizedDescription, privacy: .public)]"
                )
                setupProgress = .failed(error)
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Organization Management
    
    /// Creates or joins an organization based on deployment mode
    func setupOrganization(
        name: String,
        adminUserID: String,
        inviteEmail: String? = nil
    ) -> AnyPublisher<Organization, Error> {
        
        if shouldUseScalableArchitecture {
            return setupScalableOrganization(name: name, adminUserID: adminUserID)
        } else {
            return setupSimpleOrganization(inviteEmail: inviteEmail)
        }
    }
    
    private func setupScalableOrganization(
        name: String,
        adminUserID: String
    ) -> AnyPublisher<Organization, Error> {
        
        setupProgress = .creatingOrganization
        
        // Create organization object
        let organization = Organization(
            name: name,
            adminUserID: adminUserID
        )
        
        return Future<Organization, Error> { [weak self] promise in
            guard let self = self else { 
                promise(.failure(RHEIRCloudKitError.noCurrentOrganization))
                return 
            }
            
            Task { @MainActor in
                do {
                    // Setup shared zone for the organization
                    let _ = try await self.organizationZoneService.setupOrganizationSharedZone(for: organization.id)
                    
                    self.currentOrganization = organization
                    self.setupProgress = .complete
                    self.isSetupComplete = true
                    
                    promise(.success(organization))
                } catch {
                    Logger.cloudKitManager.error(
                        "Failed to create scalable organization [error=\(error.localizedDescription, privacy: .public)]"
                    )
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func setupSimpleOrganization(
        inviteEmail: String?
    ) -> AnyPublisher<Organization, Error> {
        
        // For simple mode, create a basic organization object
        let organization = Organization(
            name: "RHEIR LLC",
            adminUserID: getCurrentUserID() ?? "unknown"
        )
        
        currentOrganization = organization
        
        // If invite email provided, send invitation
        if let email = inviteEmail {
            return inviteToSimpleOrganization(email: email)
                .map { _ in organization }
                .eraseToAnyPublisher()
        } else {
            return Just(organization)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Project Management
    
    /// Saves a project using OrganizationZoneService
    func saveProject(_ project: Project) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else { 
                promise(.failure(RHEIRCloudKitError.noCurrentOrganization))
                return 
            }
            
            Task {
                do {
                    try await self.organizationZoneService.saveProject(project)
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Loads projects using OrganizationZoneService
    func loadProjects() -> AnyPublisher<[Project], Error> {
        return Future<[Project], Error> { [weak self] promise in
            guard let self = self else { 
                promise(.failure(RHEIRCloudKitError.noCurrentOrganization))
                return 
            }
            
            Task {
                do {
                    let projects = try await self.organizationZoneService.loadProjectsFromCurrentSharedZone()
                    promise(.success(projects))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Team Management
    
    /// Invites a user to the organization using OrganizationZoneService
    func inviteUser(email: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else { 
                promise(.failure(RHEIRCloudKitError.noCurrentOrganization))
                return 
            }
            
            Task {
                do {
                    let _ = try await self.organizationZoneService.inviteUserToOrganization(email)
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func inviteToSimpleOrganization(email: String) -> AnyPublisher<Void, Error> {
        return inviteUser(email: email)
    }
    
    /// Gets the share URL using OrganizationZoneService
    func getShareURL() -> String? {
        return organizationZoneService.getOrganizationInviteURL()
    }
    
    // MARK: - Data Management by Type
    
    /// Saves organization-wide data using OrganizationZoneService
    func saveOrganizationData<T: Codable>(
        _ data: [T],
        type: OrganizationDataType
    ) -> AnyPublisher<Void, Error> {
        
        // For now, store in UserDefaults with both architectures
        // This will be enhanced when we add more CloudKit record types
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: type.storageKey)
        }
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    /// Loads organization-wide data using OrganizationZoneService
    func loadOrganizationData<T: Codable>(
        type: OrganizationDataType,
        dataType: T.Type
    ) -> AnyPublisher<[T], Error> {
        
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: type.storageKey),
           let decoded = try? JSONDecoder().decode([T].self, from: data) {
            return Just(decoded)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Migration Support
    
    /// Migrates data using OrganizationZoneService only
    func migrateToScalableArchitecture() -> AnyPublisher<Void, Error> {
        Logger.cloudKitManager.info("Skipped CloudKit migration because OrganizationZoneService already owns the active path.")
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    private func migrateExistingData() -> AnyPublisher<Void, Error> {
        // No migration needed with single service architecture
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
    
    private func isDebugMode() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Gets current setup status for UI display
    func getSetupStatus() -> String {
        switch setupProgress {
        case .notStarted:
            return "🔄 Setup not started"
        case .initializingSimpleSharing:
            return "📱 Setting up two-phone sharing..."
        case .initializingScalableArchitecture:
            return "🏢 Initializing enterprise architecture..."
        case .creatingOrganization:
            return "🏗️ Creating organization..."
        case .waitingForOrganization:
            return "⏳ Waiting for organization setup..."
        case .complete:
            return "✅ Setup complete"
        case .failed(let error):
            return "❌ Setup failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

enum DeploymentMode: String {
    case twoPhone = "two_phone"
    case appStore = "app_store"
    case enterprise = "enterprise"
}

enum SetupProgress {
    case notStarted
    case initializingSimpleSharing
    case initializingScalableArchitecture
    case creatingOrganization
    case waitingForOrganization
    case complete
    case failed(Error)
}

enum OrganizationDataType {
    case employees
    case vendors
    case paymentMethods
    case clients
    
    var recordType: String {
        switch self {
        case .employees: return "Employee"
        case .vendors: return "Vendor"
        case .paymentMethods: return "PaymentMethod"
        case .clients: return "Client"
        }
    }
    
    var storageKey: String {
        switch self {
        case .employees: return "org_employees"
        case .vendors: return "org_vendors"
        case .paymentMethods: return "org_payment_methods"
        case .clients: return "org_clients"
        }
    }
}

enum RHEIRCloudKitError: LocalizedError {
    case noCurrentOrganization
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .noCurrentOrganization:
            return "No current organization set"
        case .unsupportedOperation:
            return "Operation not supported in current mode"
        }
    }
}
