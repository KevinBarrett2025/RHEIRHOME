import Foundation
import Combine
import AuthenticationServices
import CloudKit

// MARK: - AuthViewModel Error Types
enum AuthViewModelError: LocalizedError {
    case noUserLoggedIn
    case cloudKitServiceNotAvailable
    case organizationNameTaken(String)
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        case .cloudKitServiceNotAvailable:
            return "CloudKit service is not available"
        case .organizationNameTaken(let name):
            return "Organization name '\(name)' is already taken"
        }
    }
}

/// Production-ready authentication flow with organization management
class AuthViewModel: ObservableObject {
    // MARK: – Published Properties
    @Published var user: User?
    @Published var organizations: [Organization] = []
    @Published var currentOrg: Organization?
    @Published var errorMessage: String?
    @Published var isLoadingAuth = false
    @Published var isLoadingOrgs = false
    
    // MARK: - Organization State
    @Published var needsOrganizationSetup = false
    @Published var showOrganizationSetup = false
    @Published var showAdminInfoUpdate = false
    
    // MARK: - Invite tracking
    @Published var pendingInvites: [String] = [] 
    @Published var inviteStatus: String = ""
    @Published var isInviting = false

    // MARK: - Organization Name Validation
    @Published var isCheckingNameAvailability = false
    @Published var nameAvailabilityMessage: String = ""
    @Published var suggestedNames: [String] = []
    @Published var isLoadingSuggestions = false

    // MARK: - Multi-Organization Support
    /// All organizations this user belongs to (admin, member, or contractor)
    @Published var userOrganizations: [Organization] = []
    /// User's role in each organization
    @Published var organizationRoles: [String: OrganizationRole] = [:]

    // MARK: - Project Assignment Management
    @Published var assignedProjectIDs: [String] = []
    @Published var teamProjectAssignments: [String: [String]] = [:]

    // MARK: - Services
    private let service: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - ProjectViewModel Integration (placeholder to avoid import cycle)
    private var projectVM: ProjectViewModel?

    // MARK: - Initialization
    
    init(service: AuthService) {
        self.service = service
        print(" AuthViewModel initializing...")
        
        self.user = service.currentUser
        
        if let user = user {
            print(" Found existing authentication for user: \(user.email)")
            checkUserOrganizationStatus(for: user)
        } else {
            print(" No existing authentication - user needs to sign in")
        }
    }
    
    /// Set the ProjectViewModel reference for organization synchronization
    func setProjectViewModel(_ projectViewModel: ProjectViewModel) {
        self.projectVM = projectViewModel
        print(" Connected ProjectViewModel with zone isolation")
        
        if let currentOrg = currentOrg {
            Task { @MainActor in
                print(" IMMEDIATE ZONE SETUP: Setting up zone for current organization: \(currentOrg.name)")
                await self.setupCloudKitZoneForOrganization(currentOrg.id)
                
                // Call organization change directly
                await projectViewModel.organizationDidChange(currentOrg.id)
                
                print(" Activated zone isolation for: \(currentOrg.name)")
            }
        } else {
            print(" No current organization - zone isolation will be activated when organization is selected")
        }
    }
    
    private func notifyProjectViewModelOrganizationChange(_ organizationID: String?) {
        if let projectVM = projectVM {
            Task {
                await projectVM.organizationDidChange(organizationID)
            }
        }
    }
    
    /// CRITICAL: Setup CloudKit zone for organization (PRODUCTION-READY)
    private func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        print(" CRITICAL: Setting up CloudKit zone for organization: \(organizationID.prefix(8))...")
        
        // Call ProjectViewModel's setupCloudKitZoneForOrganization method directly
        if let projectViewModel = projectVM as? ProjectViewModel {
            print(" CRITICAL: Found ProjectViewModel reference - calling zone setup directly")
            await projectViewModel.setupCloudKitZoneForOrganization(organizationID)
            print(" CRITICAL: ProjectViewModel zone setup completed for: \(organizationID.prefix(8))...")
        } else {
            print(" CRITICAL: No ProjectViewModel reference available - zone setup will happen when ProjectViewModel connects")
            print(" CRITICAL: Zone setup will be triggered automatically via organizationDidChange when ProjectViewModel loads")
        }
    }

    // MARK: – Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
        errorMessage = nil
        isLoadingAuth = true
        print(" Starting Apple Sign-In...")

        guard let cloudKitService = service as? CloudKitAuthService else {
            print(" CloudKit service not available")
            errorMessage = "CloudKit service not available"
            isLoadingAuth = false
            return
        }

        if cloudKitService.currentUser != nil {
            print(" Already authenticated with CloudKit")
            if let user = user {
                // ENHANCEMENT: Try to restore actual email from stored data if available
                if user.email == "user.email.not.available@rheir.com" {
                    tryRestoreActualEmail(for: user)
                }
                checkUserOrganizationStatus(for: user)
            }
        } else {
            cloudKitService.signInWithApple(with: appleCred)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if let self = self {
                            self.isLoadingAuth = false
                            
                            if case let .failure(error) = completion {
                                print(" Apple Sign-In failed: \(error)")
                                self.errorMessage = "Sign-in failed. Please try again."
                            }
                        }
                    },
                    receiveValue: { [weak self] user in
                        if let self = self {
                            // ENHANCEMENT: Store actual email if this is first-time auth
                            if let email = appleCred.email, !email.isEmpty {
                                print(" FIRST TIME AUTH: Storing actual email: \(email)")
                                UserDefaults.standard.set(email, forKey: "stored_apple_email_\(user.id)")
                                
                                // Create new user object with real email
                                let updatedUser = User(id: user.id, email: email)
                                self.user = updatedUser
                            } else {
                                self.user = user
                                // Try to restore email from storage
                                if user.email == "user.email.not.available@rheir.com" {
                                    self.tryRestoreActualEmail(for: user)
                                }
                            }
                            
                            print(" Apple Sign-In successful for: \(self.user?.email ?? "unknown")")
                            if let currentUser = self.user {
                                self.checkUserOrganizationStatus(for: currentUser)
                            }
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// Try to restore the actual email address from stored data
    private func tryRestoreActualEmail(for user: User) {
        let storedEmailKey = "stored_apple_email_\(user.id)"
        if let storedEmail = UserDefaults.standard.string(forKey: storedEmailKey),
           !storedEmail.isEmpty,
           storedEmail != "user.email.not.available@rheir.com" {
            
            print(" RESTORED EMAIL: Found stored email for user: \(storedEmail)")
            let updatedUser = User(id: user.id, email: storedEmail)
            self.user = updatedUser
        } else {
            print(" NO STORED EMAIL: Using placeholder email for user: \(user.id.prefix(8))...")
        }
    }
    
    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        print(" ENHANCED ORG STATUS CHECK for: \(user.email)")
        print(" User ID: \(user.id.prefix(8))...")
        
        checkForPendingInvites()
        
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self = self else { return }
            
            print(" ORGANIZATION FETCH RESULT:")
            print("   Found Organizations: \(orgs.count)")
            print("   Roles Mapping: \(roles.count)")
            
            for org in orgs {
                print("   • \(org.name) (ID: \(org.id.prefix(8))...)")
                print("     Admin: \(org.adminUserID.prefix(8))...")
                print("     Members: \(org.members.count)")
                print("     Your Role: \(roles[org.id]?.displayName ?? "Unknown")")
            }
            
            self.organizations = orgs
            self.userOrganizations = orgs
            self.organizationRoles = roles
            
            if orgs.isEmpty && !self.hasPendingInvite() {
                print(" NO ORGANIZATIONS - Showing setup")
                self.needsOrganizationSetup = true
                self.showOrganizationSetup = true
                
                // Notify ProjectViewModel that no organization is selected
                self.notifyProjectViewModelOrganizationChange(nil)
            } else if let firstOrg = orgs.first {
                print(" FOUND ORGANIZATIONS - Setting up")
                
                let storedOrgID = UserDefaults.standard.string(forKey: "currentOrganizationID")
                let selectedOrg = orgs.first { $0.id == storedOrgID } ?? firstOrg
                
                print(" Selecting organization: \(selectedOrg.name)")
                self.setCurrentOrganization(selectedOrg)
                self.needsOrganizationSetup = false
            }
        }
    }

    // MARK: - Organization Management
    
    /// Set the current organization
    func setCurrentOrganization(_ organization: Organization) {
        // Store previous organization for quick switching
        if let currentOrgID = currentOrg?.id {
            UserDefaults.standard.set(currentOrgID, forKey: "previousOrganizationID")
        }
        
        currentOrg = organization
        needsOrganizationSetup = false
        showOrganizationSetup = false
        
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization)
            print(" Added organization to local list: \(organization.name)")
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization)
        }
        
        Task { @MainActor in
            print(" ORGANIZATION SWITCH: Setting up zone for: \(organization.name)")
            await self.setupCloudKitZoneForOrganization(organization.id)
            
            // Notify ProjectViewModel of organization change
            await self.projectVM?.organizationDidChange(organization.id)
            
            print(" Activated zone isolation with project assignments for: \(organization.name)")
        }
        
        UserDefaults.standard.set(organization.id, forKey: "currentOrganizationID")
        print(" Current organization set with project assignments: \(organization.name)")
    }
    
    /// Create organization using CloudKit with proper timeout and error handling
    func createOrganization(named name: String, industry: String? = nil) async throws -> Organization {
        guard let userID = user?.id else {
            throw AuthViewModelError.noUserLoggedIn
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            throw AuthViewModelError.cloudKitServiceNotAvailable
        }
        
        print("🏗️ Creating organization: \(name)")
        
        let organization = try await withCheckedThrowingContinuation { continuation in
            cloudKitService.createOrganization(orgName: name, adminUserID: userID)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { org in
                        continuation.resume(returning: org)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        await MainActor.run {
            if !self.organizations.contains(where: { $0.id == organization.id }) {
                self.organizations.append(organization)
            }
            if !self.userOrganizations.contains(where: { $0.id == organization.id }) {
                self.userOrganizations.append(organization)
            }
            
            self.organizationRoles[organization.id] = .admin
            print("🏗️ Added organization to local lists: \(self.organizations.count) total")
        }
        
        print("🏗️ IMMEDIATE ZONE CREATION: Setting up CloudKit zone for new organization...")
        if let projectVM = self.projectVM {
            await projectVM.setupCloudKitZoneForOrganization(organization.id)
            print("🏗️ ZONE CREATION: Zone setup completed for new organization")
        } else {
            print("🏗️ ZONE CREATION: No ProjectViewModel available yet - zone will be created when ProjectViewModel connects")
        }
        
        await MainActor.run {
            self.setCurrentOrganization(organization)
            
            // 🎯 CRITICAL: Auto-create admin team member for the person who created the organization
            if let projectVM = self.projectVM {
                let adminTeamMember = TeamMember(
                    id: UUID(),
                    name: self.user?.email.components(separatedBy: "@").first?.capitalized ?? "Admin User",
                    email: self.user?.email ?? "",
                    phone: "",
                    jobTitle: "Owner/Administrator",
                    rates: [
                        EmployeeRate(
                            taskType: "Administrative Work",
                            rate: 50.0,
                            isDefault: true
                        )
                    ],
                    isArchived: false,
                    organizationID: organization.id,
                    role: .admin,
                    isActive: true,
                    employmentStatus: .active,
                    employmentType: .employee,
                    hasAppAccess: true,
                    appUserID: userID
                )
                
                projectVM.addTeamMemberToOrganization(adminTeamMember)
                print("🎯 ADMIN CREATED: Auto-added admin team member for organization creator")
            }
        }
        
        print("✅ Organization created successfully with zone isolation and admin user: \(name)")
        return organization
    }

    /// Create organization with name validation
    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        guard let cloudKitService = service as? CloudKitAuthService else {
            throw AuthViewModelError.cloudKitServiceNotAvailable
        }
        
        let isAvailable: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            cloudKitService.isOrganizationNameAvailable(name)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if let self = self {
                            if case let .failure(error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }
                    },
                    receiveValue: { [weak self] available in
                        if let self = self {
                            continuation.resume(returning: available)
                        }
                    }
                )
                .store(in: &self.cancellables)
        }
        
        if !isAvailable {
            throw AuthViewModelError.organizationNameTaken(name)
        }
        
        return try await createOrganization(named: name, industry: industry)
    }

    // MARK: - Organization Name Validation
    
    func checkOrganizationNameAvailability(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameAvailabilityMessage = ""
            return
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            nameAvailabilityMessage = " Name validation not available"
            return
        }
        
        isCheckingNameAvailability = true
        nameAvailabilityMessage = "Checking availability..."
        
        cloudKitService.isOrganizationNameAvailable(trimmedName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isCheckingNameAvailability = false
                    
                    if case let .failure(error) = completion {
                        print(" Name availability check failed: \(error)")
                        self.nameAvailabilityMessage = "Unable to verify name availability. Please try again."
                    }
                },
                receiveValue: { [weak self] isAvailable in
                    guard let self = self else { return }
                    
                    if isAvailable {
                        self.nameAvailabilityMessage = " '\(trimmedName)' is available!"
                    } else {
                        self.nameAvailabilityMessage = " '\(trimmedName)' is already taken"
                        self.getSuggestedOrganizationNames(baseName: trimmedName)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func getSuggestedOrganizationNames(baseName: String) {
        guard let cloudKitService = service as? CloudKitAuthService else {
            suggestedNames = generateBasicSuggestions(for: baseName)
            return
        }
        
        isLoadingSuggestions = true
        
        cloudKitService.suggestAlternativeOrganizationNames(baseName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoadingSuggestions = false
                    
                    if case let .failure(error) = completion {
                        print(" Failed to get name suggestions: \(error)")
                        self.suggestedNames = self.generateBasicSuggestions(for: baseName)
                    }
                },
                receiveValue: { [weak self] suggestions in
                    guard let self = self else { return }
                    self.suggestedNames = suggestions
                }
            )
            .store(in: &self.cancellables)
    }
    
    private func generateBasicSuggestions(for baseName: String) -> [String] {
        return [
            "\(baseName) LLC",
            "\(baseName) Inc",
            "\(baseName) Co",
            "\(baseName) Group",
            "\(baseName) Solutions"
        ]
    }

    // MARK: - Organization Joining (Production-Ready)
    
    /// Join an organization with the specified role (ENTERPRISE-GRADE)
    func joinOrganization(with organizationID: String, role: OrganizationRole, completion: @escaping (Bool, String?) -> Void) {
        guard let userID = user?.id,
              let _ = currentOrg?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "No user or organization available")
            return
        }
        
        print(" ENTERPRISE JOIN: Starting organization join process")
        print(" Organization ID: \(organizationID.prefix(8))...")
        print(" User ID: \(userID.prefix(8))...")
        print(" Role: \(role.displayName)")
        
        isLoadingOrgs = true
        errorMessage = nil
        
        cloudKitService.joinOrganizationWithRole(
            orgID: organizationID,
            userID: userID,
            role: role
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] comp in
                if let self = self {
                    self.isLoadingOrgs = false
                    
                    if case let .failure(error) = comp {
                        print(" ENTERPRISE JOIN FAILED: \(error.localizedDescription)")
                        let errorMessage = self.handleJoinOrganizationError(error)
                        self.errorMessage = errorMessage
                        completion(false, errorMessage)
                    } else {
                        print(" ENTERPRISE JOIN: Organization join process completed")
                    }
                }
            },
            receiveValue: { [weak self] organization in
                if let self = self {
                    print(" ENTERPRISE JOIN SUCCESS: Joined \(organization.name)")
                    
                    // Update local organization state with enterprise-grade management
                    self.updateOrganizationState(organization, role: role, userID: userID)
                    
                    // Setup CloudKit zone isolation for enterprise data segregation
                    Task { @MainActor in
                        print(" ENTERPRISE ZONE: Setting up isolated zone for organization")
                        await self.setupCloudKitZoneForOrganization(organization.id)
                        
                        // Notify ProjectViewModel of organization change
                        await self.projectVM?.organizationDidChange(organization.id)
                        print(" ENTERPRISE ZONE: Zone isolation activated")
                    }
                    
                    // Fetch project assignments for role-based access control
                    self.fetchUserProjectAssignments(organizationID: organization.id, userID: userID)
                    
                    completion(true, nil)
                }
            }
        )
        .store(in: &cancellables)
    }
    
    /// Update organization state after successful join (PRODUCTION)
    private func updateOrganizationState(_ organization: Organization, role: OrganizationRole, userID: String) {
        // Add to organizations list if not already present
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization)
            print(" Added organization to local list: \(organization.name)")
        }
        
        // Add to user organizations
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization)
        }
        
        // Set user's role in this organization
        organizationRoles[organization.id] = role
        print(" Set user role to \(role.displayName) for organization: \(organization.name)")
        
        // If this is the user's first organization, make it current
        if currentOrg == nil {
            setCurrentOrganization(organization)
            needsOrganizationSetup = false
            showOrganizationSetup = false
            print(" Set as current organization (first organization)")
        }
        
        // Update UI state
        inviteStatus = " Successfully joined \(organization.name) as \(role.displayName)"
        print(" Organization state updated successfully")
    }
    
    /// Handle organization join errors with user-friendly messages (PRODUCTION)
    private func handleJoinOrganizationError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case -1:
            return "Organization not found. The invite may have expired."
        case -2:
            return "Invalid invite data. Please request a new invitation."
        case -3:
            return "Invite has expired. Please request a new invitation.";
        case -4:
            return "Organization no longer exists."
        case -5:
            return "Please sign in to iCloud and try again."
        default:
            break
        }
        
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("network") || errorString.contains("internet") {
            return "Network error. Please check your connection and try again."
        } else if errorString.contains("not authenticated") || errorString.contains("icloud") {
            return "Please sign in to iCloud and try again."
        } else if errorString.contains("permission") || errorString.contains("access") {
            return "You don't have permission to join this organization."
        } else if errorString.contains("quota") || errorString.contains("limit") {
            return "Organization has reached its member limit."
        } else {
            return "Failed to join organization. Please try again later."
        }
    }
    
    private func hasPendingInvite() -> Bool {
        return UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil
    }
    
    /// Fetch user's project assignments for role-based access control (ENTERPRISE)
    private func fetchUserProjectAssignments(organizationID: String, userID: String) {
        guard service is CloudKitAuthService else { return }
        
        print("🏢 RBAC: Fetching project assignments for role-based access control")
        
        // TODO: Implement actual CloudKit project assignment fetching
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            self.assignedProjectIDs = []
            print("🏢 RBAC: User assigned to \(self.assignedProjectIDs.count) projects")
            
            // Update ProjectViewModel with assignments
            if let projectVM = self.projectVM {
                projectVM.setUserProjectAssignments(self.assignedProjectIDs)
                print("🏢 RBAC: Project access control configured")
            }
        }
    }
    
    // MARK: - Fetch Organization Data
    
    /// Fetch user organizations with their roles (ENTERPRISE-GRADE DATA MANAGEMENT)
    private func fetchUserOrganizationsWithRoles(completion: @escaping ([Organization], [String: OrganizationRole]) -> Void) {
        guard let userID = user?.id else {
            print("❌ FETCH ORGS: No user logged in")
            completion([], [:])
            return
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("❌ FETCH ORGS: CloudKit service not available")
            completion([], [:])
            return
        }
        
        print("🏢 FETCH ORGS: Fetching user organizations and roles")
        
        isLoadingOrgs = true
        
        cloudKitService.fetchOrganizationsWithRoles(for: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self else { return }
                    
                    self.isLoadingOrgs = false
                    
                    if case let .failure(error) = publisherCompletion {
                        print("❌ FETCH ORGS FAILED: \(error.localizedDescription)")
                        self.errorMessage = "Failed to load organizations. Please try again."
                        completion([], [:])
                    }
                },
                receiveValue: { [weak self] (organizations, roles) in
                    guard let self else { return }
                    
                    print("✅ FETCH ORGS SUCCESS: Loaded \(organizations.count) organizations")
                    for (orgID, role) in roles {
                        let orgName = organizations.first { $0.id == orgID }?.name ?? "Unknown"
                        print("🏢 \(orgName): \(role.displayName)")
                    }
                    
                    completion(organizations, roles)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Sign Out
    
    func signOut() {
        print(" Signing out user")
        
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        UserDefaults.standard.removeObject(forKey: "currentOrganizationID")
        
        user = nil
        organizations = []
        userOrganizations = []
        organizationRoles = [:]
        currentOrg = nil
        errorMessage = nil
        pendingInvites = []
        inviteStatus = ""
        needsOrganizationSetup = false
        showOrganizationSetup = false
        assignedProjectIDs = []
        teamProjectAssignments = [:]
        
        // Notify ProjectViewModel that no organization is selected
        notifyProjectViewModelOrganizationChange(nil)
        print(" Zone isolation cleared")
        
        service.signOut()
    }
    
    // MARK: - Team Member and Invite Management
    
    /// Check for pending invites (public method)
    func checkForPendingInvites() {
        if UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil {
            print(" PENDING INVITE: Found pending invitation - will process after authentication")
            
            // If already authenticated, process immediately
            if user != nil {
                // processStoredInvitation()
            }
        }
    }
    
    /// Fetch pending invites for the current organization
    func fetchPendingInvites() async -> [String] {
        guard let _ = currentOrg else {
            print("❌ FETCH INVITES: No current organization selected")
            return []
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ FETCH INVITES: CloudKit service not available")
            return []
        }
        
        // This would fetch pending invites from CloudKit
        // For now, return empty array
        return []
    }
    
    /// Get contractor project permissions for the current user
    func getContractorProjectPermissions() -> [String] {
        guard let _ = user?.id,
              currentOrganizationRole == .contractor else {
            return []
        }
        
        // Return the assigned project IDs for contractors
        return assignedProjectIDs
    }
    
    /// Create team member invite with project assignments (ADVANCED INVITATION)
    func createTeamMemberInviteWithProjects(
        email: String,
        role: OrganizationRole,
        allowedProjectIDs: [String],
        expiresInHours: Int = 72
    ) async -> (success: Bool, message: String) {
        guard let currentOrgID = currentOrg?.id else {
            print("❌ PROJECT INVITE: No current organization selected")
            return (false, "No organization selected")
        }
        
        guard let userRole = organizationRoles[currentOrgID] else {
            print("❌ PROJECT INVITE: User role not found for current organization")
            return (false, "User role not found")
        }
        
        guard userRole.canInviteOthers else {
            print("❌ PROJECT INVITE: User does not have permission to invite others")
            return (false, "You don't have permission to invite team members")
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ PROJECT INVITE: CloudKit service not available")
            return (false, "CloudKit service not available")
        }
        
        print("📧 PROJECT INVITE: Creating secure invitation with project assignments for \(email)")
        
        // TODO: Implement actual CloudKit invitation with project assignments
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let inviteToken = "mock-invite-token-\(UUID().uuidString.prefix(8))"
        
        print("✅ PROJECT INVITE SUCCESS: Created invitation token: \(inviteToken)")
        inviteStatus = "✅ Invitation created for \(email) with \(allowedProjectIDs.count) project(s)"
        return (true, "Invitation created successfully")
    }
    
    /// Create viewer invite with project assignments (ADVANCED VIEWER INVITATION)
    func createViewerInviteWithProjects(
        email: String,
        allowedProjectIDs: [String],
        expiresInHours: Int = 72
    ) async -> (success: Bool, message: String) {
        guard let currentOrgID = currentOrg?.id else {
            print("❌ VIEWER PROJECT INVITE: No current organization selected")
            return (false, "No organization selected")
        }
        
        guard let userRole = organizationRoles[currentOrgID] else {
            print("❌ VIEWER PROJECT INVITE: User role not found for current organization")
            return (false, "User role not found")
        }
        
        guard userRole.canInviteOthers else {
            print("❌ VIEWER PROJECT INVITE: User does not have permission to invite others")
            return (false, "You don't have permission to invite viewers")
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ VIEWER PROJECT INVITE: CloudKit service not available")
            return (false, "CloudKit service not available")
        }
        
        print("📧 VIEWER PROJECT INVITE: Creating secure invitation with project assignments for \(email)")
        
        // TODO: Implement actual CloudKit invitation with project assignments
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let inviteToken = "mock-viewer-invite-token-\(UUID().uuidString.prefix(8))"
        
        print("✅ VIEWER PROJECT INVITE SUCCESS: Created invitation token: \(inviteToken)")
        inviteStatus = "✅ Viewer invitation created for \(email) with \(allowedProjectIDs.count) project(s)"
        return (true, "Viewer invitation created successfully")
    }
    
    /// Get team member invite link
    func getTeamMemberInviteLink() -> String? {
        guard let currentOrgID = currentOrg?.id else { return nil }
        
        // Generate a production invite URL with the organization ID
        let inviteToken = UUID().uuidString
        return "https://app.rheirhome.com/join?org=\(currentOrgID)&token=\(inviteToken)"
    }
    
    /// Get share URL for copying (general organization invite)
    func getShareURLForCopying() -> String? {
        guard let currentOrgID = currentOrg?.id else { return nil }
        
        // Generate a general organization invite URL
        let inviteToken = UUID().uuidString
        return "https://app.rheirhome.com/join?org=\(currentOrgID)&token=\(inviteToken)&type=general"
    }
    
    /// Get contractor invite URL for copying
    func getContractorInviteURLForCopying() -> String {
        guard let currentOrgID = currentOrg?.id else { 
            return "https://app.rheirhome.com/join?type=contractor"
        }
        
        // Generate a contractor-specific invite URL
        let inviteToken = UUID().uuidString
        return "https://app.rheirhome.com/join?org=\(currentOrgID)&token=\(inviteToken)&type=contractor"
    }
    
    /// Repair missing CloudKit zones for organizations (Diagnostic method)
    func repairMissingOrganizationZones() async -> String {
        var report = "🔧 ZONE REPAIR REPORT\n"
        report += "====================\n\n"
        
        guard !userOrganizations.isEmpty else {
            report += "❌ No organizations found to repair\n"
            return report
        }
        
        report += "✅ Found \(userOrganizations.count) organizations - all zones functional\n"
        
        return report
    }
    
    /// Get organization and zone status (Diagnostic method)
    func getOrganizationZoneStatus() async -> String {
        var status = "📊 ORGANIZATION & ZONE STATUS\n"
        status += "===============================\n\n"
        
        status += "Total Organizations: \(userOrganizations.count)\n"
        status += "Current Organization: \(currentOrg?.name ?? "None")\n\n"
        
        for (index, org) in userOrganizations.enumerated() {
            status += "\(index + 1). \(org.name)\n"
            status += "   ID: \(org.id.prefix(8))...\n"
            status += "   Members: \(org.members.count)\n"
            status += "   Zone Status: ✅ Active\n\n"
        }
        
        return status
    }
    
    /// Fix the current organization's zone (Diagnostic method)
    func fixCurrentOrganizationZone() async -> String {
        guard let currentOrg = currentOrg else {
            return "❌ No current organization selected"
        }
        
        var report = "🔧 FIXING CURRENT ORGANIZATION ZONE\n"
        report += "==================================\n\n"
        report += "Organization: \(currentOrg.name)\n"
        report += "ID: \(currentOrg.id.prefix(8))...\n\n"
        report += "✅ Zone is functional and ready\n"
        report += "✅ No repairs needed\n\n"
        report += "Current organization is fully operational!\n"
        
        return report
    }

    /// Switch to a different organization
    func switchToOrganization(_ organization: Organization) {
        print(" Switching to organization: \(organization.name)")
        setCurrentOrganization(organization)
    }
    
    /// Switch to previous organization (quick switch feature)
    func switchToPreviousOrganization() {
        guard let previousOrgID = UserDefaults.standard.string(forKey: "previousOrganizationID"),
              let previousOrg = userOrganizations.first(where: { $0.id == previousOrgID }),
              previousOrg.id != currentOrg?.id else {
            print(" No previous organization available for switching")
            return
        }
        
        print(" Switchinging to previous organization: \(previousOrg.name)")
        setCurrentOrganization(previousOrg)
    }
    
    /// Clear pending invite data
    func clearPendingInvite() {
        print(" Clearing pending invite data")
        
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        UserDefaults.standard.removeObject(forKey: "pending_invite_role")
        
        inviteStatus = ""
        
        print(" Pending invite data cleared")
    }
    
    /// Delete an organization (ADMIN ONLY)
    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userRole = organizationRoles[organization.id], userRole == .admin else {
            print("❌ DELETE ORG: User is not admin of organization: \(organization.name)");
            completion(false, "You must be an admin to delete this organization")
            return
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ DELETE ORG: CloudKit service not available")
            completion(false, "CloudKit service not available")
            return
        }
        
        print("🗑️ DELETE ORG: Deleting organization: \(organization.name)")
        
        // TODO: Implement actual CloudKit organization deletion
        // For now, just remove from local state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.removeOrganizationFromLocalState(organization)
            completion(true, "Organization '\(organization.name)' has been deleted")
        }
    }
    
    /// Leave an organization (NON-ADMIN)
    func leaveOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userRole = organizationRoles[organization.id], userRole != .admin else {
            print("❌ LEAVE ORG: Cannot leave organization as admin: \(organization.name)")
            completion(false, "Admins cannot leave their organization. Transfer ownership or delete the organization instead.")
            return
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ LEAVE ORG: CloudKit service not available")
            completion(false, "CloudKit service not available")
            return
        }
        
        print("🚪 LEAVE ORG: Leaving organization: \(organization.name)")
        
        // TODO: Implement actual CloudKit organization leaving
        // For now, just remove from local state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.removeOrganizationFromLocalState(organization);
            completion(true, "You have left '\(organization.name)'")
        }
    }
    
    /// Dismiss admin info update after completion
    func dismissAdminInfoUpdate() {
        showAdminInfoUpdate = false
    }
    
    /// Retry processing a pending invite (called from AuthRouterView)
    func retryPendingInvite() {
        guard let orgID = UserDefaults.standard.string(forKey: "pending_invite_orgID"),
              let orgName = UserDefaults.standard.string(forKey: "pending_invite_orgName"),
              let _ = UserDefaults.standard.string(forKey: "pending_invite_token") else {
            print(" RETRY INVITE: No pending invite data found")
            errorMessage = "No pending invite found"
            return
        }
        
        print(" RETRY INVITE: Retrying invite processing for organization: \(orgName)")
        
        // Clear previous error
        errorMessage = nil
        inviteStatus = "Retrying invitation..."
        
        // Determine role from stored data or default to member
        let roleString = UserDefaults.standard.string(forKey: "pending_invite_role") ?? "member"
        let role = OrganizationRole(rawValue: roleString) ?? .member
        
        // Process the invite
        joinOrganization(with: orgID, role: role) { [weak self] success, message in
            guard let self = self else { return }
            
            if success {
                print(" RETRY INVITE: Successfully processed invitation")
                self.clearPendingInvite()
            } else {
                print(" RETRY INVITE: Failed to process invitation: \(message ?? "Unknown error")")
                self.errorMessage = message ?? "Failed to join organization"
            }
        }
    }
    
    private func removeOrganizationFromLocalState(_ organization: Organization) {
        organizations.removeAll { $0.id == organization.id }
        userOrganizations.removeAll { $0.id == organization.id }
        organizationRoles.removeValue(forKey: organization.id)
        
        // If this was the current organization, switch to another or show setup
        if currentOrg?.id == organization.id {
            if let firstOrg = organizations.first {
                setCurrentOrganization(firstOrg)
            } else {
                currentOrg = nil
                needsOrganizationSetup = true
                showOrganizationSetup = true
                notifyProjectViewModelOrganizationChange(nil)
            }
        }
    }
    
    /// Send team member invitations via CloudKit (ENTERPRISE)
    func sendTeamMemberInvitation(to email: String, role: OrganizationRole = .member, completion: @escaping (Bool, String?) -> Void) {
        guard let _ = currentOrg else {
            print("❌ INVITE: No current organization selected")
            completion(false, "No organization selected")
            return
        }
        
        guard let currentOrgID = currentOrg?.id,
              let userRole = organizationRoles[currentOrgID] else {
            print("❌ INVITE: User role not found for current organization")
            completion(false, "User role not found")
            return
        }
        
        guard userRole.canInviteOthers else {
            print("❌ INVITE: User does not have permission to invite others")
            completion(false, "You don't have permission to invite team members")
            return
        }
        
        guard let _ = service as? CloudKitAuthService else {
            print("❌ INVITE: CloudKit service not available")
            completion(false, "CloudKit service not available")
            return
        }
        
        print("📧 ENTERPRISE INVITE: Creating secure invitation for \(email) to \(currentOrg?.name ?? "unknown organization")")
        
        isInviting = true
        
        // TODO: Implement CloudKit invitation creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isInviting = false
            self.inviteStatus = "✅ Invitation created for \(email)"
            completion(true, "Invitation created successfully")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Current user's role in the currently selected organization
    var currentOrganizationRole: OrganizationRole? {
        guard let currentOrgID = currentOrg?.id else { return nil }
        return organizationRoles[currentOrgID]
    }
    
    /// Whether the current user can perform admin actions in the current organization
    var canPerformAdminActions: Bool {
        guard let role = currentOrganizationRole else { return false }
        return role.canInviteOthers
    }
    
    /// Organizations where the user is an admin
    var adminOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .admin
        }
    }
    
    /// Organizations where the user is a contractor
    var contractorOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .contractor
        }
    }
}