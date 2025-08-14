import SwiftUI

struct AddEmployeeView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var email = ""
    @State private var jobTitle = ""
    @State private var hourlyRate = ""
    @State private var taskType = "General Labor"
    
    private var isValidForm: Bool {
        !name.isEmpty && !jobTitle.isEmpty && !hourlyRate.isEmpty && (Double(hourlyRate) ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Team Member Details") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Job Title", text: $jobTitle)
                }
                
                Section("Default Rate") {
                    TextField("Task Type", text: $taskType)
                    
                    HStack {
                        Text("Hourly Rate")
                        Spacer()
                        TextField("0.00", text: $hourlyRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Text("You can add more rates for different types of work after creating the team member.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTeamMember()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
    }
    
    private func saveTeamMember() {
        let rate = EmployeeRate(
            taskType: taskType,
            rate: Double(hourlyRate) ?? 0,
            isDefault: true
        )
        
        let teamMember = TeamMember(
            name: name,
            email: email,
            jobTitle: jobTitle,
            rates: [rate],
            organizationID: "RHEIR-LLC-MAIN-ORG" // Default organization
        )
        
        projectVM.addTeamMemberToOrganization(teamMember)
        
        isPresented = false
    }
}

struct AddEmployeeView_Previews: PreviewProvider {
    static var previews: some View {
        AddEmployeeView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}