import SwiftUI

// MARK: - Project Team Management View (Extracted from BudgetBreakdownView)
struct ProjectTeamManagementView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingAddTeamMember = false
    @State private var showingAssignMember = false
    @State private var showingFullDirectory = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingMemberDetail = false
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    // Team members currently working on this project (based on receipts, hours, progress)
    private var projectTeamMembers: [TeamMember] {
        guard let project = project else { return [] }
        
        // Find team members explicitly assigned to the project
        let assignedMemberIDs = Set(project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) })
        
        // Find team members who have worked on this project
        let receiptMemberIDs = project.receipts.compactMap { $0.teamMemberID }
        let progressMemberIDs = project.progressReports.flatMap { $0.employeeIDs }
        
        // CRITICAL FIX: Also check logged hours (work hours) for team member activity
        let loggedHoursMemberIDs = project.loggedHours.compactMap { workHour in
            workHour.employeeID
        }
        
        // Combine all sets
        let workingMemberIDs = Set(receiptMemberIDs + progressMemberIDs + loggedHoursMemberIDs)
        let allRelevantMemberIDs = assignedMemberIDs.union(workingMemberIDs)
        
        return projectVM.teamMembers.filter { member in
            // Include if explicitly assigned or has worked on the project (including logged hours)
            allRelevantMemberIDs.contains(member.id) || 
            // Or if they're active and belong to the organization
            (member.employmentStatus.canBeAssignedToProjects && member.organizationID == project.organizationID)
        }.filter { member in
            // Filter to only show active members or those who have actually worked
            member.employmentStatus == .active ||
            assignedMemberIDs.contains(member.id) ||
            hasWorkedOnProject(member, project)
        }
    }
    
    // Available team members who could be assigned to this project
    private var availableTeamMembers: [TeamMember] {
        let projectMemberIDs = Set(projectTeamMembers.map { $0.id })
        return projectVM.teamMembers.filter { member in
            !projectMemberIDs.contains(member.id) &&
            member.employmentStatus.canBeAssignedToProjects
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let project = project {
                projectTeamContent(for: project)
            } else {
                emptyProjectView
            }
        }
        .sheet(isPresented: $showingAddTeamMember) {
            EnhancedAddTeamMemberView()
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingAssignMember) {
            ProjectTeamAssignmentView(
                project: project!,
                availableMembers: availableTeamMembers
            )
            .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingFullDirectory) {
            if let currentOrg = authVM.currentOrg {
                NavigationView {
                    EnhancedOrganizationDirectoryView(organization: currentOrg)
                        .environmentObject(authVM)
                        .environmentObject(projectVM)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingFullDirectory = false
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingMemberDetail) {
            if let member = selectedTeamMember {
                ProjectTeamMemberDetailView(
                    member: member,
                    project: project!
                )
                .environmentObject(projectVM)
            }
        }
    }
    
    @ViewBuilder
    private func projectTeamContent(for project: Project) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Project Header
                projectHeaderSection(for: project)
                
                Divider()
                
                // Team Overview Stats
                teamOverviewSection
                
                Divider()
                
                // Current Project Team
                if projectTeamMembers.isEmpty {
                    emptyTeamSection
                } else {
                    activeTeamSection
                }
                
                Divider()
                
                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func projectHeaderSection(for project: Project) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("for \(project.name)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Project Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(project.status.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(project.status == .active ? .green : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Client")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(project.client)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var teamOverviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Team Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                TeamStatCard(
                    icon: "person.fill.checkmark",
                    title: "Active on Project",
                    value: "\(projectTeamMembers.count)",
                    subtitle: "Currently assigned",
                    color: .green
                )
                
                TeamStatCard(
                    icon: "person.badge.plus",
                    title: "Available to Assign",
                    value: "\(availableTeamMembers.count)",
                    subtitle: "Ready for work",
                    color: .blue
                )
                
                TeamStatCard(
                    icon: "dollarsign.circle",
                    title: "Total Labor Cost",
                    value: projectVM.calculateTotalLaborCost().formatAsCurrency(),
                    subtitle: "Estimated project cost",
                    color: .orange
                )
                
                TeamStatCard(
                    icon: "clock.fill",
                    title: "Hours Logged",
                    value: "\(projectVM.calculateTotalHours())",
                    subtitle: "Total project hours",
                    color: .purple
                )
            }
        }
    }
    
    @ViewBuilder
    private var activeTeamSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Project Team Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Assign More") {
                    showingAssignMember = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .disabled(availableTeamMembers.isEmpty)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(projectTeamMembers) { member in
                    ProjectTeamMemberCard(member: member, project: project!) {
                        selectedTeamMember = member
                        showingMemberDetail = true
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyTeamSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Team Members Assigned")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Assign team members to this project to track their work, hours, and contributions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Assign Team Members") {
                if availableTeamMembers.isEmpty {
                    showingAddTeamMember = true
                } else {
                    showingAssignMember = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(projectVM.teamMembers.isEmpty)
        }
        .padding(.vertical, 32)
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                QuickActionCard(
                    icon: "person.badge.plus.fill",
                    title: "Add New Team Member",
                    description: "Create a new team member and add them to your organization",
                    color: .green
                ) {
                    showingAddTeamMember = true
                }
                
                if !availableTeamMembers.isEmpty {
                    QuickActionCard(
                        icon: "person.2.circle.fill",
                        title: "Assign Existing Member",
                        description: "Assign an existing team member to this project",
                        color: .blue
                    ) {
                        showingAssignMember = true
                    }
                }
                
                QuickActionCard(
                    icon: "building.2.fill",
                    title: "Manage All Team Members",
                    description: "View and manage all organization team members",
                    color: .purple
                ) {
                    showingFullDirectory = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view and manage team member assignments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
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
            hour.employeeID == member.id
        }
        
        return hasReceipts || hasProgress || hasLoggedHours
    }
    
    // New helper methods
    private func getReceiptCountForMember(_ member: TeamMember, in project: Project) -> Int {
        return project.receipts.filter { receipt in
            receipt.teamMemberID == member.id
        }.count
    }
    
    private func getProgressCountForMember(_ member: TeamMember, in project: Project) -> Int {
        return project.progressReports.filter { log in
            log.employeeIDs.contains(member.id)
        }.count
    }
    
    private func getLastActivityDateForMember(_ member: TeamMember, in project: Project) -> Date? {
        let receiptDates = project.receipts.filter { receipt in
            receipt.teamMemberID == member.id
        }.map { $0.date }
        
        let progressDates = project.progressReports.filter { log in
            log.employeeIDs.contains(member.id)
        }.map { $0.date }
        
        let allDates = receiptDates + progressDates
        return allDates.max()
    }
}

// MARK: - Project Team Assignment View
struct ProjectTeamAssignmentView: View {
    let project: Project
    let availableMembers: [TeamMember]
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMemberIDs: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assign Team Members")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select team members to assign to \(project.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Available members list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableMembers) { member in
                            TeamMemberSelectionRow(
                                member: member,
                                isSelected: selectedMemberIDs.contains(member.id)
                            ) {
                                if selectedMemberIDs.contains(member.id) {
                                    selectedMemberIDs.remove(member.id)
                                } else {
                                    selectedMemberIDs.insert(member.id)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                    
                    Button("Assign Selected (\(selectedMemberIDs.count))") {
                        assignSelectedMembers()
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(selectedMemberIDs.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
                    .disabled(selectedMemberIDs.isEmpty)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func assignSelectedMembers() {
        // Assign selected team members to the project
        var updatedProject = project
        let newAssignments = selectedMemberIDs.map { $0.uuidString }
        updatedProject.assignedTeamMemberIDs.append(contentsOf: newAssignments)
        
        projectVM.updateProject(updatedProject)
        dismiss()
    }
}

// MARK: - Team Member Selection Row
struct TeamMemberSelectionRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                // Member info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(member.role)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let rate = member.hourlyRate {
                            Text("• \(rate.formatAsCurrency())/hr")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(member.employmentStatus == .active ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Project Team Member Detail View
struct ProjectTeamMemberDetailView: View {
    let member: TeamMember
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Member Header
                    memberHeaderSection
                    
                    // Project Activity Summary
                    activitySummarySection
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Team Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var memberHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(member.role)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let rate = member.hourlyRate {
                        Text("\(rate.formatAsCurrency())/hour")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(member.employmentStatus == .active ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(member.employmentStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var activitySummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Project Activity Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ActivityStatCard(
                    icon: "receipt.fill",
                    title: "Receipts",
                    value: "\(getReceiptCount())",
                    color: .blue
                )
                
                ActivityStatCard(
                    icon: "photo.fill",
                    title: "Progress Reports",
                    value: "\(getProgressCount())",
                    color: .green
                )
                
                ActivityStatCard(
                    icon: "clock.fill",
                    title: "Hours Logged",
                    value: "\(getHoursLogged())",
                    color: .orange
                )
                
                ActivityStatCard(
                    icon: "calendar.badge.clock",
                    title: "Last Activity",
                    value: getLastActivityText(),
                    color: .purple
                )
            }
        }
    }
    
    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Placeholder for recent activity items
            Text("Recent activity details will be shown here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // Helper methods
    private func getReceiptCount() -> Int {
        return project.receipts.filter { $0.teamMemberID == member.id }.count
    }
    
    private func getProgressCount() -> Int {
        return project.progressReports.filter { $0.employeeIDs.contains(member.id) }.count
    }
    
    private func getHoursLogged() -> Int {
        let hours = project.loggedHours.filter { $0.employeeID == member.id }
        return Int(hours.reduce(0) { $0 + $1.hoursWorked })
    }
    
    private func getLastActivityText() -> String {
        // Find most recent activity date
        let receiptDates = project.receipts.filter { $0.teamMemberID == member.id }.map { $0.date }
        let progressDates = project.progressReports.filter { $0.employeeIDs.contains(member.id) }.map { $0.date }
        let hourDates = project.loggedHours.filter { $0.employeeID == member.id }.map { $0.date }
        
        let allDates = receiptDates + progressDates + hourDates
        guard let lastDate = allDates.max() else { return "No activity" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastDate, relativeTo: Date())
    }
}

// MARK: - Activity Stat Card
struct ActivityStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}