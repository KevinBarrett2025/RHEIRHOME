import SwiftUI

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
                             jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addTeamMember() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty, !trimmedJobTitle.isEmpty else { return }
        
        let newMember = TeamMember(
            id: .init(),
            name: trimmedName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            jobTitle: trimmedJobTitle,
            rates: [EmployeeRate(taskType: "General Labor", rate: 25.0, isDefault: true)], // Add default rate
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
        print("👥 Successfully added new team member: \(trimmedName)")
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
    
    init(member: TeamMember) {
        self.member = member
        self._name = State(initialValue: member.name)
        self._email = State(initialValue: member.email)
        self._phone = State(initialValue: member.phone)
        self._jobTitle = State(initialValue: member.jobTitle)
        self._employmentType = State(initialValue: member.employmentType)
        self._hasAppAccess = State(initialValue: member.hasAppAccess)
        self._notes = State(initialValue: member.notes)
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
                }
            }
        }
    }
    
    private func saveTeamMember() {
        var updatedMember = member
        updatedMember.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.jobTitle = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMember.employmentType = employmentType
        updatedMember.hasAppAccess = hasAppAccess
        updatedMember.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Actually update the team member through ProjectViewModel
        projectVM.updateTeamMember(updatedMember)
        print("💾 Successfully updated team member: \(updatedMember.name)")
        dismiss()
    }
}

#Preview {
    EnhancedAddTeamMemberView()
        .environmentObject(ProjectViewModel())
}