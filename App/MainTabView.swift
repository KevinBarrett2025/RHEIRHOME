import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    private let releaseProfile = AppReleaseProfile.current
    @State private var selection: Tab = .projects

    var body: some View {
        TabView(selection: $selection) {
            LandingPageView(selectedTab: $selection)
                .environmentObject(projectVM)
                .environmentObject(sessionStore)
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(Tab.projects)

            ReceiptsView(selectedTab: $selection)
                .environmentObject(projectVM)
                .environmentObject(sessionStore)
                .tabItem { Label("Receipts", systemImage: "tray.full") }
                .tag(Tab.receipts)

            LaborModuleView(selectedTab: $selection)
                .environmentObject(projectVM)
                .environmentObject(sessionStore)
                .tabItem { Label("Labor", systemImage: "clock") }
                .tag(Tab.labor)

            NavigationStack {
                TasksListView(selectedTab: $selection)
                    .environmentObject(projectVM)
                    .environmentObject(sessionStore)
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .tag(Tab.tasks)

            if !releaseProfile.shouldHideCompanySurface {
                NavigationStack {
                    MasterCompanySettingsView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                        .environmentObject(sessionStore)
                }
                .tabItem { Label("Company", systemImage: "building.2") }
                .tag(Tab.company)
            }
        }
        .onAppear {
            if !releaseProfile.mainTabs.contains(selection) {
                selection = .projects
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let projectViewModel = ProjectViewModel(offlineDataManager: OfflineDataManager())
        let authViewModel = AuthViewModel(service: CloudKitAuthService())
        MainTabView()
            .environmentObject(projectViewModel)
            .environmentObject(authViewModel)
            .environmentObject(
                SessionStore(
                    authViewModel: authViewModel,
                    projectViewModel: projectViewModel
                )
            )
    }
}
