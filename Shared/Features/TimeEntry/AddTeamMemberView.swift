import SwiftUI
import OSLog

struct AddTeamMemberView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let editingTeamMember: TeamMember?
    
    @State private var name = ""
    @State private var email = ""
    @State private var jobTitle = ""
    @State private var rates: [EmployeeRate] = [] // Keep EmployeeRate for backward compatibility
    @State private var isArchived = false
    @State private var role: TeamMemberRole = .member
    
    // UI State
    @State private var showingAddRate = false
    @State private var showingEditRate = false
    @State private var rateToEdit: EmployeeRate?
    
    init(editingTeamMember: TeamMember? = nil) {
        self.editingTeamMember = editingTeamMember
        
        if let teamMember = editingTeamMember {
            _name = State(initialValue: teamMember.name)
            _email = State(initialValue: teamMember.email)
            _jobTitle = State(initialValue: teamMember.jobTitle)
            _rates = State(initialValue: teamMember.rates.isEmpty ? [] : teamMember.rates)
            _isArchived = State(initialValue: teamMember.isArchived)
            _role = State(initialValue: teamMember.role)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !rates.isEmpty
    }
    
    private var isEditing: Bool {
        editingTeamMember != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Team Member Information")) {
                    TextField("Full Name", text: $name)
                    
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Job Title", text: $jobTitle)
                    
                    Picker("Role", selection: $role) {
                        ForEach(TeamMemberRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Role Permissions")) {
                    let permissions = role.permissions
                    
                    PermissionRow("Create Projects", granted: permissions.canCreateProjects)
                    PermissionRow("Edit Projects", granted: permissions.canEditProjects)
                    PermissionRow("Delete Projects", granted: permissions.canDeleteProjects)
                    PermissionRow("Manage Team", granted: permissions.canManageTeam)
                    PermissionRow("View Reports", granted: permissions.canViewReports)
                    PermissionRow("Edit Receipts", granted: permissions.canEditReceipts)
                    PermissionRow("Log Hours", granted: permissions.canLogHours)
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
                                    HStack {
                                        Text(rate.taskType)
                                            .font(.headline)
                                        if rate.isDefault {
                                            Text("DEFAULT")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .cornerRadius(4)
                                        }
                                    }
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
                                    
                                    HStack {
                                        Button("Edit") {
                                            editRate(rate)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        
                                        if !rate.isDefault {
                                            Button("Set Default") {
                                                setDefaultRate(rate)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if rates.count > 1 {
                                    Button("Delete", role: .destructive) {
                                        deleteSpecificRate(rate)
                                    }
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
                
                if isEditing {
                    Section(header: Text("Status")) {
                        Toggle("Active Team Member", isOn: Binding(
                            get: { !isArchived },
                            set: { isArchived = !$0 }
                        ))
                        
                        if isArchived {
                            Text("Archived team members won't appear in new time entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !rates.isEmpty {
                    Section {
                        HStack {
                            Text("Total Rate Types")
                            Spacer()
                            Text("\(rates.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Default Rate")
                            Spacer()
                            if let defaultRate = rates.first(where: { $0.isDefault }) {
                                Text("\(defaultRate.taskType) - $\(defaultRate.rate, specifier: "%.2f")")
                                    .foregroundColor(.green)
                            } else {
                                Text("No default set")
                                    .foregroundColor(.orange)
                            }
                        }
                        
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
                
                Section(footer: Text("Team members can be assigned to projects and time tracking with different rates for different types of work. One rate should be marked as default for quick hour logging.")) {
                    // Empty section for footer text
                }
            }
            .navigationTitle(isEditing ? "Edit Team Member" : "New Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTeamMember()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingAddRate) {
                AddRateView(
                    existingTaskTypes: rates.map(\.taskType),
                    onAdd: { taskType, rate, isDefault in
                        addNewRate(taskType: taskType, rate: rate, isDefault: isDefault)
                    }
                )
            }
            .sheet(isPresented: $showingEditRate) {
                if let rateToEdit = rateToEdit {
                    EditRateView(
                        rate: rateToEdit,
                        existingTaskTypes: rates.filter { $0.id != rateToEdit.id }.map(\.taskType),
                        onSave: { updatedRate in
                            updateRate(updatedRate)
                        }
                    )
                }
            }
            .onAppear {
                if !isEditing && rates.isEmpty {
                    rates = [EmployeeRate(taskType: "General Labor", rate: 25.0, isDefault: true)]
                }
                
                // Ensure rates have proper default status
                validateRates()
            }
        }
    }
    
    private var ratesHeader: some View {
        HStack {
            Text("Rate Types")
            Spacer()
            Text("Different rates for different work")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func setDefaultRate(_ rate: EmployeeRate) {
        for i in 0..<rates.count {
            rates[i].isDefault = (rates[i].id == rate.id)
        }
        Logger.teamMember.notice(
            "Set default rate for team member editor [taskType=\(rate.taskType, privacy: .public)]"
        )
    }
    
    private func addNewRate(taskType: String, rate: Double, isDefault: Bool) {
        let newRate = EmployeeRate(taskType: taskType, rate: rate, isDefault: isDefault)
        
        // If this is set as default, clear other defaults
        if isDefault {
            for i in 0..<rates.count {
                rates[i].isDefault = false
            }
        }
        
        rates.append(newRate)
        validateRates()
    }
    
    private func updateRate(_ updatedRate: EmployeeRate) {
        if let index = rates.firstIndex(where: { $0.id == rateToEdit?.id }) {
            rates[index] = updatedRate
            validateRates()
        }
    }
    
    private func editRate(_ rate: EmployeeRate) {
        rateToEdit = rate
        showingEditRate = true
    }
    
    private func validateRates() {
        let defaultRates = rates.filter { $0.isDefault }
        
        if defaultRates.count > 1 {
            // Multiple defaults - keep only the first one
            for i in 0..<rates.count {
                rates[i].isDefault = (i == 0 && rates[i].isDefault)
            }
        } else if defaultRates.isEmpty && !rates.isEmpty {
            // No default - make first rate the default
            rates[0].isDefault = true
        }
    }
    
    private func deleteRate(at offsets: IndexSet) {
        // Don't allow deleting the last rate
        if rates.count <= 1 {
            return
        }
        
        let wasDefaultDeleted = offsets.contains { rates[$0].isDefault }
        rates.remove(atOffsets: offsets)
        
        // If we deleted the default rate, make the first remaining rate default
        if wasDefaultDeleted && !rates.isEmpty {
            rates[0].isDefault = true
        }
        
        validateRates()
    }
    
    private func deleteSpecificRate(_ rate: EmployeeRate) {
        // Don't allow deleting the last rate
        if rates.count <= 1 {
            return
        }
        
        let wasDefault = rate.isDefault
        rates.removeAll { $0.id == rate.id }
        
        // If we deleted the default rate, make the first remaining rate default
        if wasDefault && !rates.isEmpty {
            rates[0].isDefault = true
        }
        
        validateRates()
    }
    
    private func saveTeamMember() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespaces)
        
        // Ensure rates are valid before saving
        validateRates()
        
        if isEditing, let existingTeamMember = editingTeamMember {
            // Update existing team member
            var updatedTeamMember = existingTeamMember
            updatedTeamMember.name = trimmedName
            updatedTeamMember.email = trimmedEmail
            updatedTeamMember.jobTitle = trimmedJobTitle
            updatedTeamMember.rates = rates
            updatedTeamMember.isArchived = isArchived
            updatedTeamMember.role = role
            
            viewModel.updateTeamMember(updatedTeamMember)
            Logger.teamMember.notice(
                "Updated team member from editor [teamMember=\(trimmedName, privacy: .private(mask: .hash)) rates=\(rates.count, privacy: .public)]"
            )
        } else {
            // Create new team member
            let newTeamMember = TeamMember(
                name: trimmedName,
                email: trimmedEmail,
                jobTitle: trimmedJobTitle,
                rates: rates,
                isArchived: false,
                organizationID: "RHEIR-LLC-MAIN-ORG", // TODO: Get from viewModel
                role: role,
                isActive: true
            )
            viewModel.addTeamMember(newTeamMember)
            Logger.teamMember.notice(
                "Added team member from editor [teamMember=\(trimmedName, privacy: .private(mask: .hash)) rates=\(rates.count, privacy: .public)]"
            )
        }
        
        dismiss()
    }
}

// MARK: - Permission Row Helper
struct PermissionRow: View {
    let title: String
    let granted: Bool
    
    init(_ title: String, granted: Bool) {
        self.title = title
        self.granted = granted
    }
    
    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(granted ? .green : .gray)
                .font(.system(size: 16))
            
            Text(title)
                .foregroundColor(granted ? .primary : .secondary)
            
            Spacer()
        }
    }
}

// MARK: - Enhanced Add Rate View
struct AddRateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let existingTaskTypes: [String]
    let onAdd: (String, Double, Bool) -> Void
    
    @State private var selectedTaskType = ""
    @State private var customTaskType = ""
    @State private var rateText = ""
    @State private var useCustomType = false
    @State private var setAsDefault = false
    
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
                
                Section(header: Text("Rate Details")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $rateText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("per hour")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Set as Default Rate", isOn: $setAsDefault)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                if !taskTypeToUse.isEmpty && !rateText.isEmpty,
                   let rate = Double(rateText), rate > 0 {
                    Section(header: Text("Preview")) {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(taskTypeToUse)
                                        .font(.headline)
                                    if setAsDefault {
                                        Text("DEFAULT")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green)
                                            .cornerRadius(4)
                                    }
                                }
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
                            onAdd(taskTypeToUse, rate, setAsDefault)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Enhanced Edit Rate View
struct EditRateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let rate: EmployeeRate
    let existingTaskTypes: [String]
    let onSave: (EmployeeRate) -> Void
    
    @State private var taskType = ""
    @State private var rateText = ""
    @State private var isDefault = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rate Type")) {
                    TextField("Rate Type", text: $taskType)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: Text("Rate Details")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $rateText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("per hour")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Default Rate", isOn: $isDefault)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                if !taskType.isEmpty && !rateText.isEmpty,
                   let rateValue = Double(rateText), rateValue > 0 {
                    Section(header: Text("Preview")) {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(taskType)
                                        .font(.headline)
                                    if isDefault {
                                        Text("DEFAULT")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green)
                                            .cornerRadius(4)
                                    }
                                }
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
            }
            .navigationTitle("Edit Rate Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let rateValue = Double(rateText) {
                            let updatedRate = EmployeeRate(
                                id: rate.id,
                                taskType: taskType.trimmingCharacters(in: .whitespaces),
                                rate: rateValue,
                                isDefault: isDefault
                            )
                            onSave(updatedRate)
                            dismiss()
                        }
                    }
                    .disabled(taskType.isEmpty || rateText.isEmpty || Double(rateText) == nil)
                }
            }
            .onAppear {
                taskType = rate.taskType
                rateText = String(rate.rate)
                isDefault = rate.isDefault
            }
        }
    }
}

// MARK: - Backward Compatibility
typealias AddEmployeeView = AddTeamMemberView

#if DEBUG
struct AddTeamMemberView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // New team member
            AddTeamMemberView()
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
                .previewDisplayName("Add Team Member")
            
            // Edit team member
            AddTeamMemberView(editingTeamMember: TeamMember(
                name: "Kevin Barrett",
                email: "kevin@rheirhome.com",
                jobTitle: "Contractor",
                rates: [
                    EmployeeRate(taskType: "General Labor", rate: 45.0, isDefault: true),
                    EmployeeRate(taskType: "3D Modeling", rate: 75.0)
                ],
                organizationID: "RHEIR-LLC-MAIN-ORG",
                role: .admin
            ))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .previewDisplayName("Edit Team Member")
        }
    }
}
#endif
