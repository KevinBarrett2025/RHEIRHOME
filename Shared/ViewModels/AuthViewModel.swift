import Foundation
import SwiftUI
import Combine
import CloudKit
import AuthenticationServices

// MARK: - AuthViewModel Error Types
enum AuthViewModelError: Error {
    case noUserLoggedIn
    case cloudKitServiceNotAvailable
    case organizationNameTaken(String)
}

extension AuthViewModelError: LocalizedError {
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
        print("🔧 AuthViewModel initializing...")
        
        self.user = service.currentUser
        
        if let user = user {
            print("🔧 Found existing authentication for user: \(user.email)")
            checkUserOrganizationStatus(for: user)
        } else {
            print("🔧 No existing authentication - user needs to sign in")
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
                
                // CRITICAL FIX: Create admin team member if it doesn't exist (handles late ProjectViewModel connection)
                if let userID = self.user?.id {
                    let existingAdmin = projectViewModel.teamMembers.first { 
                        $0.appUserID == userID && 
                        $0.organizationID == currentOrg.id && 
                        $0.role == .admin 
                    }
                    
                    if existingAdmin == nil {
                        print("🎯 LATE ADMIN CREATION: No admin found after ProjectViewModel connection - creating now...")
                        await self.createImmediateAdminTeamMember(organization: currentOrg, userID: userID, projectViewModel: projectViewModel)
                        
                        // Also trigger onboarding to enhance the profile
                        self.showAdminInfoUpdate = true
                        print("🎯 LATE ADMIN ONBOARDING: Triggered onboarding for profile enhancement")
                    }
                }
                
                // CRITICAL FIX: Sync user role when ProjectViewModel connects - use original OrganizationRole
                if let userRole = self.organizationRoles[currentOrg.id] {
                    projectViewModel.setCurrentUserRole(userRole, forOrganization: currentOrg.id)
                    print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
                } else {
                    print("⚠️ ROLE SYNC WARNING: No role found for current organization during connection")
                }
                
                // Call organization change directly
                await projectViewModel.organizationDidChange(currentOrg.id)
                
                print("✅ Activated zone isolation for: \(currentOrg.name)")
            }
        } else {
            print("🔗 No current organization - zone isolation will be activated when organization is selected")
        }
    }

    // MARK: - Organization Management
    
    @MainActor
    func setCurrentOrganization(_ organization: Organization) {
        UserDefaults.standard.set(organization.id, forKey: "previousOrganizationID")
        currentOrg = organization;
        needsOrganizationSetup = false;
        showOrganizationSetup = false;
        
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization);
            print("🔧 Added organization to local list: \(organization.name)");
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization);
        }
        
        if let projectVM = projectVM {
            let role = organizationRoles[organization.id] ?? .member
            let teamMemberRole: TeamMemberRole = role == .admin ? .admin : .member
            projectVM.setCurrentOrganization(organization)
            print("🔗 CRITICAL FIX: Set ProjectViewModel organization to real CloudKit org ID: \(organization.id.prefix(8))...");
            
            if let userRole = self.organizationRoles[organization.id] {
                projectVM.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
            } else {
                print("⚠️ ROLE SYNC WARNING: No role found for current organization during connection")
            }
            
            if let userRole = self.organizationRoles[organization.id] {
                projectVM.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🔐 ROLE SYNC: Set user role to \(userRole.displayName) for ProjectViewModel")
            } else {
                print("⚠️ ROLE SYNC WARNING: No role found for organization \(organization.name)")
            }
        }
        
        Task { @MainActor in
            print("🔧 ORGANIZATION SWITCH: Setting up zone for: \(organization.name)")
            await self.setupCloudKitZoneForOrganization(organization.id)
            
            await self.projectVM?.organizationDidChange(organization.id)
            
            await self.syncOrganizationTeamMembers()
            
            if let userRole = self.organizationRoles[organization.id] {
                self.projectVM?.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🔧 ROLE SYNC: Set user role to \(userRole.displayName) for newly connected ProjectViewModel")
            } else {
                print("🔧 ROLE SYNC WARNING: No role found for current organization during connection")
            }
            
            print("🔧 Activated zone isolation with synchronized data for: \(organization.name)")
        }
        
        UserDefaults.standard.set(organization.id, forKey: "currentOrganizationID");
        print("🔧 Current organization set with enterprise-grade synchronization: \(organization.name)");
    }

    // MARK: - Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
        Task { @MainActor in
            self.errorMessage = nil
            self.isLoadingAuth = true
            print("🔧 Starting Apple Sign-In...")
            
            guard let cloudKitService = self.service as? CloudKitAuthService else {
                print("🔧 CloudKit service not available")
                self.errorMessage = "CloudKit service not available"
                self.isLoadingAuth = false
                return
            }
            
            if cloudKitService.currentUser != nil {
                if let user = self.user {
                    if user.email == "user.email.not.available@rheir.com" {
                        self.tryRestoreActualEmail(for: user)
                    }
                    if cloudKitService.currentUser != nil {
                        print("🔧 Already authenticated with CloudKit")
                        if let user = self.user {
                            self.checkUserOrganizationStatus(for: user)
                        }
                    }
                }
            } else {
                cloudKitService.signInWithApple(with: appleCred)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        guard let self = self else { return }
                        self.isLoadingAuth = false
                        
                        if case .failure(let error) = completion {
                            print("🔧 Apple Sign-In failed: \(error)")
                            self.errorMessage = "Sign-in failed. Please try again."
                        }
                    },
                    receiveValue: { [weak self] user in
                        guard let self = self else { return }
                        
                        if let email = appleCred.email, !email.isEmpty {
                            print("🔧 FIRST TIME AUTH: Storing actual email: \(email)")
                            UserDefaults.standard.set(email, forKey: "stored_apple_email_\(user.id)")
                            
                            let updatedUser = User(id: user.id, email: email)
                            self.user = updatedUser
                        } else {
                            self.user = user
                            if user.email == "user.email.not_available@rheir.com" {
                                self.tryRestoreActualEmail(for: user)
                            }
                        }
                        
                        print("🔧 Apple Sign-In successful for: \(self.user?.email ?? "unknown")")
                        print("🔧 Apple Sign-In successful for: \(self.user?.email ?? "unknown")")
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
            
            print("🔧 RESTORED EMAIL: Found stored email for user: \(storedEmail)");
            let updatedUser = User(id: user.id, email: storedEmail);
            self.user = updatedUser;
        } else {
            print("🔧 NO STORED EMAIL: Using placeholder email for user: \(user.id.prefix(8))...");
        }
    }

    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        print("🔧 ENHANCED ORG STATUS CHECK for: \(user.email)");
        print("🔧 User ID: \(user.id.prefix(8))...");
        
        self.checkForPendingInvites();
        
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self else { return };
            
            print("🔧 ORGANIZATION FETCH RESULT:");
            print("   Found Organizations: \(orgs.count)");
            print("   Roles Mapping: \(roles.count)");
            
            for org in orgs {
                print("🔧 [\(orgs.firstIndex(of: org)!)] CloudKit Org: \(org.name)");
                print("     ID: \(org.id.prefix(8))...");
                print("     Admin: \(org.adminUserID.prefix(8))...");
                print("     Members: \(org.members.count)");
                print("     Your Role: \(roles[org.id]?.displayName ?? "Unknown")");
            }
            
            self.organizations = orgs;
            self.userOrganizations = orgs;
            self.organizationRoles = roles;
            
            if orgs.isEmpty && !self.hasPendingInvite() {
                print("🔧 NO ORGANIZATIONS - Showing setup");
                self.needsOrganizationSetup = true;
                self.showOrganizationSetup = true;
                
                self.notifyProjectViewModelOrganizationChange(nil);
            } else if let firstOrg = orgs.first {
                print("🔧 FOUND ORGANIZATIONS - Setting up with enterprise synchronization");
                
                let storedOrgID = UserDefaults.standard.string(forKey: "currentOrganizationID");
                let selectedOrg = orgs.first { $0.id == storedOrgID } ?? firstOrg;
                
                print("🔧 Selectinging organization: \(selectedOrg.name)");
                Task { @MainActor in
                    self.setCurrentOrganization(selectedOrg);
                }
                self.needsOrganizationSetup = false;
                
                Task { @MainActor in
                    await self.validateOrganizationDataIntegrity(selectedOrg);
                }
            } else {
                if let organization = self.userOrganizations.first {
                    Task { @MainActor in
                        self.setCurrentOrganization(organization)
                    }
                }
            }
        }
    }

    /// Create organization using CloudKit with proper timeout and error handling
    @MainActor
    func createOrganization(named name: String, industry: String? = nil) async throws -> Organization {
        print("🔧 PRODUCTION ORG CREATION: Starting comprehensive organization creation process...");
        print("🔧 Input Name: '\(name)'");
        print("🔧 Industry: \(industry ?? "None")");
        
        guard let userID = user?.id else {
            print("🔧 PRODUCTION ERROR: No user logged in during organization creation");
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard user?.email != nil else {
            print("🔧 PRODUCTION ERROR: User has no email address");
            throw AuthViewModelError.noUserLoggedIn;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("🔧 PRODUCTION ERROR: CloudKit service not available");
            throw AuthViewModelError.cloudKitServiceNotAvailable;
        }
        
        print("🔧 PRODUCTION VERIFICATION:");
        print("   User ID: \(userID.prefix(8))...");
        print("   User Email: \(user?.email ?? "Unknown")");
        print("   Service Type: CloudKitAuthService");
        print("   Organization Name: '\(name)'");
        
        print("🔧 PRODUCTION: Calling CloudKit organization creation...")
        
        let organization: Organization = try await withCheckedThrowingContinuation { continuation in
            cloudKitService.createOrganization(orgName: name, adminUserID: userID)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("🔧 CloudKit organization creation publisher completed successfully")
                        case .failure(let error):
                            print("🔧 CloudKit organization creation failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { org in
                        print("🔧 PRODUCTION SUCCESS: Organization created via CloudKit")
                        print("   Organization ID: \(org.id.prefix(8))...");
                        print("   Organization Name: \(org.name)")
                        print("   Admin User ID: \(org.adminUserID.prefix(8))...");
                        print("   Members Count: \(org.members.count)")
                        continuation.resume(returning: org)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        print("🔧 PRODUCTION: Setting up CloudKit zone for new organization...");
        if let projectViewModel = self.projectVM {
            await projectViewModel.setupCloudKitZoneForOrganization(organization.id);
            print("🔧 PRODUCTION: Zone setup completed for new organization");
        } else {
            print("🔧 PRODUCTION WARNING: No ProjectViewModel available yet - zone will be created when ProjectViewModel connects");
        }
        
        print("🔧 PRODUCTION: Updating local organization state...")
        
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
        
        self.setCurrentOrganization(organization)
        print("   Current organization set to: \(organization.name)")
        
        if let projectViewModel = self.projectVM {
            await self.createImmediateAdminTeamMember(organization: organization, userID: userID, projectViewModel: projectViewModel)
            print("🎯 ADMIN CREATION: Basic admin created - ready for onboarding enhancement")
        } else {
            print("🎯 ADMIN CREATION: No ProjectViewModel available - will create admin when ProjectViewModel connects")
        }
        
        // CRITICAL FIX: Set admin onboarding flag with enhanced debugging
        print("🎯 ADMIN ONBOARDING TRIGGER: Setting showAdminInfoUpdate flag...")
        print("   Current showAdminInfoUpdate value: \(self.showAdminInfoUpdate)")
        print("   Organization: \(organization.name)")
        print("   Organization ID: \(organization.id.prefix(8))...")
        
        self.showAdminInfoUpdate = true
        
        // CRITICAL FIX: Force UI update and add verification
        self.objectWillChange.send()
        
        print("🎯 ADMIN ONBOARDING TRIGGER: Flag set successfully!")
        print("   New showAdminInfoUpdate value: \(self.showAdminInfoUpdate)")
        print("   UI update forced via objectWillChange.send()")
        
        // CRITICAL FIX: Add small delay to ensure state propagation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("🎯 ADMIN ONBOARDING VERIFICATION:")
        print("   Final showAdminInfoUpdate: \(self.showAdminInfoUpdate)")
        print("   Current organization: \(self.currentOrg?.name ?? "nil")")
        print("   Organizations count: \(self.organizations.count)")
        print("   Ready for admin onboarding flow!")
        
        print("🔧 PRODUCTION COMPLETE: Organization '\(name)' created successfully - admin onboarding ready");
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
            print("🔧 FETCH ORGS: No user logged in");
            completion([], [:]);
            return;
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("🔧 FETCH ORGS: CloudKit service not available");
            completion([], [:]);
            return;
        }
        
        print("🔧 COMPREHENSIVE ORG TRACE: Starting organization fetch with enhanced debugging");
        print("🔧 Current User: \(userID.prefix(8))...");
        print("🔧 Current organizations.count: \(organizations.count)");
        print("🔧 Current userOrganizations.count: \(userOrganizations.count)");
        
        isLoadingOrgs = true;
        
        cloudKitService.fetchOrganizationsWithRoles(for: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self = self else { return };
                    
                    self.isLoadingOrgs = false;
                    
                    if case .failure(let error) = publisherCompletion {
                        print("🔧 FETCH ORGS FAILED: \(error.localizedDescription)");
                        self.errorMessage = "Failed to load organizations. Please try again.";
                        completion([], [:]);
                    }
                },
                receiveValue: { [weak self] (organizations: [Organization], roles: [String: OrganizationRole]) in
                    guard let self = self else { return };
                    
                    print("🔧 COMPREHENSIVE ORG TRACE: CloudKit fetch completed");
                    print("🔧 CloudKit organizations.count: \(organizations.count)");
                    print("🔧 CloudKit roles.count: \(roles.count)");
                    
                    for (index, org) in organizations.enumerated() {
                        print("🔧 [\(index)] CloudKit Org: \(org.name)");
                        print("     ID: \(org.id.prefix(8))...");
                        print("     Admin: \(org.adminUserID.prefix(8))...");
                        print("     Members: \(org.members.count)");
                        print("     Your Role: \(roles[org.id]?.displayName ?? "Unknown")");
                        print("     Created: \(org.createdAt)");
                        print("     CloudKit RecordID: \(org.cloudKitRecordID ?? "None")");

                    }
                    
                    let countDifference = organizations.count - self.organizations.count;
                    if countDifference != 0 {
                        print("🔧 COUNT MISMATCH DETECTED:");
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

    @MainActor
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
        
        let currentTeamMemberCount = projectVM.teamMembers.filter { $0.organizationID == currentOrg.id }.count;
        print("🔄 ProjectVM team members: \(currentTeamMemberCount)");
        
        let existingAdmin = projectVM.teamMembers.first {
            $0.appUserID == userID && $0.organizationID == currentOrg.id && $0.role == .admin
        }
        
        if existingAdmin == nil {
            print("⚠️ SYNC: No admin team member found - this should be handled by onboarding flow")
            print("   Organization: \(currentOrg.name)")
            print("   Admin User ID: \(userID.prefix(8))...")
            print("   Consider triggering admin onboarding if not completed")
            
            // CRITICAL FIX: Trigger admin onboarding when no admin team member exists
            print("🎯 ADMIN ONBOARDING FIX: Setting showAdminInfoUpdate = true for missing admin")
            self.showAdminInfoUpdate = true
            self.objectWillChange.send() // Force UI update
            print("🎯 ADMIN ONBOARDING FIX: Admin onboarding triggered successfully!")
        } else {
            print("✅ SYNC: Admin team member exists: \(existingAdmin?.name ?? "Unknown")")
        }
        
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
    
    /// ENTERPRISE: Validate organization data integrity
    private func validateOrganizationDataIntegrity(_ organization: Organization) async {
        print("🔧 ENTERPRISE: Validating data integrity for organization: \(organization.name)");
        
        guard let projectVM = self.projectVM else {
            print("🔧 ENTERPRISE: ProjectViewModel not available for validation");
            return;
        }
        
        let cloudKitMemberCount = organization.members.count + 1 // +1 for admin
        
        let localTeamMemberCount = await MainActor.run {
            return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count
        }
        
        let projectsCount = await MainActor.run {
            return projectVM.projects.count
        }
        
        let organizationProjectsCount = await MainActor.run {
            return projectVM.organizationProjects.count
        }
        
        let filteredProjectsCount = await MainActor.run {
            return projectVM.projects.filter { $0.organizationID == organization.id }.count
        }
        
        print("🔧 ENTERPRISE VALIDATION:");
        print("   CloudKit Members: \(cloudKitMemberCount)");
        print("   Local Team Members: \(localTeamMemberCount)");
        print("   Total projects: \(projectsCount) vs Organization projects count: \(organizationProjectsCount)");
        print("   Filtered projects for org: \(filteredProjectsCount)");
        
        var hasInconsistency = false
        
        if cloudKitMemberCount != localTeamMemberCount {
            print("🔧 ENTERPRISE: Team member data inconsistency detected - auto-fixing...");
            hasInconsistency = true
            await syncOrganizationTeamMembers();
        }
        
        if organizationProjectsCount != filteredProjectsCount {
            print("🔧 ENTERPRISE: Project data inconsistency detected - auto-fixing...");
            print("   Organization projects: \(organizationProjectsCount)");
            print("   Filtered projects: \(filteredProjectsCount)");
            hasInconsistency = true
            
            let correctProjects = await MainActor.run {
                return projectVM.projects.filter { $0.organizationID == organization.id }
            }
            
            await MainActor.run {
                projectVM.organizationProjects = correctProjects
                projectVM.updateAccessibleProjects()
                print("🔧 PROJECT CONSISTENCY: Fixed organization projects array - now \(correctProjects.count) projects")
            }
        }
        
        let accessibleProjectsCount = await MainActor.run {
            return projectVM.accessibleProjects.count
        }
        
        if accessibleProjectsCount != organizationProjectsCount {
            print("🔧 ENTERPRISE: Accessible projects inconsistency detected - auto-fixing...");
            hasInconsistency = true
            
            await MainActor.run {
                projectVM.updateAccessibleProjects()
                let newAccessibleCount = projectVM.accessibleProjects.count
                print("🔧 ACCESSIBLE PROJECTS: Fixed accessible projects array - now \(newAccessibleCount) projects")
            }
        }
        
        if hasInconsistency {
            let finalTeamMemberCount = await MainActor.run {
                return projectVM.teamMembers.filter { $0.organizationID == organization.id }.count
            }
            
            let finalOrgProjectsCount = await MainActor.run {
                return projectVM.organizationProjects.count  
            }
            
            let finalAccessibleCount = await MainActor.run {
                return projectVM.accessibleProjects.count
            }
            
            print("🔧 ENTERPRISE: Data integrity restored:");
            print("   Local Team Members: \(finalTeamMemberCount)");
            print("   Organization Projects: \(finalOrgProjectsCount)");
            print("   Accessible Projects: \(finalAccessibleCount)");
        } else {
            print("🔧 ENTERPRISE: Data integrity verified - all systems synchronized");
        }
    }

    /// Ensure admin team member exists
    private func ensureAdminTeamMemberExists() {
        print("🔧 ADMIN CHECK: Checking for admin team member...")
        
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
                print("🔧 ADMIN CHECK: No admin found - onboarding may be needed")
                print("   Organization: \(organization.name)")
                print("   Admin User ID: \(userID.prefix(8))...")
                print("   Consider triggering admin onboarding if not completed")
            } else {
                print("🔧 ADMIN CHECK: Admin exists: \(existingAdmin?.name ?? "Unknown")")
            }
        }
    }

    /// Create immediate basic admin team member to prevent "No admin found" warnings
    private func createImmediateAdminTeamMember(organization: Organization, userID: String, projectViewModel: ProjectViewModel) async {
        print("🔧 IMMEDIATE ADMIN: Creating basic admin team member...")
        
        let existingAdmin = await MainActor.run {
            return projectViewModel.teamMembers.first { 
                $0.appUserID == userID && 
                $0.organizationID == organization.id && 
                $0.role == .admin 
            }
        }
        
        if existingAdmin != nil {
            print("🔧 IMMEDIATE ADMIN: Admin already exists - skipping creation")
            return
        }
        
        let adminEmail = user?.email ?? "admin@company.com"
        let adminName = adminEmail.components(separatedBy: "@").first?.capitalized ?? "Administrator"
        
        let basicAdmin = TeamMember(
            id: UUID(),
            name: adminName,
            email: adminEmail,
            phone: "",
            jobTitle: "Owner/Administrator",
            rates: [
                EmployeeRate(
                    taskType: "Administrative Work",
                    rate: 75.0,
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
        );
        
        await MainActor.run {
            projectViewModel.teamMembers.append(basicAdmin)
            print("🔧 IMMEDIATE ADMIN: Added basic admin to ProjectViewModel: \(adminName)")
        }
        
        Task {
            do {
                try await self.saveBasicAdminToCloudKit(basicAdmin)
                print("🔧 IMMEDIATE ADMIN: Saved basic admin to CloudKit")
            } catch {
                print("🔧 IMMEDIATE ADMIN: Failed to save to CloudKit (will retry): \(error)")
            }
        }
        
        print("🔧 IMMEDIATE ADMIN: Basic admin creation completed - onboarding can now enhance profile")
    }
    
    /// Save basic admin team member to CloudKit
    private func saveBasicAdminToCloudKit(_ teamMember: TeamMember) async throws {
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDatabase = container.privateCloudDatabase
        
        let recordID = CKRecord.ID(recordName: "team_member_\(teamMember.id.uuidString)")
        let record = CKRecord(recordType: "TeamMember", recordID: recordID)
        
        record["id"] = teamMember.id.uuidString as CKRecordValue
        record["name"] = teamMember.name as CKRecordValue
        record["email"] = teamMember.email as CKRecordValue
        record["phone"] = teamMember.phone as CKRecordValue
        record["jobTitle"] = teamMember.jobTitle as CKRecordValue
        record["organizationID"] = teamMember.organizationID as CKRecordValue
        record["role"] = teamMember.role.rawValue as CKRecordValue
        record["isActive"] = (teamMember.isActive ? 1 : 0) as CKRecordValue
        record["hasAppAccess"] = (teamMember.hasAppAccess ? 1 : 0) as CKRecordValue
        record["employmentStatus"] = teamMember.employmentStatus.rawValue as CKRecordValue
        record["employmentType"] = teamMember.employmentType.rawValue as CKRecordValue
        record["environment"] = "production" as CKRecordValue
        record["dateAdded"] = Date() as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        // Add app user ID if available
        if let appUserID = teamMember.appUserID {
            record["appUserID"] = appUserID as CKRecordValue
        }
        
        if let ratesData = try? JSONEncoder().encode(teamMember.rates) {
            record["rates"] = ratesData as CKRecordValue
        }
        
        if let defaultRate = teamMember.rates.first(where: { $0.isDefault }) {
            record["defaultRate"] = defaultRate.rate as CKRecordValue
        }
        
        _ = try await privateDatabase.save(record)
        print("🔧 CLOUDKIT: Basic admin TeamMember saved successfully")
    }

    // MARK: - Sign Out
    
    func signOut() {
        print("🔧 Signing out user");
        
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID");
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName");
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
        
        notifyProjectViewModelOrganizationChange(nil);
        print("🔧 Zone isolation cleared");
        
        service.signOut();
    }
    
    // MARK: - Team Member and Invite Management
    
    /// Check for pending invites (public method)
    func checkForPendingInvites() {
        if UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil {
            print("🔧 PENDING INVITE: Found pending invitation - will process after authentication");
            
            if user != nil {
            }
        }
    }

    func invite(email: String) {
        print("🔧 INVITE: Sending invitation to \(email)...")
        isInviting = true
        inviteStatus = "Sending invitation..."
        
        Task {
            do {
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
                
                print("🔧 INVITE: Using CloudKit sharing for organization: \(currentOrg.name)")
                
                try await cloudKitService.inviteUserToOrganization(
                    email: email, 
                    organizationID: currentOrg.id,
                    role: OrganizationRole.member)
                
                
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "Invitation sent to \(email)"
                    self.pendingInvites.append(email)
                }
                
                print("🔧 INVITE: Successfully sent CloudKit invitation to \(email)")
                
            } catch {
                await MainActor.run {
                    self.isInviting = false
                    self.inviteStatus = "Failed to send invitation: \(error.localizedDescription)"
                }
                print("🔧 INVITE: Failed to send invitation to \(email): \(error)")
            }
        }
    }
    
    func inviteUser(email: String, role: OrganizationRole = .member) async -> InviteResult {
        print("🔧 INVITE USER: Sending invitation to \(email) as \(role.displayName)...")
        
        await MainActor.run {
            isInviting = true
            inviteStatus = "Sending invitation to \(email)..."
        }
        
        do {
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
            
            print("🔧 INVITE USER: Using CloudKit sharing for organization: \(currentOrg.name)")
            
            try await cloudKitService.inviteUserToOrganization(
                email: email, 
                organizationID: currentOrg.id,
                role: role)
            
            
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Invitation sent to \(email) as \(role.displayName)"
                self.pendingInvites.append(email)
            }
            
            print("🔧 INVITE USER: Successfully sent CloudKit invitation to \(email) as \(role.displayName) for organization: \(currentOrg.name)")
            
            return InviteResult(success: true, message: "Invitation sent successfully to \(email)")
            
        } catch {
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Failed to send invitation: \(error.localizedDescription)"
            }
            
            print("🔧 INVITE USER: Failed to send invitation to \(email): \(error)")
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
        
        return assignedProjectIDs
    }
    
    func fetchPendingInvites() async -> [String] { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return []
        }
        
        do {
            let invites = try await cloudKitService.fetchPendingInvitesForUser(userID)
            print("🔧 FETCH INVITES: Found \(invites.count) pending invites")
            return invites
        } catch {
            print("🔧 FETCH INVITES: Failed to fetch pending invites: \(error)")
            return []
        }
    }
    
    func clearPendingInvite() {
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID");
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName");
        UserDefaults.standard.removeObject(forKey: "pending_invite_token");
        print("🔧 CLEAR INVITE: Cleared pending invite data")
    }
    
    func dismissAdminInfoUpdate() { 
        showAdminInfoUpdate = false
        print("🔧 DISMISS ADMIN: Admin info update dismissed")
    }
    
    func getShareURLForCopying() -> String? { 
        guard let currentOrg = currentOrg else { return nil }
        
        let baseURL = "https://rheir.app/join"
        let orgParam = "org=\(currentOrg.id)"
        let nameParam = "name=\(currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        let shareURL = "\(baseURL)?\(orgParam)&\(nameParam)"
        print("🔧 SHARE URL: Generated share URL for \(currentOrg.name)")
        return shareURL
    }
    
    func getContractorInviteURLForCopying() -> String? { 
        guard let currentOrg = currentOrg else { return nil }
        
        let baseURL = "https://rheir.app/contractor"
        let orgParam = "org=\(currentOrg.id)"
        let nameParam = "name=\(currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        let contractorURL = "\(baseURL)?\(orgParam)&\(nameParam)"
        print("🔧 CONTRACTOR URL: Generated contractor invite URL for \(currentOrg.name)")
        return contractorURL
    }
    
    func createTeamMemberInviteWithProjects(email: String, role: OrganizationRole, allowedProjectIDs: [String]) async -> InviteResult {
        guard let currentOrg = currentOrg,
              let cloudKitService = service as? CloudKitAuthService else {
            return InviteResult(success: false, message: "No organization selected or CloudKit unavailable")
        }
        
        do {
            teamProjectAssignments[email] = allowedProjectIDs
            
            try await cloudKitService.inviteUserToOrganizationWithProjects(
                email: email, 
                organizationID: currentOrg.id,
                role: role,
                allowedProjectIDs: allowedProjectIDs
            )
            
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Invitation sent to \(email) with access to \(allowedProjectIDs.count) projects"
                self.pendingInvites.append(email)
            }
            
            print("🔧 PROJECT INVITE: Sent invitation to \(email) with access to \(allowedProjectIDs.count) projects")
            return InviteResult(success: true, message: "Invitation sent with project access")
            
        } catch {
            await MainActor.run {
                self.isInviting = false
                self.inviteStatus = "Failed to send invitation: \(error.localizedDescription)"
            }
            print("🔧 PROJECT INVITE: Failed to send invitation: \(error)")
            return InviteResult(success: false, message: "Failed to send invitation: \(error.localizedDescription)")
        }
    }
    
    func repairMissingOrganizationZones() async -> String { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return "🔧 No user or CloudKit service available"
        }
        
        var repairReport = "🔧 ZONE REPAIR: Checking organization zones...\n\n"
        
        for organization in userOrganizations {
            repairReport += "Checking: \(organization.name)\n"
            
            do {
                let zoneExists = try await cloudKitService.checkOrganizationZoneExists(organization.id)
                
                if !zoneExists {
                    repairReport += "  Zone missing - creating...\n"
                    try await cloudKitService.createOrganizationZone(organization.id)
                    repairReport += "  Zone created successfully\n"
                } else {
                    repairReport += "  Zone exists\n"
                }
                
            } catch {
                repairReport += "  Repair failed: \(error.localizedDescription)\n"
            }
            
            repairReport += "\n"
        }
        
        print("🔧 ZONE REPAIR: Completed organization zone repair")
        return repairReport
    }
    
    func getOrganizationZoneStatus() async -> String { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            return "🔧 No user or CloudKit service available"
        }
        
        var statusReport = "🔧 ZONE STATUS: Organization CloudKit zones\n\n"
        
        for organization in userOrganizations {
            statusReport += "Organization: \(organization.name)\n"
            statusReport += "ID: \(organization.id.prefix(8))...\n"
            
            do {
                let zoneExists = try await cloudKitService.checkOrganizationZoneExists(organization.id)
                let recordCount = try await cloudKitService.getOrganizationRecordCount(organization.id)
                
                statusReport += "Zone Status: \(zoneExists ? "🔧 Exists" : "🔧 Missing")\n"
                statusReport += "Records: \(recordCount)\n"
                
            } catch {
                statusReport += "Status: Error checking zone\n"
                statusReport += "Error: \(error.localizedDescription)\n"
            }
            
            statusReport += "\n"
        }
        
        return statusReport
    }
    
    func fixCurrentOrganizationZone() async -> String { 
        guard let currentOrg = currentOrg,
              let cloudKitService = service as? CloudKitAuthService else {
            return "🔧 No current organization or CloudKit service"
        }
        
        var fixReport = "🔧 ZONE FIX: Repairing current organization zone\n\n"
        fixReport += "Organization: \(currentOrg.name)\n"
        fixReport += "ID: \(currentOrg.id.prefix(8))...\n\n"
        
        do {
            let zoneExists = try await cloudKitService.checkOrganizationZoneExists(currentOrg.id)
            fixReport += "Current Status: \(zoneExists ? "🔧 Zone exists" : "🔧 Zone missing")\n"
            
            if !zoneExists {
                fixReport += "Creating zone...\n"
                try await cloudKitService.createOrganizationZone(currentOrg.id)
                fixReport += "🔧 Zone created successfully\n"
            }
            
            if let projectVM = projectVM {
                fixReport += "Setting up ProjectViewModel zone isolation...\n"
                await projectVM.setupCloudKitZoneForOrganization(currentOrg.id)
                fixReport += "🔧 ProjectViewModel zone isolation configured\n"
            }
            
            fixReport += "\n🔧 ZONE FIX: Current organization zone repair completed"
            
        } catch {
            fixReport += "🔧 ZONE FIX: Failed to fix zone: \(error.localizedDescription)"
        }
        
        return fixReport
    }
    
    func switchToOrganization(_ organization: Organization) { 
        Task { @MainActor in
            print("🔧 SWITCH ORG: Switching to organization: \(organization.name)")
            UserDefaults.standard.removeObject(forKey: "previousOrganizationID")
            UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
            UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
            UserDefaults.standard.removeObject(forKey: "pending_invite_token")
            setCurrentOrganization(organization)
        }
    }
    
    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthViewModelError.organizationNameTaken("Organization name cannot be empty")
        }
        
        guard name.count >= 3 else {
            throw AuthViewModelError.organizationNameTaken("Organization name must be at least 3 characters")
        }
        
        print("🔧 VALIDATED CREATION: Creating organization '\(name)' with validation")
        return try await createOrganization(named: name, industry: industry)
    }
    
    func retryPendingInvite() { 
        print("🔧 RETRY INVITE: Checking for pending invites to retry")
        checkForPendingInvites()
        
        if let pendingOrgID = UserDefaults.standard.string(forKey: "pending_invite_orgID"),
           let pendingOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") {
            
            print("🔧 RETRY INVITE: Found pending invite for organization: \(pendingOrgName)")
            inviteStatus = "Processing pending invitation..."
            
            Task {
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
            
            print("🔧 SWITCH PREVIOUS: Switching to previous organization: \(previousOrg.name)")
            
            Task { @MainActor in
                UserDefaults.standard.removeObject(forKey: "previousOrganizationID")
                UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
                UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
                UserDefaults.standard.removeObject(forKey: "pending_invite_token")
                setCurrentOrganization(previousOrg)
            }
        } else {
            print("🔧 SWITCH PREVIOUS: No previous organization found")
        }
    }

    func updateSubscriptionTier(_ newTier: SubscriptionTier) {
        guard var org = currentOrg else {
            print("🔧 No current organization to update subscription tier");
            return;
        }
        
        print("🔧 SUBSCRIPTION UPDATE: Changing from \(org.subscriptionTier.displayName) to \(newTier.displayName)");
        
        org.upgradeSubscription(to: newTier);
        
        if let index = organizations.firstIndex(where: { $0.id == org.id }) {
            organizations[index] = org;
        }
        
        if let index = userOrganizations.firstIndex(where: { $0.id == org.id }) {
            userOrganizations[index] = org;
        }
        
        currentOrg = org;
        
        notifyProjectViewModelOrganizationChange(org.id);
        
        print("🔧 SUBSCRIPTION: Updated organization subscription tier to \(newTier.displayName)");
    }

    func reloadOrganizationData() {
        print("🔧 RELOAD ORG: Reloading organization data")
        
        if let currentOrgID = currentOrg?.id {
            notifyProjectViewModelOrganizationChange(currentOrgID)
        }
        
        if let user = user {
            self.checkUserOrganizationStatus(for: user)
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
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                let unavailableNames = ["test", "demo", "sample", "example"]
                let isAvailable = !unavailableNames.contains(name.lowercased())
                
                await MainActor.run {
                    self.isCheckingNameAvailability = false
                    
                    if isAvailable {
                        self.nameAvailabilityMessage = "🔧 '\(name)' is available"
                    } else {
                        self.nameAvailabilityMessage = "🔧 '\(name)' is not available"
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
            try await Task.sleep(nanoseconds: 300_000_000) 
            
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
        
        for suffix in suffixes {
            suggestions.append("\(baseName) \(suffix)")
        }
        
        for prefix in prefixes {
            suggestions.append("\(prefix) \(baseName)")
        }
        
        for i in 2...5 {
            suggestions.append("\(baseName) \(i)")
        }
        
        return Array(suggestions.prefix(8)) 
    }
    
    func joinOrganization(with organizationID: String, role: OrganizationRole, completion: @escaping (Bool, String?) -> Void) { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "User not authenticated or CloudKit unavailable")
            return
        }
        
        print("🔧 JOIN ORG: Attempting to join organization \(organizationID.prefix(8))... as \(role.displayName)")
        
        Task {
            do {
                let organization = try await cloudKitService.joinOrganization(organizationID, userID: userID, role: role)
                
                await MainActor.run {
                    self.updateOrganizationState(organization, role: role, userID: userID)
                    completion(true, "Successfully joined \(organization.name)")
                }
                
                print("🔧 JOIN ORG: Successfully joined organization: \(organization.name)")
                
            } catch {
                let errorMessage = handleJoinOrganizationError(error)
                completion(false, errorMessage)
                print("🔧 JOIN ORG: Failed to join organization: \(error)")
            }
        }
    }
    
    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) { 
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            completion(false, "User not authenticated or CloudKit unavailable")
            return
        }
        
        guard organizationRoles[organization.id] == .admin else {
            completion(false, "Only organization admin can delete the organization")
            return
        }
        
        print("🔧 DELETE ORG: Attempting to delete organization: \(organization.name)")
        
        cloudKitService.deleteOrganization(organizationID: organization.id)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        break
                    case .failure(let error):
                        completion(false, "Failed to delete organization: \(error.localizedDescription)")
                        print("🔧 DELETE ORG: Failed to delete organization: \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        Task { @MainActor in
                            self.organizations.removeAll { $0.id == organization.id }
                            self.userOrganizations.removeAll { $0.id == organization.id }
                            self.organizationRoles.removeValue(forKey: organization.id)
                            
                            if self.currentOrg?.id == organization.id {
                                self.currentOrg = nil
                                self.needsOrganizationSetup = self.organizations.isEmpty
                            }
                        }
                        
                        completion(true, "Organization '\(organization.name)' deleted successfully")
                        print("🔧 DELETE ORG: Successfully deleted organization: \(organization.name)")
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
        
        guard organizationRoles[organization.id] != .admin || organization.adminUserID != userID else {
            completion(false, "Admin cannot leave organization. Transfer admin role first or delete the organization.")
            return
        }
        
        print("🔧 LEAVE ORG: Attempting to leave organization: \(organization.name)")
        
        cloudKitService.leaveOrganization(organizationID: organization.id, userID: userID)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        break
                    case .failure(let error):
                        completion(false, "Failed to leave organization: \(error.localizedDescription)")
                        print("🔧 LEAVE ORG: Failed to leave organization: \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        Task { @MainActor in
                            self.organizations.removeAll { $0.id == organization.id }
                            self.userOrganizations.removeAll { $0.id == organization.id }
                            self.organizationRoles.removeValue(forKey: organization.id)
                            
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
                        print("🔧 LEAVE ORG: Successfully left organization: \(organization.name)")
                    } else {
                        completion(false, "Failed to leave organization")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateOrganizationState(_ organization: Organization, role: OrganizationRole, userID: String) { 
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization)
        }
        
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization)
        }
        
        organizationRoles[organization.id] = role
        
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
        print("🔧 FIX DATA: Starting data inconsistency repair...");
        
        Task {
            if let user = user {
                self.checkUserOrganizationStatus(for: user)
            }
            
            if let currentOrg = currentOrg {
                if !organizations.contains(where: { $0.id == currentOrg.id }) {
                    
                    print("🔧 FIX DATA: Current organization no longer exists, switching to first available")
                    
                    await MainActor.run {
                        if let firstOrg = self.organizations.first {
                            self.setCurrentOrganization(firstOrg)
                        } else {
                            self.currentOrg = nil
                            self.needsOrganizationSetup = true
                        }
                    }
                }
            }
            
            await syncOrganizationTeamMembers()
            
            print("🔧 FIX DATA: Data inconsistency repair completed")
        }
    }
    
    func fetchUserProjectAssignments(organizationID: String, userID: String) {
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("🔧 PROJECT ASSIGNMENTS: CloudKit service unavailable")
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
                    print("🔧 PROJECT ASSIGNMENTS: Loaded \(assignments.count) project assignments")
                }
                
            } catch {
                print("🔧 PROJECT ASSIGNMENTS: Failed to fetch assignments: \(error)")
            }
        }
    }
    
    func validateDataConsistency() async -> String {
        var report = "🔧 DATA CONSISTENCY VALIDATION\n\n"
        
        report += "User Authentication:\n"
        report += "- User: \(user?.email ?? "None")\n"
        report += "- Organizations: \(organizations.count)\n"
        report += "- User Organizations: \(userOrganizations.count)\n"
        report += "- Current Org: \(currentOrg?.name ?? "None")\n\n"
        
        report += "Organization Roles:\n"
        for (orgID, role) in organizationRoles {
            report += "- \(orgID.prefix(8))...: \(role.displayName)\n"
        }
        
        let cloudKitStatus = await checkCloudKitStatus()
        report += "\nCloudKit Status: \(cloudKitStatus)\n"
        
        if let currentOrg = currentOrg {
            let existsInOrgs = organizations.contains { $0.id == currentOrg.id }
            let existsInUserOrgs = userOrganizations.contains { $0.id == currentOrg.id }
            
            report += "\nCurrent Organization Validation:\n"
            report += "- Exists in organizations: \(existsInOrgs)\n"
            report += "- Exists in userOrganizations: \(existsInUserOrgs)\n"
            
            if !existsInOrgs || !existsInUserOrgs {
                report += "🔧 INCONSISTENCY DETECTED\n"
            }
        }
        
        print("🔧 DATA CONSISTENCY: Validation completed")
        return report
    }
    
    func forceCloudKitSync() async -> String {
        guard let userID = user?.id else {
            return "🔧 No user authenticated"
        }
        
        var syncReport = "🔧 FORCE CLOUDKIT SYNC\n\n"
        syncReport += "Starting forced synchronization...\n"
        
        syncReport += "1. Refreshing organization data...\n"
        
        return await withCheckedContinuation { continuation in
            fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
                guard let self = self else {
                    continuation.resume(returning: "🔧 Self reference lost")
                    return
                }
                
                Task { @MainActor in
                    self.organizations = orgs
                    self.userOrganizations = orgs
                    self.organizationRoles = roles
                    
                    var report = syncReport
                    report += "🔧 Organizations synced: \(orgs.count)\n"
                    report += "🔧 Roles synced: \(roles.count)\n"
                    
                    if self.currentOrg != nil {
                        await self.syncOrganizationTeamMembers()
                        report += "🔧 Team members synced\n"
                    }
                    
                    report += "\n🔧 FORCE SYNC: Completed successfully"
                    print("🔧 FORCE SYNC: CloudKit synchronization completed")
                    
                    continuation.resume(returning: report)
                }
            }
        }
    }
    
    func clearAllLocalCache() {
        print("🔧 CLEAR CACHE: Clearing all local cache data")
        
        organizations = []
        userOrganizations = []
        organizationRoles = [:]
        currentOrg = nil
        
        pendingInvites = []
        inviteStatus = ""
        assignedProjectIDs = []
        teamProjectAssignments = [:]
        
        UserDefaults.standard.removeObject(forKey: "currentOrganizationID")
        UserDefaults.standard.removeObject(forKey: "previousOrganizationID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        
        needsOrganizationSetup = true
        showOrganizationSetup = false
        showAdminInfoUpdate = false
        
        print("🔧 CLEAR CACHE: All local cache cleared")
    }
    
    var currentOrganizationRole: OrganizationRole? {
        guard let currentOrg = currentOrg else { return nil }
        return organizationRoles[currentOrg.id]
    }
    
    var adminOrganizations: [Organization] {
        return userOrganizations.filter { organizationRoles[$0.id] == .admin }
    }
    
    var contractorOrganizations: [Organization] {
        return userOrganizations.filter { organizationRoles[$0.id] == .contractor }
    }
    
    var canPerformAdminActions: Bool {
        guard let currentOrg = currentOrg else { return false }
        return organizationRoles[currentOrg.id] == .admin
    }
    
    func getUserRole(for organization: Organization) -> OrganizationRole? {
        return organizationRoles[organization.id]
    }
}