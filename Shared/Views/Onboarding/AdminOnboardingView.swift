import SwiftUI
import CloudKit
import OSLog

/// Professional admin onboarding flow for construction company administrators
/// This replaces the messy "ensure admin exists" logic with proper upfront profile setup
struct AdminOnboardingView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Organization context
    let organization: Organization
    
    // Admin profile data
    @State private var companyName: String = ""
    @State private var adminName: String = ""
    @State private var adminEmail: String = ""
    @State private var adminPhone: String = ""
    @State private var jobTitle: String = "Owner/Administrator"
    @State private var defaultHourlyRate: String = "75"
    
    // Business details
    @State private var businessPhone: String = ""
    @State private var businessEmail: String = ""
    @State private var businessAddress: String = ""
    @State private var businessCity: String = ""
    @State private var businessState: String = ""
    @State private var businessZip: String = ""
    @State private var businessWebsite: String = ""
    @State private var businessEIN: String = ""
    @State private var businessLicense: String = ""
    
    // Professional credentials
    @State private var licenseType: String = ""
    @State private var licenseNumber: String = ""
    @State private var yearsExperience: String = ""
    @State private var specialties: String = ""
    
    // UI state
    @State private var currentStep: OnboardingStep = .adminProfile
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum OnboardingStep: CaseIterable {
        case adminProfile
        case businessDetails
        case professionalInfo
        case review
        
        var title: String {
            switch self {
            case .adminProfile: return "Admin Profile"
            case .businessDetails: return "Business Details"
            case .professionalInfo: return "Professional Info"
            case .review: return "Review & Complete"
            }
        }
        
        var subtitle: String {
            switch self {
            case .adminProfile: return "Set up your administrator profile"
            case .businessDetails: return "Complete your company information"
            case .professionalInfo: return "Add your professional credentials"
            case .review: return "Review and finalize your setup"
            }
        }
    }
    
    init(organization: Organization) {
        self.organization = organization
        self._companyName = State(initialValue: organization.name)
        
        // Pre-populate admin info from current user
        if let userEmail = UserDefaults.standard.string(forKey: "stored_apple_email_\(organization.adminUserID)") {
            self._adminEmail = State(initialValue: userEmail)
            self._adminName = State(initialValue: userEmail.components(separatedBy: "@").first?.capitalized ?? "Administrator")
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress indicator
                    progressIndicator
                    
                    // Header
                    headerSection
                    
                    // Step content
                    stepContent
                    
                    // Navigation buttons
                    navigationButtons
                }
                .padding()
            }
            .navigationTitle("Setup Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Later") {
                        // Skip onboarding for now - create basic admin
                        createBasicAdminProfile()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        HStack {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(stepColor(step))
                    .frame(width: 12, height: 12)
                
                if step != OnboardingStep.allCases.last {
                    Rectangle()
                        .fill(stepColor(step).opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func stepColor(_ step: OnboardingStep) -> Color {
        let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0
        let stepIndex = OnboardingStep.allCases.firstIndex(of: step) ?? 0
        
        if stepIndex <= currentIndex {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text(currentStep.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 20) {
            switch currentStep {
            case .adminProfile:
                adminProfileStep
            case .businessDetails:
                businessDetailsStep
            case .professionalInfo:
                professionalInfoStep
            case .review:
                reviewStep
            }
        }
    }
    
    @ViewBuilder
    private var adminProfileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Administrator Profile")
                .font(.headline)
            
            VStack(spacing: 12) {
                FloatingLabelTextField("Company Name", text: $companyName)
                FloatingLabelTextField("Your Full Name", text: $adminName)
                FloatingLabelTextField("Email Address", text: $adminEmail)
                    .keyboardType(.emailAddress)
                FloatingLabelTextField("Phone Number", text: $adminPhone)
                    .keyboardType(.phonePad)
                FloatingLabelTextField("Job Title", text: $jobTitle)
                
                HStack {
                    Text("Default Hourly Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        Text("$")
                        TextField("75", text: $defaultHourlyRate)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var businessDetailsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                FloatingLabelTextField("Business Phone", text: $businessPhone)
                    .keyboardType(.phonePad)
                FloatingLabelTextField("Business Email", text: $businessEmail)
                    .keyboardType(.emailAddress)
                FloatingLabelTextField("Street Address", text: $businessAddress)
                
                HStack(spacing: 12) {
                    FloatingLabelTextField("City", text: $businessCity)
                    FloatingLabelTextField("State", text: $businessState)
                        .frame(maxWidth: 100)
                    FloatingLabelTextField("ZIP", text: $businessZip)
                        .frame(maxWidth: 100)
                }
                
                FloatingLabelTextField("Website (Optional)", text: $businessWebsite)
                    .keyboardType(.URL)
                FloatingLabelTextField("EIN (Optional)", text: $businessEIN)
                FloatingLabelTextField("Business License (Optional)", text: $businessLicense)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var professionalInfoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Professional Credentials")
                .font(.headline)
            
            VStack(spacing: 12) {
                FloatingLabelTextField("License Type (e.g., General Contractor)", text: $licenseType)
                FloatingLabelTextField("License Number", text: $licenseNumber)
                FloatingLabelTextField("Years of Experience", text: $yearsExperience)
                    .keyboardType(.numberPad)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specialties (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $specialties)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review Your Information")
                .font(.headline)
            
            // Admin Profile Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Administrator")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    reviewRow("Name", adminName)
                    reviewRow("Email", adminEmail)
                    if !adminPhone.isEmpty {
                        reviewRow("Phone", adminPhone)
                    }
                    reviewRow("Title", jobTitle)
                    reviewRow("Rate", "$\(defaultHourlyRate)/hr")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Business Summary
            if hasBusinessDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !businessPhone.isEmpty {
                            reviewRow("Phone", businessPhone)
                        }
                        if !businessEmail.isEmpty {
                            reviewRow("Email", businessEmail)
                        }
                        if hasBusinessAddress {
                            reviewRow("Address", businessAddressFormatted)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Professional Summary
            if hasProfessionalDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Professional Info")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !licenseType.isEmpty {
                            reviewRow("License", "\(licenseType) - \(licenseNumber)")
                        }
                        if !yearsExperience.isEmpty {
                            reviewRow("Experience", "\(yearsExperience) years")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep != .adminProfile {
                Button("Back") {
                    withAnimation {
                        previousStep()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            
            Button(currentStep == .review ? "Complete Setup" : "Next") {
                if currentStep == .review {
                    completeOnboarding()
                } else {
                    withAnimation {
                        nextStep()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(!canProceed)
        }
    }
    
    // MARK: - Navigation Logic
    
    private func nextStep() {
        guard canProceed else { return }
        
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex < allSteps.count - 1 {
            currentStep = allSteps[currentIndex + 1]
        }
    }
    
    private func previousStep() {
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            currentStep = allSteps[currentIndex - 1]
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .adminProfile:
            return !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !adminName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !adminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !defaultHourlyRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .businessDetails, .professionalInfo:
            return true // Optional steps
        case .review:
            return !isSubmitting
        }
    }
    
    // MARK: - Business Logic
    
    private var hasBusinessDetails: Bool {
        return !businessPhone.isEmpty || !businessEmail.isEmpty || hasBusinessAddress
    }
    
    private var hasBusinessAddress: Bool {
        return !businessAddress.isEmpty && !businessCity.isEmpty && !businessState.isEmpty
    }
    
    private var businessAddressFormatted: String {
        if hasBusinessAddress {
            return "\(businessAddress), \(businessCity), \(businessState) \(businessZip)"
        }
        return ""
    }
    
    private var hasProfessionalDetails: Bool {
        return !licenseType.isEmpty || !yearsExperience.isEmpty
    }
    
    // MARK: - Admin Creation
    
    private func completeOnboarding() {
        isSubmitting = true
        
        Task {
            do {
                // Create the professional admin profile
                try await createProfessionalAdminProfile()
                
                // Update organization with business details
                await updateOrganizationBusinessDetails()
                
                await MainActor.run {
                    // Mark onboarding as complete
                    authVM.showAdminInfoUpdate = false
                    dismiss()
                }

                Logger.auth.notice("Admin onboarding completed with professional setup.")
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to complete setup: \(error.localizedDescription)"
                    showingError = true
                    isSubmitting = false
                }
            }
        }
    }
    
    private func createBasicAdminProfile() {
        // Create minimal admin profile for users who skip onboarding
        Task {
            do {
                try await createProfessionalAdminProfile(isBasic: true)
                
                await MainActor.run {
                    authVM.showAdminInfoUpdate = false
                    dismiss()
                }

                Logger.auth.notice("Admin onboarding completed with basic setup.")
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create admin profile: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    /// CRITICAL: Single admin creation point that replaces all the messy logic
    private func createProfessionalAdminProfile(isBasic: Bool = false) async throws {
        guard let userID = authVM.user?.id else {
            throw NSError(domain: "AdminOnboarding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }

        Logger.auth.info(
            "Creating admin onboarding profile [organization=\(organization.id, privacy: .private(mask: .hash)), user=\(userID, privacy: .private(mask: .hash)), isBasic=\(isBasic, privacy: .public)]"
        )
        
        // CRITICAL: Check for existing admin first to prevent duplicates
        let existingAdmin = await MainActor.run {
            return projectVM.teamMembers.first { 
                $0.appUserID == userID && 
                $0.organizationID == organization.id && 
                $0.role == .admin 
            }
        }
        
        if existingAdmin != nil {
            Logger.auth.notice("Skipped admin onboarding profile creation because an admin record already exists.")
            return
        }
        
        // Determine profile data (basic vs complete)
        let finalAdminName = isBasic ? (adminName.isEmpty ? "Administrator" : adminName) : adminName
        let finalJobTitle = isBasic ? "Owner/Administrator" : jobTitle
        let finalRate = Double(defaultHourlyRate) ?? 75.0
        let finalEmail = isBasic ? (authVM.user?.email ?? "admin@company.com") : adminEmail
        
        // Create professional admin team member
        let adminTeamMember = TeamMember(
            id: UUID(),
            name: finalAdminName,
            email: finalEmail,
            phone: isBasic ? "" : adminPhone,
            jobTitle: finalJobTitle,
            rates: [
                EmployeeRate(
                    taskType: "Administrative Work",
                    rate: finalRate,
                    isDefault: true
                ),
                EmployeeRate(
                    taskType: "Project Management", 
                    rate: finalRate * 1.2,
                    isDefault: false
                ),
                EmployeeRate(
                    taskType: "Supervision",
                    rate: finalRate * 1.1,
                    isDefault: false
                )
            ],
            isArchived: false,
            organizationID: organization.id,
            role: .admin,
            isActive: true,
            employmentStatus: .active,
            employmentType: .employee,
            hasAppAccess: true,
            appUserID: userID
        )
        
        // Add professional credentials if provided
        var finalTeamMember = adminTeamMember
        if !isBasic && !licenseType.isEmpty {
            finalTeamMember.notes = "License: \(licenseType) #\(licenseNumber)"
            if !yearsExperience.isEmpty {
                finalTeamMember.notes += "\nExperience: \(yearsExperience) years"
            }
            if !specialties.isEmpty {
                finalTeamMember.notes += "\nSpecialties: \(specialties)"
            }
        }
        
        // CRITICAL: Add admin to ProjectViewModel (single source of truth)
        await MainActor.run {
            projectVM.teamMembers.append(finalTeamMember)
            Logger.auth.info("Added admin onboarding profile to the in-memory team-member directory.")
        }
        
        // Save to CloudKit TeamMember record
        try await saveAdminToCloudKit(finalTeamMember)

        Logger.auth.notice(
            "Created admin onboarding profile successfully [organization=\(organization.id, privacy: .private(mask: .hash)), rate=\(finalRate, privacy: .public)]"
        )
    }
    
    /// Save admin team member to CloudKit using proper schema
    private func saveAdminToCloudKit(_ teamMember: TeamMember) async throws {
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDatabase = container.privateCloudDatabase
        
        // Create TeamMember record using CloudKit schema
        let recordID = CKRecord.ID(recordName: "team_member_\(teamMember.id.uuidString)")
        let record = CKRecord(recordType: "TeamMember", recordID: recordID)
        
        // Map to CloudKit schema fields
        record["id"] = teamMember.id.uuidString as CKRecordValue
        record["name"] = teamMember.name as CKRecordValue
        record["email"] = teamMember.email as CKRecordValue
        record["phone"] = teamMember.phone as CKRecordValue
        record["jobTitle"] = teamMember.jobTitle as CKRecordValue
        // Add app user ID if available - moved below
        record["role"] = teamMember.role.rawValue as CKRecordValue
        record["isActive"] = (teamMember.isActive ? 1 : 0) as CKRecordValue
        record["hasAppAccess"] = (teamMember.hasAppAccess ? 1 : 0) as CKRecordValue
        record["employmentStatus"] = teamMember.employmentStatus.rawValue as CKRecordValue
        record["employmentType"] = teamMember.employmentType.rawValue as CKRecordValue
        record["environment"] = "production" as CKRecordValue
        record["dateAdded"] = Date() as CKRecordValue
        
        // Encode rates as BYTES (per schema)
        if let ratesData = try? JSONEncoder().encode(teamMember.rates) {
            record["rates"] = ratesData as CKRecordValue
        }
        
        if let defaultRate = teamMember.rates.first(where: { $0.isDefault }) {
            record["defaultRate"] = defaultRate.rate as CKRecordValue
        }
        
        if !teamMember.notes.isEmpty {
            record["notes"] = teamMember.notes as CKRecordValue
        }
        
        _ = try await privateDatabase.save(record)
        Logger.auth.notice("Saved admin onboarding team-member record to CloudKit.")
    }
    
    /// Update organization with business details collected during onboarding
    private func updateOrganizationBusinessDetails() async {
        guard !businessPhone.isEmpty || !businessEmail.isEmpty || hasBusinessAddress else {
            return // No business details to update
        }
        
        var updatedOrg = organization
        
        // Update business details
        updatedOrg.updateBusinessDetails(
            phone: businessPhone.isEmpty ? nil : businessPhone,
            email: businessEmail.isEmpty ? nil : businessEmail,
            address: businessAddress.isEmpty ? nil : businessAddress,
            city: businessCity.isEmpty ? nil : businessCity,
            state: businessState.isEmpty ? nil : businessState,
            zip: businessZip.isEmpty ? nil : businessZip,
            ein: businessEIN.isEmpty ? nil : businessEIN,
            license: businessLicense.isEmpty ? nil : businessLicense,
            website: businessWebsite.isEmpty ? nil : businessWebsite
        )
        
        // Update in AuthViewModel
        await MainActor.run {
            authVM.currentOrg = updatedOrg
            if let index = authVM.organizations.firstIndex(where: { $0.id == organization.id }) {
                authVM.organizations[index] = updatedOrg
            }
        }
        
        Logger.auth.notice("Updated organization business details during admin onboarding.")
    }
}

// MARK: - Floating Label Text Field Component

struct FloatingLabelTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !text.isEmpty {
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .transition(.opacity)
            }
            
            TextField(text.isEmpty ? placeholder : "", text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    AdminOnboardingView(
        organization: Organization(
            name: "RHEIR Construction",
            adminUserID: "preview_admin_id"
        )
    )
    .environmentObject(AuthViewModel(service: PreviewAuthService()))
    .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
