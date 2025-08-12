import SwiftUI

struct EnhancedTeamManagementView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCreateInvite = false
    @State private var showingContractorInvite = false
    @State private var pendingInvites: [String] = []
    @State private var isLoadingInvites = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    organizationOverview
                    
                    if authVM.canPerformAdminActions {
                        inviteActionsSection
                        pendingInvitesSection
                    }
                    
                    currentTeamSection
                    projectPermissionsSection
                }
                .padding()
            }
            .navigationTitle("Team Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreateInvite) {
                CreateTeamInviteView()
            }
            .sheet(isPresented: $showingContractorInvite) {
                CreateTeamInviteView()
            }
            .onAppear {
                loadPendingInvites()
            }
        }
    }
    
    @ViewBuilder
    private var organizationOverview: some View {
        if let org = authVM.currentOrg {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(org.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let role = authVM.currentOrganizationRole {
                            Text("Your role: \(role.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    StatCard(
                        title: "Team Members",
                        value: "\(org.members.count)",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Projects",
                        value: "\(projectVM.projects.count)",
                        icon: "folder.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Pending",
                        value: "\(pendingInvites.count)",
                        icon: "clock.fill",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var inviteActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite Team Members")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    showingCreateInvite = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invite Team Member")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                
                Button {
                    showingContractorInvite = true
                } label: {
                    HStack {
                        Image(systemName: "hammer.circle")
                        Text("Invite Contractor")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    @ViewBuilder
    private var pendingInvitesSection: some View {
        if !pendingInvites.isEmpty || isLoadingInvites {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Pending Invites")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        loadPendingInvites()
                    }
                    .font(.caption)
                }
                
                if isLoadingInvites {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading invites...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingInvites, id: \.self) { invite in
                            Text(invite)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var currentTeamSection: some View {
        if let org = authVM.currentOrg {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Team")
                    .font(.headline)
                
                LazyVStack(spacing: 8) {
                    ForEach(org.members, id: \.self) { memberID in
                        TeamMemberRow(
                            memberID: memberID,
                            role: getMemberRole(memberID),
                            isCurrentUser: memberID == authVM.user?.id
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var projectPermissionsSection: some View {
        if authVM.currentOrganizationRole == .contractor {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Project Access")
                    .font(.headline)
                
                let allowedProjects = authVM.getContractorProjectPermissions()
                
                if allowedProjects.isEmpty {
                    Text("No specific projects assigned. Contact admin for project access.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(allowedProjects, id: \.self) { projectID in
                            if let project = projectVM.projects.first(where: { $0.id.uuidString == projectID }) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(project.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("Contractor Access")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getMemberRole(_ memberID: String) -> OrganizationRole {
        guard let org = authVM.currentOrg else { return .member }
        
        if memberID == org.adminUserID {
            return .admin
        }
        
        // For now, default to member. In a full implementation, you'd query member roles
        return .member
    }
    
    private func loadPendingInvites() {
        isLoadingInvites = true
        
        Task {
            let invites = await authVM.fetchPendingInvites()
            
            await MainActor.run {
                self.pendingInvites = invites
                self.isLoadingInvites = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TeamMemberRow: View {
    let memberID: String
    let role: OrganizationRole
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            Image(systemName: roleIcon)
                .font(.title3)
                .foregroundColor(roleColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(memberID.prefix(8) + "...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(role.displayName)
                    .font(.caption)
                    .foregroundColor(roleColor)
            }
            
            Spacer()
            
            if role == .admin {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var roleIcon: String {
        switch role {
        case .admin: return "crown.fill"
        case .member: return "person.fill"
        case .contractor: return "hammer.fill"
        case .viewer: return "eye.fill"
        }
    }
    
    private var roleColor: Color {
        switch role {
        case .admin: return .orange
        case .member: return .blue
        case .contractor: return .green
        case .viewer: return .gray
        }
    }
}

struct CreateTeamInviteView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var selectedRole = OrganizationRole.member
    @State private var selectedProjects: Set<UUID> = []
    @State private var isCreatingInvite = false
    @State private var inviteURL = ""
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    inviteFormSection
                    
                    projectAssignmentSection
                    
                    if !inviteURL.isEmpty {
                        shareSection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Invite Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Invite") {
                        createInvite()
                    }
                    .disabled(email.isEmpty || isCreatingInvite)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [inviteURL])
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: roleIcon)
                .font(.system(size: 50))
                .foregroundColor(roleColor)
            
            Text("Invite \(selectedRole.displayName)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("All team members only see projects they're specifically assigned to.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var inviteFormSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Email Address")
                    .font(.headline)
                
                TextField("Enter email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            VStack(alignment: .leading) {
                Text("Role")
                    .font(.headline)
                
                Picker("Role", selection: $selectedRole) {
                    ForEach([OrganizationRole.member, .contractor, .viewer], id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Role Permissions:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(rolePermissionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var projectAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assign Projects")
                    .font(.headline)
                
                Spacer()
                
                if selectedProjects.count == projectVM.projects.count {
                    Button("Deselect All") {
                        selectedProjects.removeAll()
                    }
                    .font(.caption)
                } else {
                    Button("Select All") {
                        selectedProjects = Set(projectVM.projects.map { $0.id })
                    }
                    .font(.caption)
                }
            }
            
            Text("Select which projects this \(selectedRole.displayName.lowercased()) can access:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if projectVM.projects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Projects Yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Create some projects first, then invite team members to work on them.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(projectVM.projects) { project in
                        ProjectSelectionRow(
                            project: project,
                            isSelected: selectedProjects.contains(project.id),
                            onToggle: {
                                toggleProjectSelection(project.id)
                            }
                        )
                    }
                }
            }
            
            // Assignment Summary
            if !selectedProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assignment Summary:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("This \(selectedRole.displayName.lowercased()) will have \(accessTypeDescription) to \(selectedProjects.count) project(s).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(roleColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var shareSection: some View {
        VStack(spacing: 16) {
            Text("Invite Created!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            VStack(spacing: 4) {
                Text("Share this with \(email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if selectedProjects.isEmpty {
                    Text("⚠️ No projects assigned - they'll need project access from admin")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("They'll have \(accessTypeDescription) to \(selectedProjects.count) project(s)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text(inviteURL)
                .font(.caption)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onTapGesture {
                    UIPasteboard.general.string = inviteURL
                }
            
            HStack(spacing: 12) {
                Button("Copy Link") {
                    UIPasteboard.general.string = inviteURL
                }
                .buttonStyle(.bordered)
                
                Button("Share") {
                    showingShareSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var roleIcon: String {
        switch selectedRole {
        case .admin: return "crown.fill"
        case .member: return "person.fill"
        case .contractor: return "hammer.fill"
        case .viewer: return "eye.fill"
        }
    }
    
    private var roleColor: Color {
        switch selectedRole {
        case .admin: return .orange
        case .member: return .blue
        case .contractor: return .green
        case .viewer: return .gray
        }
    }
    
    private var rolePermissionDescription: String {
        switch selectedRole {
        case .admin:
            return "Full access: Can manage team, see all projects, invite others, manage all data."
        case .member:
            return "Edit access: Can view and edit assigned projects, add receipts and progress logs."
        case .contractor:
            return "Edit access: Can view and edit assigned projects, limited to specific work scope."
        case .viewer:
            return "Read-only access: Can view assigned projects but cannot make changes."
        }
    }
    
    private var accessTypeDescription: String {
        switch selectedRole {
        case .admin:
            return "full access"
        case .member, .contractor:
            return "edit access"
        case .viewer:
            return "read-only access"
        }
    }
    
    private func toggleProjectSelection(_ projectID: UUID) {
        if selectedProjects.contains(projectID) {
            selectedProjects.remove(projectID)
        } else {
            selectedProjects.insert(projectID)
        }
    }
    
    private func createInvite() {
        isCreatingInvite = true
        
        Task {
            let result = await authVM.createTeamMemberInviteWithProjects(
                email: email,
                role: selectedRole,
                allowedProjectIDs: selectedProjects.map { $0.uuidString }
            )
            
            await MainActor.run {
                self.isCreatingInvite = false
                
                if result.success {
                    // Generate a share URL from the result message or create one
                    self.inviteURL = authVM.getTeamMemberInviteLink() ?? "https://app.rheirhome.com/invite"
                } else {
                    print("Failed to create invite: \(result.message)")
                }
            }
        }
    }
}

struct ProjectSelectionRow: View {
    let project: Project
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .green : .gray)
                .onTapGesture(perform: onToggle)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    if !project.client.isEmpty {
                        Label(project.client, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if !project.fullAddress.isEmpty {
                        Label(project.fullAddress, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if project.totalBudget > 0 {
                VStack(alignment: .trailing) {
                    Text(project.totalBudget.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text("Budget")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture(perform: onToggle)
    }
}

#Preview {
    EnhancedTeamManagementView()
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}