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
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(Tab.projects)

            ReceiptsView(selectedTab: $selection)
                .environmentObject(projectVM)
                .tabItem { Label("Receipts", systemImage: "tray.full") }
                .tag(Tab.receipts)

            LaborModuleView()
                .environmentObject(projectVM)
                .tabItem { Label("Labor", systemImage: "clock") }
                .tag(Tab.labor)

            NavigationStack {
                TasksListView()
                    .environmentObject(projectVM)
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .tag(Tab.tasks)

            NavigationStack {
                MoreTabView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(Tab.more)

            // Add this as a debug tab in your TabView (temporary)
            #if DEBUG
            NavigationStack {
                OrganizationDebugView()
                    .environmentObject(authVM)
            }
            .tabItem {
                Image(systemName: "ladybug")
                Text("Debug")
            }
            #endif
        }
        .onAppear(perform: selectFirstProjectIfNeeded)
    }

    private func selectFirstProjectIfNeeded() {
        guard projectVM.selectedProject == nil,
              let first = projectVM.projects.first(where: { $0.status == .active })
        else { return }
        projectVM.select(first)
    }
}

// MARK: - More Tab View
struct MoreTabView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    
    var body: some View {
        List {
            NavigationLink(destination: CompletedProjectsView().environmentObject(projectVM)) {
                Label("Completed", systemImage: "checkmark.circle")
            }
            
            NavigationLink(destination: DailyProgressView().environmentObject(projectVM)) {
                Label("Reports", systemImage: "chart.bar.fill")
            }
        }
        .navigationTitle("More")
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
            .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}