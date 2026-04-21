import SwiftUI
import OSLog

struct LandingPageView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var selectedTab: Tab
    private let releaseProfile = AppReleaseProfile.current

    @State private var showNewProject = false
    @State private var isRefreshing = false
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showAdminOnboardingSheet = false
    @Namespace private var animation

    private var activeProjects: [Project] {
        // Use role-based filtered projects instead of all projects
        return viewModel.accessibleProjects.filter { $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    // Use UniversalHeaderView instead of custom header to get tier switcher
                    UniversalHeaderView(
                        showSettingsGear: true,
                        showProjectContext: false
                    )
                    
                    // Additional context info below header
                    if authVM.currentOrg != nil && !releaseProfile.shouldHideCollaborationSurface {
                        HStack {
                            // Multi-org indicator and quick stats  
                            if authVM.userOrganizations.count > 1 {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.2.crop.circle")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("\(authVM.userOrganizations.count) organizations")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if let role = authVM.currentOrganizationRole {
                                        Text("Role: \(role.displayName)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
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
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    selectionContextSection
                    
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
            .sheet(isPresented: $showAdminOnboardingSheet) {
                if let currentOrg = authVM.currentOrg {
                    AdminOnboardingView(organization: currentOrg)
                        .environmentObject(authVM)
                        .environmentObject(viewModel)
                }
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
    
    private var logoSection: some View {
        Image("RheirLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .padding(.top, 8)
    }

    @ViewBuilder
    private var selectionContextSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(authVM.currentOrg?.name ?? "Workspace Unavailable")
                        .font(.headline)

                    if releaseProfile.shouldHideCollaborationSurface {
                        Text("Personal workspace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let role = authVM.currentOrganizationRole {
                        Text(role.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select an organization to continue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !releaseProfile.shouldHideCollaborationSurface && authVM.userOrganizations.count > 1 {
                    Button("Switch") {
                        sessionStore.showOrganizationSelector()
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 12) {
                Label(
                    viewModel.selectedProject?.name ?? "No Project Selected",
                    systemImage: viewModel.selectedProject == nil ? "folder.badge.questionmark" : "folder.fill"
                )
                .font(.subheadline)
                .lineLimit(1)
                .accessibilityIdentifier("project-selection-current-project")

                Spacer()

                Menu {
                    Button("Clear Selection") {
                        viewModel.deselectProject()
                    }
                    .disabled(viewModel.selectedProject == nil)

                    if activeProjects.isEmpty {
                        Text("No active projects available")
                    } else {
                        ForEach(activeProjects) { project in
                            Button(project.name) {
                                sessionStore.selectProject(project)
                            }
                        }
                    }
                } label: {
                    Text(viewModel.selectedProject == nil ? "Choose Project" : "Change")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeProjects.isEmpty)
                .accessibilityIdentifier("project-selection-menu")
            }

            if viewModel.selectedProject == nil && activeProjects.count > 1 {
                Text("Choose a project before working in Receipts, Labor, or Tasks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("project-selection-guidance")
            }
        }
        .padding(.horizontal)
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
                
                if releaseProfile.shouldHideCollaborationSurface {
                    VStack(spacing: 8) {
                        Text("Create your first project to start tracking receipts, labor, tasks, and budget.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button {
                            showNewProject = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Project")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let org = authVM.currentOrg {
                    VStack(spacing: 8) {
                        if let role = authVM.currentOrganizationRole {
                            switch role {
                            case .admin, .member:
                                Text("Create your first project for \(org.name)")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            case .contractor:
                                Text("No projects assigned to you in \(org.name)")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                Text("Contact the admin to assign you to projects")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            case .viewer:
                                Text("No projects to view in \(org.name)")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Multi-org context for contractors
                        if authVM.userOrganizations.count > 1 {
                            VStack(spacing: 4) {
                                Text("You belong to \(authVM.userOrganizations.count) organizations")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text("Use the organization dropdown to switch between them")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        
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
                // Projects count header with role context
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if !releaseProfile.shouldHideCollaborationSurface, let role = authVM.currentOrganizationRole {
                            HStack {
                                Text("\(activeProjects.count) Active Projects")
                                    .font(.headline)
                                
                                Text("(\(role.displayName))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("\(activeProjects.count) Active Projects")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 12) {
                            Label("\(viewModel.projects.filter { $0.status == .active }.count)", systemImage: "iphone")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Label("\(viewModel.accessibleProjects.filter { $0.status == .active }.count)", systemImage: "icloud")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Show organization context for multi-org users
                        if !releaseProfile.shouldHideCollaborationSurface,
                           authVM.userOrganizations.count > 1,
                           let currentOrg = authVM.currentOrg {
                            Text("Current: \(currentOrg.name)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        // Show bulk sync progress if syncing
                        if viewModel.isBulkSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(viewModel.bulkSyncProgressText)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                    Spacer()
                    
                    Menu {
                        // Multi-org actions
                        if !releaseProfile.shouldHideCollaborationSurface && authVM.userOrganizations.count > 1 {
                            Button("Switch Organization") {
                                // This would trigger the organization selector
                            }
                        }
                        
                        if !activeProjects.isEmpty {
                            Divider()
                            
                            ForEach(activeProjects) { project in
                                Button("Complete '\(project.name)'") {
                                    viewModel.markProjectAsCompleted(project)
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
                        Text(releaseProfile.shouldHideCollaborationSurface ? "Synced" : "Shared")
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
        .simultaneousGesture(
            TapGesture().onEnded {
                sessionStore.selectProject(project)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.name)
        .accessibilityIdentifier("project-card-\(project.id.uuidString)")
    }
    
    // MARK: - Project Loading Methods
    
    private func refreshProjects() {
        guard !isRefreshing else { return }
        
        withAnimation {
            isRefreshing = true
        }
        
        Logger.project.info("Manually refreshing projects from CloudKit.")
        
        Task {
            await viewModel.loadProjects() // This now loads from CloudKit organization zone
            
            await MainActor.run {
                withAnimation {
                    isRefreshing = false
                }
                Logger.project.notice(
                    "Completed manual project refresh [activeProjects=\(activeProjects.count, privacy: .public)]"
                )
            }
        }
    }
    
    private func refreshProjectsAsync() async {
        Logger.project.info("Triggered pull-to-refresh for projects.")
        
        // Load projects from CloudKit organization zone
        await viewModel.loadProjects()
        
        Logger.project.notice("Completed pull-to-refresh for projects.")
    }
    
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
            
            if success {
                refreshProjects()
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
        let offlineDataManager = OfflineDataManager()
        let vm = ProjectViewModel(offlineDataManager: offlineDataManager)
        let authVM = AuthViewModel(service: PreviewAuthService()) 
        let sessionStore = SessionStore(
            authViewModel: authVM,
            projectViewModel: vm
        )
        return LandingPageView(selectedTab: .constant(Tab.projects))
            .environmentObject(vm)
            .environmentObject(authVM)
            .environmentObject(sessionStore)
    }
}
