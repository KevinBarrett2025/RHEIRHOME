import SwiftUI

struct NewProjectView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var client = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var notes = ""
    @State private var totalBudget = ""
    @State private var generalConditions = ""
    @State private var materials = ""
    @State private var labor = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    
    // Computed contingency with safe math
    private var contingencyAmount: Double {
        let total = Double(totalBudget) ?? 0
        let gc = Double(generalConditions) ?? 0
        let mat = Double(materials) ?? 0
        let lab = Double(labor) ?? 0
        
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
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
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
                SemiTransparentCurrencyField(title: "Materials", text: $materials)
                SemiTransparentCurrencyField(title: "Labor", text: $labor)
                
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
    
    private func createProject() {
        // Validate all numeric inputs
        let totalBudgetValue = Double(totalBudget) ?? 0
        let materialsValue = Double(materials) ?? 0
        let laborValue = Double(labor) ?? 0
        let generalConditionsValue = Double(generalConditions) ?? 0
        
        // Ensure all values are valid
        guard totalBudgetValue.isFinite && totalBudgetValue >= 0,
              materialsValue.isFinite && materialsValue >= 0,
              laborValue.isFinite && laborValue >= 0,
              generalConditionsValue.isFinite && generalConditionsValue >= 0,
              contingencyAmount.isFinite && contingencyAmount >= 0 else {
            print("❌ Invalid budget values detected, cannot create project")
            return
        }
        
        let project = Project(
            name: name,
            client: client,
            phone: phone,
            email: email,
            street: street,
            city: city,
            state: state,
            zip: zip,
            notes: notes,
            totalBudget: totalBudgetValue,
            materialCost: materialsValue,
            laborCost: laborValue,
            generalConditions: generalConditionsValue,
            contingency: contingencyAmount,
            profit: 0, // Remove profit field per user request
            startDate: startDate,
            endDate: endDate
        )
        
        projectVM.createNewProject(project)
        isPresented = false
    }
}

// MARK: - Semi-Transparent Components for NewProjectView

struct SemiTransparentTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentCurrencyField: View {
    let title: String
    @Binding var text: String
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("$")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("0", text: $text)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentDatePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct NewProjectView_Previews: PreviewProvider {
    static var previews: some View {
        NewProjectView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}