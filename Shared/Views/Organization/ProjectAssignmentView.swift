import SwiftUI

struct ProjectAssignmentView: View {
    let teamMember: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProjects: Set<UUID> = []
    
    private var availableProjects: [Project] {
        // CRITICAL FIX: Use all accessible projects instead of just organizationProjects
        // and add debug logging to identify why projects aren't showing
        let projects = projectVM.accessibleProjects.filter { $0.status == .active }
        
        print("🔍 PROJECT ASSIGNMENT DEBUG:")
        print("   Total accessible projects: \(projectVM.accessibleProjects.count)")
        print("   Organization projects: \(projectVM.organizationProjects.count)")
        print("   Active projects for assignment: \(projects.count)")
        print("   Current organization ID: \(projectVM.currentOrganizationID ?? "none")")
        
        if projects.isEmpty {
            print("⚠️ PROJECT ASSIGNMENT: No projects available!")
            print("   Accessible projects: \(projectVM.accessibleProjects.map { $0.name })")
            print("   Organization projects: \(projectVM.organizationProjects.map { $0.name })")
            
            // CRITICAL FIX: Try to load projects if none are available
            Task {
                print("🔄 PROJECT ASSIGNMENT: Attempting to load projects...")
                await projectVM.loadProjects()
            }
        }
        
        return projects
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Assign \(teamMember.name) to Projects")) {
                    // CRITICAL FIX: Add loading state and better error handling
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
                            
                            // CRITICAL FIX: Add debug information to help diagnose the issue
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
                // CRITICAL FIX: Load projects when view appears to ensure data is available
                Task {
                    if projectVM.accessibleProjects.isEmpty {
                        print("🔄 PROJECT ASSIGNMENT: Loading projects on view appear...")
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
                        print("✅ Assigned \(updatedMember.name) to project: \(project.name)")
                    }
                }
            }
            
            // Update the team member with any changes
            await MainActor.run {
                projectVM.updateTeamMemberInOrganization(updatedMember)
            }
            
            print("✅ Successfully assigned \(teamMember.name) to \(selectedProjects.count) project(s)")
            print("📊 Updated employment status to: \(updatedMember.employmentStatus.displayName)")
            
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