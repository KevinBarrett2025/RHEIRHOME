import SwiftUI

struct EditEmployeeView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    let employee: Employee
    
    @State private var name: String
    @State private var email: String
    @State private var jobTitle: String
    @State private var rates: [EmployeeRate]
    @State private var isArchived: Bool
    
    // UI State
    @State private var showingAddRate = false
    @State private var showingEditRate = false
    @State private var rateToEdit: EmployeeRate?
    @State private var newRateTaskType = ""
    @State private var newRateAmount = ""
    
    // Common rate types for quick selection
    private let commonRateTypes = [
        "General Labor",
        "Skilled Labor",
        "3D Modeling",
        "Design Work",
        "Project Management",
        "Consultation",
        "Supervision",
        "Equipment Operation",
        "Specialty Work"
    ]
    
    init(employee: Employee) {
        self.employee = employee
        _name = State(initialValue: employee.name)
        _email = State(initialValue: employee.email)
        _jobTitle = State(initialValue: employee.jobTitle)
        _rates = State(initialValue: employee.rates)
        _isArchived = State(initialValue: employee.isArchived)
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !rates.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Employee Information")) {
                    TextField("Full Name", text: $name)
                    
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Job Title", text: $jobTitle)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: ratesHeader) {
                    if rates.isEmpty {
                        Text("No rates defined")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(rates) { rate in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rate.taskType)
                                        .font(.headline)
                                    Text("Hourly Rate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(rate.rate, specifier: "%.2f")")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    
                                    Button("Edit") {
                                        editRate(rate)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    deleteSpecificRate(rate)
                                }
                            }
                        }
                        .onDelete(perform: deleteRate)
                    }
                    
                    Button(action: { showingAddRate = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Rate Type")
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Status")) {
                    Toggle("Active Employee", isOn: Binding(
                        get: { !isArchived },
                        set: { isArchived = !$0 }
                    ))
                    
                    if isArchived {
                        Text("Archived employees won't appear in new time entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    HStack {
                        Text("Total Rate Types")
                        Spacer()
                        Text("\(rates.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !rates.isEmpty {
                        HStack {
                            Text("Rate Range")
                            Spacer()
                            if let minRate = rates.map(\.rate).min(),
                               let maxRate = rates.map(\.rate).max() {
                                if minRate == maxRate {
                                    Text("$\(minRate, specifier: "%.2f")")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("$\(minRate, specifier: "%.2f") - $\(maxRate, specifier: "%.2f")")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEmployee()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingAddRate) {
                AddRateView(
                    existingTaskTypes: rates.map(\.taskType),
                    onAdd: { taskType, rate in
                        let newRate = EmployeeRate(taskType: taskType, rate: rate)
                        rates.append(newRate)
                    }
                )
            }
            .sheet(isPresented: $showingEditRate) {
                if let rateToEdit = rateToEdit {
                    EditRateView(
                        rate: rateToEdit,
                        existingTaskTypes: rates.filter { $0.id != rateToEdit.id }.map(\.taskType),
                        onSave: { updatedRate in
                            if let index = rates.firstIndex(where: { $0.id == rateToEdit.id }) {
                                rates[index] = updatedRate
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var ratesHeader: some View {
        HStack {
            Text("Rate Types")
            Spacer()
            Text("Different rates for different types of work")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func deleteRate(at offsets: IndexSet) {
        rates.remove(atOffsets: offsets)
    }
    
    private func deleteSpecificRate(_ rate: EmployeeRate) {
        rates.removeAll { $0.id == rate.id }
    }
    
    private func editRate(_ rate: EmployeeRate) {
        rateToEdit = rate
        showingEditRate = true
    }
    
    private func saveEmployee() {
        var updatedEmployee = employee
        updatedEmployee.name = name.trimmingCharacters(in: .whitespaces)
        updatedEmployee.email = email.trimmingCharacters(in: .whitespaces)
        updatedEmployee.jobTitle = jobTitle.trimmingCharacters(in: .whitespaces)
        updatedEmployee.rates = rates
        updatedEmployee.isArchived = isArchived
        
        projectVM.updateEmployee(updatedEmployee)
        dismiss()
    }
}

// MARK: - Add Rate View
struct AddRateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let existingTaskTypes: [String]
    let onAdd: (String, Double) -> Void
    
    @State private var selectedTaskType = ""
    @State private var customTaskType = ""
    @State private var rateText = ""
    @State private var useCustomType = false
    
    private let commonRateTypes = [
        "General Labor",
        "Skilled Labor",
        "3D Modeling",
        "Design Work",
        "Project Management",
        "Consultation",
        "Supervision",
        "Equipment Operation",
        "Specialty Work"
    ]
    
    private var availableTaskTypes: [String] {
        commonRateTypes.filter { !existingTaskTypes.contains($0) }
    }
    
    private var taskTypeToUse: String {
        useCustomType ? customTaskType.trimmingCharacters(in: .whitespaces) : selectedTaskType
    }
    
    private var canSave: Bool {
        !taskTypeToUse.isEmpty &&
        Double(rateText) != nil &&
        Double(rateText)! > 0 &&
        !existingTaskTypes.contains(taskTypeToUse)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rate Type")) {
                    if !availableTaskTypes.isEmpty {
                        Picker("Select Type", selection: $selectedTaskType) {
                            Text("Choose a type...").tag("")
                            ForEach(availableTaskTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .disabled(useCustomType)
                        
                        Toggle("Custom Type", isOn: $useCustomType)
                    } else {
                        Text("All common types are already used")
                            .foregroundColor(.secondary)
                        Toggle("Custom Type", isOn: .constant(true))
                            .disabled(true)
                            .onAppear { useCustomType = true }
                    }
                    
                    if useCustomType {
                        TextField("Custom Rate Type", text: $customTaskType)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section(header: Text("Hourly Rate")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $rateText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("per hour")
                            .foregroundColor(.secondary)
                    }
                }
                
                if !taskTypeToUse.isEmpty && !rateText.isEmpty,
                   let rate = Double(rateText), rate > 0 {
                    Section(header: Text("Preview")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(taskTypeToUse)
                                    .font(.headline)
                                Text("Hourly Rate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("$\(rate, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if existingTaskTypes.contains(taskTypeToUse) {
                    Section {
                        Text("⚠️ This rate type already exists")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Add Rate Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let rate = Double(rateText) {
                            onAdd(taskTypeToUse, rate)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Edit Rate View
struct EditRateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let rate: EmployeeRate
    let existingTaskTypes: [String]
    let onSave: (EmployeeRate) -> Void
    
    @State private var taskType = ""
    @State private var rateText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rate Type")) {
                    TextField("Rate Type", text: $taskType)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            taskType = rate.taskType
                        }
                }
                
                Section(header: Text("Hourly Rate")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $rateText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("per hour")
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        rateText = String(rate.rate)
                    }
                }
            }
            .navigationTitle("Edit Rate Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedRate = EmployeeRate(taskType: taskType, rate: Double(rateText) ?? 0)
                        onSave(updatedRate)
                        dismiss()
                    }
                    .disabled(taskType.isEmpty || rateText.isEmpty || Double(rateText) == nil)
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct EditEmployeeView_Previews: PreviewProvider {
    static var previews: some View {
        EditEmployeeView(employee: Employee(
            name: "Kevin Barrett",
            email: "kevin@rheirhome.com",
            jobTitle: "Contractor",
            rates: [
                EmployeeRate(taskType: "General Labor", rate: 45.0),
                EmployeeRate(taskType: "3D Modeling", rate: 75.0),
                EmployeeRate(taskType: "Project Management", rate: 65.0)
            ]
        ))
        .environmentObject(ProjectViewModel())
    }
}
#endif
