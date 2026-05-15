import SwiftUI
import OSLog

struct LaborModuleView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showingLogHours = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingWorkerManagement = false
    
    // CRITICAL FIX: Use project-based team member discovery like BudgetBreakdownView
    private var workingTeamMembers: [TeamMember] {
        guard let project = projectVM.selectedProject else { return [] }
        
        // Find team members explicitly assigned to the project
        let assignedMemberIDs = Set(project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) })
        
        // Find team members who have worked on this project
        let receiptMemberIDs = project.receipts.compactMap { $0.teamMemberID }
        let progressMemberIDs = project.progressReports.flatMap { $0.employeeIDs }
        
        // CRITICAL FIX: Also check logged hours (work hours) for team member activity
        let loggedHoursMemberIDs = project.loggedHours.compactMap { workHour in
            workHour.employeeID
        }
        
        // Also check by name matching for legacy hours without employeeID
        let _ = project.loggedHours.compactMap { workHour in
            workHour.employeeID == nil ? workHour.employee : nil
        }
        
        // Combine all sets
        let workingMemberIDs = Set(receiptMemberIDs + progressMemberIDs + loggedHoursMemberIDs)
        let allRelevantMemberIDs = assignedMemberIDs.union(workingMemberIDs)
        
        // Get team members from the reusable business resource directory first.
        var discoveredMembers = projectVM.teamMembers.filter { member in
            allRelevantMemberIDs.contains(member.id) || 
            assignedMemberIDs.contains(member.id) ||
            hasWorkedOnProject(member, project) ||
            member.employmentStatus.canBeAssignedToProjects
        }
        
        // FALLBACK: If no organization team members found, create virtual members from work hours
        if discoveredMembers.isEmpty && !project.loggedHours.isEmpty {
            Logger.labor.notice("Creating fallback team-member models from logged hours for labor module.")
            let uniqueEmployeeNames = Set(project.loggedHours.map { $0.employee })
            
            for employeeName in uniqueEmployeeNames {
                let virtualMember = TeamMember(
                    name: employeeName,
                    jobTitle: "Worker",
                    organizationID: project.organizationID
                )
                // Add a rate based on their work hours
                let averageRate = project.loggedHours
                    .filter { $0.employee == employeeName }
                    .reduce(0.0) { $0 + $1.rate } / 
                    Double(project.loggedHours.filter { $0.employee == employeeName }.count)
                
                var memberWithRate = virtualMember
                memberWithRate.rates = [EmployeeRate(taskType: "Labor", rate: averageRate)]
                discoveredMembers.append(memberWithRate)
            }
        }
        
        return discoveredMembers.filter { member in
            // Only show active members or those who have actually worked
            member.employmentStatus.canBeAssignedToProjects ||
            assignedMemberIDs.contains(member.id) ||
            hasWorkedOnProject(member, project)
        }
        .sorted { lhs, rhs in
            if hasWorkedOnProject(lhs, project) != hasWorkedOnProject(rhs, project) {
                return hasWorkedOnProject(lhs, project)
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private func hasWorkedOnProject(_ member: TeamMember, _ project: Project) -> Bool {
        // Check if member has receipts, progress reports, or hours logged on this project
        let hasReceipts = project.receipts.contains { receipt in
            receipt.teamMemberID == member.id
        }
        let hasProgress = project.progressReports.contains { log in
            log.employeeIDs.contains(member.id)
        }
        // CRITICAL FIX: Also check logged hours (work hours)
        let hasLoggedHours = project.loggedHours.contains { hour in
            hour.employeeID == member.id || hour.employee.lowercased() == member.name.lowercased()
        }
        
        return hasReceipts || hasProgress || hasLoggedHours
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Universal Header
                UniversalHeaderView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if let project = projectVM.selectedProject {
                            laborSummarySection(project)

                            // CRITICAL FIX: Use workingTeamMembers instead of projectVM.teamMembers
                            teamMembersList
                        } else {
                            noProjectSelectedView
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Log Hours") {
                            showingLogHours = true
                        }
                        Button("Manage Workers") {
                            showingWorkerManagement = true
                        }
                        Button("Live Tracking") {
                            // Show live tracking
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogHours) {
                LogHoursView(isPresented: $showingLogHours)
                    .environmentObject(projectVM)
            }
            .sheet(item: $selectedTeamMember) { member in
                LaborPaymentView(teamMember: member)
                    .environmentObject(projectVM)
            }
            .sheet(isPresented: $showingWorkerManagement) {
                NavigationStack {
                    BusinessWorkersResourceView()
                        .environmentObject(projectVM)
                }
            }
        }
    }
    
    @ViewBuilder
    private func laborSummarySection(_ project: Project) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Labor Summary")
                    .font(.headline)
                Spacer()
                Button("Log Hours") {
                    showingLogHours = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("labor-log-hours-button")

                Button("Workers") {
                    showingWorkerManagement = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("labor-manage-workers-button")
            }
            
            HStack {
                summaryCard("Total Hours", String(format: "%.1f", projectVM.projectTotalHours), .blue)
                summaryCard("Total Cost", projectVM.projectTotalLaborCost.formatAsCurrency(), .green)
                summaryCard("Unpaid", projectVM.projectUnpaidAmount.formatAsCurrency(), .orange)
            }
        }
    }
    
    @ViewBuilder
    private func summaryCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var teamMembersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Team Members")
                    .font(.headline)
                
                if !workingTeamMembers.isEmpty {
                    Text("\(workingTeamMembers.count) workers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // CRITICAL FIX: Use workingTeamMembers instead of projectVM.teamMembers
            if workingTeamMembers.isEmpty {
                emptyTeamMembersView
            } else {
                ForEach(workingTeamMembers) { member in
                    TeamMemberLaborRowView(member: member) {
                        selectedTeamMember = member
                    }
                }
            }
        }
        .accessibilityIdentifier("labor-team-members-section")
    }
    
    @ViewBuilder
    private var emptyTeamMembersView: some View {
        WorkflowEmptyStateCard(
            icon: "person.2.circle",
            title: "No Labor Logged Yet",
            message: "Add a worker or choose an existing business resource before logging project labor.",
            primaryActionTitle: "Manage Workers",
            primaryAction: {
                showingWorkerManagement = true
            }
        )
    }
    
    @ViewBuilder 
    private var noProjectSelectedView: some View {
        ProjectSelectionRequiredView(
            title: "Select a Project",
            message: "Choose a project before viewing or logging labor hours.",
            actionTitle: "Go to Projects",
            action: {
                selectedTab = .projects
            }
        )
    }
}

struct TeamMemberLaborRowView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    let member: TeamMember
    let onTap: () -> Void
    
    private var memberHours: Double {
        projectVM.getTotalHours(for: member.name)
    }
    
    private var unpaidAmount: Double {
        projectVM.getUnpaidAmount(for: member.name)
    }
    
    private var paidAmount: Double {
        projectVM.getPaidAmount(for: member.name)
    }

    private var defaultRateLabel: String {
        guard let rate = member.defaultRate else { return "No default rate" }
        return "\(rate.rate.formatAsCurrency())/hr \(rate.taskType)"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("labor-member-name-\(member.id.uuidString)")
                    
                    HStack {
                        Text(String(format: "%.1f hrs", memberHours))
                            .font(.caption)
                            .foregroundColor(.blue)

                        Text("• \(defaultRateLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if unpaidAmount > 0 {
                            Text("• \(unpaidAmount.formatAsCurrency()) unpaid")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if unpaidAmount > 0 {
                        Text("Pay")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    } else if paidAmount > 0 {
                        Text("Paid")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("labor-member-row-\(member.id.uuidString)")
    }
}

// MARK: - Simplified Team Member Labor Detail View (until we add the full LaborPaymentView)
struct TeamMemberLaborDetailView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    let teamMember: TeamMember
    
    private var memberHours: [WorkHour] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.loggedHours.filter { hour in
            hour.employeeID == teamMember.id || hour.employee.lowercased() == teamMember.name.lowercased()
        }.sorted { $0.date > $1.date }
    }
    
    private var unpaidHours: [WorkHour] {
        memberHours.filter { !$0.isPaid }
    }
    
    private var totalUnpaidAmount: Double {
        unpaidHours.reduce(0) { $0 + ($1.hours * $1.rate) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(teamMember.name.prefix(1)).uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(teamMember.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(teamMember.jobTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(totalUnpaidAmount.formatAsCurrency())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("UNPAID")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Unpaid Hours List
                if unpaidHours.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("All Caught Up!")
                            .font(.headline)
                        
                        Text("No unpaid hours for this team member")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unpaid Hours (\(unpaidHours.count) entries)")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(unpaidHours, id: \.id) { hour in
                                    SimpleWorkHourRowView(hour: hour) {
                                        // Mark as paid
                                        projectVM.markHoursAsPaid(hour, method: "Cash", note: "Paid via labor management")
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Labor Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !unpaidHours.isEmpty {
                        Button("Pay All") {
                            payAllHours()
                        }
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private func payAllHours() {
        for hour in unpaidHours {
            projectVM.markHoursAsPaid(hour, method: "Cash", note: "Bulk payment - \(Date().formatted())")
        }
    }
}

struct SimpleWorkHourRowView: View {
    let hour: WorkHour
    let onPayTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(hour.startTime.formatted(date: .omitted, time: .shortened)) - \(hour.endTime?.formatted(date: .omitted, time: .shortened) ?? "Active")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(hour.category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f hrs", hour.hours))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text((hour.hours * hour.rate).formatAsCurrency())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Button("Pay") {
                    onPayTap()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        LaborModuleView(selectedTab: .constant(.labor))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}
