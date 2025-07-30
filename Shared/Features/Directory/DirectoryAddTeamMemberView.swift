import SwiftUI

struct DirectoryAddTeamMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var teamMembers: [TeamMember]
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var jobTitle = ""
    @State private var rateText = ""
    @State private var showingInviteStatus = false
    @State private var inviteMessage = ""

    private var canSave: Bool {
        !name.isEmpty && Double(rateText) != nil
    }

    var body: some View {
        NavigationView {
            Form {
                TeamMemberFormSection(
                    name: $name,
                    email: $email,
                    jobTitle: $jobTitle,
                    rateText: $rateText
                )
                
                FormFooterSection(organizationName: authVM.currentOrg?.name ?? "organization")
                
                if !authVM.inviteStatus.isEmpty {
                    Section("Invitation Status") {
                        Text(authVM.inviteStatus)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTeamMember()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert("Team Member Invited!", isPresented: $showingInviteStatus) {
            Button("OK") {}
            Button("Copy Invite Link") {
                if let link = authVM.getTeamMemberInviteLink() {
                    UIPasteboard.general.string = link
                }
            }
        } message: {
            Text(inviteMessage)
        }
    }
    
    // MARK: - Private Methods
    private func saveTeamMember() {
        guard let rate = Double(rateText) else { return }
        
        let teamMember = TeamMember(
            name: name,
            email: email,
            jobTitle: jobTitle,
            rates: [EmployeeRate(taskType: "Default", rate: rate)],
            organizationID: authVM.currentOrg?.id ?? "RHEIR-LLC-MAIN-ORG"
        )
        
        teamMembers.append(teamMember)
        saveToUserDefaults()
        
        // Send organization invitation if email is provided
        if !email.isEmpty {
            sendOrganizationInvite(to: teamMember)
        }
        
        dismiss()
    }
    
    private func sendOrganizationInvite(to teamMember: TeamMember) {
        print("📧 Sending organization invite to: \(teamMember.email)")
        authVM.inviteTeamMemberToOrganization(teamMember: teamMember)
        
        // Show the invite status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !authVM.inviteStatus.isEmpty {
                showingInviteStatus = true
                inviteMessage = authVM.inviteStatus
            }
        }
    }

    private func saveToUserDefaults() {
        guard let orgID = authVM.currentOrg?.id,
              let data = try? JSONEncoder().encode(teamMembers) else { return }
        
        UserDefaults.standard.set(data, forKey: "teamMembers_\(orgID)")
    }
}

// MARK: - Supporting Views
private struct TeamMemberFormSection: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var jobTitle: String
    @Binding var rateText: String
    
    var body: some View {
        Section(header: Text("Team Member Info")) {
            TextField("Full Name", text: $name)
            TextField("Email Address", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            TextField("Job Title", text: $jobTitle)
            TextField("Hourly Rate", text: $rateText)
                .keyboardType(.decimalPad)
        }
    }
}

private struct FormFooterSection: View {
    let organizationName: String
    
    var body: some View {
        Section(
            footer: Text("Team members will be added to your \(organizationName) directory and can be assigned to projects.")
        ) {
            // Empty section for footer text
        }
    }
}

#Preview {
    DirectoryAddTeamMemberView(teamMembers: .constant([]))
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}