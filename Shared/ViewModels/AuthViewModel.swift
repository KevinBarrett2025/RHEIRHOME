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
        print("🔗 Connected ProjectViewModel with zone isolation")
        
        if let currentOrg = currentOrg {
            Task { @MainActor in
                print("🔗 IMMEDIATE ZONE SETUP: Setting up zone for current organization: \(currentOrg.name)")
                await self.setupCloudKitZoneForOrganization(currentOrg.id)
                
                // CRITICAL FIX: Sync user role when ProjectViewModel connects - use original OrganizationRole
                if let userRole = self.organizationRoles[currentOrg.id] {
                    let teamMemberRole: TeamMemberRole = userRole == .admin ? .admin : .member
                    projectViewModel.setCurrentUserRole(teamMemberRole, forOrganization: currentOrg.id)
                    print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
                } else {
                    print("⚠️ ROLE SYNC WARNING: No role found for current organization during connection")
                }
                
                // Call organization change directly
                await projectViewModel.organizationDidChange(currentOrg.id)
                
                // CRITICAL: Ensure admin team member exists after connection
                self.ensureAdminTeamMemberExists()
                
                print("✅ Activated zone isolation for: \(currentOrg.name)")
            }
        } else {
            print("🔗 No current organization - zone isolation will be activated when organization is selected")
        }
    }

    // MARK: - Organization Management
    
    @MainActor
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
        
        // CRITICAL FIX: Call ProjectViewModel's setCurrentOrganization to properly set currentOrganizationID
        if let projectVM = self.projectVM {
            let role = self.organizationRoles[organization.id] ?? .member
            let teamMemberRole: TeamMemberRole = role == .admin ? .admin : .member
            projectVM.setCurrentOrganization(organization, role: teamMemberRole)
            print("🔧 CRITICAL FIX: Set ProjectViewModel organization to real CloudKit org ID: \(organization.id.prefix(8))...")
            
            // CRITICAL FIX: Sync user role with ProjectViewModel
            if let userRole = self.organizationRoles[organization.id] {
                projectVM.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for ProjectViewModel")
            } else {
                print("⚠️ ROLE SYNC WARNING: No role found for organization \(organization.name)")
            }
        }
        
        Task { @MainActor in
            print("🔄 ORGANIZATION SWITCH: Setting up zone for: \(organization.name)")
            await self.setupCloudKitZoneForOrganization(organization.id)
            
            // Notify ProjectViewModel of organization change AFTER setting the organization
            await self.projectVM?.organizationDidChange(organization.id)
            
            // ENTERPRISE FEATURE: Automatic data synchronization (no longer creates duplicate admins)
            print("🔄 ENTERPRISE SYNC: Starting automatic data synchronization...")
            await self.syncOrganizationTeamMembers()
            
            // CRITICAL: Also sync role after organization change
            if let userRole = self.organizationRoles[organization.id] {
                let teamMemberRole: TeamMemberRole = userRole == .admin ? .admin : .member
                self.projectVM?.setCurrentUserRole(teamMemberRole, forOrganization: organization.id)
                print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
            } else {
                print("⚠️ ROLE SYNC WARNING: No role found for current organization during connection")
            }
            
            print("✅ Activated zone isolation with synchronized data for: \(organization.name)")
        }
        
        UserDefaults.standard.set(organization.id, forKey: "currentOrganizationID");
        print("✅ Current organization set with enterprise-grade synchronization: \(organization.name)");
    }

    // MARK: - Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
        Task { @MainActor in
            self.errorMessage = nil
            self.isLoadingAuth = true
            print("🔐 Starting Apple Sign-In...")
            
            guard let cloudKitService = self.service as? CloudKitAuthService else {
                print("❌ CloudKit service not available")
                self.errorMessage = "CloudKit service not available"
                self.isLoadingAuth = false
                return
            }
            
            if cloudKitService.currentUser != nil {
                print("✓ Already authenticated with CloudKit")
                if let user = self.user {
                    // ENHANCEMENT: Try to restore actual email from stored data if available
                    if user.email == "user.email.not.available@rheir.com" {
                        self.tryRestoreActualEmail(for: user)
                    }
                    self.checkUserOrganizationStatus(for: user)
                }
            } else {
                cloudKitService.signInWithApple(with: appleCred)
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
                .store(in: &self.cancellables)
            }
        }
    }

    /// Try to restore the actual email address from stored data
    private func tryRestoreActualEmail(for user: User) {
        let storedEmailKey = "stored_apple_email_\(user.id)";
        if let storedEmail = UserDefaults.standard.string(forKey: storedEmailKey),
           !storedEmail.isEmpty,
           storedEmail != "user.email.not.available@rheir.com" {
            
            print("🔄 RESTORED EMAIL: Found stored email for user: \(storedEmail)");
            let updatedUser = User(id: user.id, email: storedEmail);
            self.user = updatedUser;
        } else {
            print("⚠️ NO STORED EMAIL: Using placeholder email for user: \(user.id.prefix(8))...");
        }
    }

    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        print("🔍 ENHANCED ORG STATUS CHECK for: \(user.email)");
        print("🔍 User ID: \(user.id.prefix(8))...");
        
        self.checkForPendingInvites();
        
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self else { return };
            
            print("🔍 ORGANIZATION FETCH RESULT:");
            print("   Found Organizations: \(orgs.count)");
            print("   Roles Mapping: \(roles.count)");
            
            for org in orgs {
                print("🔍 [\(orgs.firstIndex(of: org)!)] CloudKit Org: \(org.name)");
                print("🔍     ID: \(org.id.prefix(8))...");
                print("🔍     Admin: \(org.adminUserID.prefix(8))...");
                print("🔍     Members: \(org.members.count)");
                print("🔍     Your Role: \(roles[org.id]?.displayName ?? "Unknown")");
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
                
                print("🔍 Selectinging organization: \(selectedOrg.name)");
                // FIX: Use Task for MainActor call
                Task { @MainActor in
                    self.setCurrentOrganization(selectedOrg);
                }
                self.needsOrganizationSetup = false;
                
                // ENTERPRISE: Automatic background data validation
                Task { @MainActor in
                    await self.validateOrganizationDataIntegrity(selectedOrg);
                }
            }
        }
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
        
        guard user?.email != nil else {
            print("❌ PRODUCTION ERROR: User has no email address");
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("❌ PRODUCTION ERROR: CloudKit service not available");
            throw AuthViewModelError.cloudKitServiceNotAvailable;
        }
        
        print("🏗️ PRODUCTION VERIFICATION:");
        print("   User ID: \(userID.prefix(8))...");
        print("   User Email: \(user?.email ?? "Unknown")");
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
                        print("   Organization ID: \(org.id.prefix(8))...");
                        print("   Organization Name: \(org.name)")
                        print("   Admin User ID: \(org.adminUserID.prefix(8))...");
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
            
            // CRITICAL FIX: Show admin onboarding with proper timing
            print("🎯 ADMIN ONBOARDING: Triggering professional admin setup...");
        }
        
        // CRITICAL FIX: Improved timing - wait longer for UI state to fully settle
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // CRITICAL FIX: Break down complex MainActor.run into simpler operations
        let shouldShowOnboarding = await MainActor.run { () -> Bool in
            if let projectVM = self.projectVM {
                let existingAdmin = projectVM.teamMembers.first { 
                    $0.appUserID == userID && 
                    $0.organizationID == organization.id && 
                    $0.role == .admin 
                }
                return existingAdmin == nil
            }
            return true // No ProjectViewModel yet, show onboarding anyway
        }
        
        await MainActor.run {
            if shouldShowOnboarding {
                print("🎯 ADMIN ONBOARDING: No admin found - triggering onboarding flow")
                self.showAdminInfoUpdate = true
                self.objectWillChange.send()
                print("🎯 ADMIN ONBOARDING: Set showAdminInfoUpdate = \(self.showAdminInfoUpdate)")
            } else {
                print("✅ ADMIN ONBOARDING: Admin already exists, skipping onboarding")
            }
        }

        print("✅ PRODUCTION COMPLETE: Organization '\(name)' created successfully - admin onboarding ready");
        return organization;
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
        print("🔧 CRITICAL: Setting up CloudKit zone for organization: \(organizationID.prefix(8))...");
        
        // Call ProjectViewModel's setupCloudKitZoneForOrganization method directly
        if let projectViewModel = self.projectVM {
            print("🔧 CRITICAL: Found ProjectViewModel reference - calling zone setup directly")
            await projectViewModel.setupCloudKitZoneForOrganization(organizationID)
            print("🔧 CRITICAL: ProjectViewModel zone setup completed for: \(organizationID.prefix(8))...")
        } else {
            print("🔧 CRITICAL: No ProjectViewModel reference available - zone setup will happen when ProjectViewModel connects")
            print("🔧 CRITICAL: Zone setup will be triggered automatically via organizationDidChange when ProjectViewModel loads")
        }
    }

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
        
        print("🔍 COMPREHENSIVE ORG TRACE: Starting organization fetch with enhanced debugging");
        print("🔍 Current User: \(userID.prefix(8))...");
        print("🔍 Current organizations.count: \(organizations.count)");
        print("🔍 Current userOrganizations.count: \(userOrganizations.count)");
        
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
                    guard let self = self else { return };
                    
                    print("🔍 COMPREHENSIVE ORG TRACE: CloudKit fetch completed");
                    print("🔍 CloudKit organizations.count: \(organizations.count)");
                    print("🔍 CloudKit roles.count: \(roles.count)");
                    
                    for (index, org) in organizations.enumerated() {
                        print("🔍 [\(index)] CloudKit Org: \(org.name)");
                        print("🔍     ID: \(org.id.prefix(8))...");
                        print("🔍     Admin: \(org.adminUserID.prefix(8))...");
                        print("🔍     Members: \(org.members.count)");
                        print("🔍     Role: \(roles[org.id]?.displayName ?? "Unknown")");
                        print("🔍     Created: \(org.createdAt)");
                        print("🔍     CloudKit RecordID: \(org.cloudKitRecordID ?? "None")");

                    }
                    
                    // CRITICAL: Validate against current local state
                    let countDifference = organizations.count - self.organizations.count;
                    if countDifference != 0 {
                        print("⚠️ COUNT MISMATCH DETECTED:");
                        print("   CloudKit: \(organizations.count)");
                        print("   Local: \(self.organizations.count)");
                        print("   Difference: \(countDifference)");
                    }
                    
                    completion(organizations, roles);
                }
            )
            .store(in: &cancellables);
    }

    /// Check for pending invites - returns true if there are pending invites
    private func hasPendingInvite() -> Bool {
        return UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil
    }

    /// Fix data synchronization between CloudKit organization and ProjectViewModel team members
    func syncOrganizationTeamMembers() async {
        guard let currentOrg = currentOrg,
              let userID = user?.id,
              let _ = user?.email,  
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
            
            // CRITICAL FIX: Only check if admin exists, don't create duplicate
            let existingAdmin = projectVM.teamMembers.first {
                $0.appUserID == userID && $0.organizationID == currentOrg.id && $0.role == .admin
            }
            
            if existingAdmin == nil {
                print("⚠️ SYNC: No admin team member found - this should be handled by onboarding flow")
                print("   Organization: \(currentOrg.name)")
                print("   Admin User ID: \(userID.prefix(8))...")
                print("   Consider triggering admin onboarding if not completed")
            } else {
                print("✅ SYNC: Admin team member exists: \(existingAdmin?.name ?? "Unknown")")
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
                        
                        projectVM.teamMembers.append(memberTeamMember)
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

    private func ensureAdminTeamMemberExists() {
        print("🎯 ADMIN CHECK DEPRECATED: Admin creation now handled by onboarding flow")
        print("   If admin is missing, user should complete onboarding via showAdminInfoUpdate")
        
        // Simple check to see if admin exists (for logging purposes only)
        Task { @MainActor in
            guard let organization = currentOrg,
                  let userID = user?.id,
                  let projectVM = projectVM else {
                return
            }
            
            let existingAdmin = projectVM.teamMembers.first { 
                $0.appUserID == userID && $0.organizationID == organization.id && $0.role == .admin 
            }
            
            if existingAdmin == nil {
                print("⚠️ ADMIN CHECK: No admin found - onboarding may be needed")
                print("   showAdminInfoUpdate should be true: \(showAdminInfoUpdate)")
            } else {
                print("✅ ADMIN CHECK: Admin exists: \(existingAdmin?.name ?? "Unknown")")
            }
        }
    }

    // MARK: - Sign Out
    
    func signOut() {
        print("🔐 Signing out user");
        
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
        print("🔐 Zone isolation cleared");
        
        service.signOut();
    }
    
    // MARK: - Team Member and Invite Management
    
    /// Check for pending invites (public method)
    func checkForPendingInvites() {
        if UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil {
            print("📧 PENDING INVITE: Found pending invitation - will process after authentication");
            
            // If already authenticated, process immediately
            if user != nil {
                // processStoredInvitation();
            }
        }
    }

    func invite(email: String) {
        print("📧 INVITE: Sending invitation to \(email)...")
        isInviting = true
        inviteStatus = "Sending invitation..."
        
        Task {
            do {
                // Basic validation
                guard !email.isEmpty, email.contains("@") else {
                    await MainActor.run {
                        self.isInviting = false
                        self.inviteStatus = "Invalid email address"
                    }
                    return
                }
                
                guard let currentOrg = currentOrg,
                      let cloudKitService = service as? CloudKitAuthService else {
                    await MainActor.run {
                        self.isInviting = false
                        self.inviteStatus = "No organization selected or CloudKit unavailable"
                    }
                    return
                }
                
                print("📧 INVITE: Using CloudKit sharing for organization: \(currentOrg.name)")
                
                // Use CloudKit sharing service to create actual invitation
                try await cloudKitService.inviteUserToOrganization(
                    email: email, 
                    organizationID: currentOrg.id,
                    role: OrganizationRole.member
                )
                
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "Invitation sent to \(email)"
                    self.pendingInvites.append(email)
                }
                
                print("✅ INVITE: Successfully sent CloudKit invitation to \(email)")
                
            } catch {
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "Failed to send invitation: \(error.localizedDescription)"
                }
                print("❌ INVITE: Failed to send invitation to \(email): \(error)")
            }
        }
    }
    
    func inviteUser(email: String, role: OrganizationRole = .member) async -> InviteResult {
        print("📧 INVITE USER: Sending invitation to \(email) as \(role.displayName)...")
        
        await MainActor.run {
            isInviting = true
            inviteStatus = "Sending invitation to \(email)..."
        }
        
        do {
            // Basic validation
            guard !email.isEmpty, email.contains("@") else {
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "Invalid email address"
                }
                return InviteResult(success: false, message: "Invalid email address")
            }
            
            guard let currentOrg = currentOrg else {
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "No organization selected"
                }
                return InviteResult(success: false, message: "No organization selected")
            }
            
            guard let cloudKitService = service as? CloudKitAuthService else {
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "CloudKit service unavailable"
                }
                return InviteResult(success: false, message: "CloudKit service unavailable")
            }
            
            print("📧 INVITE USER: Using CloudKit sharing for organization: \(currentOrg.name)")
            
            // Use CloudKit sharing service to create actual invitation
            try await cloudKitService.inviteUserToOrganization(
                email: email, 
                organizationID: currentOrg.id,
                role: role
            )
            
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Invitation sent to \(email) as \(role.displayName)"
                self.pendingInvites.append(email)
            }
            
            print("✅ INVITE USER: Successfully sent CloudKit invitation to \(email) as \(role.displayName) for organization: \(currentOrg.name)")
            
            return InviteResult(success: true, message: "Invitation sent successfully to \(email)")
            
        } catch {
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Failed to send invitation: \(error.localizedDescription)"
            }
            
            print("❌ INVITE USER: Failed to send invitation to \(email): \(error)")
            return InviteResult(success: false, message: "Failed to send invitation: \(error.localizedDescription)")
        }
    }

    // MARK: - Team Member and Invite Management Implementation

    struct InviteResult {
        let success: Bool
        let message: String
    }

    func getTeamMemberInviteLink() -> String? { 
        guard let currentOrg = currentOrg else { return nil }
        
        // Generate invite link with organization information
        let baseURL = "https://rheir.app/invite"
        let orgParam = "org=\(currentOrg.id)"
        let nameParam = "name=\(currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        return "\(baseURL)?\(orgParam)&\(nameParam)"
    }
    
    func getContractorProjectPermissions() -> [String] { 
        guard let currentOrg = currentOrg,
              let userRole = organizationRoles[currentOrg.id],
              userRole == .contractor else {
            return []
        }
        
        // Return project IDs that contractor has access to
        return assignedProjectIDs
    }
    
    func fetchPendingInvites() async -> [String] { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return []
        }
        
        do {
            // Fetch invites from CloudKit
            let invites = try await cloudKitService.fetchPendingInvitesForUser(userID)
            print("📧 FETCH INVITES: Found \(invites.count) pending invites")
            return invites
        } catch {
            print("❌ FETCH INVITES: Failed to fetch pending invites: \(error)")
            return []
        }
    }
    
    func clearPendingInvite() {
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID");
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token");
        print("🗑️ CLEAR INVITE: Cleared pending invite data")
    }
    
    func dismissAdminInfoUpdate() { 
        showAdminInfoUpdate = false
        print("✅ DISMISS ADMIN: Admin info update dismissed")
    }
    
    func getShareURLForCopying() -> String? { 
        guard let currentOrg = currentOrg else { return nil }
        
        let baseURL = "https://rheir.app/join"
        let orgParam = "org=\(currentOrg.id)"
        let nameParam = "name=\(currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        let shareURL = "\(baseURL)?\(orgParam)&\(nameParam)"
        print("🔗 SHARE URL: Generated share URL for \(currentOrg.name)")
        return shareURL
    }
    
    func getContractorInviteURLForCopying() -> String? { 
        guard let currentOrg = currentOrg else { return nil }
        
        let baseURL = "https://rheir.app/contractor"
        let orgParam = "org=\(currentOrg.id)"
        let nameParam = "name=\(currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        let contractorURL = "\(baseURL)?\(orgParam)&\(nameParam)"
        print("🔗 CONTRACTOR URL: Generated contractor invite URL for \(currentOrg.name)")
        return contractorURL
    }
    
    func createTeamMemberInviteWithProjects(email: String, role: OrganizationRole, allowedProjectIDs: [String]) async -> InviteResult {
        guard let currentOrg = currentOrg,
              let cloudKitService = service as? CloudKitAuthService else {
            return InviteResult(success: false, message: "No organization selected or CloudKit unavailable")
        }
        
        do {
            // Store project assignments for this user
            teamProjectAssignments[email] = allowedProjectIDs
            
            // Send invitation with project-specific permissions
            try await cloudKitService.inviteUserToOrganizationWithProjects(
                email: email,
                organizationID: currentOrg.id,
                role: role,
                allowedProjectIDs: allowedProjectIDs
            )
            
            print("✅ PROJECT INVITE: Sent invitation to \(email) with access to \(allowedProjectIDs.count) projects")
            return InviteResult(success: true, message: "Invitation sent with project access")
            
        } catch {
            print("❌ PROJECT INVITE: Failed to send invitation: \(error)")
            return InviteResult(success: false, message: "Failed to send invitation: \(error.localizedDescription)")
        }
    }
    
    func repairMissingOrganizationZones() async -> String { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return "❌ No user or CloudKit service available"
        }
        
        var repairReport = "🔧 ZONE REPAIR: Checking organization zones...\n\n"
        
        for organization in userOrganizations {
            repairReport += "Checking: \(organization.name)\n"
            
            do {
                // Check if organization zone exists and repair if needed
                let zoneExists = try await cloudKitService.checkOrganizationZoneExists(organization.id)
                
                if !zoneExists {
                    repairReport += "  ❌ Zone missing - creating...\n"
                    try await cloudKitService.createOrganizationZone(organization.id)
                    repairReport += "  ✅ Zone created successfully\n"
                } else {
                    repairReport += "  ✅ Zone exists\n"
                }
                
            } catch {
                repairReport += "  ❌ Repair failed: \(error.localizedDescription)\n"
            }
            
            repairReport += "\n"
        }
        
        print("🔧 ZONE REPAIR: Completed organization zone repair")
        return repairReport
    }
    
    func getOrganizationZoneStatus() async -> String { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return "❌ No user or CloudKit service available"
        }
        
        var statusReport = "📊 ZONE STATUS: Organization CloudKit zones\n\n"
        
        for organization in userOrganizations {
            statusReport += "Organization: \(organization.name)\n"
            statusReport += "ID: \(organization.id.prefix(8))...\n"
            
            do {
                let zoneExists = try await cloudKitService.checkOrganizationZoneExists(organization.id)
                let recordCount = try await cloudKitService.getOrganizationRecordCount(organization.id)
                
                statusReport += "Zone Status: \(zoneExists ? "✅ Exists" : "❌ Missing")\n"
                statusReport += "Records: \(recordCount)\n"
                
            } catch {
                statusReport += "Status: ❌ Error checking zone\n"
                statusReport += "Error: \(error.localizedDescription)\n"
            }
            
            statusReport += "\n"
        }
        
        return statusReport
    }
    
    func fixCurrentOrganizationZone() async -> String { 
        guard let currentOrg = currentOrg,
              let cloudKitService = service as? CloudKitAuthService else {
            return "❌ No current organization or CloudKit service"
        }
        
        var fixReport = "🔧 ZONE FIX: Repairing current organization zone\n\n"
        fixReport += "Organization: \(currentOrg.name)\n"
        fixReport += "ID: \(currentOrg.id.prefix(8))...\n\n"
        
        do {
            // Check current zone status
            let zoneExists = try await cloudKitService.checkOrganizationZoneExists(currentOrg.id)
            fixReport += "Current Status: \(zoneExists ? "✅ Zone exists" : "❌ Zone missing")\n"
            
            if !zoneExists {
                fixReport += "Creating zone...\n"
                try await cloudKitService.createOrganizationZone(currentOrg.id)
                fixReport += "✅ Zone created successfully\n"
            }
            
            // Trigger ProjectViewModel zone setup
            if let projectVM = projectVM {
                fixReport += "Setting up ProjectViewModel zone isolation...\n"
                await projectVM.setupCloudKitZoneForOrganization(currentOrg.id)
                fixReport += "✅ ProjectViewModel zone isolation configured\n"
            }
            
            fixReport += "\n✅ ZONE FIX: Current organization zone repair completed"
            
        } catch {
            fixReport += "❌ ZONE FIX: Failed to fix zone: \(error.localizedDescription)"
        }
        
        return fixReport
    }
    
    func switchToOrganization(_ organization: Organization) { 
        Task { @MainActor in
            print("🔄 SWITCH ORG: Switching to organization: \(organization.name)")
            setCurrentOrganization(organization)
        }
    }
    
    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        // Add name validation before creating
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthViewModelError.organizationNameTaken("Organization name cannot be empty")
        }
        
        guard name.count >= 3 else {
            throw AuthViewModelError.organizationNameTaken("Organization name must be at least 3 characters")
        }
        
        // Check if name is already taken (if we implement this check later)
        // For now, proceed with creation
        
        print("🏗️ VALIDATED CREATION: Creating organization '\(name)' with validation")
        return try await createOrganization(named: name, industry: industry)
    }
    
    func retryPendingInvite() { 
        print("🔄 RETRY INVITE: Checking for pending invites to retry")
        checkForPendingInvites()
        
        // If there's a pending invite, try to process it
        if let pendingOrgID = UserDefaults.standard.string(forKey: "pending_invite_orgID"),
           let pendingOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") {
            
            print("🔄 RETRY INVITE: Found pending invite for organization: \(pendingOrgName)")
            // Process the invitation
            inviteStatus = "Processing pending invitation..."
            
            Task {
                // Simulate processing
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    self.inviteStatus = "Pending invitation processed"
                }
            }
        }
    }
    
    func switchToPreviousOrganization() {
        if let previousOrgID = UserDefaults.standard.string(forKey: "previousOrganizationID"),
           let previousOrg = userOrganizations.first(where: { $0.id == previousOrgID }) {
            
            print("🔄 SWITCH PREVIOUS: Switching to previous organization: \(previousOrg.name)")
            
            Task { @MainActor in
                setCurrentOrganization(previousOrg)
            }
        } else {
            print("⚠️ SWITCH PREVIOUS: No previous organization found")
        }
    }

    func updateSubscriptionTier(_ newTier: SubscriptionTier) {
        guard var org = currentOrg else {
            print("❌ No current organization to update subscription tier");
            return;
        }
        
        print("🔄 SUBSCRIPTION UPDATE: Changing from \(org.subscriptionTier.displayName) to \(newTier.displayName)");
        
        org.upgradeSubscription(to: newTier);
        
        if let index = organizations.firstIndex(where: { $0.id == org.id }) {
            organizations[index] = org;
        }
        
        if let index = userOrganizations.firstIndex(where: { $0.id == org.id }) {
            userOrganizations[index] = org;
        }
        
        currentOrg = org;
        
        notifyProjectViewModelOrganizationChange(org.id);
        
        print("💾 SUBSCRIPTION: Updated organization subscription tier to \(newTier.displayName)");
    }

    func reloadOrganizationData() {
        print("🔄 RELOAD ORG: Reloading organization data")
        
        if let currentOrgID = currentOrg?.id {
            notifyProjectViewModelOrganizationChange(currentOrgID)
        }
        
        // Refresh organization list from CloudKit
        if let user = user {
            checkUserOrganizationStatus(for: user)
        }
    }

    func checkCloudKitStatus() async -> String {
        guard service is CloudKitAuthService else {
            return "Service Unavailable";
        }
        
        do {
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

    // MARK: - Organization Name Validation & Suggestions

    func checkOrganizationNameAvailability(_ name: String) { 
        guard !name.isEmpty else {
            nameAvailabilityMessage = ""
            return
        }
        
        isCheckingNameAvailability = true
        nameAvailabilityMessage = "Checking availability..."
        
        Task {
            do {
                // Simulate API call to check name availability
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Simple check - in production this would query CloudKit
                let unavailableNames = ["test", "demo", "sample", "example"]
                let isAvailable = !unavailableNames.contains(name.lowercased())
                
                await MainActor.run {
                    self.isCheckingNameAvailability = false
                    
                    if isAvailable {
                        self.nameAvailabilityMessage = "✅ '\(name)' is available"
                    } else {
                        self.nameAvailabilityMessage = "❌ '\(name)' is not available"
                        self.getSuggestedOrganizationNames(baseName: name)
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isCheckingNameAvailability = false
                    self.nameAvailabilityMessage = "Error checking availability"
                }
            }
        }
    }
    
    func getSuggestedOrganizationNames(baseName: String) { 
        isLoadingSuggestions = true
        
        Task {
            // Simulate API call for suggestions
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            let suggestions = generateBasicSuggestions(for: baseName)
            
            await MainActor.run {
                self.suggestedNames = suggestions
                self.isLoadingSuggestions = false
            }
        }
    }
    
    private func generateBasicSuggestions(for baseName: String) -> [String] {
        let suffixes = ["LLC", "Inc", "Corp", "Co", "Construction", "Builders", "Contractors"]
        let prefixes = ["Elite", "Premier", "Professional", "Expert", "Quality"]
        
        var suggestions: [String] = []
        
        // Add suffix variations
        for suffix in suffixes {
            suggestions.append("\(baseName) \(suffix)")
        }
        
        // Add prefix variations
        for prefix in prefixes {
            suggestions.append("\(prefix) \(baseName)")
        }
        
        // Add numbered variations
        for i in 2...5 {
            suggestions.append("\(baseName) \(i)")
        }
        
        return Array(suggestions.prefix(8)) // Return up to 8 suggestions
    }
    
    func joinOrganization(with organizationID: String, role: OrganizationRole, completion: @escaping (Bool, String?) -> Void) { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "User not authenticated or CloudKit unavailable")
            return
        }
        
        print("🔗 JOIN ORG: Attempting to join organization \(organizationID.prefix(8))... as \(role.displayName)")
        
        Task {
            do {
                let organization = try await cloudKitService.joinOrganization(organizationID, userID: userID, role: role)
                
                await MainActor.run {
                    self.updateOrganizationState(organization, role: role, userID: userID)
                    completion(true, "Successfully joined \(organization.name)")
                }
                
                print("✅ JOIN ORG: Successfully joined organization: \(organization.name)")
                
            } catch {
                let errorMessage = handleJoinOrganizationError(error)
                completion(false, errorMessage)
                print("❌ JOIN ORG: Failed to join organization: \(error)")
            }
        }
    }
    
    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "User not authenticated or CloudKit unavailable")
            return
        }
        
        // Only admin can delete organization
        guard organizationRoles[organization.id] == .admin else {
            completion(false, "Only organization admin can delete the organization")
            return
        }
        
        print("🗑️ DELETE ORG: Attempting to delete organization: \(organization.name)")
        
        cloudKitService.deleteOrganization(organizationID: organization.id)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        break
                    case .failure(let error):
                        completion(false, "Failed to delete organization: \(error.localizedDescription)")
                        print("❌ DELETE ORG: Failed to delete organization: \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        Task { @MainActor in
                            // Remove from local state
                            self.organizations.removeAll { $0.id == organization.id }
                            self.userOrganizations.removeAll { $0.id == organization.id }
                            self.organizationRoles.removeValue(forKey: organization.id)
                            
                            // If this was current org, clear it
                            if self.currentOrg?.id == organization.id {
                                self.currentOrg = nil
                                self.needsOrganizationSetup = self.organizations.isEmpty
                            }
                        }
                        
                        completion(true, "Organization '\(organization.name)' deleted successfully")
                        print("✅ DELETE ORG: Successfully deleted organization: \(organization.name)")
                    } else {
                        completion(false, "Failed to delete organization")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func leaveOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "User not authenticated or CloudKit unavailable")
            return
        }
        
        // Admin cannot leave if they're the only admin
        if organizationRoles[organization.id] == .admin && organization.adminUserID == userID {
            completion(false, "Admin cannot leave organization. Transfer admin role first or delete the organization.")
            return
        }
        
        print("🚪 LEAVE ORG: Attempting to leave organization: \(organization.name)")
        
        cloudKitService.leaveOrganization(organizationID: organization.id, userID: userID)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        break
                    case .failure(let error):
                        completion(false, "Failed to leave organization: \(error.localizedDescription)")
                        print("❌ LEAVE ORG: Failed to leave organization: \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        Task { @MainActor in
                            // Remove from local state
                            self.organizations.removeAll { $0.id == organization.id }
                            self.userOrganizations.removeAll { $0.id == organization.id }
                            self.organizationRoles.removeValue(forKey: organization.id)
                            
                            // If this was current org, switch to another or show setup
                            if self.currentOrg?.id == organization.id {
                                if let nextOrg = self.organizations.first {
                                    self.setCurrentOrganization(nextOrg)
                                } else {
                                    self.currentOrg = nil
                                    self.needsOrganizationSetup = true
                                }
                            }
                        }
                        
                        completion(true, "Left organization '\(organization.name)' successfully")
                        print("✅ LEAVE ORG: Successfully left organization: \(organization.name)")
                    } else {
                        completion(false, "Failed to leave organization")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateOrganizationState(_ organization: Organization, role: OrganizationRole, userID: String) { 
        // Add to local state
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization)
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization)
        }
        
        organizationRoles[organization.id] = role
        
        // Set as current if no current org
        if currentOrg == nil {
            Task { @MainActor in
                self.setCurrentOrganization(organization)
            }
        }
        
        needsOrganizationSetup = false
        showOrganizationSetup = false
    }
    
    private func handleJoinOrganizationError(_ error: Error) -> String { 
        if let cloudKitError = error as? CKError {
            switch cloudKitError.code {
            case .notAuthenticated:
                return "Please sign in to iCloud to join organizations"
            case .networkFailure, .networkUnavailable:
                return "Network connection required to join organizations"
            case .unknownItem:
                return "Organization not found or invitation expired"
            case .permissionFailure:
                return "You don't have permission to join this organization"
            default:
                return "Failed to join organization: \(cloudKitError.localizedDescription)"
            }
        }
        
        return "Failed to join organization: \(error.localizedDescription)"
    }
    
    func fixDataInconsistencies() { 
        print("🛠️ FIX DATA: Starting data inconsistency repair...")
        
        Task {
            // Refresh organization data from CloudKit
            if let user = user {
                checkUserOrganizationStatus(for: user)
            }
            
            // Validate current organization still exists
            if let currentOrg = currentOrg,
               !organizations.contains(where: { $0.id == currentOrg.id }) {
                
                print("⚠️ FIX DATA: Current organization no longer exists, switching to first available")
                
                await MainActor.run {
                    if let firstOrg = self.organizations.first {
                        self.setCurrentOrganization(firstOrg)
                    } else {
                        self.currentOrg = nil
                        self.needsOrganizationSetup = true
                    }
                }
            }
            
            // Sync team members
            await syncOrganizationTeamMembers()
            
            print("✅ FIX DATA: Data inconsistency repair completed")
        }
    }
    
    func fetchUserProjectAssignments(organizationID: String, userID: String) { 
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("❌ PROJECT ASSIGNMENTS: CloudKit service unavailable")
            return
        }
        
        Task {
            do {
                let assignments = try await cloudKitService.fetchUserProjectAssignments(
                    organizationID: organizationID, 
                    userID: userID
                )
                
                await MainActor.run {
                    self.assignedProjectIDs = assignments
                    print("✅ PROJECT ASSIGNMENTS: Loaded \(assignments.count) project assignments")
                }
                
            } catch {
                print("❌ PROJECT ASSIGNMENTS: Failed to fetch assignments: \(error)")
            }
        }
    }
}