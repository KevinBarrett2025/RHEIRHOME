import SwiftUI

struct EditProjectView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
    @State private var name: String
    @State private var client: String
    @State private var phone: String
    @State private var email: String
    @State private var street: String
    @State private var city: String
    @State private var state: String
    @State private var zip: String
    @State private var notes: String
    @State private var totalBudget: String
    @State private var materialCost: String
    @State private var laborCost: String
    @State private var generalConditions: String
    @State private var startDate: Date
    @State private var endDate: Date
    
    // Computed contingency with safe math (like NewProjectView)
    private var contingencyAmount: Double {
        let total = Double(totalBudget) ?? 0
        let gc = Double(generalConditions) ?? 0
        let mat = Double(materialCost) ?? 0
        let lab = Double(laborCost) ?? 0
        
        // Ensure all values are valid and non-negative
        guard total >= 0, gc >= 0, mat >= 0, lab >= 0 else {
            return 0
        }
        
        let result = total - gc - mat - lab
        
        // Ensure result is valid and non-negative
        guard result.isFinite && result >= 0 else {
            return 0
        }
        
        return result
    }
    
    init(project: Project) {
        self.project = project
        self._name = State(initialValue: project.name)
        self._client = State(initialValue: project.client)
        self._phone = State(initialValue: project.phone)
        self._email = State(initialValue: project.email)
        self._street = State(initialValue: project.street)
        self._city = State(initialValue: project.city)
        self._state = State(initialValue: project.state)
        self._zip = State(initialValue: project.zip)
        self._notes = State(initialValue: project.notes)
        
        // For budget fields, show empty string if value is 0, otherwise show the actual value
        self._totalBudget = State(initialValue: project.totalBudget == 0 ? "" : String(format: "%.0f", project.totalBudget))
        self._materialCost = State(initialValue: project.materialCost == 0 ? "" : String(format: "%.0f", project.materialCost))
        self._laborCost = State(initialValue: project.laborCost == 0 ? "" : String(format: "%.0f", project.laborCost))
        self._generalConditions = State(initialValue: project.generalConditions == 0 ? "" : String(format: "%.0f", project.generalConditions))
        
        self._startDate = State(initialValue: project.startDate)
        self._endDate = State(initialValue: project.endDate)
    }
    
    private var isValidForm: Bool {
        !name.isEmpty && !client.isEmpty && !totalBudget.isEmpty && contingencyAmount >= 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background blur effect
                Color.clear
                
                ScrollView {
                    VStack(spacing: 20) {
                        projectDetailsSection
                        addressSection
                        budgetBreakdownSection
                        timelineSection
                        notesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProject()
                    }
                    .disabled(!isValidForm)
                    .foregroundColor(isValidForm ? .blue : .secondary)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.thinMaterial)
    }
    
    @ViewBuilder
    private var projectDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Project Details")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentTextField(title: "Project Name", text: $name, isRequired: true)
                SemiTransparentTextField(title: "Client Name", text: $client, isRequired: true)
                SemiTransparentTextField(title: "Phone", text: $phone, keyboardType: .phonePad)
                SemiTransparentTextField(title: "Email", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder 
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Address")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentTextField(title: "Street Address", text: $street)
                
                HStack(spacing: 12) {
                    SemiTransparentTextField(title: "City", text: $city)
                    SemiTransparentTextField(title: "State", text: $state)
                        .frame(maxWidth: 100)
                    SemiTransparentTextField(title: "Zip", text: $zip, keyboardType: .numberPad)
                        .frame(maxWidth: 100)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var budgetBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Budget Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentCurrencyField(title: "Total Budget", text: $totalBudget, isRequired: true)
                SemiTransparentCurrencyField(title: "General Conditions", text: $generalConditions)
                SemiTransparentCurrencyField(title: "Materials", text: $materialCost)
                SemiTransparentCurrencyField(title: "Labor", text: $laborCost)
                
                // Auto-calculated contingency display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Contingency")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(Auto-calculated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Remaining budget after all expenses")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(contingencyAmount.formatAsCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(contingencyAmount >= 0 ? .green : .red)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentDatePicker(title: "Start Date", selection: $startDate)
                SemiTransparentDatePicker(title: "End Date", selection: $endDate)
                
                // Duration display
                HStack {
                    Text("Project Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let duration = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                    Text("\(duration) days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(duration > 0 ? .primary : .red)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .font(.title2) 
                    .foregroundColor(.indigo)
                Text("Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            TextField("Additional notes about the project...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .lineLimit(3...6)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func saveProject() {
        print("🔄 EDIT PROJECT SAVE STARTED")
        print("  - Original project name: '\(project.name)'")
        print("  - New project name: '\(name)'")
        
        // Validate all numeric inputs (same as NewProjectView)
        let totalBudgetValue = Double(totalBudget) ?? 0
        let materialCostValue = Double(materialCost) ?? 0
        let laborCostValue = Double(laborCost) ?? 0
        let generalConditionsValue = Double(generalConditions) ?? 0
        
        // Ensure all values are valid
        guard totalBudgetValue.isFinite && totalBudgetValue >= 0,
              materialCostValue.isFinite && materialCostValue >= 0,
              laborCostValue.isFinite && laborCostValue >= 0,
              generalConditionsValue.isFinite && generalConditionsValue >= 0,
              contingencyAmount.isFinite && contingencyAmount >= 0 else {
            print("❌ Invalid budget values detected, cannot save project")
            return
        }
        
        // Preserve ALL original project data, only updating the fields that were edited
        var updatedProject = project
        
        // Update basic info
        updatedProject.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.client = client.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update address
        updatedProject.street = street.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.state = state.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.zip = zip.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update notes
        updatedProject.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update budget values
        updatedProject.totalBudget = totalBudgetValue
        updatedProject.materialCost = materialCostValue
        updatedProject.laborCost = laborCostValue
        updatedProject.generalConditions = generalConditionsValue
        updatedProject.contingency = contingencyAmount // Use calculated contingency
        
        // Update dates
        updatedProject.startDate = startDate
        updatedProject.endDate = endDate
        
        print("💾 PREPARING TO SAVE PROJECT UPDATES:")
        print("  - Project ID: \(updatedProject.id)")
        print("  - Updated Name: '\(updatedProject.name)'")
        print("  - Updated Client: '\(updatedProject.client)'")
        print("  - Updated Total Budget: $\(updatedProject.totalBudget)")
        print("  - Organization ID: \(updatedProject.organizationID ?? "none")")
        print("  - Same ID as original? \(updatedProject.id == project.id)")
        
        // CRITICAL: Make sure this save completes before dismissing
        Task { @MainActor in
            print("🔄 Starting async project update...")
            
            // Call updateProject and wait for it to complete
            await updateProjectWithCompletion(updatedProject)
            
            print("✅ EDIT PROJECT SAVE COMPLETED - dismissing view")
            dismiss()
        }
    }
    
    @MainActor
    private func updateProjectWithCompletion(_ updatedProject: Project) async {
        return await withCheckedContinuation { continuation in
            print("🔄 Calling projectVM.updateProject...")
            
            // Update the project synchronously first
            projectVM.updateProject(updatedProject)
            
            // Give it a moment to process
            Task {
                // Wait a bit for the update to process
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                print("✅ ProjectViewModel.updateProject call completed")
                continuation.resume()
            }
        }
    }
}

struct EditProjectView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            phone: "(555) 123-4567",
            email: "john.doe@email.com",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            profit: 0,
            startDate: Date(),
            endDate: Date()
        )
        
        EditProjectView(project: sampleProject)
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}