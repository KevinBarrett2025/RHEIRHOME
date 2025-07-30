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
    @State private var contingency: String
    @State private var startDate: Date
    @State private var endDate: Date
    
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
        self._totalBudget = State(initialValue: String(format: "%.2f", project.totalBudget))
        self._materialCost = State(initialValue: String(format: "%.2f", project.materialCost))
        self._laborCost = State(initialValue: String(format: "%.2f", project.laborCost))
        self._generalConditions = State(initialValue: String(format: "%.2f", project.generalConditions))
        self._contingency = State(initialValue: String(format: "%.2f", project.contingency))
        self._startDate = State(initialValue: project.startDate)
        self._endDate = State(initialValue: project.endDate)
    }
    
    private var isValidForm: Bool {
        !name.isEmpty && !client.isEmpty && !totalBudget.isEmpty
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
                
                Section("Budget") {
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
                        TextField("0", text: $materialCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Labor")
                        Spacer()
                        TextField("0", text: $laborCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Contingency")
                        Spacer()
                        TextField("0", text: $contingency)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProject()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
    }
    
    private func saveProject() {
        var updatedProject = project
        updatedProject.name = name
        updatedProject.client = client
        updatedProject.phone = phone
        updatedProject.email = email
        updatedProject.street = street
        updatedProject.city = city
        updatedProject.state = state
        updatedProject.zip = zip
        updatedProject.notes = notes
        updatedProject.totalBudget = Double(totalBudget) ?? project.totalBudget
        updatedProject.materialCost = Double(materialCost) ?? project.materialCost
        updatedProject.laborCost = Double(laborCost) ?? project.laborCost
        updatedProject.generalConditions = Double(generalConditions) ?? project.generalConditions
        updatedProject.contingency = Double(contingency) ?? project.contingency
        updatedProject.startDate = startDate
        updatedProject.endDate = endDate
        
        projectVM.save(updatedProject)
        dismiss()
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