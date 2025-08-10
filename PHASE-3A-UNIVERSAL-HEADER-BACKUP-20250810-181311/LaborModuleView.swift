import SwiftUI

struct LaborModuleView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingLogHours = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingPaymentView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let project = projectVM.selectedProject {
                    laborSummarySection(project)
                    teamMembersList
                } else {
                    noProjectSelectedView
                }
            }
            .padding()
            .navigationTitle("Labor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Log Hours") {
                            showingLogHours = true
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
                TeamMemberLaborDetailView(teamMember: member)
                    .environmentObject(projectVM)
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
            Text("Team Members")
                .font(.headline)
            
            if projectVM.teamMembers.isEmpty {
                emptyTeamMembersView
            } else {
                ForEach(projectVM.teamMembers) { member in
                    TeamMemberLaborRowView(member: member) {
                        selectedTeamMember = member
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyTeamMembersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No team members")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Add team members to track their work hours")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder 
    private var noProjectSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "briefcase")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select a project to view and manage labor hours")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
                    
                    HStack {
                        Text(String(format: "%.1f hrs", memberHours))
                            .font(.caption)
                            .foregroundColor(.blue)
                        
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
                        Button("Pay") {
                            onTap()
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    } else {
                        Text("Paid")
                            .font(.caption)
                            .foregroundColor(.green)
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
        LaborModuleView()
            .environmentObject(ProjectViewModel())
    }
}