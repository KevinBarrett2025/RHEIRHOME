import SwiftUI

struct EnhancedTeamMemberDetailView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var member: TeamMember
    @State private var isEditing = false
    @State private var showingPaymentView = false
    @State private var selectedTab: DetailTab = .overview
    
    init(member: TeamMember) {
        self._member = State(initialValue: member)
    }
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case labor = "Labor"
        case rates = "Rates"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .overview: return "person.circle"
            case .labor: return "clock"
            case .rates: return "dollarsign.circle"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content
                tabContent
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaymentView) {
            LaborPaymentView(teamMember: member)
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(member.name.prefix(2)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        TextField("Name", text: $member.name)
                            .textFieldStyle(.roundedBorder)
                        TextField("Job Title", text: $member.jobTitle)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(member.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(member.jobTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(member.employmentType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Text(member.employmentStatus.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(member.employmentStatus == .active ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .foregroundColor(member.employmentStatus == .active ? .green : .orange)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            
            // Quick stats
            HStack {
                statBox("Total Hours", "\(getTotalHours(), specifier: "%.1f")", .blue)
                statBox("Unpaid", getUnpaidAmount().formatAsCurrency(), .orange)
                statBox("This Month", getMonthlyHours().formatAsCurrency(), .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private func statBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(DetailTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedTab == tab ? Color.blue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            switch selectedTab {
            case .overview:
                overviewTab
            case .labor:
                laborTab
            case .rates:
                ratesTab
            case .settings:
                settingsTab
            }
        }
    }
    
    @ViewBuilder
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Contact Information
            sectionHeader("Contact Information")
            
            VStack(spacing: 12) {
                infoRow("Email", member.email ?? "Not provided")
                infoRow("Phone", member.phone ?? "Not provided")
                infoRow("Address", member.address ?? "Not provided")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Employment Details
            sectionHeader("Employment Details")
            
            VStack(spacing: 12) {
                infoRow("Hire Date", member.hireDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                infoRow("Employment Type", member.employmentType.displayName)
                infoRow("Employment Status", member.employmentStatus.displayName)
                infoRow("Organization ID", member.organizationID)
                infoRow("App Access", member.hasAppAccess ? "Yes" : "No")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Recent Activity
            sectionHeader("Recent Activity")
            
            VStack(spacing: 8) {
                ForEach(getRecentWorkHours().prefix(5), id: \.id) { hour in
                    RecentWorkHourRowView(hour: hour)
                }
                
                if getRecentWorkHours().isEmpty {
                    Text("No recent activity")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var laborTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Labor Management")
                
                Spacer()
                
                if getUnpaidAmount() > 0 {
                    Button("Process Payment") {
                        showingPaymentView = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Labor stats
            VStack(spacing: 12) {
                laborStatRow("Total Hours Worked", "\(getTotalHours(), specifier: "%.1f") hrs")
                laborStatRow("Total Earnings", getTotalEarnings().formatAsCurrency())
                laborStatRow("Amount Paid", getPaidAmount().formatAsCurrency())
                laborStatRow("Amount Outstanding", getUnpaidAmount().formatAsCurrency())
                
                Divider()
                
                laborStatRow("Average Rate", getAverageRate().formatAsCurrency() + "/hr")
                laborStatRow("Hours This Month", "\(getMonthlyHours(), specifier: "%.1f") hrs")
                laborStatRow("Earnings This Month", getMonthlyEarnings().formatAsCurrency())
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Work history
            sectionHeader("Work History")
            
            VStack(spacing: 8) {
                ForEach(getAllWorkHours().prefix(10), id: \.id) { hour in
                    WorkHourDetailRowView(hour: hour)
                }
                
                if getAllWorkHours().isEmpty {
                    Text("No work hours logged")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var ratesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Pay Rates")
                
                Spacer()
                
                if isEditing {
                    Button("Add Rate") {
                        addNewRate()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if member.rates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No pay rates set")
                        .font(.headline)
                    
                    Text("Add pay rates for different types of work")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if isEditing {
                        Button("Add First Rate") {
                            addNewRate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(member.rates.indices, id: \.self) { index in
                        RateRowView(
                            rate: $member.rates[index],
                            isEditing: isEditing,
                            onDelete: {
                                member.rates.remove(at: index)
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Team Member Settings")
            
            VStack(spacing: 16) {
                if isEditing {
                    // Employment Type
                    VStack(alignment: .leading) {
                        Text("Employment Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Employment Type", selection: $member.employmentType) {
                            ForEach(EmploymentType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Employment Status
                    VStack(alignment: .leading) {
                        Text("Employment Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Employment Status", selection: $member.employmentStatus) {
                            ForEach(EmploymentStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // App Access
                    Toggle("App Access", isOn: $member.hasAppAccess)
                    
                    // Contact Information
                    VStack(alignment: .leading) {
                        Text("Contact Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Email", text: $member.email)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Phone", text: $member.phone)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Address", text: $member.address, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                } else {
                    // View-only settings
                    VStack(spacing: 12) {
                        settingRow("Employment Type", member.employmentType.displayName)
                        settingRow("Employment Status", member.employmentStatus.displayName)
                        settingRow("App Access", member.hasAppAccess ? "Enabled" : "Disabled")
                        settingRow("Member Since", member.hireDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                        settingRow("Organization", member.organizationID)
                        settingRow("Email", member.email.isEmpty ? "Not provided" : member.email)
                        settingRow("Phone", member.phone.isEmpty ? "Not provided" : member.phone)
                        settingRow("Address", member.address.isEmpty ? "Not provided" : member.address)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            // Danger Zone
            if isEditing {
                sectionHeader("Danger Zone")
                
                VStack(spacing: 12) {
                    Button("Remove from Organization") {
                        removeTeamMember()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private func laborStatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private func settingRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getTotalHours() -> Double {
        projectVM.getTotalHours(for: member.name)
    }
    
    private func getUnpaidAmount() -> Double {
        projectVM.getUnpaidAmount(for: member.name)
    }
    
    private func getPaidAmount() -> Double {
        projectVM.getPaidAmount(for: member.name)
    }
    
    private func getTotalEarnings() -> Double {
        return getUnpaidAmount() + getPaidAmount()
    }
    
    private func getAverageRate() -> Double {
        let totalEarnings = getTotalEarnings()
        let totalHours = getTotalHours()
        return totalHours > 0 ? totalEarnings / totalHours : 0
    }
    
    private func getMonthlyHours() -> Double {
        // Calculate hours for current month
        let calendar = Calendar.current
        let now = Date()
        
        return getAllWorkHours().filter { hour in
            calendar.isDate(hour.date, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.hours }
    }
    
    private func getMonthlyEarnings() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        return getAllWorkHours().filter { hour in
            calendar.isDate(hour.date, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    private func getAllWorkHours() -> [WorkHour] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.loggedHours.filter { hour in
            hour.employeeID == member.id || hour.employee.lowercased() == member.name.lowercased()
        }.sorted { $0.date > $1.date }
    }
    
    private func getRecentWorkHours() -> [WorkHour] {
        let allHours = getAllWorkHours()
        return Array(allHours.prefix(10))
    }
    
    private func addNewRate() {
        let newRate = EmployeeRate(
            taskType: "Labor",
            rate: 25.0,
            isDefault: member.rates.isEmpty
        )
        member.rates.append(newRate)
    }
    
    private func saveChanges() {
        projectVM.updateTeamMemberInOrganization(member)
        print("✅ Saved changes for team member: \(member.name)")
    }
    
    private func removeTeamMember() {
        projectVM.removeTeamMemberFromOrganization(member.id)
        dismiss()
    }
}

// MARK: - Supporting Views

struct RateRowView: View {
    @Binding var rate: EmployeeRate
    let isEditing: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            if isEditing {
                TextField("Task Type", text: $rate.taskType)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Rate", value: $rate.rate, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                
                Toggle("Default", isOn: $rate.isDefault)
                    .labelsHidden()
                
                Button("Delete") {
                    onDelete()
                }
                .foregroundColor(.red)
            } else {
                VStack(alignment: .leading) {
                    Text(rate.taskType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if rate.isDefault {
                        Text("Default Rate")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Text(rate.rate.formatAsCurrency() + "/hr")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RecentWorkHourRowView: View {
    let hour: WorkHour
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(hour.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(hour.hours, specifier: "%.1f") hrs")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text((hour.hours * hour.rate).formatAsCurrency())
                    .font(.caption)
                    .foregroundColor(hour.isPaid ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct WorkHourDetailRowView: View {
    let hour: WorkHour
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(hour.hours, specifier: "%.1f") hrs")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("\(hour.startTime.formatted(date: .omitted, time: .shortened)) - \(hour.endTime?.formatted(date: .omitted, time: .shortened) ?? "Active")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Text((hour.hours * hour.rate).formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(hour.isPaid ? .green : .orange)
                    
                    Image(systemName: hour.isPaid ? "checkmark.circle.fill" : "clock")
                        .font(.caption)
                        .foregroundColor(hour.isPaid ? .green : .orange)
                }
            }
            
            if hour.isPaid, let method = hour.paymentMethod {
                Text("Paid via \(method)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    EnhancedTeamMemberDetailView(member: TeamMember.example)
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}