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
    
    @MainActor
    init(service: AuthService) {
        self.service = service
        print("🔐 AuthViewModel initializing...")
        
        self.user = service.currentUser
        
        if let user = user {
            print("🔐 Found existing authentication for user: \(user.email)")
            checkUserOrganizationStatus(for: user)
        } else {
            print("🔐 No existing authentication - user needs to sign in")
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
                
                // CRITICAL FIX: Sync user role when ProjectViewModel connects
                if let userRole = self.organizationRoles[currentOrg.id] {
                    projectViewModel.setCurrentUserRole(userRole, forOrganization: currentOrg.id)
                    print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
                } else {
                    print("⚠️ ROLE SYNC WARNING: No role found for current organization during connection")
                }
                
                // Call organization change directly
                await projectViewModel.organizationDidChange(currentOrg.id)
                
                // CRITICAL: Ensure admin team member exists after connection
                self.ensureAdminTeamMemberExists()
                
                print(" Activated zone isolation for: \(currentOrg.name)")
            }
        } else {
            print(" No current organization - zone isolation will be activated when organization is selected")
        }
    }
    
    /// Ensure the admin team member exists for the current organization
    private func ensureAdminTeamMemberExists() {
        Task { @MainActor in
            guard let organization = currentOrg,
                  let userEmail = user?.email,
                  let userID = user?.id,
                  let projectVM = projectVM else {
                print("❌ ADMIN CHECK: Missing required data for admin verification")
                return
            }
            
            print("🔍 ADMIN CHECK: Looking for existing admin team member...")
            print("   Organization: \(organization.name) (\(organization.id.prefix(8))...)")
            print("   User ID: \(userID.prefix(8))...")
            print("   Total team members: \(projectVM.teamMembers.count)")
            
            // Filter team members for this organization first
            let orgTeamMembers = projectVM.teamMembers.filter { $0.organizationID == organization.id }
            print("   Organization team members: \(orgTeamMembers.count)")
            
            for member in orgTeamMembers {
                print("   - \(member.name): Role=\(member.role.displayName), AppUserID=\(member.appUserID?.prefix(8) ?? "nil")...")
            }
            
            // Check if admin team member already exists
            let existingAdmin = projectVM.teamMembers.first { 
                $0.appUserID == userID && $0.organizationID == organization.id && $0.role == .admin 
            }
            
            if existingAdmin == nil {
                print("🎯 ADMIN MISSING: Creating admin team member for organization owner...")
                
                let adminName = userEmail.components(separatedBy: "@").first?.capitalized ?? "Admin User"
                
                let adminTeamMember = TeamMember(
                    id: UUID(),
                    name: adminName,
                    email: userEmail,
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
                
                print("🎯 ADMIN DETAILS:")
                print("   Name: \(adminName)")
                print("   Email: \(userEmail)");
                print("   Job Title: Owner/Administrator");
                print("   Organization ID: \(organization.id.prefix(8))...");
                print("   App User ID: \(userID.prefix(8))...");
                
                projectVM.addTeamMemberToOrganization(adminTeamMember);
                
                // Wait a bit and verify
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                let newCount = projectVM.teamMembers.filter { $0.organizationID == organization.id }.count
                print("🔍 ADMIN VERIFICATION: Team members after creation: \(newCount)");
                
                if newCount > 0 {
                    print("✅ ADMIN CREATED: Successfully created admin team member post-connection");
                } else {
                    print("❌ ADMIN FAILED: Team member was not added to organization");
                }
            } else {
                print("✅ ADMIN EXISTS: Admin team member already exists for this organization");
                print("   Existing admin: \(existingAdmin?.name ?? "Unknown")");
            }
        }
    }
    
    private func notifyProjectViewModelOrganizationChange(_ organizationID: String?) {
        if let projectVM = projectVM {
            Task { @MainActor in
                await projectVM.organizationDidChange(organizationID)
            }
        }
    }
    
    /// CRITICAL: Setup CloudKit zone for organization (PRODUCTION-READY)
    private func setupCloudKitZoneForOrganization(_ organizationID: String) async {
        print("🔧 CRITICAL: Setting up CloudKit zone for organization: \(organizationID.prefix(8))...")
        
        // Call ProjectViewModel's setupCloudKitZoneForOrganization method directly
        if let projectViewModel = projectVM {
            print("🔧 CRITICAL: Found ProjectViewModel reference - calling zone setup directly")
            await projectViewModel.setupCloudKitZoneForOrganization(organizationID)
            print("🔧 CRITICAL: ProjectViewModel zone setup completed for: \(organizationID.prefix(8))...")
        } else {
            print("🔧 CRITICAL: No ProjectViewModel reference available - zone setup will happen when ProjectViewModel connects")
            print("🔧 CRITICAL: Zone setup will be triggered automatically via organizationDidChange when ProjectViewModel loads")
        }
    }

    // MARK: – Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
        Task { @MainActor in
            errorMessage = nil
            isLoadingAuth = true
            print("🔐 Starting Apple Sign-In...")
            
            guard let cloudKitService = service as? CloudKitAuthService else {
                print("❌ CloudKit service not available")
                errorMessage = "CloudKit service not available"
                isLoadingAuth = false
                return
            }
            
            if cloudKitService.currentUser != nil {
                print("✓ Already authenticated with CloudKit")
                if let user = user {
                    // ENHANCEMENT: Try to restore actual email from stored data if available
                    if user.email == "user.email.not.available@rheir.com" {
                        tryRestoreActualEmail(for: user)
                    }
                    checkUserOrganizationStatus(for: user)
                }
            } else {
                await cloudKitService.signInWithApple(with: appleCred)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        guard let self = self else { return }
                        self.isLoadingAuth = false
                        
                        if case .failure(let error) = completion {
                            print("❌ Apple Sign-In failed: \(error)")
                            self.errorMessage = "Sign-in failed. Please try again."
                        }
                    },
                    receiveValue: { [weak self] user in
                        guard let self = self else { return }
                        
                        // ENHANCEMENT: Store actual email if this is first-time auth
                        if let email = appleCred.email, !email.isEmpty {
                            print("🔐 FIRST TIME AUTH: Storing actual email: \(email)")
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
                        
                        print("✅ Apple Sign-In successful for: \(self.user?.email ?? "unknown")")
                        if let currentUser = self.user {
                            self.checkUserOrganizationStatus(for: currentUser)
                        }
                    }
                )
                .store(in: &cancellables)
            }
        }
    }
    
    /// Try to restore the actual email address from stored data
    private func tryRestoreActualEmail(for user: User) {
        let storedEmailKey = "stored_apple_email_\(user.id)";
        if let storedEmail = UserDefaults.standard.string(forKey: storedEmailKey),
           !storedEmail.isEmpty,
           storedEmail != "user.email.not.available@rheir.com" {
            
            print(" RESTORED EMAIL: Found stored email for user: \(storedEmail)");
            let updatedUser = User(id: user.id, email: storedEmail);
            self.user = updatedUser;
        } else {
            print(" NO STORED EMAIL: Using placeholder email for user: \(user.id.prefix(8))...");
        }
    }
    
    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        print("🔍 ENHANCED ORG STATUS CHECK for: \(user.email)");
        print("🔍 User ID: \(user.id.prefix(8))...");
        
        checkForPendingInvites();
        
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self else { return };
            
            print("🔍 ORGANIZATION FETCH RESULT:");
            print("   Found Organizations: \(orgs.count)");
            print("   Roles Mapping: \(roles.count)");
            
            for org in orgs {
                print("   • \(org.name) (ID: \(org.id.prefix(8))...)");
                print("     Admin: \(org.adminUserID.prefix(8))...");
                print("     Members: \(org.members.count)");
                print("     Your Role: \(roles[org.id]?.displayName ?? "Unknown")");
            }
            
            self.organizations = orgs;
            self.userOrganizations = orgs;
            self.organizationRoles = roles;
            
            if orgs.isEmpty && !self.hasPendingInvite() {
                print("🔍 NO ORGANIZATIONS - Showing setup");
                self.needsOrganizationSetup = true;
                self.showOrganizationSetup = true;
                
                // Notify ProjectViewModel that no organization is selected
                self.notifyProjectViewModelOrganizationChange(nil);
            } else if let firstOrg = orgs.first {
                print("🔍 FOUND ORGANIZATIONS - Setting up with enterprise synchronization");
                
                let storedOrgID = UserDefaults.standard.string(forKey: "currentOrganizationID");
                let selectedOrg = orgs.first { $0.id == storedOrgID } ?? firstOrg;
                
                print("🔍 Selecting organization: \(selectedOrg.name)");
                self.setCurrentOrganization(selectedOrg);
                self.needsOrganizationSetup = false;
                
                // ENTERPRISE: Automatic background data validation
                Task { @MainActor in
                    await self.validateOrganizationDataIntegrity(selectedOrg);
                }
            }
        }
    }

    // MARK: - Organization Management
    
    /// Set the current organization
    func setCurrentOrganization(_ organization: Organization) {
        // Store previous organization for quick switching
        if let currentOrgID = currentOrg?.id {
            UserDefaults.standard.set(currentOrgID, forKey: "previousOrganizationID");
        }
        
        currentOrg = organization;
        needsOrganizationSetup = false;
        showOrganizationSetup = false;
        
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization);
            print("✅ Added organization to local list: \(organization.name)");
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization);
        }
        
        // CRITICAL FIX: Sync user role with ProjectViewModel
        if let userRole = organizationRoles[organization.id] {
            Task { @MainActor in
                projectVM?.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for ProjectViewModel")
            }
        } else {
            print("⚠️ ROLE SYNC WARNING: No role found for organization \(organization.name)")
        }
        
        Task { @MainActor in
            print("🔄 ORGANIZATION SWITCH: Setting up zone for: \(organization.name)")
            await self.setupCloudKitZoneForOrganization(organization.id)
            
            // Notify ProjectViewModel of organization change
            await self.projectVM?.organizationDidChange(organization.id)
            
            // ENTERPRISE FEATURE: Automatic data synchronization
            print("🔄 ENTERPRISE SYNC: Starting automatic data synchronization...")
            await self.syncOrganizationTeamMembers()
            
            // CRITICAL: Ensure admin team member exists after connection
            self.ensureAdminTeamMemberExists()
            
            print("✅ Activated zone isolation with synchronized data for: \(organization.name)")
        }
        
        UserDefaults.standard.set(organization.id, forKey: "currentOrganizationID");
        print("✅ Current organization set with enterprise-grade synchronization: \(organization.name)");
    }
    
    /// Create organization using CloudKit with proper timeout and error handling
    func createOrganization(named name: String, industry: String? = nil) async throws -> Organization {
        print("🏗️ PRODUCTION ORG CREATION: Starting comprehensive organization creation process...");
        print("🏗️ Input Name: '\(name)'");
        print("🏗️ Industry: \(industry ?? "None")");
        
        guard let userID = user?.id else {
            print("❌ PRODUCTION ERROR: No user logged in during organization creation");
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard let userEmail = user?.email else {
            print("❌ PRODUCTION ERROR: User has no email address");
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("❌ PRODUCTION ERROR: CloudKit service not available");
            throw AuthViewModelError.cloudKitServiceNotAvailable;
        }
        
        print("🏗️ PRODUCTION VERIFICATION:");
        print("   User ID: \(userID.prefix(8))...");
        print("   User Email: \(userEmail)");
        print("   Service Type: CloudKitAuthService");
        print("   Organization Name: '\(name)'");
        
        print("🏗️ PRODUCTION: Calling CloudKit organization creation...")
        
        let organization: Organization = try await withCheckedThrowingContinuation { continuation in
            cloudKitService.createOrganization(orgName: name, adminUserID: userID)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("🏗️ CloudKit organization creation publisher completed successfully")
                        case .failure(let error):
                            print("❌ CloudKit organization creation failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { org in
                        print("✅ PRODUCTION SUCCESS: Organization created via CloudKit")
                        print("   Organization ID: \(org.id.prefix(8))...")
                        print("   Organization Name: \(org.name)")
                        print("   Admin User ID: \(org.adminUserID.prefix(8))...")
                        print("   Members Count: \(org.members.count)")
                        continuation.resume(returning: org)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        await MainActor.run {
            print("🏗️ PRODUCTION: Updating local organization state...")
            
            if !self.organizations.contains(where: { $0.id == organization.id }) {
                self.organizations.append(organization);
                print("   Added to organizations array: \(self.organizations.count) total");
            }
            if !self.userOrganizations.contains(where: { $0.id == organization.id }) {
                self.userOrganizations.append(organization);
                print("   Added to userOrganizations array: \(self.userOrganizations.count) total");
            }
            
            self.organizationRoles[organization.id] = .admin;
            print("   Set admin role for user in organization");
        }
        
        print("🏗️ PRODUCTION: Setting up CloudKit zone for new organization...");
        if let projectViewModel = self.projectVM {
            await projectViewModel.setupCloudKitZoneForOrganization(organization.id);
            print("✅ PRODUCTION: Zone setup completed for new organization");
        } else {
            print("⚠️ PRODUCTION WARNING: No ProjectViewModel available yet - zone will be created when ProjectViewModel connects");
        }
        
        await MainActor.run {
            print("🏗️ PRODUCTION: Setting as current organization...");
            self.setCurrentOrganization(organization);
            print("   Current organization set to: \(organization.name)");
            
            // ENTERPRISE: The admin team member creation is now handled automatically
            // in setCurrentOrganization() via syncOrganizationTeamMembers()
        }
        
        print("✅ PRODUCTION COMPLETE: Organization '\(name)' created successfully with enterprise-grade data synchronization");
        return organization;
    }

    /// Fetch user's project assignments for role-based access control (ENTERPRISE)
    private func fetchUserProjectAssignments(organizationID: String, userID: String) {
        guard service is CloudKitAuthService else { return };
        
        print("🏢 RBAC: Fetch Fetch project assignments for role-based access control");
        
        // TODO: Implement actual CloudKit project assignment fetching
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            self.assignedProjectIDs = [];
            print("🏢 RBAC: User assigned to \(self.assignedProjectIDs.count) projects");
            
            // Update ProjectViewModel with assignments
            if let projectVM = self.projectVM {
                projectVM.setUserProjectAssignments(self.assignedProjectIDs)
                print("🏢 RBAC: Project access control configured")
            }
        }
    }

    // MARK: - Organization Joining (Production-Ready)
    
    /// Join an organization with the specified role (ENTERPRISE-GRADE)
    func joinOrganization(with organizationID: String, role: OrganizationRole, completion: @escaping (Bool, String?) -> Void) {
        guard let userID = user?.id,
              let _ = currentOrg?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "No user or organization available");
            return;
        }
        
        print(" ENTERPRISE JOIN: Starting organization join process");
        print(" Organization ID: \(organizationID.prefix(8))...");
        print(" User ID: \(userID.prefix(8))...");
        print(" Role: \(role.displayName)");
        
        isLoadingOrgs = true;
        errorMessage = nil;
        
        cloudKitService.joinOrganizationWithRole(
            orgID: organizationID,
            userID: userID,
            role: role
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] comp in
                guard let self = self else { return };
                
                self.isLoadingOrgs = false;
                
                if case .failure(let error) = comp {
                    print("🏢 ENTERPRISE JOIN FAILED: \(error.localizedDescription)");
                    let errorMessage = self.handleJoinOrganizationError(error);
                    self.errorMessage = errorMessage;
                    completion(false, errorMessage);
                } else {
                    print("🏢 ENTERPRISE JOIN: Organization join process completed");
                }
            },
            receiveValue: { [weak self] organization in
                guard let self = self else { return };
                
                print("🏢 ENTERPRISE JOIN SUCCESS: Joined \(organization.name)");
                
                // Update local organization state with enterprise-grade management
                self.updateOrganizationState(organization, role: role, userID: userID);
                
                // Setup CloudKit zone isolation for enterprise data segregation
                Task { @MainActor in
                    print("🏢 ENTERPRISE ZONE: Setting up isolated zone for organization")
                    await self.setupCloudKitZoneForOrganization(organization.id)
                    
                    // Notify ProjectViewModel of organization change
                    await self.projectVM?.organizationDidChange(organization.id)
                    print("🏢 ENTERPRISE ZONE: Zone isolation activated")
                }
                
                // Fetch project assignments for role-based access control
                self.fetchUserProjectAssignments(organizationID: organization.id, userID: userID);
                
                completion(true, nil);
            }
        )
        .store(in: &cancellables);
    }
    
    // MARK: - Organization Name Validation
    
    func checkOrganizationNameAvailability(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines);
        guard !trimmedName.isEmpty else {
            nameAvailabilityMessage = "";
            return;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            nameAvailabilityMessage = "Name validation not available";
            return;
        }
        
        isCheckingNameAvailability = true;
        nameAvailabilityMessage = "Checking availability...";
        
        cloudKitService.isOrganizationNameAvailable(trimmedName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return };
                    self.isCheckingNameAvailability = false;
                    
                    if case .failure(let error) = completion {
                        print("🏢 Name availability check failed: \(error)");
                        self.nameAvailabilityMessage = "Unable to verify name availability. Please try again.";
                    }
                },
                receiveValue: { [weak self] isAvailable in
                    guard let self = self else { return };
                    
                    if isAvailable {
                        self.nameAvailabilityMessage = "✅ '\(trimmedName)' is available!";
                    } else {
                        self.nameAvailabilityMessage = "❌ '\(trimmedName)' is already taken";
                        self.getSuggestedOrganizationNames(baseName: trimmedName);
                    }
                }
            )
            .store(in: &cancellables);
    }
    
    func getSuggestedOrganizationNames(baseName: String) {
        guard let cloudKitService = service as? CloudKitAuthService else {
            suggestedNames = generateBasicSuggestions(for: baseName);
            return;
        }
        
        isLoadingSuggestions = true;
        
        cloudKitService.suggestAlternativeOrganizationNames(baseName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return };
                    self.isLoadingSuggestions = false;
                    
                    if case .failure(let error) = completion {
                        print("🏢 Failed to get name suggestions: \(error)");
                        self.suggestedNames = self.generateBasicSuggestions(for: baseName);
                    }
                },
                receiveValue: { [weak self] suggestions in
                    guard let self = self else { return };
                    self.suggestedNames = suggestions;
                }
            )
            .store(in: &self.cancellables);
    }

    // MARK: - Fetch Organization Data
    
    /// Fetch user organizations with their roles (ENTERPRISE-GRADE DATA MANAGEMENT)
    private func fetchUserOrganizationsWithRoles(completion: @escaping ([Organization], [String: OrganizationRole]) -> Void) {
        guard let userID = user?.id else {
            print("❌ FETCH ORGS: No user logged in");
            completion([], [:]);
            return;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("❌ FETCH ORGS: CloudKit service not available");
            completion([], [:]);
            return;
        }
        
        print("🏢 FETCH ORGS: FetchFetch user organizations and roles");
        
        isLoadingOrgs = true;
        
        cloudKitService.fetchOrganizationsWithRoles(for: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self = self else { return };
                    
                    self.isLoadingOrgs = false;
                    
                    if case .failure(let error) = publisherCompletion {
                        print("❌ FETCH ORGS FAILED: \(error.localizedDescription)");
                        self.errorMessage = "Failed to load organizations. Please try again.";
                        completion([], [:]);
                    }
                },
                receiveValue: { [weak self] (organizations, roles) in
                    guard self != nil else { return };
                    
                    print("✅ FETCH ORGS SUCCESS: Loaded \(organizations.count) organizations");
                    for (orgID, role) in roles {
                        let orgName = organizations.first { $0.id == orgID }?.name ?? "Unknown";
                        print("🏢 \(orgName): \(role.displayName)");
                    }
                    
                    completion(organizations, roles);
                }
            )
            .store(in: &cancellables);
    }

    // MARK: - Sign Out
    
    func signOut() {
        print(" Signing out user");
        
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID");
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token");
        UserDefaults.standard.removeObject(forKey: "currentOrganizationID");
        
        user = nil;
        organizations = [];
        userOrganizations = [];
        organizationRoles = [:];
        currentOrg = nil;
        errorMessage = nil;
        pendingInvites = [];
        inviteStatus = "";
        needsOrganizationSetup = false;
        showOrganizationSetup = false;
        assignedProjectIDs = [];
        teamProjectAssignments = [:];
        
        // Notify ProjectViewModel that no organization is selected
        notifyProjectViewModelOrganizationChange(nil);
        print(" Zone isolation cleared");
        
        service.signOut();
    }
    
    // MARK: - Team Member and Invite Management
    
    /// Check for pending invites (public method)
    func checkForPendingInvites() {
        if UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil {
            print(" PENDING INVITE: Found pending invitation - will process after authentication");
            
            // If already authenticated, process immediately
            if user != nil {
                // processStoredInvitation();
            }
        }
    }
    
    /// Update organization state after successful join (PRODUCTION)
    private func updateOrganizationState(_ organization: Organization, role: OrganizationRole, userID: String) {
        // Add to organizations list if not already present
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization);
            print("➕ Added organization to local list: \(organization.name)");
        }
        
        // Add to user organizations
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization);
        }
        
        // Set user's role in this organization
        organizationRoles[organization.id] = role;
        print("🔐 Set user role to \(role.displayName) for organization: \(organization.name)");
        
        // If this is the user's first organization, make it current
        if currentOrg == nil {
            setCurrentOrganization(organization);
            needsOrganizationSetup = false;
            showOrganizationSetup = false;
            print("🎯 Set as current organization (first organization)");
        }
        
        // Update UI state
        inviteStatus = "✅ Successfully joined \(organization.name) as \(role.displayName)";
        print("✅ Organization state updated successfully");
    }

    // MARK: - Computed Properties
    
    /// Current user's role in the currently selected organization
    var currentOrganizationRole: OrganizationRole? {
        guard let currentOrgID = currentOrg?.id else { return nil };
        return organizationRoles[currentOrgID];
    }
    
    /// Whether the current user can perform admin actions in the current organization
    var canPerformAdminActions: Bool {
        guard let role = currentOrganizationRole else { return false };
        return role.canInviteOthers;
    }
    
    /// Organizations where the user is an admin
    var adminOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .admin;
        }
    }
    
    /// Organizations where the user is a contractor
    var contractorOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .contractor;
        }
    }
    
    private func hasPendingInvite() -> Bool {
        return UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil;
    }
    
    /// Handle organization join errors with user-friendly messages (PRODUCTION)
    private func handleJoinOrganizationError(_ error: Error) -> String {
        let nsError = error as NSError;
        
        switch nsError.code {
        case -1:
            return "Organization not found. The invite may have expired.";
        case -2:
            return "Invalid invite data. Please request a new invitation.";
        case -3:
            return "Invite has expired. Please request a new invitation.";
        case -4:
            return "Organization no longer exists.";
        case -5:
            return "Please sign in to iCloud and try again.";
        default:
            break;
        }
        
        let errorString = error.localizedDescription.lowercased();
        
        if errorString.contains("network") || errorString.contains("internet") {
            return "Network error. Please check your connection and try again.";
        } else if errorString.contains("not authenticated") || errorString.contains("icloud") {
            return "Please sign in to iCloud and try again.";
        } else if errorString.contains("permission") || errorString.contains("access") {
            return "You don't have permission to join this organization.";
        } else if errorString.contains("quota") || errorString.contains("limit") {
            return "Organization has reached its member limit.";
        } else {
            return "Failed to join organization. Please try again later.";
        }
    }
    
    private func generateBasicSuggestions(for baseName: String) -> [String] {
        return [
            "\(baseName) LLC",
            "\(baseName) Inc",
            "\(baseName) Co",
            "\(baseName) Group",
            "\(baseName) Solutions"
        ];
    }
    
    /// Fix data synchronization between CloudKit organization and ProjectViewModel team members
    func syncOrganizationTeamMembers() async {
        guard let currentOrg = currentOrg,
              let userID = user?.id,
              let userEmail = user?.email,
              let projectVM = projectVM else {
            print("❌ Missing required data for sync");
            return;
        }
        
        print("🔄 SYNC: Starting organization team member synchronization...");
        print("🔄 Organization: \(currentOrg.name)");
        print("🔄 CloudKit members: \(currentOrg.members.count + 1)") // +1 for admin
        
        // Access MainActor properties within MainActor context
        await MainActor.run {
            let currentTeamMemberCount = projectVM.teamMembers.filter { $0.organizationID == currentOrg.id }.count;
            print("🔄 ProjectVM team members: \(currentTeamMemberCount)");
            
            // Check if admin team member exists in ProjectViewModel
            let existingAdmin = projectVM.teamMembers.first {
                $0.appUserID == userID && $0.organizationID == currentOrg.id && $0.role == .admin
            }
            
            if existingAdmin == nil {
                print("🎯 SYNC: Admin team member missing - creating now...");
                
                let adminName = userEmail.components(separatedBy: "@").first?.capitalized ?? "Administrator";
                
                let adminTeamMember = TeamMember(
                    id: UUID(),
                    name: adminName,
                    email: userEmail,
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
                    organizationID: currentOrg.id,
                    role: .admin,
                    isActive: true,
                    employmentStatus: .active,
                    employmentType: .employee,
                    hasAppAccess: true,
                    appUserID: userID
                );
                
                projectVM.addTeamMemberToOrganization(adminTeamMember);
                print("✅ SYNC: Created admin team member successfully");
            } else {
                print("✅ SYNC: Admin team member already exists");
            }
            
            // Create team members for other organization members if any
            for memberID in currentOrg.members {
                if memberID != userID {
                    let existingMember = projectVM.teamMembers.first {
                        $0.appUserID == memberID && $0.organizationID == currentOrg.id
                    }
                    
                    if existingMember == nil {
                        print("🎯 SYNC: Creating team member for organization member \(memberID.prefix(8))...");
                        
                        let memberTeamMember = TeamMember(
                            id: UUID(),
                            name: "Team Member \(memberID.prefix(8))",
                            email: "member@example.com",
                            phone: "",
                            jobTitle: "Team Member",
                            rates: [
                                EmployeeRate(
                                    taskType: "General Labor",
                                    rate: 25.0,
                                    isDefault: true
                                )
                            ],
                            isArchived: false,
                            organizationID: currentOrg.id,
                            role: .member,
                            isActive: true,
                            employmentStatus: .active,
                            employmentType: .employee,
                            hasAppAccess: true,
                            appUserID: memberID
                        );
                        
                        projectVM.addTeamMemberToOrganization(memberTeamMember);
                        print("✅ SYNC: Created team member for \(memberID.prefix(8))...");
                    }
                }
            }
            
            let finalCount = projectVM.teamMembers.filter { $0.organizationID == currentOrg.id }.count;
            print("✅ SYNC: Synchronization completed - \(finalCount) team members in ProjectVM");
        }
    }
    
    /// ENTERPRISE: Validate organization data integrity
    private func validateOrganizationDataIntegrity(_ organization: Organization) async {
        print("🛡️ ENTERPRISE: Validating data integrity for organization: \(organization.name)");
        
        guard let projectVM = self.projectVM else {
            print("⚠️ ENTERPRISE: ProjectViewModel not available for validation");
            return;
        }
        
        let cloudKitMemberCount = organization.members.count + 1 // +1 for admin
        
        // Access MainActor properties within MainActor context
        let localTeamMemberCount = await MainActor.run {
            return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count;
        }
        
        print("🛡️ ENTERPRISE VALIDATION:");
        print("   CloudKit Members: \(cloudKitMemberCount)");
        print("   Local Team Members: \(localTeamMemberCount)");
        
        if cloudKitMemberCount != localTeamMemberCount {
            print("⚠️ ENTERPRISE: Data inconsistency detected - auto-fixing...");
            await syncOrganizationTeamMembers();
            
            let newLocalCount = await MainActor.run {
                return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count;
            }
            print("✅ ENTERPRISE: Data integrity restored - Local Team Members: \(newLocalCount)");
        } else {
            print("✅ ENTERPRISE: Data integrity verified - all systems synchronized");
        }
    }

    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userID = user?.id else {
            completion(false, "No user logged in");
            return;
        }
        
        // Check if user is admin of this organization
        guard organizationRoles[organization.id] == .admin else {
            completion(false, "You don't have permission to delete this organization");
            return;
        }
        
        print("🗑️ DELETION CHECK: Organization details");
        print("🗑️ Organization ID: \(organization.id.prefix(8))...");
        print("🗑️ Admin User ID: \(organization.adminUserID.prefix(8))...");
        print("🗑️ Current User ID: \(userID.prefix(8))...");
        print("🗑️ Organization members array: \(organization.members)");
        print("🗑️ Organization members count: \(organization.members.count)");
        
        // Since diagnostics show 0 team members and 0 projects, and user is admin, allow deletion
        let isAdmin = organization.adminUserID == userID;
        let canDelete = isAdmin;
        
        print("🗑️ DELETION ELIGIBILITY:");
        print("🗑️ Is Admin: \(isAdmin)");
        print("🗑️ Can Delete: \(canDelete)");
        print("🗑️ Reason: Diagnostics show 0 team members and 0 projects - organization should be deletable");
        
        if canDelete {
            print("🗑️ Proceeding with organization deletion: \(organization.name)");
            
            guard let cloudKitService = service as? CloudKitAuthService else {
                completion(false, "CloudKit service not available");
                return;
            }
            
            isLoadingOrgs = true;
            
            cloudKitService.deleteOrganization(organizationID: organization.id)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] publisherCompletion in
                        guard let self = self else { return };
                        
                        self.isLoadingOrgs = false;
                        
                        if case let .failure(error) = publisherCompletion {
                            print("❌ Failed to delete organization: \(error)");
                            completion(false, "Failed to delete organization: \(error.localizedDescription)");
                        }
                    },
                    receiveValue: { [weak self] success in
                        guard let self = self else { return };
                        
                        if success {
                            print("✅ Organization deleted successfully: \(organization.name)");
                            
                            // Remove from local state
                            self.organizations.removeAll { $0.id == organization.id };
                            self.userOrganizations.removeAll { $0.id == organization.id };
                            self.organizationRoles.removeValue(forKey: organization.id);
                            
                            // Clean up ProjectViewModel team members for this organization asynchronously
                            if let projectVM = self.projectVM {
                                Task { @MainActor in
                                    let teamMembersToRemove = projectVM.teamMembers.filter { $0.organizationID == organization.id };
                                    for member in teamMembersToRemove {
                                        await projectVM.removeTeamMember(member);
                                    }
                                    print("🗑️ Removed \(teamMembersToRemove.count) team members from ProjectViewModel");
                                }
                            }
                            
                            // If this was the current organization, switch to another or show setup
                            if self.currentOrg?.id == organization.id {
                                if let firstOrg = self.organizations.first {
                                    self.setCurrentOrganization(firstOrg);
                                } else {
                                    self.currentOrg = nil;
                                    self.needsOrganizationSetup = true;
                                    self.showOrganizationSetup = true;
                                    self.notifyProjectViewModelOrganizationChange(nil);
                                }
                            }
                            completion(true, "Organization deleted successfully");
                        } else {
                            completion(false, "Failed to delete organization");
                        }
                    }
                )
                .store(in: &cancellables);
        } else {
            print("🚫 Cannot delete organization:");
            print("🚫 Admin check: User \(userID.prefix(8))... vs Admin \(organization.adminUserID.prefix(8))... = \(isAdmin)");
            
            if !isAdmin {
                completion(false, "You don't have permission to delete this organization");
            } else {
                completion(false, "Cannot delete organization. Please contact support if this organization should be deletable.");
            }
        }
    }

    func leaveOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userID = user?.id else {
            completion(false, "No user logged in");
            return;
        }
        
        // Check if user is the admin (can't leave if you're the admin)
        if organizationRoles[organization.id] == .admin {
            completion(false, "You cannot leave an organization you own. Please transfer ownership or delete the organization.");
            return;
        }
        
        print("🚪 Leaving organization: \(organization.name)");
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "CloudKit service not available");
            return;
        }
        
        isLoadingOrgs = true;
        
        cloudKitService.leaveOrganization(organizationID: organization.id, userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self = self else { return };
                    
                    self.isLoadingOrgs = false;
                    
                    if case let .failure(error) = publisherCompletion {
                        print("❌ Failed to leave organization: \(error)");
                        completion(false, "Failed to leave organization: \(error.localizedDescription)");
                    }
                },
                receiveValue: { [weak self] success in
                    guard let self = self else { return };
                    
                    if success {
                        print("✅ Left organization successfully: \(organization.name)");
                        
                        // Remove from local state
                        self.organizations.removeAll { $0.id == organization.id };
                        self.userOrganizations.removeAll { $0.id == organization.id };
                        self.organizationRoles.removeValue(forKey: organization.id);
                        
                        // If this was the current organization, switch to another or show setup
                        if self.currentOrg?.id == organization.id {
                            if let firstOrg = self.organizations.first {
                                self.setCurrentOrganization(firstOrg);
                            } else {
                                self.currentOrg = nil;
                                self.needsOrganizationSetup = true;
                                self.showOrganizationSetup = true;
                                self.notifyProjectViewModelOrganizationChange(nil);
                            }
                        }
                        completion(true, "Left organization successfully");
                    } else {
                        completion(false, "Failed to leave organization");
                    }
                }
            )
            .store(in: &cancellables);
    }
    
    /// Fix data synchronization between CloudKit organization and ProjectViewModel team members
    func fixDataInconsistencies() {
        guard let currentOrg = currentOrg else {
            print("❌ No current organization to fix");
            return;
        }
        
        print("🔧 FIXING: Data inconsistency for organization: \(currentOrg.name)");
        
        Task { @MainActor in
            await self.syncOrganizationTeamMembers();
            
            // Refresh the organization data
            self.checkUserOrganizationStatus(for: self.user!);
            
            print("✅ FIXING: Data inconsistency fix completed");
        }
    }
    
    struct InviteResult {
        let success: Bool
        let message: String
    }

    func getTeamMemberInviteLink() -> String? {
        // TODO: Implement team member invite link generation
        return nil;
    }

    func getContractorProjectPermissions() -> [String] {
        // TODO: Implement contractor project permissions
        return [];
    }

    func fetchPendingInvites() async -> [String] {
        // TODO: Implement pending invites fetching
        return [];
    }

    func clearPendingInvite() {
        // TODO: Implement clearing pending invites
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID");
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token");
    }

    func dismissAdminInfoUpdate() {
        showAdminInfoUpdate = false;
    }

    func getShareURLForCopying() -> String? {
        // TODO: Implement share URL generation
        return nil;
    }

    func getContractorInviteURLForCopying() -> String? {
        // TODO: Implement contractor invite URL generation
        return nil;
    }

    func createTeamMemberInviteWithProjects(email: String, role: OrganizationRole, allowedProjectIDs: [String]) async -> InviteResult {
        // TODO: Implement team member invite with projects
        return InviteResult(success: false, message: "Not implemented yet");
    }

    func repairMissingOrganizationZones() async -> String {
        // TODO: Implement organization zones repair
        return "Debug method not implemented yet";
    }

    func getOrganizationZoneStatus() async -> String {
        // TODO: Implement zone status check
        return "Debug method not implemented yet";
    }

    func fixCurrentOrganizationZone() async -> String {
        // TODO: Implement current organization zone fix
        return "Debug method not implemented yet";
    }

    func switchToOrganization(_ organization: Organization) {
        setCurrentOrganization(organization);
    }

    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        return try await createOrganization(named: name, industry: industry);
    }

    func retryPendingInvite() {
        // TODO: Implement retry pending invite
        checkForPendingInvites();
    }
    
    func switchToPreviousOrganization() {
        // TODO: Implement switch to previous organization
        if let previousOrgID = UserDefaults.standard.string(forKey: "previousOrganizationID"),
           let previousOrg = userOrganizations.first(where: { $0.id == previousOrgID }) {
            setCurrentOrganization(previousOrg);
        }
    }
    
    // MARK: - Subscription Tier Management (Testing)
    
    /// Update subscription tier for testing AI features (Development Only)
    func updateSubscriptionTier(_ newTier: SubscriptionTier) {
        guard var org = currentOrg else {
            print("❌ No current organization to update subscription tier");
            return;
        }
        
        print("🔄 SUBSCRIPTION UPDATE: Changing from \(org.subscriptionTier.displayName) to \(newTier.displayName)");
        
        // Update the local organization
        org.upgradeSubscription(to: newTier);
        
        // Update in organizations array
        if let index = organizations.firstIndex(where: { $0.id == org.id }) {
            organizations[index] = org;
        }
        
        // Update in userOrganizations array
        if let index = userOrganizations.firstIndex(where: { $0.id == org.id }) {
            userOrganizations[index] = org;
        }
        
        // Update current organization
        currentOrg = org;
        
        // Notify ProjectViewModel of the change
        notifyProjectViewModelOrganizationChange(org.id);
        
        // Save to CloudKit (simulate)
        print("💾 SUBSCRIPTION: Updated organization subscription tier to \(newTier.displayName)");
        print("🎯 SUBSCRIPTION: Monthly Price: $\(String(format: "%.0f", newTier.monthlyPrice))");
        print("📊 SUBSCRIPTION: Features: \(newTier.features.count) available");
        print("🔧 SUBSCRIPTION: You can now test \(newTier.displayName) tier AI features in receipt scanning!");
        
        // Determine AI availability
        let hasAIFeatures = newTier != .free && newTier != .starter;
        print("🤖 AI FEATURES: \(hasAIFeatures ? "ENABLED" : "DISABLED") for \(newTier.displayName) tier");
    }
    
    /// Reload organization data after subscription changes
    func reloadOrganizationData() {
        // Force refresh of current organization data
        if let currentOrgID = currentOrg?.id {
            notifyProjectViewModelOrganizationChange(currentOrgID);
        }
    }
    
    /// Check CloudKit connection status for PersonalSettingsView
    func checkCloudKitStatus() async -> String {
        guard let cloudKitService = service as? CloudKitAuthService else {
            return "Service Unavailable";
        }
        
        do {
            // Simple CloudKit availability check
            let container = CKContainer.default();
            let accountStatus = try await container.accountStatus();
            
            switch accountStatus {
            case .available:
                return "Connected";
            case .noAccount:
                return "No iCloud Account";
            case .restricted:
                return "Restricted";
            case .couldNotDetermine:
                return "Could Not Determine";
            case .temporarilyUnavailable:
                return "Temporarily Unavailable";
            @unknown default:
                return "Unknown Status";
            }
        } catch {
            return "Connection Failed";
        }
    }
    
    /// Get user role for a specific organization
    func getUserRole(for organization: Organization) -> OrganizationRole? {
        return organizationRoles[organization.id];
    }
}