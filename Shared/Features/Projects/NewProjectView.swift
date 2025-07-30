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
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                    TextField("Client Name", text: $client)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Address") {
                    TextField("Street Address", text: $street)
                    HStack {
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                            .frame(maxWidth: 80)
                        TextField("Zip", text: $zip)
                            .frame(maxWidth: 80)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("Budget Breakdown") {
                    HStack {
                        Text("Total Budget")
                        Spacer()
                        TextField("0", text: $totalBudget)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("General Conditions")
                        Spacer()
                        TextField("0", text: $generalConditions)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Materials")
                        Spacer()
                        TextField("0", text: $materials)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Labor")
                        Spacer()
                        TextField("0", text: $labor)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Contingency (Auto-calculated)")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(contingencyAmount, specifier: "%.2f")")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Timeline") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
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

struct NewProjectView_Previews: PreviewProvider {
    static var previews: some View {
        NewProjectView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}