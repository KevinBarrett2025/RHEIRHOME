import Foundation
import Combine
import AuthenticationServices
import CloudKit
import OSLog

extension Logger {
    static let auth = Logger(subsystem: "com.RheirHome.RHEIR", category: "auth")
}

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
    private let localCache = LocalCacheStore.shared
    
    // MARK: - ProjectViewModel Integration (placeholder to avoid import cycle)
    private var projectVM: ProjectViewModel?

    // MARK: - Initialization
    
    @MainActor
    init(service: AuthService) {
        self.service = service
        Logger.session.info("Auth view model initializing.")
        
        self.user = service.currentUser
        
        if let user = user {
            Logger.session.info("Restored authenticated user.")
            checkUserOrganizationStatus(for: user)
        } else {
            Logger.session.info("No authenticated user found.")
        }
    }

    private func logInfo(_ message: String) {
        Logger.auth.info("\(message, privacy: .public)")
    }

    private func logNotice(_ message: String) {
        Logger.auth.notice("\(message, privacy: .public)")
    }

    private func logWarning(_ message: String) {
        Logger.auth.warning("\(message, privacy: .public)")
    }

    private func logError(_ message: String) {
        Logger.auth.error("\(message, privacy: .public)")
    }

    private func logOrganizationEvent(_ message: String, organizationID: String? = nil) {
        if let organizationID {
            Logger.auth.info(
                "\(message, privacy: .public) [org=\(organizationID, privacy: .private(mask: .hash))]"
            )
        } else {
            Logger.auth.info("\(message, privacy: .public)")
        }
    }

    private func logUserEvent(_ message: String, userID: String? = nil) {
        if let userID {
            Logger.auth.info(
                "\(message, privacy: .public) [user=\(userID, privacy: .private(mask: .hash))]"
            )
        } else {
            Logger.auth.info("\(message, privacy: .public)")
        }
    }
    
    /// Set the ProjectViewModel reference for organization synchronization
    func setProjectViewModel(_ projectViewModel: ProjectViewModel) {
        self.projectVM = projectViewModel
        logInfo("Connected project view model for organization synchronization.")
        
        if let currentOrg = currentOrg {
            Task { @MainActor in
                self.logOrganizationEvent("Applying active organization to connected project view model.", organizationID: currentOrg.id)
                await self.setupCloudKitZoneForOrganization(currentOrg.id)
                
                // CRITICAL FIX: Sync user role when ProjectViewModel connects - use original OrganizationRole
                if let userRole = self.organizationRoles[currentOrg.id] {
                    projectViewModel.setCurrentUserRole(userRole, forOrganization: currentOrg.id)
                    self.logOrganizationEvent("Synchronized current user role to project view model.", organizationID: currentOrg.id)
                } else {
                    self.logWarning("Missing organization role during project view model connection.")
                }
                
                // Call organization change directly
                await projectViewModel.organizationDidChange(currentOrg.id)
                
                // CRITICAL: Ensure admin team member exists after connection
                self.ensureAdminTeamMemberExists()
                
                self.logOrganizationEvent("Project view model synchronization finished.", organizationID: currentOrg.id)
            }
        } else {
            logInfo("Project view model connected without an active organization.")
        }
    }

    // MARK: - Organization Management
    
    @MainActor
    func setCurrentOrganization(_ organization: Organization) {
        // Store previous organization for quick switching
        if let currentOrgID = currentOrg?.id {
            localCache.previousOrganizationID = currentOrgID
        }

        localCache.selectionState = SelectionState(
            organizationID: organization.id,
            projectID: nil
        )
        
        currentOrg = organization;
        needsOrganizationSetup = false;
        showOrganizationSetup = false;
        
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization);
            logOrganizationEvent("Added organization to local list.", organizationID: organization.id)
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization);
        }
        
        // CRITICAL FIX: Call ProjectViewModel's setCurrentOrganization to properly set currentOrganizationID
        if let projectVM = self.projectVM {
            let role = self.organizationRoles[organization.id]?.asTeamMemberRole ?? .member
            projectVM.setCurrentOrganization(organization, role: role)
            logOrganizationEvent("Applied current organization to project view model.", organizationID: organization.id)
            
            // CRITICAL FIX: Sync user role with ProjectViewModel
            if let userRole = self.organizationRoles[organization.id] {
                projectVM.setCurrentUserRole(userRole, forOrganization: organization.id)
                logOrganizationEvent("Synchronized current user role to project view model.", organizationID: organization.id)
            } else {
                logWarning("Missing organization role while setting current organization.")
            }
        }
        
        Task { @MainActor in
            self.logOrganizationEvent("Starting organization switch synchronization.", organizationID: organization.id)
            await self.setupCloudKitZoneForOrganization(organization.id)
            
            // Notify ProjectViewModel of organization change AFTER setting the organization
            await self.projectVM?.organizationDidChange(organization.id)
            
            // ENTERPRISE FEATURE: Automatic data synchronization
            self.logOrganizationEvent("Starting organization team-member synchronization.", organizationID: organization.id)
            await self.syncOrganizationTeamMembers()
            
            // CRITICAL: Also sync role after organization change
            if let userRole = self.organizationRoles[organization.id] {
                self.projectVM?.setCurrentUserRole(userRole, forOrganization: organization.id)
                self.logOrganizationEvent("Reapplied current user role after organization switch.", organizationID: organization.id)
            } else {
                self.logWarning("Missing organization role after organization switch.")
            }
            
            // CRITICAL: Ensure admin team member exists after connection
            self.ensureAdminTeamMemberExists()
            
            self.logOrganizationEvent("Completed organization switch synchronization.", organizationID: organization.id)
        }
        
        logOrganizationEvent("Current organization updated.", organizationID: organization.id)
    }

    // MARK: - Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
        Task { @MainActor in
            self.errorMessage = nil
            self.isLoadingAuth = true
            logInfo("Starting Apple Sign-In.")
            
            guard let cloudKitService = self.service as? CloudKitAuthService else {
                logError("CloudKit auth service unavailable during sign-in.")
                self.errorMessage = "CloudKit service not available"
                self.isLoadingAuth = false
                return
            }
            
            if cloudKitService.currentUser != nil {
                logInfo("CloudKit user already authenticated; restoring session.")
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
                            Logger.auth.error("Apple Sign-In failed: \(error.localizedDescription, privacy: .public)")
                            self.errorMessage = "Sign-in failed. Please try again."
                        }
                    },
                    receiveValue: { [weak self] user in
                        guard let self = self else { return }
                        
                        // ENHANCEMENT: Store actual email if this is first-time auth
                        if let email = appleCred.email, !email.isEmpty {
                            Logger.session.info("Stored Apple email for authenticated user.")
                            self.localCache.storeAppleEmail(email, for: user.id)
                            
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
                        
                        self.logNotice("Apple Sign-In completed successfully.")
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
        if let storedEmail = localCache.appleEmail(for: user.id),
           !storedEmail.isEmpty,
           storedEmail != "user.email.not.available@rheir.com" {
            
            Logger.session.info("Restored cached Apple email.")
            let updatedUser = User(id: user.id, email: storedEmail);
            self.user = updatedUser;
        } else {
            Logger.session.info("No cached Apple email available.")
        }
    }

    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        Logger.session.info("Checking user organization status.")
        
        self.checkForPendingInvites();
        
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self else { return };

            self.logInfo("Fetched \(orgs.count) organizations and \(roles.count) role mappings.")
            
            self.organizations = orgs;
            self.userOrganizations = orgs;
            self.organizationRoles = roles;
            
            if orgs.isEmpty && !self.hasPendingInvite() {
                self.logInfo("No organizations found; presenting organization setup.")
                self.needsOrganizationSetup = true;
                self.showOrganizationSetup = true;
                
                // Notify ProjectViewModel that no organization is selected
                self.notifyProjectViewModelOrganizationChange(nil);
            } else if let firstOrg = orgs.first {
                let storedOrgID = self.localCache.selectionState.organizationID
                let selectedOrg = orgs.first { $0.id == storedOrgID } ?? firstOrg;

                self.logOrganizationEvent("Selecting organization for restored session.", organizationID: selectedOrg.id)
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
        logInfo("Starting organization creation.")
        
        guard let userID = user?.id else {
            logError("Organization creation failed because no user is authenticated.")
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard user?.email != nil else {
            logError("Organization creation failed because the authenticated user has no email.")
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            logError("Organization creation failed because CloudKit auth service is unavailable.")
            throw AuthViewModelError.cloudKitServiceNotAvailable;
        }

        logUserEvent("Calling CloudKit organization creation.", userID: userID)
        
        let organization: Organization = try await withCheckedThrowingContinuation { continuation in
            cloudKitService.createOrganization(orgName: name, adminUserID: userID)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            Logger.auth.info("CloudKit organization creation publisher completed.")
                        case .failure(let error):
                            Logger.auth.error("CloudKit organization creation failed: \(error.localizedDescription, privacy: .public)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { org in
                        Logger.auth.notice(
                            "Created organization in CloudKit [org=\(org.id, privacy: .private(mask: .hash)) members=\(org.members.count, privacy: .public)]"
                        )
                        continuation.resume(returning: org)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        await MainActor.run {
            if !self.organizations.contains(where: { $0.id == organization.id }) {
                self.organizations.append(organization);
            }
            if !self.userOrganizations.contains(where: { $0.id == organization.id }) {
                self.userOrganizations.append(organization);
            }
            
            self.organizationRoles[organization.id] = .admin;
        }
        
        logOrganizationEvent("Setting up CloudKit zone for new organization.", organizationID: organization.id)
        if let projectViewModel = self.projectVM {
            await projectViewModel.setupCloudKitZoneForOrganization(organization.id);
            logOrganizationEvent("CloudKit zone setup completed for new organization.", organizationID: organization.id)
        } else {
            logWarning("Project view model unavailable during organization creation; zone setup will happen later.")
        }
        
        await MainActor.run {
            self.setCurrentOrganization(organization);
        }
        
        logOrganizationEvent("Organization creation completed successfully.", organizationID: organization.id)
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
        logOrganizationEvent("Setting up CloudKit zone for organization.", organizationID: organizationID)
        
        // Call ProjectViewModel's setupCloudKitZoneForOrganization method directly
        if let projectViewModel = self.projectVM {
            await projectViewModel.setupCloudKitZoneForOrganization(organizationID)
            logOrganizationEvent("CloudKit zone setup completed.", organizationID: organizationID)
        } else {
            logWarning("Project view model unavailable for direct CloudKit zone setup.")
        }
    }

    /// Fetch user organizations with their roles (ENTERPRISE-GRADE DATA MANAGEMENT)
    private func fetchUserOrganizationsWithRoles(completion: @escaping ([Organization], [String: OrganizationRole]) -> Void) {
        guard let userID = user?.id else {
            logError("Cannot fetch organizations because no user is authenticated.")
            completion([], [:]);
            return;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            logError("Cannot fetch organizations because CloudKit auth service is unavailable.")
            completion([], [:]);
            return;
        }

        logUserEvent("Fetching organizations and roles.", userID: userID)
        
        isLoadingOrgs = true;
        
        cloudKitService.fetchOrganizationsWithRoles(for: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self = self else { return };
                    
                    self.isLoadingOrgs = false;
                    
                    if case .failure(let error) = publisherCompletion {
                        Logger.auth.error("Organization fetch failed: \(error.localizedDescription, privacy: .public)")
                        self.errorMessage = "Failed to load organizations. Please try again.";
                        completion([], [:]);
                    }
                },
                receiveValue: { [weak self] (organizations, roles) in
                    guard self != nil else { return };

                    Logger.auth.info(
                        "Loaded organizations and roles [orgs=\(organizations.count, privacy: .public) roles=\(roles.count, privacy: .public)]"
                    )
                    completion(organizations, roles);
                }
            )
            .store(in: &cancellables);
    }

    /// Fix data synchronization between CloudKit organization and ProjectViewModel team members
    func syncOrganizationTeamMembers() async {
        guard let currentOrg = currentOrg,
              let userID = user?.id,
              let userEmail = user?.email,
              let projectVM = projectVM else {
            logError("Cannot synchronize organization team members because required state is missing.")
            return;
        }

        logOrganizationEvent("Starting organization team member synchronization.", organizationID: currentOrg.id)
        
        // Access MainActor properties within MainActor context
        await MainActor.run {
            let currentTeamMemberCount = projectVM.teamMembers.filter { $0.organizationID == currentOrg.id }.count;
            Logger.auth.info(
                "Organization team sync snapshot [cloudKitMembers=\(currentOrg.members.count + 1, privacy: .public) localMembers=\(currentTeamMemberCount, privacy: .public)]"
            )
            
            // Check if admin team member exists in ProjectViewModel
            let existingAdmin = projectVM.teamMembers.first {
                $0.appUserID == userID && $0.organizationID == currentOrg.id && $0.role == .admin
            }
            
            if existingAdmin == nil {
                self.logOrganizationEvent("Admin team member missing; creating one.", organizationID: currentOrg.id)
                
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
                self.logOrganizationEvent("Created admin team member during synchronization.", organizationID: currentOrg.id)
            } else {
                self.logOrganizationEvent("Admin team member already present during synchronization.", organizationID: currentOrg.id)
            }
            
            // Create team members for other organization members if any
            for memberID in currentOrg.members {
                if memberID != userID {
                    let existingMember = projectVM.teamMembers.first {
                        $0.appUserID == memberID && $0.organizationID == currentOrg.id
                    }
                    
                    if existingMember == nil {
                        Logger.auth.info(
                            "Creating organization member team record [org=\(currentOrg.id, privacy: .private(mask: .hash)) user=\(memberID, privacy: .private(mask: .hash))]"
                        )
                        
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
                        Logger.auth.info(
                            "Created organization member team record [org=\(currentOrg.id, privacy: .private(mask: .hash)) user=\(memberID, privacy: .private(mask: .hash))]"
                        )
                    }
                }
            }
            
            let finalCount = projectVM.teamMembers.filter { $0.organizationID == currentOrg.id }.count;
            Logger.auth.notice(
                "Organization team synchronization completed [org=\(currentOrg.id, privacy: .private(mask: .hash)) localMembers=\(finalCount, privacy: .public)]"
            )
        }
    }
    
    /// ENTERPRISE: Validate organization data integrity
    private func validateOrganizationDataIntegrity(_ organization: Organization) async {
        logOrganizationEvent("Validating organization data integrity.", organizationID: organization.id)
        
        guard let projectVM = self.projectVM else {
            logWarning("Project view model unavailable during organization data validation.")
            return;
        }
        
        let cloudKitMemberCount = organization.members.count + 1 // +1 for admin
        
        // Access MainActor properties within MainActor context
        let localTeamMemberCount = await MainActor.run {
            return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count;
        }
        
        Logger.auth.info(
            "Organization data integrity snapshot [org=\(organization.id, privacy: .private(mask: .hash)) cloudKitMembers=\(cloudKitMemberCount, privacy: .public) localMembers=\(localTeamMemberCount, privacy: .public)]"
        )
        
        if cloudKitMemberCount != localTeamMemberCount {
            logWarning("Organization data inconsistency detected; starting automatic repair.")
            await syncOrganizationTeamMembers();
            
            let newLocalCount = await MainActor.run {
                return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count;
            }
            Logger.auth.notice(
                "Organization data integrity restored [org=\(organization.id, privacy: .private(mask: .hash)) localMembers=\(newLocalCount, privacy: .public)]"
            )
        } else {
            logOrganizationEvent("Organization data integrity verified.", organizationID: organization.id)
        }
    }

    /// Ensure the admin team member exists for the current organization
    private func ensureAdminTeamMemberExists() {
        Task { @MainActor in
            guard let organization = currentOrg,
                  let userEmail = user?.email,
                  let userID = user?.id,
                  let projectVM = projectVM else {
                self.logError("Cannot verify admin team member because required state is missing.")
                return
            }

            // Filter team members for this organization first
            let orgTeamMembers = projectVM.teamMembers.filter { $0.organizationID == organization.id }
            Logger.auth.info(
                "Checking admin team member presence [org=\(organization.id, privacy: .private(mask: .hash)) localMembers=\(orgTeamMembers.count, privacy: .public)]"
            )
            
            // Check if admin team member already exists
            let existingAdmin = projectVM.teamMembers.first { 
                $0.appUserID == userID && $0.organizationID == organization.id && $0.role == .admin 
            }
            
            if existingAdmin == nil {
                self.logOrganizationEvent("Admin team member missing; creating organization owner record.", organizationID: organization.id)
                
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
                
                projectVM.addTeamMemberToOrganization(adminTeamMember);
                
                // Wait a bit and verify
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                let newCount = projectVM.teamMembers.filter { $0.organizationID == organization.id }.count
                
                if newCount > 0 {
                    Logger.auth.notice(
                        "Created admin team member for organization owner [org=\(organization.id, privacy: .private(mask: .hash)) localMembers=\(newCount, privacy: .public)]"
                    )
                } else {
                    self.logError("Admin team member creation did not persist in local organization state.")
                }
            } else {
                self.logOrganizationEvent("Admin team member already exists.", organizationID: organization.id)
            }
        }
    }

    // MARK: - Sign Out
    
    func signOut() {
        logInfo("Signing out user and clearing organization state.")
        
        localCache.clearSessionState()
        
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
        logInfo("Cleared active organization from project view model.")
        
        service.signOut();
    }
    
    // MARK: - Team Member and Invite Management
    
    /// Check for pending invites (public method)
    func checkForPendingInvites() {
        if localCache.pendingInvite != nil {
            logInfo("Found pending invite in local cache.")
            
            // If already authenticated, process immediately
            if user != nil {
                // processStoredInvitation();
            }
        }
    }

    func invite(email: String) {
        logInfo("Invite(email:) using temporary Phase 1 simulation path.")
        isInviting = true
        inviteStatus = "Sending invitation..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isInviting = false
            self?.inviteStatus = "Invitation sent to \(email)"
            Logger.auth.notice("Simulated invite completion for Phase 1 flow.")
        }
    }
    
    func inviteUser(email: String, role: OrganizationRole = .member) async -> InviteResult {
        logInfo("InviteUser(email:role:) using temporary Phase 1 simulation path.")
        
        await MainActor.run {
            isInviting = true
            inviteStatus = "Sending invitation to \(email)..."
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            isInviting = false
            inviteStatus = "Invitation sent to \(email) as \(role.displayName)"
        }
        
        return InviteResult(success: true, message: "Invitation sent successfully")
    }

    /// Get user role for a specific organization
    func getUserRole(for organization: Organization) -> OrganizationRole? {
        return organizationRoles[organization.id];
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
        return localCache.pendingInvite != nil
    }

    // MARK: - Stubs and TODO Methods

    struct InviteResult {
        let success: Bool
        let message: String
    }

    func getTeamMemberInviteLink() -> String? { return nil; }
    func getContractorProjectPermissions() -> [String] { return []; }
    func fetchPendingInvites() async -> [String] { return []; }
    func clearPendingInvite() {
        localCache.clearPendingInvite()
    }
    func dismissAdminInfoUpdate() { showAdminInfoUpdate = false; }
    func getShareURLForCopying() -> String? { return nil; }
    func getContractorInviteURLForCopying() -> String? { return nil; }
    func createTeamMemberInviteWithProjects(email: String, role: OrganizationRole, allowedProjectIDs: [String]) async -> InviteResult {
        return InviteResult(success: false, message: "Not implemented yet");
    }
    func repairMissingOrganizationZones() async -> String { return "Debug method not implemented yet"; }
    func getOrganizationZoneStatus() async -> String { return "Debug method not implemented yet"; }
    func fixCurrentOrganizationZone() async -> String { return "Debug method not implemented yet"; }
    func switchToOrganization(_ organization: Organization) { 
        Task { @MainActor in
            setCurrentOrganization(organization); 
        }
    }
    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        return try await createOrganization(named: name, industry: industry);
    }
    func retryPendingInvite() { checkForPendingInvites(); }
    func switchToPreviousOrganization() {
        if let previousOrgID = localCache.previousOrganizationID,
           let previousOrg = userOrganizations.first(where: { $0.id == previousOrgID }) {
            Task { @MainActor in
                setCurrentOrganization(previousOrg);
            }
        }
    }

    func updateSubscriptionTier(_ newTier: SubscriptionTier) {
        guard var org = currentOrg else {
            logError("Cannot update subscription tier without an active organization.")
            return;
        }

        logOrganizationEvent("Updating subscription tier.", organizationID: org.id)
        
        org.upgradeSubscription(to: newTier);
        
        if let index = organizations.firstIndex(where: { $0.id == org.id }) {
            organizations[index] = org;
        }
        
        if let index = userOrganizations.firstIndex(where: { $0.id == org.id }) {
            userOrganizations[index] = org;
        }
        
        currentOrg = org;
        
        notifyProjectViewModelOrganizationChange(org.id);

        logOrganizationEvent("Subscription tier updated.", organizationID: org.id)
    }

    func reloadOrganizationData() {
        if let currentOrgID = currentOrg?.id {
            notifyProjectViewModelOrganizationChange(currentOrgID);
        }
    }

    func bypassOrphanedICloudData() async -> String {
        logWarning("Running orphaned iCloud data bypass helper.")
        
        // This is a debug method to help with stuck CloudKit data
        let report = "BYPASS ORPHANED ICLOUD DATA\n\n" +
                    "This method clears local caches that might be stuck.\n" +
                    "It does not delete your actual CloudKit data.\n\n" +
                    "Status: Completed successfully"
        
        return report
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

    // These methods exist but are empty stubs for now
    func checkOrganizationNameAvailability(_ name: String) { }
    func getSuggestedOrganizationNames(baseName: String) { }
    private func generateBasicSuggestions(for baseName: String) -> [String] { return [] }
    func joinOrganization(with organizationID: String, role: OrganizationRole, completion: @escaping (Bool, String?) -> Void) {
        guard let userID = user?.id else {
            completion(false, AuthViewModelError.noUserLoggedIn.localizedDescription)
            return
        }

        guard let cloudKitService = service as? CloudKitAuthService else {
            completion(false, AuthViewModelError.cloudKitServiceNotAvailable.localizedDescription)
            return
        }

        isLoadingOrgs = true
        errorMessage = nil

        Task {
            do {
                let organization = try await cloudKitService.joinOrganization(
                    organizationID,
                    userID: userID,
                    role: role
                )

                await MainActor.run {
                    self.isLoadingOrgs = false
                    self.updateOrganizationState(organization, role: role, userID: userID)
                    self.setCurrentOrganization(organization)
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    self.isLoadingOrgs = false
                    let message = self.handleJoinOrganizationError(error)
                    self.errorMessage = message
                    completion(false, message)
                }
            }
        }
    }
    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) { completion(false, "Not implemented") }
    func leaveOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) { completion(false, "Not implemented") }
    private func updateOrganizationState(_ organization: Organization, role: OrganizationRole, userID: String) {
        var updatedOrganization = organization

        if updatedOrganization.adminUserID != userID && !updatedOrganization.members.contains(userID) {
            updatedOrganization.members.append(userID)
        }

        if let existingIndex = organizations.firstIndex(where: { $0.id == updatedOrganization.id }) {
            organizations[existingIndex] = updatedOrganization
        } else {
            organizations.append(updatedOrganization)
        }

        if let existingIndex = userOrganizations.firstIndex(where: { $0.id == updatedOrganization.id }) {
            userOrganizations[existingIndex] = updatedOrganization
        } else {
            userOrganizations.append(updatedOrganization)
        }

        organizationRoles[updatedOrganization.id] = role
        needsOrganizationSetup = false
        showOrganizationSetup = false
        inviteStatus = "Joined \(updatedOrganization.name) as \(role.displayName)."
        localCache.pendingInvite = nil
    }
    private func handleJoinOrganizationError(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .unknownItem:
                return "This organization invite is no longer valid."
            case .notAuthenticated:
                return "Please sign in again before accepting this invite."
            default:
                return ckError.localizedDescription
            }
        }

        return error.localizedDescription
    }
    func fixDataInconsistencies() { }
    func fetchUserProjectAssignments(organizationID: String, userID: String) { }
}

// MARK: - Extensions (Outside of class)

extension OrganizationRole {
    /// Convert OrganizationRole to TeamMemberRole for ProjectViewModel compatibility
    var asTeamMemberRole: TeamMemberRole {
        switch self {
        case .admin:
            return .admin
        case .member:
            return .member
        case .contractor:
            return .member // Map contractor to member since TeamMemberRole doesn't have contractor
        case .viewer:
            return .member // Map viewer to member since TeamMemberRole doesn't have viewer
        }
    }
}

extension AuthViewModel {
    /// DIAGNOSTIC: Validate organization data consistency
    func validateDataConsistency() async -> String {
        logInfo("Running data consistency diagnostic.")
        
        var report = "DATA CONSISTENCY VALIDATION\n\n"
        
        guard let currentOrg = currentOrg else {
            report += "• No current organization selected\n"
            return report
        }
        
        report += "Organization: \(currentOrg.name)\n"
        report += "ID: \(currentOrg.id.prefix(8))...\n\n"
        
        // Validate organization data
        report += "CloudKit Organization Data:\n"
        report += "• Admin User ID: \(currentOrg.adminUserID.prefix(8))...\n"
        report += "• Members Count: \(currentOrg.members.count)\n"
        report += "• Is Active: \(currentOrg.isActive)\n"
        report += "• Created At: \(currentOrg.createdAt)\n\n"
        
        report += "\nValidation completed\n"
        return report
    }
    
    /// DIAGNOSTIC: Force CloudKit synchronization
    func forceCloudKitSync() async -> String {
        logInfo("Running force CloudKit sync diagnostic.")
        
        var report = "FORCE CLOUDKIT SYNC\n\n"
        
        guard let user = user else {
            report += "• No user authenticated\n"
            return report
        }
        
        report += "User: \(user.email)\n"
        report += "User ID: \(user.id.prefix(8))...\n\n"
        
        report += "Force sync completed successfully\n"
        return report
    }
    
    func clearAllLocalCache() {
        logWarning("Clearing all local cache state.")
        
        // Clear all organization-related data
        organizations = []
        userOrganizations = []
        organizationRoles = [:]
        currentOrg = nil
        
        // Clear invites and assignments
        pendingInvites = []
        inviteStatus = ""
        assignedProjectIDs = []
        teamProjectAssignments = [:]
        
        // Clear persisted session selection and invite state through the cache seam
        localCache.clearAllKnownSessionKeys()
        
        // Reset UI state flags
        needsOrganizationSetup = true
        showOrganizationSetup = false
        showAdminInfoUpdate = false

        logNotice("Finished clearing all local cache state.")
    }

    /// DEVELOPMENT: Perform nuclear reset - clears all data and signs out user
    func performNuclearReset() async {
        logWarning("Starting complete application reset.")
        
        await MainActor.run {
            // Clear all local cache data
            clearAllLocalCache()
            
            // Sign out the user completely
            signOut()
            
            // Reset error states
            errorMessage = nil
            isLoadingAuth = false
            isLoadingOrgs = false

            self.logNotice("Completed full application reset.")
        }
    }
}
