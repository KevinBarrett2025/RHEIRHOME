import SwiftUI

struct AdminInfoUpdateView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var adminName = ""
    @State private var adminEmail = ""
    @State private var isUpdating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Complete Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("As the organization administrator, please provide your information for team management.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Full Name", text: $adminName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Email", text: $adminEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                Button {
                    updateAdminInfo()
                } label: {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isUpdating ? "Updating..." : "Complete Setup")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(adminName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(adminName.isEmpty || isUpdating)
                .padding(.horizontal)
            }
            .navigationTitle("Admin Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        authVM.dismissAdminInfoUpdate()
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
            }
        }
        .onAppear {
            // Pre-fill with user email if available
            if let userEmail = authVM.user?.email, !userEmail.isEmpty {
                adminEmail = userEmail
            }
        }
    }
    
    private func updateAdminInfo() {
        let trimmedName = adminName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = adminEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        isUpdating = true
        
        Task { @MainActor in
            // Find the current user's team member record
            guard let userID = authVM.user?.id,
                  let adminMember = projectVM.teamMembers.first(where: { $0.appUserID == userID }) else {
                print("❌ Cannot find admin team member to update")
                isUpdating = false
                return
            }
            
            // Update the admin team member with provided info
            var updatedAdmin = adminMember
            updatedAdmin.name = trimmedName
            updatedAdmin.email = trimmedEmail
            
            // Update through ProjectViewModel
            projectVM.updateTeamMemberInOrganization(updatedAdmin)
            
            // Small delay to ensure the update completes
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            isUpdating = false
            authVM.dismissAdminInfoUpdate()
            dismiss()
        }
    }
}

#Preview {
    AdminInfoUpdateView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
}