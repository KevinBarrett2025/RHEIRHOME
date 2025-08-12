import SwiftUI

struct CompletedProjectsView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    private var completedProjects: [Project] {
        return projectVM.projects.filter { $0.status == .completed }
    }
    
    var body: some View {
        Group {
            if completedProjects.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(completedProjects.sorted { $0.endDate > $1.endDate }) { project in
                        NavigationLink(destination: CompletedProjectDetailView(project: project).environmentObject(projectVM)) {
                            CompletedProjectRowView(project: project)
                        }
                    }
                }
            }
        }
        .navigationTitle("Completed Projects")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Completed Projects")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Completed projects will appear here when you mark them as done")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct CompletedProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Text("Client: \(project.client)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Budget: $\(project.totalBudget, specifier: "%.0f")")
                    .font(.caption)
                Spacer()
                Text("Completed: \(project.endDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CompletedProjectsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CompletedProjectsView()
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        }
    }
}