import SwiftUI

struct ProjectAssignmentView: View {
    let teamMember: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProjects: Set<UUID> = []
    
    private var availableProjects: [Project] {
        return projectVM.organizationProjects.filter { $0.status == .active }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assign \(teamMember.name) to Projects")) {
                    if availableProjects.isEmpty {
                        Text("No active projects available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableProjects) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text(project.client)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Budget: \(project.totalBudget.formatAsCurrency())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: selectedProjects.contains(project.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedProjects.contains(project.id) ? .blue : .gray)
                                    .font(.title2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedProjects.contains(project.id) {
                                    selectedProjects.remove(project.id)
                                } else {
                                    selectedProjects.insert(project.id)
                                }
                            }
                        }
                    }
                }
                
                if !selectedProjects.isEmpty {
                    Section("Assignment Summary") {
                        Text("Will assign \(teamMember.name) to \(selectedProjects.count) project(s)")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Assign to Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Assign") {
                        assignToProjects()
                    }
                    .disabled(selectedProjects.isEmpty)
                }
            }
        }
    }
    
    private func assignToProjects() {
        guard !selectedProjects.isEmpty else { return }
        
        // Update team member status to active if they're being assigned to projects
        var updatedMember = teamMember
        updatedMember.employmentStatus = .active
        
        // Assign the team member to each selected project using the available method
        for projectID in selectedProjects {
            // Find the project and update its assigned users directly
            if let projectIndex = projectVM.organizationProjects.firstIndex(where: { $0.id == projectID }) {
                var project = projectVM.organizationProjects[projectIndex]
                if !project.assignedUserIDs.contains(updatedMember.id.uuidString) {
                    project.assignUser(updatedMember.id.uuidString)
                    projectVM.updateProject(project)
                    print("✅ Assigned \(updatedMember.name) to project: \(project.name)")
                }
            }
        }
        
        // Update the team member with any changes
        projectVM.updateTeamMemberInOrganization(updatedMember)
        
        print("✅ Successfully assigned \(teamMember.name) to \(selectedProjects.count) project(s)")
        print("📊 Updated employment status to: \(updatedMember.employmentStatus.displayName)")
        
        dismiss()
    }
}

#Preview {
    let sampleMember = TeamMember(
        name: "John Doe",
        email: "john@example.com",
        jobTitle: "Construction Worker",
        organizationID: "test-org"
    )
    
    ProjectAssignmentView(teamMember: sampleMember)
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
}