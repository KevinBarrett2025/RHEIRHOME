import Foundation
import Combine
import CloudKit

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
    
    @Published var scalableArchitecture = ScalableCloudKitArchitecture()
    @Published var simpleSharing = SimpleCloudKitSharingService()
    
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
        print("🏗️ RHEIRCloudKitManager initializing...")
        
        // Determine deployment mode based on environment and configuration
        detectDeploymentMode()
        
        // Initialize appropriate architecture
        if shouldUseScalableArchitecture {
            print("🏢 Using scalable architecture for \(deploymentMode)")
            initializeScalableArchitecture()
        } else {
            print("📱 Using simple sharing for two-phone setup")
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
        
        print("🔍 Detected deployment mode: \(deploymentMode)")
    }
    
    private func initializeScalableArchitecture() {
        setupProgress = .initializingScalableArchitecture
        
        // The scalable architecture will handle organization setup
        // when createOrganization is called
        setupProgress = .waitingForOrganization
    }
    
    private func initializeSimpleSharing() {
        setupProgress = .initializingSimpleSharing
        
        // Auto-setup organization sharing for two-phone mode
        simpleSharing.setupOrganizationSharing()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        print("❌ Simple sharing setup failed: \(error)")
                        self?.setupProgress = .failed(error)
                    }
                },
                receiveValue: { [weak self] shareURL in
                    print("✅ Simple sharing setup complete")
                    self?.setupProgress = .complete
                    self?.isSetupComplete = true
                }
            )
            .store(in: &cancellables)
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
        
        return scalableArchitecture.createOrganization(
            name: name,
            adminUserID: adminUserID,
            industry: "Construction",
            settings: OrganizationSettings()
        )
        .map { result in
            self.currentOrganization = result.organization
            self.setupProgress = .complete
            self.isSetupComplete = true
            return result.organization
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
    
    /// Saves a project using the appropriate architecture
    func saveProject(_ project: Project) -> AnyPublisher<Void, Error> {
        if shouldUseScalableArchitecture {
            return scalableArchitecture.saveProject(project)
                .map { _ in () }
                .eraseToAnyPublisher()
        } else {
            return simpleSharing.saveProjectToSharedZone(project)
                .map { _ in () }
                .eraseToAnyPublisher()
        }
    }
    
    /// Loads projects using the appropriate architecture
    func loadProjects() -> AnyPublisher<[Project], Error> {
        if shouldUseScalableArchitecture {
            return scalableArchitecture.loadOrganizationProjects()
        } else {
            return simpleSharing.loadProjectsFromSharedZone()
        }
    }
    
    // MARK: - Team Management
    
    /// Invites a user to the organization
    func inviteUser(email: String) -> AnyPublisher<Void, Error> {
        if shouldUseScalableArchitecture {
            return scalableArchitecture.inviteUserToOrganization(email: email)
                .map { _ in () }
                .eraseToAnyPublisher()
        } else {
            return inviteToSimpleOrganization(email: email)
        }
    }
    
    private func inviteToSimpleOrganization(email: String) -> AnyPublisher<Void, Error> {
        return simpleSharing.inviteUserToOrganization(email: email)
    }
    
    /// Gets the share URL for manual sharing
    func getShareURL() -> String? {
        if shouldUseScalableArchitecture {
            return scalableArchitecture.getOrganizationShareURL()?.absoluteString
        } else {
            return simpleSharing.getOrganizationShareURL()
        }
    }
    
    // MARK: - Data Management by Type
    
    /// Saves organization-wide data (employees, vendors, etc.)
    func saveOrganizationData<T: Codable>(
        _ data: [T],
        type: OrganizationDataType
    ) -> AnyPublisher<Void, Error> {
        
        if shouldUseScalableArchitecture {
            // Save each item individually in scalable architecture
            let publishers = data.enumerated().map { index, item in
                scalableArchitecture.saveOrganizationData(
                    item,
                    recordType: type.recordType,
                    recordName: "\(type.recordType)_\(index)_\(UUID().uuidString)"
                )
            }
            
            return Publishers.MergeMany(publishers)
                .collect()
                .map { _ in () }
                .eraseToAnyPublisher()
        } else {
            // For simple architecture, store in UserDefaults temporarily
            // This will be migrated when switching to scalable architecture
            if let encoded = try? JSONEncoder().encode(data) {
                UserDefaults.standard.set(encoded, forKey: type.storageKey)
            }
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    /// Loads organization-wide data
    func loadOrganizationData<T: Codable>(
        type: OrganizationDataType,
        dataType: T.Type
    ) -> AnyPublisher<[T], Error> {
        
        if shouldUseScalableArchitecture {
            return scalableArchitecture.loadOrganizationData(
                recordType: type.recordType,
                dataType: dataType
            )
        } else {
            // Load from UserDefaults for simple architecture
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
    }
    
    // MARK: - Migration Support
    
    /// Migrates from simple to scalable architecture when needed
    func migrateToScalableArchitecture() -> AnyPublisher<Void, Error> {
        print("🔄 Migrating to scalable architecture...")
        
        guard !shouldUseScalableArchitecture else {
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Switch to scalable mode
        deploymentMode = .appStore
        
        // Create organization in scalable architecture
        guard let currentOrg = currentOrganization else {
            return Fail(error: RHEIRCloudKitError.noCurrentOrganization)
                .eraseToAnyPublisher()
        }
        
        return scalableArchitecture.createOrganization(
            name: currentOrg.name,
            adminUserID: currentOrg.adminUserID,
            industry: "Construction",
            settings: OrganizationSettings()
        )
        .flatMap { result in
            // Migrate existing projects and data
            self.migrateExistingData()
        }
        .map { _ in
            print("✅ Migration to scalable architecture complete")
        }
        .eraseToAnyPublisher()
    }
    
    private func migrateExistingData() -> AnyPublisher<Void, Error> {
        // Load projects from simple sharing and save to scalable architecture
        return simpleSharing.loadProjectsFromSharedZone()
            .flatMap { projects in
                let projectPublishers = projects.map { project in
                    self.scalableArchitecture.saveProject(project)
                }
                
                return Publishers.MergeMany(projectPublishers)
                    .collect()
                    .map { _ in () }
            }
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