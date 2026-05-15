import SwiftUI
import OSLog

struct LandingPageView: View {
    private enum ProjectListScope: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"

        var id: String { rawValue }

        func title(for count: Int) -> String {
            switch self {
            case .active:
                return count == 1 ? "Active Project" : "Active Projects"
            case .completed:
                return count == 1 ? "Completed Project" : "Completed Projects"
            }
        }
    }

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
    @State private var projectListScope: ProjectListScope = .active
    @Namespace private var animation

    private var activeProjects: [Project] {
        // Use role-based filtered projects instead of all projects
        return viewModel.accessibleProjects.filter { $0.status == .active }
    }

    private var completedProjects: [Project] {
        viewModel.accessibleProjects.filter { $0.status == .completed }
    }

    private var visibleProjects: [Project] {
        switch projectListScope {
        case .active:
            return activeProjects
        case .completed:
            return completedProjects
        }
    }

    private var visibleProjectsTitle: String {
        "\(visibleProjects.count) \(projectListScope.title(for: visibleProjects.count))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if releaseProfile.shouldHideCollaborationSurface {
                        fastShipHeaderSection
                        businessResourcesEntrySection
                    } else {
                        // Use UniversalHeaderView instead of custom header to get tier switcher
                        UniversalHeaderView(
                            showSettingsGear: true,
                            showProjectContext: false
                        )
                    }
                    
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

                    if !releaseProfile.shouldHideCollaborationSurface {
                        selectionContextSection
                        logoSection
                    }
                    
                    if !activeProjects.isEmpty || !completedProjects.isEmpty {
                        projectScopePicker
                    }

                    if visibleProjects.isEmpty {
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

    private var projectScopePicker: some View {
        Picker("Project status", selection: $projectListScope) {
            ForEach(ProjectListScope.allCases) { scope in
                Text(scope.rawValue)
                    .tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 4)
        .accessibilityIdentifier("project-status-scope-picker")
    }

    private var fastShipHeaderSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("Projects")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("fast-ship-projects-title")

                Spacer()

                NavigationLink {
                    PersonalSettingsView()
                        .environmentObject(viewModel)
                        .environmentObject(authVM)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
            }

            if let selectedProject = viewModel.selectedProject {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Project")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundColor(.secondary)
                        Text(selectedProject.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
                .accessibilityIdentifier("fast-ship-current-project-card")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a project to begin")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Receipts, labor, tasks, and budget unlock after a project is selected.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("fast-ship-project-selection-guidance")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var businessResourcesEntrySection: some View {
        NavigationLink {
            BusinessResourcesView()
                .environmentObject(viewModel)
                .environmentObject(authVM)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.16))
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Business Resources")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Workers, vendors, and payment methods used across projects.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("business-resources-entry")
        .padding(.horizontal)
        .padding(.bottom, 8)
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
                Image(systemName: projectListScope == .active ? "folder.circle" : "checkmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text(projectListScope == .active ? "No active projects." : "No completed projects yet.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if projectListScope == .completed {
                    Text("Closed-out jobs will appear here after you mark a project complete.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else if releaseProfile.shouldHideCollaborationSurface {
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
                                Text(visibleProjectsTitle)
                                    .font(.headline)
                                
                                Text("(\(role.displayName))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(visibleProjectsTitle)
                                .font(.headline)
                        }
                        
                        if !releaseProfile.shouldHideCollaborationSurface {
                            HStack(spacing: 12) {
                                Label("\(viewModel.projects.filter { $0.status == .active }.count)", systemImage: "iphone")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Label("\(viewModel.accessibleProjects.filter { $0.status == .active }.count)", systemImage: "icloud")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
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
                    
                    if !releaseProfile.shouldHideCollaborationSurface {
                        Menu {
                            // Multi-org actions
                            if authVM.userOrganizations.count > 1 {
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
                
                ForEach(visibleProjects) { project in
                    switch projectListScope {
                    case .active:
                        projectCard(for: project)
                    case .completed:
                        completedProjectCard(for: project)
                    }
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
                            if !releaseProfile.shouldHideCollaborationSurface {
                                // Show source indicator
                                Image(systemName: isSharedProject ? "icloud.fill" : "iphone")
                                    .font(.caption)
                                    .foregroundColor(isSharedProject ? .green : .blue)
                            }
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
                    if isSelected && releaseProfile.shouldHideCollaborationSurface {
                        Text("Selected")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.18))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    } else if isSharedProject && !releaseProfile.shouldHideCollaborationSurface {
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
                        isSelected ? Color.blue : (isSharedProject && !releaseProfile.shouldHideCollaborationSurface ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)),
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

    private func completedProjectCard(for project: Project) -> some View {
        NavigationLink {
            CompletedProjectDetailView(project: project)
                .environmentObject(viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Client: \(project.client)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Final Budget: $\(project.totalBudget, specifier: "%.0f")")
                        .font(.caption)
                    Spacer()
                    Text("Closed \(project.endDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(project.receipts.count)", systemImage: "receipt")
                    Label("\(project.workHours.count)", systemImage: "clock")
                    Label("\(project.tasks.filter { $0.isCompleted }.count)/\(project.tasks.count)", systemImage: "checklist")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.blue.opacity(0.28), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed project \(project.name)")
        .accessibilityIdentifier("completed-project-card-\(project.id.uuidString)")
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

// MARK: - Fast-Ship Business Resources

struct BusinessResourcesView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var activeSheet: BusinessResourceSheet?

    private enum BusinessResourceSheet: Identifiable {
        case workers
        case vendors
        case paymentMethods

        var id: String {
            switch self {
            case .workers: return "workers"
            case .vendors: return "vendors"
            case .paymentMethods: return "paymentMethods"
            }
        }
    }

    private var activeWorkers: [TeamMember] {
        projectVM.teamMembers.filter { member in
            guard !member.isArchived, member.isActive else { return false }
            guard let organizationID = projectVM.currentOrganizationID else { return true }
            return member.organizationID == organizationID
        }
    }

    private var activeVendorsCount: Int {
        projectVM.vendorService.vendors.filter(\.isActive).count
    }

    private var activePaymentMethodCount: Int {
        projectVM.paymentMethodService.paymentMethods.filter(\.isActive).count
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Reusable Project Setup", systemImage: "wrench.and.screwdriver.fill")
                        .font(.headline)
                    Text("Manage the people, vendors, and cards/checking methods you use across jobs. These resources stay available without exposing company or organization admin screens.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            }

            Section("Directories") {
                resourceButton(
                    title: "Workers & Rates",
                    subtitle: "\(activeWorkers.count) active",
                    icon: "person.2.fill",
                    color: .blue,
                    identifier: "business-resources-workers-link"
                ) {
                    activeSheet = .workers
                }

                resourceButton(
                    title: "Vendors",
                    subtitle: "\(activeVendorsCount) active",
                    icon: "building.2.fill",
                    color: .orange,
                    identifier: "business-resources-vendors-link"
                ) {
                    activeSheet = .vendors
                }

                resourceButton(
                    title: "Payment Methods",
                    subtitle: "\(activePaymentMethodCount) active",
                    icon: "creditcard.fill",
                    color: .green,
                    identifier: "business-resources-payment-methods-link"
                ) {
                    activeSheet = .paymentMethods
                }
            }
        }
        .navigationTitle("Business Resources")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("business-resources-hub")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .workers:
                NavigationStack {
                    BusinessWorkersResourceView()
                        .environmentObject(projectVM)
                }
            case .vendors:
                VendorManagementView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            case .paymentMethods:
                PaymentMethodManagementView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
        }
    }

    private func resourceButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.16))
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

struct BusinessWorkersResourceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectVM: ProjectViewModel
    @State private var editorState: BusinessWorkerEditorState?
    @State private var removingWorker: TeamMember?

    private var workers: [TeamMember] {
        projectVM.teamMembers
            .filter { member in
                guard !member.isArchived, member.isActive else { return false }
                guard let organizationID = projectVM.currentOrganizationID else { return true }
                return member.organizationID == organizationID
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workers & Rates")
                        .font(.title2.weight(.bold))
                    Text("Set default job titles and hourly rates so labor logs, payroll review, and project actuals use consistent data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("Active Workers") {
                if workers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No workers yet")
                            .font(.headline)
                        Text("Add your first worker to make labor logging faster and more accurate.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Add Worker") {
                            editorState = .add
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("business-workers-empty-add-button")
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(workers) { worker in
                        workerRow(worker)
                    }
                }
            }
        }
        .navigationTitle("Workers & Rates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorState = .add
                } label: {
                    Label("Add Worker", systemImage: "plus")
                }
                .accessibilityIdentifier("business-workers-add-button")
            }
        }
        .sheet(item: $editorState) { state in
            if let worker = state.worker {
                EnhancedEditTeamMemberView(member: worker)
                    .environmentObject(projectVM)
            } else {
                EnhancedAddTeamMemberView()
                    .environmentObject(projectVM)
            }
        }
        .alert(
            "Remove Worker?",
            isPresented: Binding(
                get: { removingWorker != nil },
                set: { if !$0 { removingWorker = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove from Active Workers", role: .destructive) {
                if let removingWorker {
                    removeFromActiveWorkers(removingWorker)
                    self.removingWorker = nil
                }
            }
        } message: {
            Text("\(removingWorker?.name ?? "This worker") will no longer appear in active worker lists. Existing hours, rates, and payment history stay in project records.")
        }
    }

    private func workerRow(_ worker: TeamMember) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(initials(for: worker.name))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(worker.name)
                    .font(.headline)
                Text(worker.jobTitle.isEmpty ? "Worker" : worker.jobTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(defaultRateSummary(for: worker))
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            Button("Edit") {
                editorState = .edit(worker)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("business-worker-edit-\(worker.id.uuidString)")

            Button(role: .destructive) {
                removingWorker = worker
            } label: {
                Image(systemName: "person.crop.circle.badge.minus")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Remove \(worker.name)")
            .accessibilityIdentifier("business-worker-remove-\(worker.id.uuidString)")
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                removingWorker = worker
            } label: {
                Label("Remove", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    private func removeFromActiveWorkers(_ worker: TeamMember) {
        var updatedWorker = worker
        updatedWorker.terminate(reason: "Removed from active worker list", type: .endOfContract)
        projectVM.updateTeamMember(updatedWorker)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap(\.first)
        return initials.isEmpty ? "?" : String(initials).uppercased()
    }

    private func defaultRateSummary(for worker: TeamMember) -> String {
        guard let rate = worker.defaultRate else { return "No rate set" }
        return "\(rate.taskType): \(rate.rate.formatAsCurrency())/hr"
    }
}

private struct BusinessWorkerEditorState: Identifiable {
    let id = UUID()
    let worker: TeamMember?

    static var add: BusinessWorkerEditorState {
        BusinessWorkerEditorState(worker: nil)
    }

    static func edit(_ worker: TeamMember) -> BusinessWorkerEditorState {
        BusinessWorkerEditorState(worker: worker)
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
