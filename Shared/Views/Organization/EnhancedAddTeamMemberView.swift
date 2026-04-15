import SwiftUI
import OSLog

struct EnhancedAddTeamMemberView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var jobTitle = ""
    @State private var employmentType: EmploymentType = .employee
    @State private var hireDate = Date()
    @State private var hasAppAccess = false
    @State private var notes = ""
    
    // MARK: - Employee Rates State
    @State private var rates: [EmployeeRate] = [EmployeeRate(taskType: "General Labor", rate: 25.0, isDefault: true)]
    @State private var showingAddRate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Full Name", text: $name)
                    TextField("Job Title", text: $jobTitle)
                    DatePicker("Hire Date", selection: $hireDate, displayedComponents: .date)
                }
                
                Section("Contact Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Employment Details") {
                    Picker("Employment Type", selection: $employmentType) {
                        ForEach(EmploymentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Toggle("Has iPhone/App Access", isOn: $hasAppAccess)
                }
                
                // MARK: - Employee Rates Section
                Section {
                    ForEach(rates) { rate in
                        EmployeeRateRowView(rate: rate, rates: $rates)
                    }
                    .onDelete(perform: deleteRate)
                    
                    Button {
                        showingAddRate = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add New Rate")
                        }
                    }
                } header: {
                    Text("Pay Rates")
                } footer: {
                    if rates.isEmpty {
                        Text("Add at least one pay rate for this team member.")
                    } else {
                        Text("Default rate is used for time entry. Tap a rate to set as default.")
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTeamMember()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             rates.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddRate) {
                AddEmployeeRateView(rates: $rates)
            }
        }
    }
    
    private func addTeamMember() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty, !trimmedJobTitle.isEmpty, !rates.isEmpty else { return }
        
        // Ensure exactly one default rate
        let updatedRates = ensureOneDefaultRate(rates)
        
        let newMember = TeamMember(
            id: .init(),
            name: trimmedName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            jobTitle: trimmedJobTitle,
            rates: updatedRates,
            isArchived: false,
            organizationID: projectVM.currentOrganizationID ?? "current-org-id",
            role: .member,
            isActive: true,
            hireDate: hireDate,
            terminationDate: nil,
            terminationReason: nil,
            terminationType: nil,
            employmentStatus: .betweenProjects, // Start as between projects until assigned
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            employmentType: employmentType,
            hasAppAccess: hasAppAccess
        )
        
        // Actually save the team member through ProjectViewModel
        projectVM.addTeamMember(newMember)
        Logger.teamMember.notice(
            "Added team member from company settings [teamMember=\(newMember.id.uuidString, privacy: .private(mask: .hash)), rateCount=\(updatedRates.count, privacy: .public)]"
        )
        dismiss()
    }
    
    private func deleteRate(offsets: IndexSet) {
        rates.remove(atOffsets: offsets)
        
        // Ensure we still have at least one default rate
        if !rates.isEmpty && !rates.contains(where: { $0.isDefault }) {
            rates[0].isDefault = true
        }
    }
    
    private func ensureOneDefaultRate(_ rates: [EmployeeRate]) -> [EmployeeRate] {
        var updatedRates = rates
        let defaultRates = updatedRates.filter { $0.isDefault }
        
        if defaultRates.isEmpty && !updatedRates.isEmpty {
            // No default - make first one default
            updatedRates[0].isDefault = true
        } else if defaultRates.count > 1 {
            // Multiple defaults - keep only the first one
            for i in 0..<updatedRates.count {
                updatedRates[i].isDefault = (i == 0 && updatedRates[i].isDefault)
            }
        }
        
        return updatedRates
    }
}

struct EmployeeRateRowView: View {
    let rate: EmployeeRate
    @Binding var rates: [EmployeeRate]
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(rate.taskType)
                        .font(.body)
                    if rate.isDefault {
                        Text("(Default)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text("$\(rate.rate, specifier: "%.2f") per hour")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                setAsDefault()
            } label: {
                Image(systemName: rate.isDefault ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(rate.isDefault ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditEmployeeRateView(rate: rate, rates: $rates)
        }
    }
    
    private func setAsDefault() {
        for i in 0..<rates.count {
            rates[i].isDefault = (rates[i].id == rate.id)
        }
    }
}

struct AddEmployeeRateView: View {
    @Binding var rates: [EmployeeRate]
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskType = ""
    @State private var rate = 25.0
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rate Details") {
                    TextField("Task Type", text: $taskType)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("Rate")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $rate, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("per hour")
                    }
                    
                    if rates.isEmpty {
                        // First rate must be default
                        Toggle("Set as Default Rate", isOn: .constant(true))
                            .disabled(true)
                    } else {
                        Toggle("Set as Default Rate", isOn: $isDefault)
                    }
                }
            }
            .navigationTitle("Add Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addRate()
                    }
                    .disabled(taskType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rate <= 0)
                }
            }
        }
    }
    
    private func addRate() {
        let trimmedTaskType = taskType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTaskType.isEmpty, rate > 0 else { return }
        
        // If this is the first rate or is being set as default, make it default
        let willBeDefault = isDefault || rates.isEmpty
        
        // If setting as default, clear other defaults
        if willBeDefault {
            for i in 0..<rates.count {
                rates[i].isDefault = false
            }
        }
        
        let newRate = EmployeeRate(
            taskType: trimmedTaskType,
            rate: rate,
            isDefault: willBeDefault
        )
        
        rates.append(newRate)
        dismiss()
    }
}

struct EditEmployeeRateView: View {
    let rate: EmployeeRate
    @Binding var rates: [EmployeeRate]
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskType = ""
    @State private var rateAmount = 0.0
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rate Details") {
                    TextField("Task Type", text: $taskType)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("Rate")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $rateAmount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("per hour")
                    }
                    
                    if rates.count > 1 {
                        Toggle("Set as Default Rate", isOn: $isDefault)
                    } else {
                        Toggle("Default Rate", isOn: .constant(true))
                            .disabled(true)
                    }
                }
            }
            .navigationTitle("Edit Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRate()
                    }
                    .disabled(taskType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rateAmount <= 0)
                }
            }
            .onAppear {
                taskType = rate.taskType
                rateAmount = rate.rate
                isDefault = rate.isDefault
            }
        }
    }
    
    private func saveRate() {
        let trimmedTaskType = taskType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTaskType.isEmpty, rateAmount > 0 else { return }
        
        guard let index = rates.firstIndex(where: { $0.id == rate.id }) else { return }
        
        // If setting as default, clear other defaults
        if isDefault && !rate.isDefault {
            for i in 0..<rates.count {
                rates[i].isDefault = false
            }
        }
        
        // Update the rate
        rates[index] = EmployeeRate(
            id: rate.id,
            taskType: trimmedTaskType,
            rate: rateAmount,
            isDefault: isDefault
        )
        
        dismiss()
    }
}

struct EnhancedEditTeamMemberView: View {
    let member: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var jobTitle: String
    @State private var employmentType: EmploymentType
    @State private var hasAppAccess: Bool
    @State private var notes: String
    
    // MARK: - Employee Rates State
    @State private var rates: [EmployeeRate]
    @State private var showingAddRate = false
    
    init(member: TeamMember) {
        self.member = member
        self._name = State(initialValue: member.name)
        self._email = State(initialValue: member.email)
        self._phone = State(initialValue: member.phone)
        self._jobTitle = State(initialValue: member.jobTitle)
        self._employmentType = State(initialValue: member.employmentType)
        self._hasAppAccess = State(initialValue: member.hasAppAccess)
        self._notes = State(initialValue: member.notes)
        
        // Initialize rates - ensure at least one rate exists
        let memberRates = member.rates.isEmpty ? 
            [EmployeeRate(taskType: "General Labor", rate: 25.0, isDefault: true)] : 
            member.rates
        self._rates = State(initialValue: memberRates)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Full Name", text: $name)
                    TextField("Job Title", text: $jobTitle)
                }
                
                Section("Contact Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Employment Details") {
                    Picker("Employment Type", selection: $employmentType) {
                        ForEach(EmploymentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Toggle("Has iPhone/App Access", isOn: $hasAppAccess)
                }
                
                // MARK: - Employee Rates Section
                Section {
                    ForEach(rates) { rate in
                        EmployeeRateRowView(rate: rate, rates: $rates)
                    }
                    .onDelete(perform: deleteRate)
                    
                    Button {
                        showingAddRate = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add New Rate")
                        }
                    }
                } header: {
                    Text("Pay Rates")
                } footer: {
                    if rates.isEmpty {
                        Text("Add at least one pay rate for this team member.")
                    } else {
                        Text("Default rate is used for time entry. Tap a rate to set as default.")
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Edit \(member.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTeamMember()
                    }
                    .disabled(rates.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddRate) {
                AddEmployeeRateView(rates: $rates)
            }
        }
    }
    
    private func saveTeamMember() {
        // Ensure exactly one default rate
        let updatedRates = ensureOneDefaultRate(rates)
        
        var updatedMember = member
        updatedMember.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.jobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.employmentType = employmentType
        updatedMember.hasAppAccess = hasAppAccess
        updatedMember.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.rates = updatedRates
        
        // Actually update the team member through ProjectViewModel
        projectVM.updateTeamMember(updatedMember)
        Logger.teamMember.notice(
            "Updated team member from company settings [teamMember=\(updatedMember.id.uuidString, privacy: .private(mask: .hash)), rateCount=\(updatedRates.count, privacy: .public)]"
        )
        dismiss()
    }
    
    private func deleteRate(offsets: IndexSet) {
        rates.remove(atOffsets: offsets)
        
        // Ensure we still have at least one default rate if any rates remain
        if !rates.isEmpty && !rates.contains(where: { $0.isDefault }) {
            rates[0].isDefault = true
        }
    }
    
    private func ensureOneDefaultRate(_ rates: [EmployeeRate]) -> [EmployeeRate] {
        var updatedRates = rates
        let defaultRates = updatedRates.filter { $0.isDefault }
        
        if defaultRates.isEmpty && !updatedRates.isEmpty {
            // No default - make first one default
            updatedRates[0].isDefault = true
        } else if defaultRates.count > 1 {
            // Multiple defaults - keep only the first one
            for i in 0..<updatedRates.count {
                updatedRates[i].isDefault = (i == 0 && updatedRates[i].isDefault)
            }
        }
        
        return updatedRates
    }
}

#Preview {
    EnhancedAddTeamMemberView()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
