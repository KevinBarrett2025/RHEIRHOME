import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    // ← Use the **global** Tab enum, not MainTabView.Tab
    @State private var selection: Tab = .projects

    var body: some View {
        TabView(selection: $selection) {
            LandingPageView(selectedTab: $selection)
                .environmentObject(projectVM)
                .environmentObject(authVM)
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(Tab.projects)

            ReceiptsView(selectedTab: $selection)
                .environmentObject(projectVM)
                .environmentObject(authVM)
                .tabItem { Label("Receipts", systemImage: "tray.full") }
                .tag(Tab.receipts)

            NavigationStack {
                TasksListView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .tag(Tab.tasks)

            LaborModuleView()
                .environmentObject(projectVM)
                .environmentObject(authVM)
                .tabItem { Label("Labor", systemImage: "clock") }
                .tag(Tab.labor)

            NavigationStack {
                MasterCompanySettingsView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
            .tabItem { Label("Company", systemImage: "building.2") }
            .tag(Tab.company)

        }
        .onAppear(perform: selectFirstProjectIfNeeded)
    }

    private func selectFirstProjectIfNeeded() {
        guard projectVM.selectedProject == nil,
              let first = projectVM.projects.first(where: { $0.status == .active })
        else { return }
        projectVM.selectProject(first)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}