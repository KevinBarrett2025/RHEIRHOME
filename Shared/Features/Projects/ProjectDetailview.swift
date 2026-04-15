import SwiftUI
import OSLog

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showingShareAlert = false
    @State private var isSharing = false
    @State private var selectedTab: Tab = .projects

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Set the selected project for the ProjectVM
                BudgetBreakdownView(selectedTab: $selectedTab)
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .onAppear {
                        projectVM.selectedProject = project
                    }
            }
            .navigationBarHidden(true)
        }
        .navigationBarHidden(true)
    }
    
    private var isProjectShared: Bool {
        projectVM.organizationProjects.contains { $0.id == project.id }
    }
    
    private func shareProject() {
        guard authVM.currentOrg != nil else {
            Logger.project.error("Project share aborted because no organization is selected.")
            return
        }
        
        isSharing = true
        
        // TODO: Re-implement when CloudKit methods are ready
        Logger.project.notice(
            "Project share requested but the CloudKit sharing flow is still pending implementation [project=\(project.id.uuidString, privacy: .private(mask: .hash))]"
        )
        isSharing = false
        
        /*
        projectVM.saveProjectToCloudKit(project: project) { success in
            DispatchQueue.main.async {
                isSharing = false
                if success {
                    Logger.project.notice("Project shared successfully.")
                } else {
                    Logger.project.error("Project share failed.")
                }
            }
        }
        */
    }
}

struct ProjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectDetailView(
            project: Project(
                name: "Sample Project",
                client: "Sample Client",
                clientEmail: "client@example.com",
                clientPhone: "(555) 123-4567",
                clientAddress: "123 Main St, Anytown, CA 12345",
                description: "Sample project notes",
                totalBudget: 10000,
                materialCost: 2000,
                laborCost: 3000,
                generalConditions: 1000,
                contingency: 500,
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                organizationID: "sample-org-id"
            )
        )
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}
