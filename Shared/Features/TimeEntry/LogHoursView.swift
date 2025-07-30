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
                    
                    if let employee = selectedEmployee {
                        Picker("Rate", selection: $selectedRate) {
                            ForEach(employee.rates) { rate in
                                Text("\(rate.taskType) - \(rate.rate.formatAsCurrency())/hr").tag(EmployeeRate?.some(rate))
                            }
                        }
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
                                Text("Total Pay")
                                Spacer()
                                Text((calculatedHours * rate.rate).formatAsCurrency())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
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
                    .disabled(!isValidForm)
                }
            }
        }
    }
    
    private func saveHours() {
        guard let employee = selectedEmployee,
              let rate = selectedRate else { return }
        
        // Calculate lunch break duration if present
        let lunchDuration: Double? = {
            if hasLunchBreak, let start = lunchStart, let end = lunchEnd, end > start {
                return end.timeIntervalSince(start) / 3600
            }
            return nil
        }()
        
        // Use the proper ProjectViewModel method
        projectVM.logHours(
            startTime: startTime,
            endTime: endTime,
            employee: employee.name,
            rate: rate.rate,
            category: category,
            lunchBreakDuration: lunchDuration
        )
        
        isPresented = false
    }
}

struct LogHoursView_Previews: PreviewProvider {
    static var previews: some View {
        LogHoursView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel())
    }
}