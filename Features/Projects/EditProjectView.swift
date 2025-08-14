import SwiftUI

struct EditProjectView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    
    @State private var name: String
    @State private var client: String
    @State private var clientPhone: String
    @State private var clientEmail: String
    @State private var clientAddress: String
    @State private var description: String
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
        self._clientPhone = State(initialValue: project.clientPhone ?? "")
        self._clientEmail = State(initialValue: project.clientEmail ?? "")
        self._clientAddress = State(initialValue: project.clientAddress ?? "")
        self._description = State(initialValue: project.description)
        
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
                SemiTransparentTextField(title: "Phone", text: $clientPhone, keyboardType: .phonePad)
                SemiTransparentTextField(title: "Email", text: $clientEmail, keyboardType: .emailAddress, autocapitalization: .never)
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
                SemiTransparentTextField(title: "Full Address", text: $clientAddress)
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
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            TextField("Additional description about the project...", text: $description, axis: .vertical)
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
        
        // Create updated project using the current project as base and updating only changed fields
        let updatedProject = Project(
            id: project.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            client: client.trimmingCharacters(in: .whitespacesAndNewlines),
            clientEmail: clientEmail.isEmpty ? nil : clientEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            clientPhone: clientPhone.isEmpty ? nil : clientPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            clientAddress: clientAddress.isEmpty ? nil : clientAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            totalBudget: totalBudgetValue,
            materialCost: materialCostValue,
            laborCost: laborCostValue,
            generalConditions: generalConditionsValue,
            contingency: contingencyAmount,
            startDate: startDate,
            endDate: endDate,
            status: project.status,
            priority: project.priority,
            assignedUserIDs: project.assignedUserIDs,
            organizationID: project.organizationID,
            creationDate: project.creationDate,
            lastModifiedDate: Date(),
            photoIDs: project.photoIDs
        )
        
        // Copy over all child collections from original project
        var finalProject = updatedProject
        finalProject.tasks = project.tasks
        finalProject.progressLogs = project.progressLogs
        finalProject.receipts = project.receipts
        finalProject.workHours = project.workHours
        finalProject.communications = project.communications
        finalProject.changeOrders = project.changeOrders
        
        print("💾 PREPARING TO SAVE PROJECT UPDATES:")
        print("  - Project ID: \(finalProject.id)")
        print("  - Updated Name: '\(finalProject.name)'")
        print("  - Updated Client: '\(finalProject.client)'")
        print("  - Updated Total Budget: $\(finalProject.totalBudget)")
        print("  - Organization ID: \(finalProject.organizationID)")
        print("  - Same ID as original? \(finalProject.id == project.id)")
        
        // CRITICAL: Make sure this save completes before dismissing
        Task { @MainActor in
            print("🔄 Starting async project update...")
            
            // Call updateProject and wait for it to complete
            await projectVM.updateProject(finalProject)
            
            print("✅ EDIT PROJECT SAVE COMPLETED - dismissing view")
            dismiss()
        }
    }
}

struct EditProjectView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            clientEmail: "john.doe@email.com",
            clientPhone: "(555) 123-4567",
            clientAddress: "123 Main St, Anytown, CA 12345",
            description: "Sample renovation project",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        EditProjectView(project: sampleProject)
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}