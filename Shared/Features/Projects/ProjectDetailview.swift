import SwiftUI

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
            print("❌ No organization selected")
            return
        }
        
        isSharing = true
        
        // TODO: Re-implement when CloudKit methods are ready
        print("🔄 Project sharing will be implemented soon...")
        isSharing = false
        
        /*
        projectVM.saveProjectToCloudKit(project: project) { success in
            DispatchQueue.main.async {
                isSharing = false
                if success {
                    print("✅ Project shared successfully")
                } else {
                    print("❌ Failed to share project")
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
                id: UUID(),
                name: "Sample Project",
                client: "Sample Client",
                phone: "(555) 123-4567",
                email: "client@example.com",
                street: "123 Main St",
                city: "Anytown",
                state: "CA",
                zip: "12345",
                notes: "Sample project notes",
                totalBudget: 10000,
                materialCost: 2000,
                laborCost: 3000,
                generalConditions: 1000,
                contingency: 500,
                spentContingency: 0,
                profit: 1500,
                startDate: Date(),
                endDate: Date(),
            organizationID: "sample-org-id".addingTimeInterval(60 * 60 * 24 * 30),
                loggedHours: [],
                tasks: [],
                communications: [],
                progressLogs: [],
                changeOrders: [],
                receipts: [],
                taskTemplates: [],
                status: .active
            )
        )
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}