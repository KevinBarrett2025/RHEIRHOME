import SwiftUI

struct LogHoursView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedEmployee: TeamMember?
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var lunchStart: Date?
    @State private var lunchEnd: Date?
    @State private var selectedRate: EmployeeRate?
    @State private var category = "Labor"
    @State private var notes = ""
    @State private var hasLunchBreak = false
    
    private var isValidForm: Bool {
        selectedEmployee != nil && selectedRate != nil && endTime > startTime
    }
    
    private var calculatedHours: Double {
        let totalTime = endTime.timeIntervalSince(startTime) / 3600
        let lunchTime: Double = {
            if hasLunchBreak, let start = lunchStart, let end = lunchEnd, end > start {
                return end.timeIntervalSince(start) / 3600
            }
            return 0
        }()
        return max(0, totalTime - lunchTime)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Team Member") {
                    Picker("Select Team Member", selection: $selectedEmployee) {
                        Text("Select...").tag(TeamMember?.none)
                        ForEach(projectVM.teamMembers) { member in
                            Text(member.name).tag(TeamMember?.some(member))
                        }
                    }
                    .onChange(of: selectedEmployee) { oldValue, newValue in
                        // AUTO-FILL: Set default rate when team member is selected
                        if let member = newValue {
                            // Find default rate or use first available rate
                            if let defaultRate = member.rates.first(where: { $0.isDefault }) {
                                selectedRate = defaultRate
                                print("✅ Auto-filled default rate: $\(defaultRate.rate)/hr for \(member.name)")
                            } else if let firstRate = member.rates.first {
                                selectedRate = firstRate
                                print("✅ Auto-filled first available rate: $\(firstRate.rate)/hr for \(member.name)")
                            }
                        } else {
                            selectedRate = nil
                        }
                    }
                    
                    if let employee = selectedEmployee {
                        Picker("Rate", selection: $selectedRate) {
                            Text("Select Rate...").tag(EmployeeRate?.none)
                            ForEach(employee.rates) { rate in
                                HStack {
                                    Text("\(rate.taskType)")
                                    Spacer()
                                    Text("\(rate.rate.formatAsCurrency())/hr")
                                    if rate.isDefault {
                                        Text("(Default)")
                                            .foregroundColor(.green)
                                    }
                                }
                                .tag(EmployeeRate?.some(rate))
                            }
                        }
                        
                        // Show team member info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Job Title: \(employee.jobTitle)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Employment Type: \(employee.employmentType.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime)
                    DatePicker("End Time", selection: $endTime)
                    
                    Toggle("Lunch Break", isOn: $hasLunchBreak)
                    
                    if hasLunchBreak {
                        DatePicker("Lunch Start", selection: Binding(
                            get: { lunchStart ?? startTime },
                            set: { lunchStart = $0 }
                        ))
                        DatePicker("Lunch End", selection: Binding(
                            get: { lunchEnd ?? startTime },
                            set: { lunchEnd = $0 }
                        ))
                    }
                }
                
                Section("Details") {
                    TextField("Category", text: $category)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                if isValidForm {
                    Section("Summary") {
                        HStack {
                            Text("Total Hours")
                            Spacer()
                            Text("\(calculatedHours, specifier: "%.2f") hrs")
                                .fontWeight(.semibold)
                        }
                        
                        if let rate = selectedRate {
                            HStack {
                                Text("Rate")
                                Spacer()
                                Text("\(rate.rate.formatAsCurrency())/hr")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("Total Pay")
                                Spacer()
                                Text((calculatedHours * rate.rate).formatAsCurrency())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // HELP SECTION: Show current project info
                if let currentProject = projectVM.selectedProject {
                    Section("Project Info") {
                        HStack {
                            Text("Logging hours for:")
                            Spacer()
                            Text(currentProject.name)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Current total hours:")
                            Spacer()
                            Text("\(currentProject.loggedHours.count) entries")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No project selected. Please select a project first.")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Log Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHours()
                    }
                    .disabled(!isValidForm || projectVM.selectedProject == nil)
                }
            }
            .onAppear {
                // Set default end time to 1 hour after start time
                endTime = startTime.addingTimeInterval(3600)
                
                // Auto-select first team member if only one available
                if projectVM.teamMembers.count == 1 {
                    selectedEmployee = projectVM.teamMembers.first
                }
                
                print("📱 LogHoursView appeared - Available team members: \(projectVM.teamMembers.count)")
                for member in projectVM.teamMembers {
                    print("  👤 \(member.name) - \(member.rates.count) rates")
                }
            }
        }
    }
    
    private func saveHours() {
        guard let employee = selectedEmployee,
              let rate = selectedRate,
              let project = projectVM.selectedProject else { 
            print("❌ Cannot save hours - missing required data")
            return 
        }
        
        print("💾 Saving hours for \(employee.name) on project \(project.name)")
        
        // Calculate lunch break duration if present
        let lunchDuration: Double? = {
            if hasLunchBreak, let start = lunchStart, let end = lunchEnd, end > start {
                return end.timeIntervalSince(start) / 3600
            }
            return nil
        }()
        
        // Use the proper ProjectViewModel method with team member ID
        projectVM.logHours(
            startTime: startTime,
            endTime: endTime,
            employee: employee.name,
            rate: rate.rate,
            category: category,
            lunchBreakDuration: lunchDuration,
            employeeID: employee.id // CRITICAL: Pass the team member ID
        )
        
        print("✅ Hours logged successfully")
        isPresented = false
    }
}

struct LogHoursView_Previews: PreviewProvider {
    static var previews: some View {
        LogHoursView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}