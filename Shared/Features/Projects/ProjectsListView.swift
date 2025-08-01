import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // Local Projects Section
                if !projectVM.projects.isEmpty {
                    Section("My Projects") {
                        ForEach(projectVM.projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRowView(project: project, isShared: false)
                            }
                        }
                    }
                }
                
                // Shared Organization Projects Section
                if !projectVM.organizationProjects.isEmpty {
                    Section("Organization Projects") {
                        ForEach(projectVM.organizationProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRowView(project: project, isShared: true)
                            }
                        }
                    }
                }
                
                if projectVM.projects.isEmpty && projectVM.organizationProjects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Projects")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create a new project or wait for shared projects to load")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Projects")
            .refreshable {
                await projectVM.loadProjects() // This loads both local and organization projects
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    let isShared: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                
                Text(project.client)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Budget: \(project.totalBudget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if isShared {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Shared")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Text(project.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(project.status == .active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectsListView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsListView()
            .environmentObject(ProjectViewModel())
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}