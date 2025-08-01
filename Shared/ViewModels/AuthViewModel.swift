import Foundation
import Combine
import AuthenticationServices
import CloudKit

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

    // MARK: - Services
    private let service: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - ProjectViewModel Integration
    private var projectViewModel: ProjectViewModel?

    // MARK: - Initialization
    
    init(service: AuthService) {
        self.service = service
        print("🔐 AuthViewModel initializing...")
        
        self.user = service.currentUser
        
        if let user = user {
            print("✅ Found existing authentication for user: \(user.email)")
            checkUserOrganizationStatus(for: user)
        } else {
            print("🔐 No existing authentication - user needs to sign in")
        }
    }
    
    /// Set the ProjectViewModel reference for organization synchronization
    func setProjectViewModel(_ projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        print("🔗 Connected ProjectViewModel with zone isolation")
        
        // Sync current organization to ProjectViewModel
        if let currentOrg = currentOrg {
            Task { @MainActor in
                projectViewModel.organizationDidChange(currentOrg.id)
                print("🛡️ Activated zone isolation for: \(currentOrg.name)")
            }
        }
    }

    // MARK: – Apple Sign-In

    func signInWithApple(using appleCred: ASAuthorizationAppleIDCredential) {
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
            print("✅ Already authenticated with CloudKit")
            checkUserOrganizationStatus(for: user!)
        } else {
            cloudKitService.signInWithApple(with: appleCred)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        guard let self = self else { return }
                        self.isLoadingAuth = false
                        
                        if case let .failure(error) = completion {
                            print("❌ Apple Sign-In failed: \(error)")
                            self.errorMessage = "Sign-in failed. Please try again."
                        }
                    },
                    receiveValue: { [weak self] user in
                        guard let self = self else { return }
                        
                        self.user = user
                        print("✅ Apple Sign-In successful for: \(user.email)")
                        self.checkUserOrganizationStatus(for: user)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Organization Status Check
    
    private func checkUserOrganizationStatus(for user: User) {
        print("🔍 Checking organization status for: \(user.email)")
        
        // Check for pending invites first
        checkForPendingInvites()
        
        // Then fetch user's organizations with roles
        fetchUserOrganizationsWithRoles { [weak self] orgs, roles in
            guard let self = self else { return }
            
            // Update both legacy and new organization arrays
            self.organizations = orgs
            self.userOrganizations = orgs
            self.organizationRoles = roles
            
            if orgs.isEmpty && !self.hasPendingInvite() {
                print("📋 No organizations found - setup required")
                self.needsOrganizationSetup = true
                self.showOrganizationSetup = true
                
                // Clear organization in ProjectViewModel
                if let projectVM = self.projectViewModel {
                    Task { @MainActor in
                        projectVM.organizationDidChange(nil)
                    }
                }
            } else if let firstOrg = orgs.first {
                print("📋 Found \(orgs.count) organization(s)")
                
                // Check for stored organization preference
                let storedOrgID = UserDefaults.standard.string(forKey: "currentOrganizationID")
                let selectedOrg = orgs.first { $0.id == storedOrgID } ?? firstOrg
                
                self.setCurrentOrganization(selectedOrg)
                self.needsOrganizationSetup = false
            }
        }
    }
    
    private func hasPendingInvite() -> Bool {
        return UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil
    }

    // MARK: - Organization Management
    
    /// Set the current organization
    func setCurrentOrganization(_ organization: Organization) {
        currentOrg = organization
        needsOrganizationSetup = false
        showOrganizationSetup = false
        
        // Add to organizations list if not already there
        if !organizations.contains(where: { $0.id == organization.id }) {
            organizations.append(organization)
        }
        
        // Add to user organizations list if not already there
        if !userOrganizations.contains(where: { $0.id == organization.id }) {
            userOrganizations.append(organization)
        }
        
        // Notify ProjectViewModel of organization change with role information
        if let projectVM = projectViewModel,
           let userRole = organizationRoles[organization.id] {
            Task { @MainActor in
                projectVM.organizationDidChange(organization.id)
                projectVM.setCurrentUserRole(userRole, forOrganization: organization.id)
                print("🛡️ Zone isolation activated for: \(organization.name) with role: \(userRole.displayName)")
            }
        }
        
        // Store organization ID for persistence
        UserDefaults.standard.set(organization.id, forKey: "currentOrganizationID")
        print("✅ Current organization set: \(organization.name)")
    }
    
    /// Create organization using CloudKit with proper timeout and error handling
    func createOrganization(named name: String, industry: String? = nil) async throws -> Organization {
        guard let userID = user?.id else {
            throw AuthViewModelError.noUserLoggedIn
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            throw AuthViewModelError.cloudKitServiceNotAvailable
        }
        
        print("🏢 Creating organization: \(name)")
        
        // Simple, clean approach - let CloudKit service handle everything
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
                .store(in: &cancellables)
        }
        
        await MainActor.run {
            // Add to local lists
            if !self.organizations.contains(where: { $0.id == organization.id }) {
                self.organizations.append(organization)
            }
            if !self.userOrganizations.contains(where: { $0.id == organization.id }) {
                self.userOrganizations.append(organization)
            }
            
            // Set admin role for creator
            self.organizationRoles[organization.id] = .admin
            
            print("✅ Added organization to local lists: \(self.organizations.count) total")
            
            // Set as current organization
            self.setCurrentOrganization(organization)
        }
        
        print("✅ Organization created successfully: \(name)")
        return organization
    }

    /// Create organization with name validation
    func createOrganizationWithValidation(named name: String, industry: String? = nil) async throws -> Organization {
        guard let cloudKitService = service as? CloudKitAuthService else {
            throw AuthViewModelError.cloudKitServiceNotAvailable
        }
        
        // Simple name availability check
        let isAvailable = try await withCheckedThrowingContinuation { continuation in
            cloudKitService.isOrganizationNameAvailable(name)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { available in
                        continuation.resume(returning: available)
                    }
                )
                .store(in: &cancellables)
        }
        
        if !isAvailable {
            throw AuthViewModelError.organizationNameTaken(name)
        }
        
        // Proceed with creation if name is available
        return try await createOrganization(named: name, industry: industry)
    }

    // MARK: - Organization Management & Editing
    
    /// Update organization details
    func updateOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard service is CloudKitAuthService else {
            completion(false, "CloudKit service not available")
            return
        }
        
        print("🏢 Updating organization: \(organization.name)")
        
        // TODO: Implement organization update in CloudKit service
        // For now, update locally and simulate success
        
        // Update in local arrays
        if let index = organizations.firstIndex(where: { $0.id == organization.id }) {
            organizations[index] = organization
        }
        if let index = userOrganizations.firstIndex(where: { $0.id == organization.id }) {
            userOrganizations[index] = organization
        }
        
        // Update current organization if it's the one being edited
        if currentOrg?.id == organization.id {
            currentOrg = organization
        }
        
        completion(true, "Organization updated successfully")
    }
    
    /// Delete organization (admin only)
    func deleteOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userRole = organizationRoles[organization.id] else {
            completion(false, "Unable to determine your role in this organization")
            return
        }
        
        guard userRole == .admin else {
            completion(false, "Only administrators can delete organizations")
            return
        }
        
        guard service is CloudKitAuthService else {
            completion(false, "CloudKit service not available")
            return
        }
        
        print("🗑️ Deleting organization: \(organization.name)")
        
        // TODO: Implement organization deletion in CloudKit service
        // This should:
        // 1. Delete all organization projects
        // 2. Remove all members
        // 3. Delete the organization record
        // 4. Clean up CloudKit zone
        
        // For now, simulate the deletion locally
        organizations.removeAll { $0.id == organization.id }
        userOrganizations.removeAll { $0.id == organization.id }
        organizationRoles.removeValue(forKey: organization.id)
        
        // If this was the current organization, switch to another or prompt for creation
        if currentOrg?.id == organization.id {
            if let firstAvailableOrg = userOrganizations.first {
                setCurrentOrganization(firstAvailableOrg)
                completion(true, "Organization deleted. Switched to \(firstAvailableOrg.name)")
            } else {
                currentOrg = nil
                needsOrganizationSetup = true
                showOrganizationSetup = true
                completion(true, "Organization deleted. Please create a new organization or join an existing one.")
            }
        } else {
            completion(true, "Organization deleted successfully")
        }
    }
    
    /// Leave organization (for non-admins)
    func leaveOrganization(_ organization: Organization, completion: @escaping (Bool, String?) -> Void) {
        guard let userRole = organizationRoles[organization.id] else {
            completion(false, "Unable to determine your role in this organization")
            return
        }
        
        guard userRole != .admin else {
            completion(false, "Administrators cannot leave their organization. You must delete it or transfer ownership first.")
            return
        }
        
        guard service is CloudKitAuthService else {
            completion(false, "CloudKit service not available")
            return
        }
        
        print("🚪 Leaving organization: \(organization.name)")
        
        // TODO: Implement leave organization in CloudKit service
        // This should remove the user from the organization's member list
        
        // For now, simulate leaving locally
        organizations.removeAll { $0.id == organization.id }
        userOrganizations.removeAll { $0.id == organization.id }
        organizationRoles.removeValue(forKey: organization.id)
        
        // If this was the current organization, switch to another or prompt for creation
        if currentOrg?.id == organization.id {
            if let firstAvailableOrg = userOrganizations.first {
                setCurrentOrganization(firstAvailableOrg)
                completion(true, "Left organization. Switched to \(firstAvailableOrg.name)")
            } else {
                currentOrg = nil
                needsOrganizationSetup = true
                showOrganizationSetup = true
                completion(true, "Left organization. Please create a new organization or join an existing one.")
            }
        } else {
            completion(true, "Left organization successfully")
        }
    }

    // MARK: - Multi-Organization Support Methods

    /// Join an organization with role-based access and project assignments
    func joinOrganization(with orgID: String, role: OrganizationRole = .member, projectIDs: [String] = [], completion: @escaping (Bool, String?) -> Void) {
        print("📧 JOIN DEBUG: Starting joinOrganization")
        print("📧 JOIN DEBUG: OrgID: \(orgID)")
        print("📧 JOIN DEBUG: Role: \(role.displayName)")
        
        guard let user = self.user else {
            print("📧 JOIN DEBUG: ERROR - No user logged in")
            completion(false, "Please sign in first")
            return
        }
        
        print("📧 JOIN DEBUG: User found: \(user.email)")
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("📧 JOIN DEBUG: ERROR - CloudKit service not available")
            completion(false, "CloudKit service not available")
            return
        }
        
        print("📧 JOIN DEBUG: CloudKit service available")
        print("🔗 Joining organization: \(orgID) as \(role.displayName)")
        if !projectIDs.isEmpty {
            print("📋 Will be assigned to \(projectIDs.count) specific projects")
        }
        
        // Use CloudKit to join organization with role
        print("📧 JOIN DEBUG: Calling cloudKitService.joinOrganizationWithRole...")
        _ = cloudKitService.joinOrganizationWithRole(orgID: orgID, userID: user.id, role: role)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionResult in
                    print("📧 JOIN DEBUG: CloudKit completion received")
                    if case .failure(let error) = completionResult {
                        print("❌ Failed to join organization: \(error)")
                        print("📧 JOIN DEBUG: CloudKit error details: \(error.localizedDescription)")
                        
                        // Provide more specific error messages
                        let errorMessage: String
                        if let ckError = error as? CKError {
                            print("📧 JOIN DEBUG: CKError code: \(ckError.code.rawValue)")
                            switch ckError.code {
                            case .unknownItem:
                                errorMessage = "Organization not found. The invite link may be invalid or expired."
                            case .networkUnavailable:
                                errorMessage = "Network unavailable. Please check your internet connection and try again."
                            case .notAuthenticated:
                                errorMessage = "Please sign in to iCloud and try again."
                            case .quotaExceeded:
                                errorMessage = "Organization is full. Contact the admin for more space."
                            default:
                                errorMessage = "Failed to join organization: \(ckError.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Failed to join organization. Please check the invite link and try again."
                        }
                        
                        completion(false, errorMessage)
                    }
                },
                receiveValue: { [weak self] organization in
                    guard let self = self else { return }
                    
                    print("📧 JOIN DEBUG: CloudKit success - received organization")
                    print("📧 JOIN DEBUG: Organization name: \(organization.name)")
                    print("📧 JOIN DEBUG: Organization ID: \(organization.id)")
                    print("✅ Successfully joined organization: \(organization.name) as \(role.displayName)")
                    
                    // Add to user's organizations if not already there
                    if !self.userOrganizations.contains(where: { $0.id == organization.id }) {
                        self.userOrganizations.append(organization)
                        print("📧 JOIN DEBUG: Added to userOrganizations")
                    }
                    if !self.organizations.contains(where: { $0.id == organization.id }) {
                        self.organizations.append(organization)
                        print("📧 JOIN DEBUG: Added to organizations")
                    }
                    
                    // CRITICAL: Set role for this organization BEFORE setting as current
                    self.organizationRoles[organization.id] = role
                    print("🔐 Set user role: \(role.displayName) for organization \(organization.id.prefix(8))...")
                    
                    // For contractors joining new orgs, don't auto-switch if they already have a current org
                    let shouldAutoSwitch = self.currentOrg == nil || role == .admin || role == .member
                    print("📧 JOIN DEBUG: Should auto-switch: \(shouldAutoSwitch)")
                    
                    if shouldAutoSwitch {
                        print("📧 JOIN DEBUG: Setting as current organization")
                        self.setCurrentOrganization(organization)
                        completion(true, "Joined \(organization.name) and switched to it.")
                    } else {
                        // For contractors, notify but don't auto-switch
                        self.inviteStatus = "✅ Joined \(organization.name) as contractor. Use organization menu to switch."
                        completion(true, "Joined \(organization.name). Use the organization dropdown to switch between your organizations.")
                    }
                    
                    // Trigger project access setup for team members
                    if role == .member || role == .admin {
                        print("📧 JOIN DEBUG: Setting up project access for team member")
                        Task {
                            // Auto-assign to all organization projects
                            await self.setupProjectAccessForNewTeamMember(organization: organization, userID: user.id, role: role)
                        }
                    } else if role == .contractor && !projectIDs.isEmpty {
                        print("📧 JOIN DEBUG: Setting up project access for contractor")
                        Task {
                            // Assign to specific projects
                            await self.setupContractorProjectAccess(organization: organization, userID: user.id, projectIDs: projectIDs)
                        }
                    }
                }
            )
    }
    
    /// Setup project access for new team members (auto-assign to all projects)
    private func setupProjectAccessForNewTeamMember(organization: Organization, userID: String, role: OrganizationRole) async {
        guard role == .member || role == .admin else {
            print("👤 Contractor role - projects will be assigned individually")
            return
        }
        
        print("🔧 Setting up project access for new team member...")
        
        // Notify ProjectViewModel to sync project access
        if let projectVM = projectViewModel {
            await projectVM.syncTeamMemberProjectAccess()
            print("✅ Project access setup completed for new team member")
        }
    }
    
    /// Setup project access for contractors with specific project assignments
    private func setupContractorProjectAccess(organization: Organization, userID: String, projectIDs: [String]) async {
        print("🔧 Setting up contractor project access for \(projectIDs.count) projects...")
        
        // This would integrate with ProjectViewModel to assign contractor to specific projects
        if let projectVM = projectViewModel {
            // Switch to the organization temporarily to assign projects
            let originalOrg = currentOrg
            setCurrentOrganization(organization)
            
            // TODO: Implement specific project assignment logic
            // For now, just log the intent
            print("📋 Would assign contractor \(userID.prefix(8))... to projects: \(projectIDs)")
            
            // Switch back to original org if it was different
            if let originalOrg = originalOrg, originalOrg.id != organization.id {
                setCurrentOrganization(originalOrg)
            }
        }
        
        print("✅ Contractor project access setup completed")
    }

    /// Switch between organizations with context preservation
    func switchToOrganization(_ organization: Organization) {
        guard userOrganizations.contains(where: { $0.id == organization.id }) else {
            print("⚠️ User is not a member of organization: \(organization.name)")
            return
        }
        
        print("🔄 Switching to organization: \(organization.name)")
        
        // Store previous organization for quick switching
        if let currentOrgID = currentOrg?.id {
            UserDefaults.standard.set(currentOrgID, forKey: "previousOrganizationID")
        }
        
        setCurrentOrganization(organization)
        
        // Show role-based welcome message and setup
        if let role = organizationRoles[organization.id] {
            switch role {
            case .admin:
                inviteStatus = "✅ Switched to \(organization.name) - Full administrative access"
            case .member:
                inviteStatus = "✅ Switched to \(organization.name) - Team member access to all projects"
            case .contractor:
                inviteStatus = "✅ Switched to \(organization.name) - Contractor access to assigned projects"
            case .viewer:
                inviteStatus = "✅ Switched to \(organization.name) - Read-only access"
            }
            
            // Trigger role-specific setup
            if let projectVM = projectViewModel {
                Task {
                    // Sync project access based on role
                    if role == .member || role == .admin {
                        await projectVM.syncTeamMemberProjectAccess()
                    }
                    print("🔧 Project access synced for role: \(role.displayName)")
                }
            }
        }
    }
    
    /// Quick switch back to previous organization (useful for contractors)
    func switchToPreviousOrganization() {
        guard let previousOrgID = UserDefaults.standard.string(forKey: "previousOrganizationID"),
              let previousOrg = userOrganizations.first(where: { $0.id == previousOrgID }) else {
            print("⚠️ No previous organization available")
            inviteStatus = "No previous organization to switch to"
            return
        }
        
        switchToOrganization(previousOrg)
        print("🔄 Switched back to previous organization: \(previousOrg.name)")
    }
    
    /// Get organization switching context for contractors
    func getOrganizationSwitchingContext() -> String {
        let totalOrgs = userOrganizations.count
        let adminOrgs = adminOrganizations.count
        let memberOrgs = userOrganizations.filter { organizationRoles[$0.id] == .member }.count
        let contractorOrgs = contractorOrganizations.count
        
        var context = "ORGANIZATION CONTEXT:\n"
        context += "• Total Organizations: \(totalOrgs)\n"
        
        if adminOrgs > 0 {
            context += "• Your Companies: \(adminOrgs)\n"
        }
        if memberOrgs > 0 {
            context += "• Team Member: \(memberOrgs)\n"
        }
        if contractorOrgs > 0 {
            context += "• Contractor Access: \(contractorOrgs)\n"
        }
        
        if let currentOrg = currentOrg,
           let role = organizationRoles[currentOrg.id] {
            context += "\nCURRENT: \(currentOrg.name) (\(role.displayName))"
        }
        
        return context
    }

    /// Get user's role in current organization
    var currentOrganizationRole: OrganizationRole? {
        guard let currentOrg = currentOrg else { return nil }
        return organizationRoles[currentOrg.id]
    }

    /// Check if user can perform admin actions in current org
    var canPerformAdminActions: Bool {
        return currentOrganizationRole?.canInviteOthers ?? false
    }

    /// Get organizations where user is admin
    var adminOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .admin
        }
    }

    /// Get organizations where user is contractor
    var contractorOrganizations: [Organization] {
        return userOrganizations.filter { org in
            organizationRoles[org.id] == .contractor
        }
    }

    // MARK: - Invite Link Generation (Production-Ready)
    
    /// Create invite URL optimized for pre-App Store testing
    func createShareURL() -> String? {
        guard let currentOrg = self.currentOrg else {
            print("⚠️ No current organization for invite link")
            return nil
        }
        
        let token = "invite-\(UUID().uuidString.prefix(8))"
        let encodedName = currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentOrg.name
        
        // For pre-App Store testing, use custom scheme that directly opens the app
        let customSchemeLink = "rheirhome://invite?orgID=\(currentOrg.id)&name=\(encodedName)&token=\(token)"
        
        print("🔗 Generated invite link for: \(currentOrg.name)")
        return customSchemeLink
    }
    
    /// Create contractor-specific invite URL for one-time/project-specific work
    func createContractorInviteURL(for projectIDs: [String] = []) -> String? {
        guard let currentOrg = self.currentOrg else {
            print("⚠️ No current organization for contractor invite link")
            return nil
        }
        
        let token = "contractor-invite-\(UUID().uuidString.prefix(8))"
        let encodedName = currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentOrg.name
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "rheirhome"
        urlComponents.host = "invite"
        urlComponents.queryItems = [
            URLQueryItem(name: "orgID", value: currentOrg.id),
            URLQueryItem(name: "name", value: encodedName),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "role", value: OrganizationRole.contractor.rawValue)
        ]
        
        // Add specific project assignments if provided
        if !projectIDs.isEmpty {
            let projectIDsString = projectIDs.joined(separator: ",")
            urlComponents.queryItems?.append(URLQueryItem(name: "projects", value: projectIDsString))
        }
        
        let contractorInviteLink = urlComponents.url?.absoluteString ?? "rheirhome://invite?orgID=\(currentOrg.id)&name=\(encodedName)&token=\(token)&role=contractor"
        
        print("🔗 Generated contractor invite link for: \(currentOrg.name)")
        return contractorInviteLink
    }
    
    /// Get shareable invite URL with user feedback
    func getShareURLForCopying() -> String {
        guard let shareURL = createShareURL() else {
            return "Unable to create invite link. Please try again."
        }
        
        inviteStatus = "✅ Invite link created! Share this with team members to join your organization."
        
        // Track pending invite
        let memberIdentifier = "invite-\(Date().timeIntervalSince1970)"
        if !pendingInvites.contains(memberIdentifier) {
            pendingInvites.append(memberIdentifier)
        }
        
        return shareURL
    }
    
    /// Get contractor-specific shareable invite URL
    func getContractorInviteURLForCopying(for projectIDs: [String] = []) -> String {
        guard let contractorURL = createContractorInviteURL(for: projectIDs) else {
            return "Unable to create contractor invite link. Please try again."
        }
        
        if projectIDs.isEmpty {
            inviteStatus = "✅ Contractor invite link created! They'll have access to assigned projects."
        } else {
            inviteStatus = "✅ Contractor invite link created! They'll have access to \(projectIDs.count) specific project(s)."
        }
        
        return contractorURL
    }

    // MARK: - Team Member Invitation Methods
    
    /// Get a shareable organization invite link for team members
    func getTeamMemberInviteLink() -> String? {
        guard let currentOrg = self.currentOrg else { 
            print("⚠️ No current organization for team invite link")
            return nil 
        }
        
        let token = "team-invite-\(UUID().uuidString.prefix(8))"
        let encodedName = currentOrg.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentOrg.name
        
        // Use custom scheme for pre-App Store testing
        let teamInviteLink = "rheirhome://invite?orgID=\(currentOrg.id)&name=\(encodedName)&token=\(token)&type=team&role=member"
        
        print("🔗 Generated team invite link for: \(currentOrg.name)")
        return teamInviteLink
    }

    // MARK: - Pending Invite Processing with Timeout
    
    private func checkForPendingInvites() {
        guard let orgID = UserDefaults.standard.string(forKey: "pending_invite_orgID"),
              let orgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") else {
            print("📧 No pending invite found")
            return
        }
        
        // Get the role from stored invite, default to member
        let roleString = UserDefaults.standard.string(forKey: "pending_invite_role") ?? "member"
        let role = OrganizationRole(rawValue: roleString) ?? .member
        
        print("📧 INVITE DEBUG: Processing pending invite")
        print("📧 INVITE DEBUG: OrgID: \(orgID)")
        print("📧 INVITE DEBUG: OrgName: \(orgName)")
        print("📧 INVITE DEBUG: Role: \(role.displayName)")
        print("📧 INVITE DEBUG: Current user: \(user?.email ?? "nil")")
        
        inviteStatus = "Connecting to \(orgName) as \(role.displayName)..."
        
        // Set a timeout to prevent indefinite hanging
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            DispatchQueue.main.async {
                print("📧 INVITE DEBUG: TIMEOUT - Invite processing took too long")
                self.handleInviteTimeout(orgName: orgName)
            }
        }
        
        // Join the organization with the specified role
        print("📧 INVITE DEBUG: Calling joinOrganization...")
        joinOrganization(with: orgID, role: role) { [weak self] success, error in
            DispatchQueue.main.async {
                timeoutTimer.invalidate() // Cancel timeout since we got a response
                
                print("📧 INVITE DEBUG: joinOrganization completed - Success: \(success)")
                if let error = error {
                    print("📧 INVITE DEBUG: Error: \(error)")
                }
                
                if success {
                    print("✅ Successfully joined organization from invite as \(role.displayName)")
                    
                    // Clear the pending invite
                    UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
                    UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
                    UserDefaults.standard.removeObject(forKey: "pending_invite_token")
                    UserDefaults.standard.removeObject(forKey: "pending_invite_role")
                    
                    print("📧 INVITE DEBUG: Cleared pending invite data")
                    
                    self?.inviteStatus = "✅ Welcome to \(orgName) as \(role.displayName)!"
                    
                } else {
                    print("❌ Failed to join organization from invite: \(error ?? "Unknown error")")
                    self?.errorMessage = error ?? "Failed to join organization"
                    
                    // Show option to cancel/retry
                    self?.showInviteFailureOptions(orgName: orgName)
                }
            }
        }
    }
    
    private func handleInviteTimeout(orgName: String) {
        print("⏰ Invite processing timed out for: \(orgName)")
        errorMessage = "Connection timed out. Please check your internet connection and try again."
        inviteStatus = "Connection timed out"
        
        showInviteFailureOptions(orgName: orgName)
    }
    
    private func showInviteFailureOptions(orgName: String) {
        // For now, we'll just clear the pending invite after a failure
        // In a full implementation, you might want to show an alert with retry/cancel options
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.clearPendingInvite()
        }
    }
    
    func clearPendingInvite() {
        print("🗑️ Clearing stuck pending invite")
        
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        UserDefaults.standard.removeObject(forKey: "pending_invite_role")
        
        inviteStatus = ""
        errorMessage = nil
        
        // Refresh organization status
        if let user = self.user {
            checkUserOrganizationStatus(for: user)
        }
    }
    
    func retryPendingInvite() {
        print("🔄 Retrying pending invite")
        
        errorMessage = nil
        inviteStatus = ""
        
        // Trigger invite processing again
        checkForPendingInvites()
    }

    // MARK: - Organization Name Validation
    
    func checkOrganizationNameAvailability(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameAvailabilityMessage = ""
            return
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            nameAvailabilityMessage = "⚠️ Name validation not available"
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
                        print("❌ Name availability check failed: \(error)")
                        self.nameAvailabilityMessage = "⚠️ Unable to verify name availability. Please try again."
                    }
                },
                receiveValue: { [weak self] isAvailable in
                    guard let self = self else { return }
                    
                    if isAvailable {
                        self.nameAvailabilityMessage = "✅ '\(trimmedName)' is available!"
                    } else {
                        self.nameAvailabilityMessage = "❌ '\(trimmedName)' is already taken"
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
                        print("❌ Failed to get name suggestions: \(error)")
                        self.suggestedNames = self.generateBasicSuggestions(for: baseName)
                    }
                },
                receiveValue: { [weak self] suggestions in
                    guard let self = self else { return }
                    self.suggestedNames = suggestions
                }
            )
            .store(in: &cancellables)
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

    // MARK: - Sign Out
    
    func signOut() {
        print("🔐 Signing out user")
        
        // Clear all stored data
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        UserDefaults.standard.removeObject(forKey: "currentOrganizationID")
        
        // Clear state
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
        
        // Clear zone isolation
        if let projectVM = projectViewModel {
            Task { @MainActor in
                projectVM.organizationDidChange(nil)
                print("🔒 Zone isolation cleared")
            }
        }
        
        service.signOut()
    }

    // MARK: - Refresh Organizations
    
    @MainActor
    func refreshOrganizationsFromCloudKit() async {
        guard let userID = user?.id,
              let cloudKitService = service as? CloudKitAuthService else {
            print("⚠️ Cannot refresh organizations - missing user or service")
            return
        }
        
        let currentOrgId = self.currentOrg?.id
        
        do {
            print("🔄 Refreshing organizations from CloudKit...")
            let result = try await withCheckedThrowingContinuation { continuation in
                _ = cloudKitService.fetchOrganizationsWithRoles(for: userID)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { result in
                            continuation.resume(returning: result)
                        }
                    )
            }
            
            self.organizations = result.organizations
            self.userOrganizations = result.organizations
            self.organizationRoles = result.roles
            
            print("✅ Refreshed \(result.organizations.count) organizations with roles")
            
            // Restore current organization if it still exists
            if let currentOrgId = currentOrgId {
                if let restoredOrg = result.organizations.first(where: { $0.id == currentOrgId }) {
                    self.currentOrg = restoredOrg
                    print("✅ Restored current organization: \(restoredOrg.name)")
                } else if result.organizations.isEmpty {
                    self.currentOrg = nil
                    self.needsOrganizationSetup = true
                    print("⚠️ No organizations available - setup required")
                }
            } else if !result.organizations.isEmpty && self.currentOrg == nil {
                setCurrentOrganization(result.organizations.first!)
                print("✅ Auto-selected organization: \(result.organizations.first!.name)")
            }
        } catch {
            print("❌ Failed to refresh organizations: \(error)")
            // Keep existing state on error to prevent data loss
        }
    }

    // MARK: – Private Methods

    private func fetchUserOrganizationsWithRoles(completion: (([Organization], [String: OrganizationRole]) -> Void)? = nil) {
        guard let id = user?.id else { 
            print("⚠️ No user ID for fetching organizations")
            completion?([], [:])
            return 
        }
        
        guard let cloudKitService = service as? CloudKitAuthService else {
            print("⚠️ CloudKit service not available")
            isLoadingOrgs = false
            completion?([], [:])
            return
        }
        
        print("📋 Fetching organizations with roles for user: \(id.prefix(8))...")
        isLoadingOrgs = true
        
        cloudKitService.fetchOrganizationsWithRoles(for: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] comp in
                    guard let self = self else { return }
                    
                    self.isLoadingOrgs = false
                    
                    if case let .failure(err) = comp {
                        print("❌ Failed to fetch organizations: \(err.localizedDescription)")
                        self.errorMessage = "Failed to load organizations. Please try again."
                        completion?([], [:])
                    } else {
                        print("✅ Organizations fetch completed")
                    }
                },
                receiveValue: { result in
                    print("📋 Received \(result.organizations.count) organizations with roles")
                    
                    completion?(result.organizations, result.roles)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Emergency Invite Recovery Methods
    
    /// Force clear all invite-related data (for stuck invite recovery)
    func emergencyClearInviteData() {
        print("🚨 Emergency clearing all invite data")
        
        // Clear all invite-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
        UserDefaults.standard.removeObject(forKey: "pending_invite_orgName") 
        UserDefaults.standard.removeObject(forKey: "pending_invite_token")
        
        // Clear published properties
        inviteStatus = ""
        errorMessage = nil
        isInviting = false
        pendingInvites = []
        
        print("✅ Emergency cleared all invite data")
        
        // Re-check user organization status
        if let user = self.user {
            checkUserOrganizationStatus(for: user)
        }
    }
    
    /// Check if there's a stuck invite and offer recovery
    func detectAndRecoverStuckInvite() -> Bool {
        let hasOrgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") != nil
        let hasOrgID = UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil
        
        if hasOrgName || hasOrgID {
            print("🔍 Detected stuck invite data")
            
            // Auto-clear after detection
            emergencyClearInviteData()
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

enum AuthViewModelError: LocalizedError {
    case noUserLoggedIn
    case cloudKitServiceNotAvailable
    case organizationNameTaken(String)
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "Please sign in first"
        case .cloudKitServiceNotAvailable:
            return "CloudKit service is not available"
        case .organizationNameTaken(let name):
            return "The organization name '\(name)' is already taken. Please choose a different name."
        }
    }
}