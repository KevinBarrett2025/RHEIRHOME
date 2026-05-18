import SwiftUI
import OSLog

struct LogHoursView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedEmployee: TeamMember?
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var lunchStart: Date?
    @State private var lunchEnd: Date?
    @State private var selectedRate: EmployeeRate?
    @State private var editingRateWorker: TeamMember?
    @State private var category = "Labor"
    @State private var notes = ""
    @State private var hasLunchBreak = false
    private let preselectedTeamMember: TeamMember?

    init(isPresented: Binding<Bool>, preselectedTeamMember: TeamMember? = nil) {
        _isPresented = isPresented
        self.preselectedTeamMember = preselectedTeamMember
    }
    
    // CRITICAL FIX: Use project-based team member discovery like BudgetBreakdownView
    private var availableTeamMembers: [TeamMember] {
        // First try to get team members from organization
        let orgTeamMembers = projectVM.teamMembers
        
        // If we have organization team members, use them
        if !orgTeamMembers.isEmpty {
            return orgTeamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }
        }
        
        // FALLBACK: If no organization team members, create from project work activity
        guard let project = projectVM.selectedProject else { return [] }
        
        Logger.teamMember.notice(
            "Creating fallback team-member options from project work activity [project=\(project.id.uuidString, privacy: .private(mask: .hash))]"
        )
        
        // Get unique employee names from logged hours
        let uniqueEmployeeNames = Set(project.loggedHours.map { $0.employee })
        
        var virtualMembers: [TeamMember] = []
        for employeeName in uniqueEmployeeNames {
            let virtualMember = TeamMember(
                name: employeeName,
                jobTitle: "Worker",
                organizationID: project.organizationID
            )
            
            // Add rates based on their historical work
            let employeeHours = project.loggedHours.filter { $0.employee == employeeName }
            let uniqueRates = Set(employeeHours.map { $0.rate })
            
            var memberWithRates = virtualMember
            memberWithRates.rates = uniqueRates.map { rate in
                EmployeeRate(taskType: "Labor", rate: rate, isDefault: rate == uniqueRates.first)
            }
            
            virtualMembers.append(memberWithRates)
        }
        
        return virtualMembers
    }
    
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
                    // CRITICAL FIX: Use availableTeamMembers instead of projectVM.teamMembers
                    Picker("Select Team Member", selection: $selectedEmployee) {
                        Text("Select...").tag(TeamMember?.none)
                        ForEach(availableTeamMembers) { member in
                            Text(member.name).tag(TeamMember?.some(member))
                        }
                    }
                    .onChange(of: selectedEmployee) { oldValue, newValue in
                        // AUTO-FILL: Set default rate when team member is selected
                        if let member = newValue {
                            // Find default rate or use first available rate
                            if let defaultRate = member.rates.first(where: { $0.isDefault }) {
                                selectedRate = defaultRate
                                Logger.labor.info(
                                    "Auto-filled default labor rate [teamMember=\(member.name, privacy: .private(mask: .hash)) rate=\(defaultRate.rate, privacy: .public)]"
                                )
                            } else if let firstRate = member.rates.first {
                                selectedRate = firstRate
                                Logger.labor.info(
                                    "Auto-filled first available labor rate [teamMember=\(member.name, privacy: .private(mask: .hash)) rate=\(firstRate.rate, privacy: .public)]"
                                )
                            }
                        } else {
                            selectedRate = nil
                        }
                    }
                    
                    // DIAGNOSTIC: Show team member source info
                    if availableTeamMembers.count != projectVM.teamMembers.count {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Team Members: \(availableTeamMembers.count) available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if projectVM.teamMembers.isEmpty {
                                Text("Using project-based discovery (no organization members)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let employee = selectedEmployee {
                        HStack {
                            Text("Rate")
                            Spacer()
                            Menu {
                                ForEach(employee.rates) { rate in
                                    Button {
                                        selectedRate = rate
                                    } label: {
                                        HStack {
                                            Text("\(rate.taskType) - \(rate.rate.formatAsCurrency())/hr")
                                            if selectedRate?.id == rate.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .accessibilityIdentifier("log-hours-rate-option-\(rate.id.uuidString)")
                                }

                                Divider()

                                Button {
                                    editingRateWorker = employee
                                } label: {
                                    Label("Add New Rate...", systemImage: "plus.circle")
                                }
                                .accessibilityIdentifier("log-hours-add-rate-button")
                            } label: {
                                HStack(spacing: 6) {
                                    Text(rateMenuTitle)
                                        .foregroundStyle(selectedRate == nil ? .secondary : .primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("log-hours-rate-menu")
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
                
                // HELP SECTION: Show current project info and team member diagnostics
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
                        
                        // DIAGNOSTIC: Show team member discovery status
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Team member discovery:")
                                Spacer()
                                Text(availableTeamMembers.isEmpty ? "❌ None found" : "✅ \(availableTeamMembers.count) found")
                                    .foregroundColor(availableTeamMembers.isEmpty ? .red : .green)
                            }
                            
                            if availableTeamMembers.isEmpty {
                                Text("You can still log hours - a team member will be created automatically")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .font(.caption)
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
            .sheet(item: $editingRateWorker) { worker in
                EnhancedEditTeamMemberView(member: worker)
                    .environmentObject(projectVM)
            }
            .onChange(of: hasLunchBreak) { _, enabled in
                if enabled {
                    initializeLunchWindowIfNeeded()
                } else {
                    lunchStart = nil
                    lunchEnd = nil
                }
            }
            .onChange(of: startTime) { _, _ in
                normalizeLunchWindowIfNeeded()
            }
            .onChange(of: endTime) { _, _ in
                normalizeLunchWindowIfNeeded()
            }
            .onChange(of: projectVM.teamMembers) { _, members in
                refreshSelectedEmployee(from: members)
            }
            .onAppear {
                // Set default end time to 1 hour after start time
                endTime = startTime.addingTimeInterval(3600)
                
                if let preselectedTeamMember {
                    selectEmployee(
                        availableTeamMembers.first(where: { $0.id == preselectedTeamMember.id })
                            ?? preselectedTeamMember
                    )
                } else if availableTeamMembers.count == 1 {
                    // Auto-select first team member if only one available
                    selectEmployee(availableTeamMembers.first)
                }
                
                Logger.labor.info(
                    "LogHoursView appeared [availableTeamMembers=\(availableTeamMembers.count, privacy: .public)]"
                )
                for member in availableTeamMembers {
                    Logger.teamMember.debug(
                        "LogHoursView team member option [teamMember=\(member.name, privacy: .private(mask: .hash)) rates=\(member.rates.count, privacy: .public)]"
                    )
                }
            }
        }
    }
    
    private func saveHours() {
        guard let employee = selectedEmployee,
              let rate = selectedRate,
              let project = projectVM.selectedProject else { 
            Logger.labor.error("Cannot save hours because required data is missing in LogHoursView.")
            return 
        }
        
        Logger.labor.notice(
            "Saving hours from LogHoursView [teamMember=\(employee.name, privacy: .private(mask: .hash)) project=\(project.id.uuidString, privacy: .private(mask: .hash)) rate=\(rate.rate, privacy: .public)]"
        )
        
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
        
        Logger.labor.notice("Hours logged successfully from LogHoursView.")
        isPresented = false
    }

    private func selectEmployee(_ member: TeamMember?) {
        selectedEmployee = member

        if let member {
            selectedRate = member.defaultRate ?? member.rates.first
        } else {
            selectedRate = nil
        }
    }

    private var rateMenuTitle: String {
        guard let selectedRate else { return "Choose Rate" }
        return "\(selectedRate.taskType) - \(selectedRate.rate.formatAsCurrency())/hr"
    }

    private func refreshSelectedEmployee(from members: [TeamMember]) {
        guard let currentEmployee = selectedEmployee,
              let refreshedEmployee = members.first(where: { $0.id == currentEmployee.id }) else {
            return
        }

        selectedEmployee = refreshedEmployee

        if let selectedRate,
           let refreshedRate = refreshedEmployee.rates.first(where: { $0.id == selectedRate.id }) {
            self.selectedRate = refreshedRate
        } else {
            self.selectedRate = refreshedEmployee.defaultRate ?? refreshedEmployee.rates.first
        }
    }

    private func initializeLunchWindowIfNeeded() {
        guard hasLunchBreak else { return }
        guard lunchStart == nil || lunchEnd == nil else { return }
        guard endTime > startTime else { return }

        let shiftDuration = endTime.timeIntervalSince(startTime)
        let lunchDuration = min(3600, shiftDuration / 2)
        guard lunchDuration > 0 else { return }

        let leadIn = max(0, (shiftDuration - lunchDuration) / 2)
        lunchStart = startTime.addingTimeInterval(leadIn)
        lunchEnd = lunchStart?.addingTimeInterval(lunchDuration)
    }

    private func normalizeLunchWindowIfNeeded() {
        guard hasLunchBreak else { return }
        guard endTime > startTime else {
            lunchStart = nil
            lunchEnd = nil
            return
        }

        guard let lunchStart,
              let lunchEnd,
              lunchEnd > lunchStart,
              lunchStart >= startTime,
              lunchEnd <= endTime else {
            self.lunchStart = nil
            self.lunchEnd = nil
            initializeLunchWindowIfNeeded()
            return
        }
    }
}

struct LogHoursView_Previews: PreviewProvider {
    static var previews: some View {
        LogHoursView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
