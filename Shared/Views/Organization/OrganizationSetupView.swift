import SwiftUI

struct OrganizationSetupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var organizationName = ""
    @State private var selectedIndustry = "Construction"
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasCheckedName = false
    @State private var nameCheckTimer: Timer?
    
    private let industries = [
        "Construction", "General Contracting", "Residential Construction",
        "Commercial Construction", "Renovation & Remodeling", "Electrical",
        "Plumbing", "HVAC", "Roofing", "Landscaping", "Other"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    organizationFormSection
                    
                    nameValidationSection
                    
                    suggestedNamesSection
                    
                    createOrganizationButton
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Setup Organization")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Create Your Organization")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Set up your organization to start managing projects and collaborating with your team.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var organizationFormSection: some View {
        VStack(spacing: 20) {
            // Organization Name Field with Validation
            VStack(alignment: .leading, spacing: 8) {
                Label("Organization Name", systemImage: "building.2")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    TextField("Enter your organization name", text: $organizationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .onChange(of: organizationName) { oldValue, newValue in
                            onNameChanged(newValue)
                        }
                    
                    if authVM.isCheckingNameAvailability {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 8)
                    }
                }
                
                Text("This will be visible to team members and clients")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Industry Selection
            VStack(alignment: .leading, spacing: 8) {
                Label("Industry", systemImage: "hammer.circle")
                    .font(.headline)
                    .foregroundColor(.primary)
                
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
                
                Text("Help us customize features for your industry")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var nameValidationSection: some View {
        if !authVM.nameAvailabilityMessage.isEmpty {
            HStack {
                Image(systemName: getValidationIcon())
                    .foregroundColor(getValidationColor())
                
                VStack(alignment: .leading) {
                    Text(authVM.nameAvailabilityMessage)
                        .font(.caption)
                        .foregroundColor(getValidationColor())
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var suggestedNamesSection: some View {
        if !authVM.suggestedNames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("Suggested alternatives:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if authVM.isLoadingSuggestions {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(authVM.suggestedNames, id: \.self) { suggestion in
                        Button {
                            organizationName = suggestion
                            onNameChanged(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(16)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var createOrganizationButton: some View {
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
            .padding()
            .background(canCreateOrganization ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreateOrganization || isCreating)
    }
    
    // MARK: - Computed Properties
    
    private var canCreateOrganization: Bool {
        let trimmedName = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidName = !trimmedName.isEmpty
        let nameIsAvailable = authVM.nameAvailabilityMessage.contains("✅")
        let notChecking = !authVM.isCheckingNameAvailability
        
        return hasValidName && nameIsAvailable && notChecking && !isCreating
    }
    
    // MARK: - Helper Methods
    
    private func onNameChanged(_ newName: String) {
        hasCheckedName = false
        
        // Cancel any existing timer
        nameCheckTimer?.invalidate()
        
        // Clear suggestions when user types
        authVM.suggestedNames = []
        
        // Debounce name checking to avoid too many API calls
        nameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
            if !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                authVM.checkOrganizationNameAvailability(newName)
                hasCheckedName = true
            }
        }
    }
    
    private func getValidationIcon() -> String {
        if authVM.nameAvailabilityMessage.contains("✅") {
            return "checkmark.circle.fill"
        } else if authVM.nameAvailabilityMessage.contains("❌") {
            return "xmark.circle.fill"
        } else {
            return "info.circle.fill"
        }
    }
    
    private func getValidationColor() -> Color {
        if authVM.nameAvailabilityMessage.contains("✅") {
            return .green
        } else if authVM.nameAvailabilityMessage.contains("❌") {
            return .red
        } else {
            return .orange
        }
    }
    
    private func createOrganization() {
        guard authVM.user != nil else {
            errorMessage = "No authenticated user found"
            showError = true
            return
        }
        
        isCreating = true
        
        Task {
            do {
                // Use the validation method to ensure name is still available
                let organization = try await authVM.createOrganizationWithValidation(
                    named: organizationName,
                    industry: selectedIndustry
                )
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
                
                print("Organization created successfully: \(organization.name)")
                
            } catch AuthViewModelError.organizationNameTaken(let name) {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "The organization name '\(name)' is already taken. Please choose a different name."
                    showError = true
                    
                    // Refresh suggestions
                    authVM.getSuggestedOrganizationNames(baseName: name)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
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