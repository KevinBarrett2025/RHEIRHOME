import SwiftUI
import OSLog

struct ProjectAssignmentView: View {
    let teamMember: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProjects: Set<UUID> = []
    
    private var availableProjects: [Project] {
        let projects = projectVM.accessibleProjects.filter { $0.status == .active }

        Logger.project.debug(
            "Project assignment view refreshed available projects [accessible=\(projectVM.accessibleProjects.count, privacy: .public), organization=\(projectVM.organizationProjects.count, privacy: .public), active=\(projects.count, privacy: .public), currentOrganization=\(projectVM.currentOrganizationID ?? "none", privacy: .private(mask: .hash))]"
        )

        if projects.isEmpty {
            Logger.project.warning("Project assignment view found no active projects; requesting reload.")
            Task {
                await projectVM.loadProjects()
            }
        }
        
        return projects
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assign \(teamMember.name) to Projects")) {
                    if projectVM.isDataLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading projects...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if availableProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No active projects available")
                                .foregroundColor(.secondary)
                            
                            Group {
                                Text("Debug Info:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Organization ID: \(projectVM.currentOrganizationID ?? "none")")
                                    .font(.caption2)
                                Text("Total projects: \(projectVM.projects.count)")
                                    .font(.caption2)
                                Text("Org projects: \(projectVM.organizationProjects.count)")
                                    .font(.caption2)
                                Text("Accessible projects: \(projectVM.accessibleProjects.count)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                            
                            Button("Reload Projects") {
                                Task {
                                    await projectVM.loadProjects()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
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
            .onAppear {
                Task {
                    if projectVM.accessibleProjects.isEmpty {
                        Logger.project.info("Project assignment view loading projects on first appearance because accessible projects are empty.")
                        await projectVM.loadProjects()
                    }
                }
            }
        }
    }
    
    private func assignToProjects() {
        guard !selectedProjects.isEmpty else { return }
        
        // Update team member status to active if they're being assigned to projects
        var updatedMember = teamMember
        updatedMember.employmentStatus = .active
        
        Task {
            // Assign the team member to each selected project using the available method
            for projectID in selectedProjects {
                // Find the project and update its assigned users directly
                if let projectIndex = projectVM.organizationProjects.firstIndex(where: { $0.id == projectID }) {
                    var project = projectVM.organizationProjects[projectIndex]
                    if !project.assignedUserIDs.contains(updatedMember.id.uuidString) {
                        project.assignUser(updatedMember.id.uuidString)
                        await projectVM.updateProject(project)
                        Logger.teamMember.notice(
                            "Assigned team member to project from project-assignment view [teamMember=\(updatedMember.id.uuidString, privacy: .private(mask: .hash)), project=\(project.id.uuidString, privacy: .private(mask: .hash))]"
                        )
                    }
                }
            }
            
            // Update the team member with any changes
            await MainActor.run {
                projectVM.updateTeamMemberInOrganization(updatedMember)
            }
            
            Logger.teamMember.notice(
                "Completed project assignment update [teamMember=\(teamMember.id.uuidString, privacy: .private(mask: .hash)), projectCount=\(selectedProjects.count, privacy: .public), employmentStatus=\(updatedMember.employmentStatus.displayName, privacy: .public)]"
            )
            
            await MainActor.run {
                dismiss()
            }
        }
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
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
