import SwiftUI

struct DirectoryAddTeamMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
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
        
        // Add team member through ProjectViewModel (single source of truth)
        projectVM.addTeamMemberToOrganization(teamMember)
        
        dismiss()
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
    DirectoryAddTeamMemberView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel())
}