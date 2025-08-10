// SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @Binding var showNewProject: Bool

    var body: some View {
        List {
            Section("Active Projects") {
                ForEach(viewModel.projects.filter { $0.status == .active }) { project in
                    Button(project.name) {
                        viewModel.select(project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNewProject = true }) {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
    }
}
