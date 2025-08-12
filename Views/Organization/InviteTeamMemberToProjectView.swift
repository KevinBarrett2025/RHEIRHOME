import SwiftUI
import MessageUI

struct InviteTeamMemberToProjectView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTeamMembers: Set<UUID> = []
    @State private var selectedProjects: Set<UUID> = []
    @State private var inviteMessage = "Hi! You've been invited to join our project team. Please check the RHEIR app for your new project assignments."
    @State private var showingEmailComposer = false
    @State private var showingTextComposer = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    
    // Available team members (excluding those already assigned to selected projects)
    private var availableTeamMembers: [TeamMember] {
        let allMembers = projectVM.teamMembers
        let currentOrgID = authVM.currentOrg?.id
        
        print("🔍 DEBUG: Filtering team members for invites")
        print("🔍 Total team members in ProjectVM: \(allMembers.count)")
        print("🔍 Current organization ID: \(currentOrgID ?? "none")")
        
        for member in allMembers {
            print("🔍 Member: \(member.name) | OrgID: \(member.organizationID) | Email: \(member.email) | Phone: \(member.phone)")
        }
        
        let filtered = allMembers.filter { member in
            let matchesOrg = member.organizationID == currentOrgID
            let notCurrentUser = member.appUserID != authVM.user?.id
            let result = matchesOrg && notCurrentUser
            
            print("🔍 \(member.name): MatchesOrg=\(matchesOrg), NotCurrentUser=\(notCurrentUser), Final=\(result)")
            
            return result
        }
        
        print("🔍 Available team members after filtering: \(filtered.count)")
        return filtered
    }
    
    // Available projects for assignment
    private var availableProjects: [Project] {
        return projectVM.organizationProjects.filter { $0.status == .active }
    }
    
    private var canSendInvitations: Bool {
        return !selectedTeamMembers.isEmpty && !selectedProjects.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Team Members to Projects")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select existing team members and projects to invite them to collaborate.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Team Member Selection
                    teamMemberSelectionSection
                    
                    // Project Selection
                    projectSelectionSection
                    
                    // Invitation Message
                    messageSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
            }
            .navigationTitle("Invite to Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var teamMemberSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Team Members")
                    .font(.headline)
                
                Spacer()
                
                if !selectedTeamMembers.isEmpty {
                    Text("\(selectedTeamMembers.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if availableTeamMembers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No Team Members Available")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Add team members first before you can invite them to projects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(availableTeamMembers) { member in
                        TeamMemberInviteRow(
                            member: member,
                            isSelected: selectedTeamMembers.contains(member.id)
                        ) {
                            toggleTeamMemberSelection(member.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Projects")
                    .font(.headline)
                
                Spacer()
                
                if !selectedProjects.isEmpty {
                    Text("\(selectedProjects.count) selected")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
            if availableProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No Active Projects")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Create active projects before inviting team members.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(availableProjects) { project in
                        ProjectInviteRow(
                            project: project,
                            isSelected: selectedProjects.contains(project.id)
                        ) {
                            toggleProjectSelection(project.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitation Message")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $inviteMessage)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Text("\(inviteMessage.count)/300 characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if canSendInvitations {
                HStack(spacing: 12) {
                    Button {
                        sendEmailInvitations()
                    } label: {
                        Label("Send via Email", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasSelectedMembersWithEmail)
                    
                    Button {
                        sendTextInvitations()
                    } label: {
                        Label("Send via Text", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSelectedMembersWithPhone)
                }
                
                Button {
                    assignMembersToProjects()
                } label: {
                    Label("Assign to Projects", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Select team members and projects to send invitations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Properties
    
    private var hasSelectedMembersWithEmail: Bool {
        selectedTeamMembers.contains { memberID in
            guard let member = projectVM.teamMembers.first(where: { $0.id == memberID }) else { return false }
            return !member.email.isEmpty
        }
    }
    
    private var hasSelectedMembersWithPhone: Bool {
        selectedTeamMembers.contains { memberID in
            guard let member = projectVM.teamMembers.first(where: { $0.id == memberID }) else { return false }
            return !member.phone.isEmpty
        }
    }
    
    // MARK: - Actions
    
    private func toggleTeamMemberSelection(_ memberID: UUID) {
        if selectedTeamMembers.contains(memberID) {
            selectedTeamMembers.remove(memberID)
        } else {
            selectedTeamMembers.insert(memberID)
        }
    }
    
    private func toggleProjectSelection(_ projectID: UUID) {
        if selectedProjects.contains(projectID) {
            selectedProjects.remove(projectID)
        } else {
            selectedProjects.insert(projectID)
        }
    }
    
    private func sendEmailInvitations() {
        guard hasSelectedMembersWithEmail else {
            errorMessage = "No selected team members have email addresses."
            showingErrorAlert = true
            return
        }
        
        let selectedMembers = projectVM.teamMembers.filter { selectedTeamMembers.contains($0.id) }
        let membersWithEmail = selectedMembers.filter { !$0.email.isEmpty }
        let selectedProjectNames = projectVM.organizationProjects.filter { selectedProjects.contains($0.id) }.map { $0.name }
        
        // Assign members to projects first
        assignMembersToProjectsInternal()
        
        // Create email content
        let emailSubject = "Project Assignment - \(authVM.currentOrg?.name ?? "Organization")"
        let emailBody = """
        Hello!
        
        You have been assigned to the following projects:
        \(selectedProjectNames.map { "• \($0)" }.joined(separator: "\n"))
        
        \(inviteMessage)
        
        Please check the RHEIR app to view your project assignments and start collaborating with the team.
        
        Best regards,
        \(authVM.currentOrg?.name ?? "Your Organization")
        """
        
        // For now, we'll copy the email content to clipboard and show success
        // In a real implementation, you would integrate with MFMailComposeViewController
        let fullEmailContent = """
        TO: \(membersWithEmail.map { $0.email }.joined(separator: ", "))
        SUBJECT: \(emailSubject)
        
        \(emailBody)
        """
        
        UIPasteboard.general.string = fullEmailContent
        
        successMessage = """
        Team members assigned to projects!
        
        Email content copied to clipboard. Send to:
        \(membersWithEmail.map { "\($0.name) (\($0.email))" }.joined(separator: "\n"))
        """
        showingSuccessAlert = true
    }
    
    private func sendTextInvitations() {
        guard hasSelectedMembersWithPhone else {
            errorMessage = "No selected team members have phone numbers."
            showingErrorAlert = true
            return
        }
        
        let selectedMembers = projectVM.teamMembers.filter { selectedTeamMembers.contains($0.id) }
        let membersWithPhone = selectedMembers.filter { !$0.phone.isEmpty }
        let selectedProjectNames = projectVM.organizationProjects.filter { selectedProjects.contains($0.id) }.map { $0.name }
        
        // Assign members to projects first
        assignMembersToProjectsInternal()
        
        // Create text message content
        let textMessage = """
        Hi! You've been assigned to: \(selectedProjectNames.joined(separator: ", ")). \(inviteMessage) Check the RHEIR app for details.
        """
        
        // Copy text content to clipboard
        let fullTextContent = """
        SEND TO: \(membersWithPhone.map { "\($0.name) (\($0.phone))" }.joined(separator: ", "))
        
        MESSAGE: \(textMessage)
        """
        
        UIPasteboard.general.string = fullTextContent
        
        successMessage = """
        Team members assigned to projects!
        
        Text message copied to clipboard. Send to:
        \(membersWithPhone.map { "\($0.name) (\($0.phone))" }.joined(separator: "\n"))
        """
        showingSuccessAlert = true
    }
    
    private func assignMembersToProjects() {
        assignMembersToProjectsInternal()
        
        let memberNames = projectVM.teamMembers.filter { selectedTeamMembers.contains($0.id) }.map { $0.name }
        let projectNames = projectVM.organizationProjects.filter { selectedProjects.contains($0.id) }.map { $0.name }
        
        successMessage = """
        Successfully assigned team members to projects!
        
        Members: \(memberNames.joined(separator: ", "))
        Projects: \(projectNames.joined(separator: ", "))
        """
        showingSuccessAlert = true
    }
    
    private func assignMembersToProjectsInternal() {
        // Assign each selected team member to each selected project
        for memberID in selectedTeamMembers {
            for projectID in selectedProjects {
                // Find the project and update its assigned users directly
                if let projectIndex = projectVM.organizationProjects.firstIndex(where: { $0.id == projectID }) {
                    var project = projectVM.organizationProjects[projectIndex]
                    if !project.assignedUserIDs.contains(memberID.uuidString) {
                        project.assignUser(memberID.uuidString)
                        projectVM.updateProject(project)
                        print("✅ Assigned team member \(memberID.uuidString.prefix(8))... to project: \(project.name)")
                    }
                }
            }
        }
    }
}

// MARK: - Team Member Invite Row

struct TeamMemberInviteRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                // Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if !member.email.isEmpty {
                            Label(member.email, systemImage: "envelope")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if !member.phone.isEmpty {
                            Label(member.phone, systemImage: "phone")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(member.employmentStatus.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Project Invite Row

struct ProjectInviteRow: View {
    let project: Project
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(project.client)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(project.status.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        
                        Text("Due: \(project.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("$\(project.totalBudget, specifier: "%.0f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text("\(project.assignedTeamMemberIDs.count) assigned")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    InviteTeamMemberToProjectView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
}