import SwiftUI

struct EditRateView: View {
    let rate: EmployeeRate
    let existingTaskTypes: [String]
    let onSave: (EmployeeRate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskType: String
    @State private var rateAmount: String
    @State private var useCustomType = false
    @State private var customTaskType = ""
    
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
        commonRateTypes.filter { !existingTaskTypes.contains($0) || $0 == rate.taskType }
    }
    
    private var taskTypeToUse: String {
        useCustomType ? customTaskType.trimmingCharacters(in: .whitespaces) : taskType
    }
    
    private var canSave: Bool {
        !taskTypeToUse.isEmpty && 
        Double(rateAmount) != nil && 
        Double(rateAmount)! > 0 &&
        (!existingTaskTypes.contains(taskTypeToUse) || taskTypeToUse == rate.taskType)
    }
    
    init(rate: EmployeeRate, existingTaskTypes: [String], onSave: @escaping (EmployeeRate) -> Void) {
        self.rate = rate
        self.existingTaskTypes = existingTaskTypes
        self.onSave = onSave
        
        _taskType = State(initialValue: rate.taskType)
        _rateAmount = State(initialValue: String(format: "%.2f", rate.rate))
        
        // Check if this is a custom type
        let isCustom = !commonRateTypes.contains(rate.taskType)
        _useCustomType = State(initialValue: isCustom)
        _customTaskType = State(initialValue: isCustom ? rate.taskType : "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rate Type")) {
                    if !availableTaskTypes.isEmpty && !useCustomType {
                        Picker("Select Type", selection: $taskType) {
                            ForEach(availableTaskTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .disabled(useCustomType)
                    }
                    
                    Toggle("Custom Type", isOn: $useCustomType)
                        .onChange(of: useCustomType) { _, isCustom in
                            if isCustom {
                                customTaskType = rate.taskType
                            } else {
                                taskType = rate.taskType
                            }
                        }
                    
                    if useCustomType {
                        TextField("Custom Rate Type", text: $customTaskType)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section(header: Text("Hourly Rate")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $rateAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("per hour")
                            .foregroundColor(.secondary)
                    }
                }
                
                if !taskTypeToUse.isEmpty && !rateAmount.isEmpty,
                   let rateValue = Double(rateAmount), rateValue > 0 {
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
                            Text("$\(rateValue, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if existingTaskTypes.contains(taskTypeToUse) && taskTypeToUse != rate.taskType {
                    Section {
                        Text("⚠️ This rate type already exists")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Edit Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let rateValue = Double(rateAmount) {
                            var updatedRate = rate
                            updatedRate.taskType = taskTypeToUse
                            updatedRate.rate = rateValue
                            onSave(updatedRate)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#if DEBUG
struct EditRateView_Previews: PreviewProvider {
    static var previews: some View {
        EditRateView(
            rate: EmployeeRate(taskType: "General Labor", rate: 45.0),
            existingTaskTypes: ["3D Modeling", "Project Management"],
            onSave: { _ in }
        )
    }
}
#endif