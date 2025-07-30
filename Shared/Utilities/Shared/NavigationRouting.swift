import SwiftUI

struct NavigationRouting: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(projectViewModel.projects) { project in
                    NavigationLink(
                        destination: ProjectDetailView(project: project)
                    ) {
                        Text(project.name)
                    }
                }
            }
            .navigationTitle("Projects")
        }
    }
}
