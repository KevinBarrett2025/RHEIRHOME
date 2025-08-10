import SwiftUI

struct OrganizationSetupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var organizationName = ""
    @State private var selectedIndustry = "Construction"
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var createdOrganizationName = ""
    
    private let industries = [
        "Construction", "General Contracting", "Residential Construction",
        "Commercial Construction", "Renovation & Remodeling", "Other"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                headerSection
                
                formSection
                
                createButton
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Organization Created!", isPresented: $showSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("'\(createdOrganizationName)' has been created successfully. You can now start adding projects and team members.")
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Create Your Organization")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Set up your company to start managing construction projects.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 24) {
            // Organization Name
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.blue)
                    Text("Company Name")
                        .font(.headline)
                }
                
                TextField("Enter your company name", text: $organizationName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
            }
            
            // Industry Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hammer.circle")
                        .foregroundColor(.blue)
                    Text("Industry")
                        .font(.headline)
                }
                
                Menu {
                    ForEach(industries, id: \.self) { industry in
                        Button(industry) {
                            selectedIndustry = industry
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedIndustry)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var createButton: some View {
        Button {
            createOrganization()
        } label: {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                
                Text(isCreating ? "Creating Organization..." : "Create Organization")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canCreate ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }
    
    private var canCreate: Bool {
        !organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }
    
    private func createOrganization() {
        let trimmedName = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a company name"
            showError = true
            return
        }
        
        guard authVM.user != nil else {
            errorMessage = "Please sign in to create an organization"
            showError = true
            return
        }
        
        print("🏗️ Creating organization: \(trimmedName)")
        isCreating = true
        
        Task {
            do {
                let newOrg = try await authVM.createOrganizationWithValidation(
                    named: trimmedName,
                    industry: selectedIndustry
                )
                
                await MainActor.run {
                    print("✅ Organization created successfully: \(newOrg.name)")
                    isCreating = false
                    createdOrganizationName = newOrg.name
                    showSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isCreating = false
                    print("❌ Failed to create organization: \(error)")
                    errorMessage = "Failed to create organization. Please try again."
                    showError = true
                }
            }
        }
    }
}

#Preview {
    OrganizationSetupView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}