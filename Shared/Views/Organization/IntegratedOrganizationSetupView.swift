import SwiftUI
import OSLog

/// Integrated organization setup flow - combines org creation with admin onboarding
/// This replaces the fragmented approach with a single cohesive experience
struct IntegratedOrganizationSetupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Multi-step flow state
    @State private var currentStep: SetupStep = .organizationInfo
    @State private var canProceed = false
    
    // Organization info (Step 1)
    @State private var organizationName = ""
    @State private var selectedIndustry = "Construction"
    
    // Admin info (Step 2)
    @State private var adminName = ""
    @State private var adminEmail = ""
    
    // Welcome & Next Steps (Step 3)
    @State private var selectedFeatures: Set<String> = []
    
    // Processing state
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let industries = [
        "Construction", "General Contracting", "Residential Construction",
        "Commercial Construction", "Renovation & Remodeling", "Other"
    ]
    
    private let quickStartFeatures = [
        "Create your first project",
        "Add team members", 
        "Set up budget tracking",
        "Enable receipt scanning"
    ]
    
    enum SetupStep: Int, CaseIterable {
        case organizationInfo = 0
        case adminProfile = 1
        case welcomeAndNext = 2
        
        var title: String {
            switch self {
            case .organizationInfo: return "Create Organization"
            case .adminProfile: return "Admin Profile"
            case .welcomeAndNext: return "Welcome!"
            }
        }
        
        var subtitle: String {
            switch self {
            case .organizationInfo: return "Set up your company information"
            case .adminProfile: return "Complete your administrator profile"
            case .welcomeAndNext: return "Your organization is ready!"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content area
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        
                        contentSection
                        
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Setup Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    // MARK: - Progress Indicator
    
    @ViewBuilder
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if step.rawValue < SetupStep.allCases.count - 1 {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Text("Step \(currentStep.rawValue + 1) of \(SetupStep.allCases.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            stepIcon
            
            Text(currentStep.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(currentStep.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var stepIcon: some View {
        Group {
            switch currentStep {
            case .organizationInfo:
                Image(systemName: "building.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            case .adminProfile:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            case .welcomeAndNext:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    private var contentSection: some View {
        switch currentStep {
        case .organizationInfo:
            organizationInfoStep
        case .adminProfile:
            adminProfileStep
        case .welcomeAndNext:
            welcomeStep
        }
    }
    
    @ViewBuilder
    private var organizationInfoStep: some View {
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
                    .onChange(of: organizationName) { _, _ in
                        updateCanProceed()
                    }
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
    private var adminProfileStep: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.headline)
                
                TextField("Full Name", text: $adminName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: adminName) { _, _ in
                        updateCanProceed()
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.headline)
                
                TextField("Email", text: $adminEmail)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            VStack(spacing: 12) {
                Text("As the administrator, you'll be able to:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    adminCapabilityRow("Manage team members and permissions", "person.2.fill")
                    adminCapabilityRow("Create and oversee projects", "folder.fill")
                    adminCapabilityRow("Access financial reports", "chart.bar.fill")
                    adminCapabilityRow("Configure organization settings", "gearshape.fill")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func adminCapabilityRow(_ text: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("🎉 Welcome to RHEIR!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let orgName = authVM.currentOrg?.name {
                    Text("'\(orgName)' has been created successfully!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text("Your construction management platform is ready. Here's what you can do next:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                ForEach(quickStartFeatures, id: \.self) { feature in
                    HStack {
                        Button {
                            if selectedFeatures.contains(feature) {
                                selectedFeatures.remove(feature)
                            } else {
                                selectedFeatures.insert(feature)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedFeatures.contains(feature) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedFeatures.contains(feature) ? .green : .gray)
                                Text(feature)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button {
                handlePrimaryAction()
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    
                    Text(primaryButtonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProceed ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProceed || isProcessing)
            
            // Secondary action (if applicable)
            if currentStep != .organizationInfo {
                Button("Back") {
                    withAnimation {
                        goToPreviousStep()
                    }
                }
                .foregroundColor(.blue)
                .disabled(isProcessing)
            }
        }
    }
    
    private var primaryButtonText: String {
        if isProcessing {
            return processingMessage
        }
        
        switch currentStep {
        case .organizationInfo:
            return "Create Organization"
        case .adminProfile:
            return "Complete Profile"
        case .welcomeAndNext:
            return "Enter RHEIR"
        }
    }
    
    // MARK: - Logic Methods
    
    private func setupInitialData() {
        // Pre-fill admin email if available
        if let userEmail = authVM.user?.email, !userEmail.isEmpty {
            adminEmail = userEmail
        }
        updateCanProceed()
    }
    
    private func updateCanProceed() {
        switch currentStep {
        case .organizationInfo:
            canProceed = !organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .adminProfile:
            canProceed = !adminName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .welcomeAndNext:
            canProceed = true
        }
    }
    
    private func handlePrimaryAction() {
        switch currentStep {
        case .organizationInfo:
            createOrganization()
        case .adminProfile:
            updateAdminProfile()
        case .welcomeAndNext:
            completeSetup()
        }
    }
    
    private func goToPreviousStep() {
        if currentStep.rawValue > 0 {
            currentStep = SetupStep(rawValue: currentStep.rawValue - 1) ?? .organizationInfo
            updateCanProceed()
        }
    }
    
    private func goToNextStep() {
        if currentStep.rawValue < SetupStep.allCases.count - 1 {
            withAnimation {
                currentStep = SetupStep(rawValue: currentStep.rawValue + 1) ?? .welcomeAndNext
                updateCanProceed()
            }
        }
    }
    
    // MARK: - Step Actions
    
    private func createOrganization() {
        let trimmedName = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        isProcessing = true
        processingMessage = "Creating organization..."
        
        Task {
            do {
                Logger.auth.info(
                    "Integrated setup creating organization [organization=\(trimmedName, privacy: .private(mask: .hash))]"
                )
                
                let newOrg = try await authVM.createOrganization(named: trimmedName, industry: selectedIndustry)
                
                await MainActor.run {
                    Logger.auth.notice(
                        "Integrated setup created organization [organization=\(newOrg.id, privacy: .private(mask: .hash))]"
                    )
                    isProcessing = false
                    processingMessage = ""
                    goToNextStep()
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    processingMessage = ""
                    errorMessage = "Failed to create organization: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func updateAdminProfile() {
        let trimmedName = adminName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = adminEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        isProcessing = true
        processingMessage = "Updating profile..."
        
        Task { @MainActor in
            // Find and update the admin team member
            guard let userID = authVM.user?.id,
                  let adminMember = projectVM.teamMembers.first(where: { $0.appUserID == userID }) else {
                Logger.auth.error("Integrated setup could not find the admin team member.")
                isProcessing = false
                processingMessage = ""
                // Continue anyway - this is not critical
                goToNextStep()
                return
            }
            
            Logger.auth.info(
                "Integrated setup updating admin profile [user=\(userID, privacy: .private(mask: .hash))]"
            )
            
            var updatedAdmin = adminMember
            updatedAdmin.name = trimmedName
            updatedAdmin.email = trimmedEmail
            
            // Update through ProjectViewModel
            projectVM.updateTeamMemberInOrganization(updatedAdmin)
            
            // Small delay for update to complete
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            isProcessing = false
            processingMessage = ""
            
            Logger.auth.notice("Integrated setup updated the admin profile.")
            goToNextStep()
        }
    }
    
    private func completeSetup() {
        Logger.session.notice(
            "Integrated setup completed [organization=\((authVM.currentOrg?.id ?? "unknown"), privacy: .private(mask: .hash)) features=\(selectedFeatures.count, privacy: .public)]"
        )
        
        // CRITICAL FIX: Ensure proper state management
        authVM.needsOrganizationSetup = false
        authVM.showOrganizationSetup = false
        authVM.showAdminInfoUpdate = false  // Ensure this is also false
        
        // Force UI state refresh to ensure MainTabView appears
        authVM.objectWillChange.send()
        
        Logger.session.info("Integrated setup cleared onboarding state flags.")
        dismiss()
    }
}

#Preview {
    IntegratedOrganizationSetupView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
