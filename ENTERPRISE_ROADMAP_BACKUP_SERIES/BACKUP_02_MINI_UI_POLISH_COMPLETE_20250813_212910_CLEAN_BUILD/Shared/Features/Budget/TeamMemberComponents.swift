import SwiftUI

// MARK: - Team Stat Card
struct TeamStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
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
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Project Team Member Card
struct ProjectTeamMemberCard: View {
    let member: TeamMember
    let project: Project
    let action: () -> Void
    
    private var memberActivity: MemberProjectActivity {
        calculateMemberActivity(member, project)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Member avatar/initials
                Circle()
                    .fill(memberColor(for: member))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(memberInitials(member))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                // Member info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(member.role)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if memberActivity.hasReceipts {
                            Label("\(memberActivity.receiptCount)", systemImage: "receipt")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if memberActivity.hasProgress {
                            Label("\(memberActivity.progressCount)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        
                        if memberActivity.hasHours {
                            Label("\(memberActivity.hoursCount)h", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(statusColor(for: member.employmentStatus))
                        .frame(width: 8, height: 8)
                    
                    if let lastActivity = memberActivity.lastActivityDate {
                        Text(lastActivity.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No activity")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func memberInitials(_ member: TeamMember) -> String {
        let components = member.name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(member.name.prefix(2))
        }
    }
    
    private func memberColor(for member: TeamMember) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .cyan, .yellow]
        let index = abs(member.name.hashValue) % colors.count
        return colors[index]
    }
    
    private func statusColor(for status: EmploymentStatus) -> Color {
        switch status {
        case .active: return .green
        case .inactive: return .orange
        case .terminated: return .red
        }
    }
    
    private func calculateMemberActivity(_ member: TeamMember, _ project: Project) -> MemberProjectActivity {
        let receipts = project.receipts.filter { $0.teamMemberID == member.id }
        let progress = project.progressReports.filter { $0.employeeIDs.contains(member.id) }
        let hours = project.loggedHours.filter { $0.employeeID == member.id }
        
        let receiptDates = receipts.map { $0.date }
        let progressDates = progress.map { $0.date }
        let hoursDates = hours.map { $0.date }
        
        let allDates = receiptDates + progressDates + hoursDates
        let lastActivity = allDates.max()
        
        return MemberProjectActivity(
            hasReceipts: !receipts.isEmpty,
            receiptCount: receipts.count,
            hasProgress: !progress.isEmpty,
            progressCount: progress.count,
            hasHours: !hours.isEmpty,
            hoursCount: Int(hours.reduce(0) { $0 + $1.hoursWorked }),
            lastActivityDate: lastActivity
        )
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
            VStack(spacing: 0) {
                if availableMembers.isEmpty {
                    emptyStateView
                } else {
                    memberSelectionList
                }
            }
            .navigationTitle("Assign Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Assign") {
                        assignSelectedMembers()
                    }
                    .disabled(selectedMemberIDs.isEmpty)
                }
            }
        }
    }
    
    @ViewBuilder
    private var memberSelectionList: some View {
        List {
            ForEach(availableMembers) { member in
                TeamMemberSelectionRow(
                    member: member,
                    isSelected: selectedMemberIDs.contains(member.id)
                ) { isSelected in
                    if isSelected {
                        selectedMemberIDs.insert(member.id)
                    } else {
                        selectedMemberIDs.remove(member.id)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Available Team Members")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("All team members are already assigned to this project or no active members are available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func assignSelectedMembers() {
        // Add selected member IDs to project
        var updatedProject = project
        let newAssignments = selectedMemberIDs.map { $0.uuidString }
        updatedProject.assignedTeamMemberIDs.append(contentsOf: newAssignments)
        
        // Remove duplicates
        updatedProject.assignedTeamMemberIDs = Array(Set(updatedProject.assignedTeamMemberIDs))
        
        projectVM.updateProject(updatedProject)
        dismiss()
    }
}

// MARK: - Team Member Selection Row
struct TeamMemberSelectionRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            // Selection checkbox
            Button {
                onToggle(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(member.role)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(member.employmentStatus.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(for: member.employmentStatus).opacity(0.2))
                .foregroundColor(statusColor(for: member.employmentStatus))
                .cornerRadius(8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
    
    private func statusColor(for status: EmploymentStatus) -> Color {
        switch status {
        case .active: return .green
        case .inactive: return .orange
        case .terminated: return .red
        }
    }
}

// MARK: - Project Team Member Detail View
struct ProjectTeamMemberDetailView: View {
    let member: TeamMember
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var memberReceipts: [Receipt] {
        project.receipts.filter { $0.teamMemberID == member.id }
    }
    
    private var memberProgress: [ProgressLog] {
        project.progressReports.filter { $0.employeeIDs.contains(member.id) }
    }
    
    private var memberHours: [WorkHour] {
        project.loggedHours.filter { $0.employeeID == member.id }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    memberHeaderSection
                    activitySummarySection
                    receiptsSection
                    progressSection
                    hoursSection
                }
                .padding()
            }
            .navigationTitle(member.name)
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
            Circle()
                .fill(memberColor(for: member))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(memberInitials(member))
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(member.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(member.role)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !member.email.isEmpty {
                    Text(member.email)
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
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActivityStatCard(
                    icon: "receipt.fill",
                    title: "Receipts",
                    value: "\(memberReceipts.count)",
                    color: .blue
                )
                
                ActivityStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Reports",
                    value: "\(memberProgress.count)",
                    color: .green
                )
                
                ActivityStatCard(
                    icon: "clock.fill",
                    title: "Hours Logged",
                    value: "\(memberHours.reduce(0) { $0 + Int($1.hoursWorked) })",
                    color: .orange
                )
            }
        }
    }
    
    @ViewBuilder
    private var receiptsSection: some View {
        if !memberReceipts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Receipts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVStack(spacing: 8) {
                    ForEach(memberReceipts.sorted { $0.date > $1.date }.prefix(5)) { receipt in
                        ReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var progressSection: some View {
        if !memberProgress.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Progress Reports")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVStack(spacing: 8) {
                    ForEach(memberProgress.sorted { $0.date > $1.date }.prefix(3)) { progress in
                        ProgressRowCard(progress: progress)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var hoursSection: some View {
        if !memberHours.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Time Entries")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVStack(spacing: 8) {
                    ForEach(memberHours.sorted { $0.date > $1.date }.prefix(5)) { hour in
                        HourRowCard(hour: hour)
                    }
                }
            }
        }
    }
    
    private func memberInitials(_ member: TeamMember) -> String {
        let components = member.name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(member.name.prefix(2))
        }
    }
    
    private func memberColor(for member: TeamMember) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .cyan, .yellow]
        let index = abs(member.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Models and Components

struct MemberProjectActivity {
    let hasReceipts: Bool
    let receiptCount: Int
    let hasProgress: Bool
    let progressCount: Int
    let hasHours: Bool
    let hoursCount: Int
    let lastActivityDate: Date?
}

struct ActivityStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ProgressRowCard: View {
    let progress: ProgressLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.taskName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(progress.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !progress.notes.isEmpty {
                Text(progress.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct HourRowCard: View {
    let hour: WorkHour
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hour.taskDescription.isEmpty ? "Work Entry" : hour.taskDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f", hour.hoursWorked))h")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if hour.hourlyRate > 0 {
                    Text((hour.hoursWorked * hour.hourlyRate).formatAsCurrency())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}