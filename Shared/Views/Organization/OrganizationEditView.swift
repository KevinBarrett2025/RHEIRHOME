import SwiftUI

struct OrganizationEditView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    let organization: Organization
    
    @State private var name: String
    @State private var industry: String
    @State private var businessPhone: String = ""
    @State private var businessEmail: String = ""
    @State private var businessAddress: String = ""
    @State private var businessCity: String = ""
    @State private var businessState: String = ""
    @State private var businessZip: String = ""
    @State private var businessEIN: String = ""
    @State private var businessLicense: String = ""
    @State private var website: String = ""
    
    @State private var isSaving = false
    @State private var showingSaveConfirmation = false
    @State private var errorMessage: String?
    
    init(organization: Organization) {
        self.organization = organization
        self._name = State(initialValue: organization.name)
        self._industry = State(initialValue: organization.industry ?? "")
        
        // Initialize business details from organization settings if available
        if let settings = organization.settings {
            self._businessPhone = State(initialValue: settings.customFields["businessPhone"] ?? "")
            self._businessEmail = State(initialValue: settings.customFields["businessEmail"] ?? "")
            self._businessAddress = State(initialValue: settings.customFields["businessAddress"] ?? "")
            self._businessCity = State(initialValue: settings.customFields["businessCity"] ?? "")
            self._businessState = State(initialValue: settings.customFields["businessState"] ?? "")
            self._businessZip = State(initialValue: settings.customFields["businessZip"] ?? "")
            self._businessEIN = State(initialValue: settings.customFields["businessEIN"] ?? "")
            self._businessLicense = State(initialValue: settings.customFields["businessLicense"] ?? "")
            self._website = State(initialValue: settings.customFields["website"] ?? "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                basicInformationSection
                businessDetailsSection
                contactInformationSection
                organizationStatsSection
            }
            .navigationTitle("Edit Organization")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOrganization()
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSaving)
            .alert("Organization Updated", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your organization details have been updated successfully.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var basicInformationSection: some View {
        Section("Basic Information") {
            HStack {
                Text("Organization Name")
                Spacer()
                TextField("Enter organization name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }
            
            HStack {
                Text("Industry")
                Spacer()
                TextField("e.g., Construction, Consulting", text: $industry)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }
            
            HStack {
                Text("Website")
                Spacer()
                TextField("https://example.com", text: $website)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }
        }
    }
    
    private var businessDetailsSection: some View {
        Section("Business Details") {
            HStack {
                Text("EIN/Tax ID")
                Spacer()
                TextField("XX-XXXXXXX", text: $businessEIN)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 150)
            }
            
            HStack {
                Text("Business License")
                Spacer()
                TextField("License Number", text: $businessLicense)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 150)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Business Address")
                    .font(.headline)
                
                TextField("Street Address", text: $businessAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 12) {
                    TextField("City", text: $businessCity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("State", text: $businessState)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 80)
                    
                    TextField("ZIP", text: $businessZip)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 100)
                        .keyboardType(.numberPad)
                }
            }
        }
    }
    
    private var contactInformationSection: some View {
        Section("Contact Information") {
            HStack {
                Text("Business Phone")
                Spacer()
                TextField("(555) 123-4567", text: $businessPhone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 150)
                    .keyboardType(.phonePad)
            }
            
            HStack {
                Text("Business Email")
                Spacer()
                TextField("contact@company.com", text: $businessEmail)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
        }
    }
    
    private var organizationStatsSection: some View {
        Section("Organization Information") {
            HStack {
                Text("Organization ID")
                Spacer()
                Text(organization.id.prefix(8) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Created")
                Spacer()
                Text(organization.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Members")
                Spacer()
                Text("\(organization.members.count) / \(organization.maxMembers)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Subscription")
                Spacer()
                Text(organization.subscriptionTier.displayName)
                    .foregroundColor(.secondary)
            }
            
            if let role = authVM.organizationRoles[organization.id] {
                HStack {
                    Text("Your Role")
                    Spacer()
                    Text(role.displayName)
                        .foregroundColor(role == .admin ? .blue : .green)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private func saveOrganization() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Organization name is required"
            return
        }
        
        isSaving = true
        
        // Create updated organization settings
        var updatedSettings = organization.settings ?? OrganizationSettings()
        updatedSettings.customFields["businessPhone"] = businessPhone
        updatedSettings.customFields["businessEmail"] = businessEmail
        updatedSettings.customFields["businessAddress"] = businessAddress
        updatedSettings.customFields["businessCity"] = businessCity  
        updatedSettings.customFields["businessState"] = businessState
        updatedSettings.customFields["businessZip"] = businessZip
        updatedSettings.customFields["businessEIN"] = businessEIN
        updatedSettings.customFields["businessLicense"] = businessLicense
        updatedSettings.customFields["website"] = website
        
        // TODO: Implement organization update through AuthViewModel
        // This would call CloudKit to update the organization record
        
        // For now, simulate the update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSaving = false
            showingSaveConfirmation = true
            
            // Update local organization name if changed
            if var currentOrg = authVM.currentOrg, currentOrg.id == organization.id {
                currentOrg.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                authVM.setCurrentOrganization(currentOrg)
            }
            
            print("✅ Organization updated: \(name)")
        }
    }
}

#Preview {
    let sampleOrg = Organization(
        name: "RHEIR Construction", 
        adminUserID: "test-admin-id"
    )
    
    return OrganizationEditView(organization: sampleOrg)
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}