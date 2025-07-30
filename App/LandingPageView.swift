import SwiftUI

struct LandingPageView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selectedTab: Tab

    @State private var showNewProject = false
    @State private var isRefreshing = false
    @Namespace private var animation

    private var activeProjects: [Project] {
        // Show ALL projects (local + shared) that are active
        return viewModel.allProjects.filter { $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    organizationHeader
                    
                    logoSection
                    
                    if activeProjects.isEmpty {
                        emptyStateSection
                    } else {
                        projectsListSection
                    }

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewProject) {
                NewProjectView(isPresented: $showNewProject)
                    .environmentObject(viewModel)
            }
            .overlay(
                FAB(icon: "plus") {
                    showNewProject = true
                }
                .padding(),
                alignment: .bottomTrailing
            )
            .onAppear {
                viewModel.navigateToBudgetBreakdown = false
                
                print(" Current Organization: \(authVM.currentOrg?.name ?? "None")")
                print(" Showing \(activeProjects.count) active projects (local + shared)")
                
                // AUTOMATIC REFRESH: Load shared projects when view appears
                loadSharedProjects()
            }
            .navigationDestination(isPresented: $viewModel.navigateToBudgetBreakdown) {
                BudgetBreakdownView(selectedTab: $selectedTab)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
            .alert("CloudKit Status", isPresented: $showingStatusAlert) {
                if statusMessage.contains("Organization Sharing: Inactive") {
                    Button("Setup Organization Sharing") {
                        setupOrganizationSharing()
                    }
                }
                Button("OK") { }
            } message: {
                Text(statusMessage)
            }
        }
    }
    
    private var organizationHeader: some View {
        Group {
            if authVM.currentOrg != nil {
                HStack {
                    // Replace the simple text with the organization selector
                    OrganizationSelectorView()
                        .environmentObject(authVM)
                    
                    Spacer()
                    
                    // Show refresh indicator if needed
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    // Refresh button
                    Button {
                        refreshProjects()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .disabled(isRefreshing)
                    
                    NavigationLink {
                        SettingsView()
                            .environmentObject(viewModel)
                            .environmentObject(authVM)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var logoSection: some View {
        Image("RheirLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .padding(.top, 8)
    }
    
    private var emptyStateSection: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "folder.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No active projects.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let org = authVM.currentOrg {
                    VStack(spacing: 8) {
                        Text("Create your first project for \(org.name)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Text("Local: \(viewModel.projects.count) • Shared: \(viewModel.organizationProjects.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Button {
                            refreshProjects()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Projects")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshing)
                    }
                } else {
                    Text("Join an organization to see shared projects")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
    
    private var projectsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Projects count header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(activeProjects.count) Active Projects")
                            .font(.headline)
                        HStack(spacing: 12) {
                            Label("\(viewModel.projects.filter { $0.status == .active }.count)", systemImage: "iphone")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Label("\(viewModel.organizationProjects.filter { $0.status == .active }.count)", systemImage: "icloud")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Show bulk sync progress if syncing
                        if viewModel.isBulkSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(viewModel.bulkSyncProgress)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                    Spacer()
                    
                    Menu {
                        ForEach(activeProjects) { project in
                            Button("Complete '\(project.name)'") {
                                viewModel.markProjectAsCompleted(project)
                            }
                        }
                        
                        if !activeProjects.isEmpty {
                            Divider()
                            
                            if viewModel.isBulkSyncing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Syncing...")
                                }
                            } else {
                                Button("🔄 Sync All Projects to CloudKit") {
                                    syncAllProjectsToCloudKit()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        refreshProjects()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .disabled(isRefreshing)
                }
                .padding(.horizontal)
                
                ForEach(activeProjects) { project in
                    projectCard(for: project)
                }
            }
            .padding()
        }
        .refreshable {
            await refreshProjectsAsync()
        }
    }
    
    private func projectCard(for project: Project) -> some View {
        let isSelected = project.id == viewModel.selectedProject?.id
        let isSharedProject = viewModel.organizationProjects.contains { $0.id == project.id }
        
        return NavigationLink {
            BudgetBreakdownView(selectedTab: $selectedTab)
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.select(project)
                }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(project.name)
                                .font(.headline)
                                .lineLimit(1)
                            Spacer()
                            // Show source indicator
                            Image(systemName: isSharedProject ? "icloud.fill" : "iphone")
                                .font(.caption)
                                .foregroundColor(isSharedProject ? .green : .blue)
                        }
                        Text("Client: \(project.client)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Budget: $\(project.totalBudget, specifier: "%.0f")")
                        .font(.caption)
                    Spacer()
                    if isSharedProject {
                        Text("Shared")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSharedProject ? Color.green.opacity(0.05) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.gray : (isSharedProject ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
            .matchedGeometryEffect(id: project.id, in: animation)
        }
    }
    
    // MARK: - Project Loading Methods
    
    private func loadSharedProjects() {
        print(" Auto-loading shared projects from CloudKit...")
        viewModel.loadOrganizationProjects()
    }
    
    private func refreshProjects() {
        guard !isRefreshing else { return }
        
        withAnimation {
            isRefreshing = true
        }
        
        print(" Manually refreshing all projects (local + shared)...")
        
        // Load shared projects from CloudKit
        viewModel.loadOrganizationProjects()
        
        // Simulate network delay and then stop refreshing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isRefreshing = false
            }
            print(" Manual refresh complete - showing \(activeProjects.count) active projects")
        }
    }
    
    private func refreshProjectsAsync() async {
        print(" Pull-to-refresh triggered...")
        
        // Load shared projects
        viewModel.loadOrganizationProjects()
        
        // Wait a moment for the data to load
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        print(" Pull-to-refresh complete - auto-sync active")
    }
    
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    
    private func setupOrganizationSharing() {
        viewModel.fixMissingOrganizationIDs { success, message in
            if success {
                statusMessage = """
                Organization sharing setup complete!
                
                \(message)
                
                Now try refreshing your projects - they should sync to CloudKit and be accessible to Rachel.
                """
            } else {
                statusMessage = "Failed to setup organization sharing: \(message)"
            }
            showingStatusAlert = true
            
            // Automatically refresh projects after setup
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    refreshProjects()
                }
            }
        }
    }
    
    private func syncAllProjectsToCloudKit() {
        viewModel.syncAllProjectsToCloudKit { success, message in
            statusMessage = message
            showingStatusAlert = true
        }
    }
}

// MARK: - Preview with Real Services
struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ProjectViewModel()
        let authVM = AuthViewModel(service: PreviewAuthService()) 
        return LandingPageView(selectedTab: .constant(Tab.projects))
            .environmentObject(vm)
            .environmentObject(authVM)
    }
}