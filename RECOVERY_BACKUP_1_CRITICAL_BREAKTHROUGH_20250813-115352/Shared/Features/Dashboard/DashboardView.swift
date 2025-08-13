import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTimeRange = TimeRange.thisMonth
    @State private var showingNewProjectSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Dashboard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            if let org = projectVM.currentOrganization {
                                Text(org.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showingNewProjectSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Stats
                    quickStatsView
                    
                    // Recent Activity
                    recentActivityView
                    
                    // Active Projects
                    activeProjectsView
                }
                .padding(.top)
            }
            .refreshable {
                await projectVM.loadProjects()
            }
            .sheet(isPresented: $showingNewProjectSheet) {
                NewProjectView(isPresented: $showingNewProjectSheet)
            }
        }
        .onAppear {
            Task {
                await projectVM.loadProjects()
            }
        }
    }
    
    private var quickStatsView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            DashboardStatCard(
                title: "Active Projects",
                value: "\(projectVM.organizationProjects.filter { $0.status == .active }.count)",
                icon: "building.2.fill",
                color: .blue
            )
            
            DashboardStatCard(
                title: "Completed",
                value: "\(projectVM.organizationProjects.filter { $0.status == .completed }.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            DashboardStatCard(
                title: "Total Budget",
                value: totalBudget,
                icon: "dollarsign.circle.fill",
                color: .orange
            )
            
            DashboardStatCard(
                title: "Past Due",
                value: "\(pastDueCount)",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }
    
    private var recentActivityView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            if recentProjects.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentProjects.prefix(3), id: \.id) { project in
                    ActivityCard(project: project)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var activeProjectsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Projects")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                NavigationLink("View All") {
                    ProjectsListView()
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
            
            if activeProjects.isEmpty {
                Text("No active projects")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(activeProjects.prefix(5), id: \.id) { project in
                    ProjectCard(project: project)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeProjects: [Project] {
        projectVM.organizationProjects.filter { $0.status == .active }
    }
    
    private var recentProjects: [Project] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        return projectVM.organizationProjects
            .filter { $0.lastModifiedDate > oneWeekAgo }
            .sorted { $0.lastModifiedDate > $1.lastModifiedDate }
    }
    
    private var totalBudget: String {
        let total = projectVM.organizationProjects
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.totalBudget }
        return total.formatted(.currency(code: "USD"))
    }
    
    private var pastDueCount: Int {
        let today = Date()
        return projectVM.organizationProjects.filter { 
            $0.status == .active && $0.endDate < today 
        }.count
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActivityCard: View {
    let project: Project
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Updated \(timeAgoString(from: project.lastModifiedDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(statusColor(for: project.status))
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .active: return .blue
        case .completed: return .green
        case .onHold: return .orange
        case .cancelled: return .red
        case .planning: return .gray
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(project.totalBudget.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                Text(project.client)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: project.budgetUtilization, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                
                HStack {
                    Text("\(Int(project.budgetUtilization * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Due: \(project.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(project.isPastDue ? .red : .secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum TimeRange: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
}

#Preview {
    NavigationView {
        DashboardView()
    }
    .environmentObject({
        let projectVM = ProjectViewModel(offlineDataManager: OfflineDataManager())
        
        // Add sample project with correct constructor
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            clientEmail: "john.doe@email.com",
            clientPhone: "(555) 123-4567", 
            clientAddress: "123 Main St, Anytown, CA 12345",
            description: "Sample project for testing",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        Task { @MainActor in
            await projectVM.addProject(sampleProject)
        }
        
        return projectVM
    }())
    .environmentObject(AuthViewModel(service: PreviewAuthService()))
}