import SwiftUI

struct DirectoryEmployeeRowView: View {
    let employee: TeamMember
    let authVM: AuthViewModel
    @State private var showingInviteConfirmation = false
    
    var body: some View {
        HStack {
            EmployeeInfoView(employee: employee)
            Spacer()
            InviteButtonView(employee: employee) {
                showingInviteConfirmation = true
            }
        }
        .padding(.vertical, 4)
        .alert("Send Invite", isPresented: $showingInviteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                authVM.inviteTeamMember(employee)
            }
        } message: {
            Text("Send an invite email to \(employee.email)?")
        }
    }
}

// MARK: - Supporting Views
private struct EmployeeInfoView: View {
    let employee: TeamMember
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(employee.name)
                .font(.headline)
            
            if !employee.jobTitle.isEmpty {
                Text(employee.jobTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !employee.email.isEmpty {
                Text(employee.email)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let defaultRate = employee.rates.first {
                Text("$\(defaultRate.rate, specifier: "%.2f")/hr")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}

private struct InviteButtonView: View {
    let employee: TeamMember
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !employee.email.isEmpty {
                action()
            }
        }) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(employee.email.isEmpty ? .gray : .blue)
        }
        .disabled(employee.email.isEmpty)
    }
}

#Preview {
    let employee = TeamMember(name: "John Doe", email: "john@example.com", jobTitle: "Developer")
    let authVM = AuthViewModel(service: PreviewAuthService())
    
    DirectoryEmployeeRowView(employee: employee, authVM: authVM)
        .padding()
}