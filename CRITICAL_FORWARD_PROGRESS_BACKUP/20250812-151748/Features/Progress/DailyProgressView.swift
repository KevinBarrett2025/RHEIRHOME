import SwiftUI

struct DailyProgressView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var showingProgressLogs = false
    @State private var showingTaskAnalytics = false
    
    enum TimeFrame: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var icon: String {
            switch self {
            case .day: return "calendar"
            case .week: return "calendar.badge.clock"
            case .month: return "calendar.circle"
            case .all: return "calendar.badge.plus"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // CRITICAL FIX: Add UniversalHeaderView for consistency
            UniversalHeaderView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
            
            ScrollView {
                VStack(spacing: 20) {
                    if let project = projectVM.selectedProject {
                        projectAnalyticsView(for: project)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(TimeFrame.allCases, id: \.rawValue) { timeframe in
                        Button {
                            selectedTimeframe = timeframe
                        } label: {
                            HStack {
                                Image(systemName: timeframe.icon)
                                Text(timeframe.rawValue)
                                if selectedTimeframe == timeframe {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedTimeframe.icon)
                        Text(selectedTimeframe.rawValue)
                            .font(.caption)
                    }
                }
                
                Button(action: { showingProgressLogs = true }) {
                    Image(systemName: "list.bullet.below.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingProgressLogs) {
            ProgressLogsListView()
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private func projectAnalyticsView(for project: Project) -> some View {
        VStack(spacing: 20) {
            // Project Header Card
            projectHeaderCard(for: project)
            
            // Key Metrics Row
            keyMetricsRow(for: project)
            
            // Task Progress Analytics
            taskProgressAnalytics(for: project)
            
            // Budget vs Timeline Progress
            budgetTimelineComparison(for: project)
            
            // Recent Activity
            recentActivityCard(for: project)
            
            // Progress Charts Section
            progressChartsSection(for: project)
        }
    }
    
    @ViewBuilder
    private func projectHeaderCard(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Client: \(project.client)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(project.status.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(project.status).opacity(0.2))
                        .foregroundColor(statusColor(project.status))
                        .cornerRadius(8)
                    
                    Text("Due \(project.endDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Project timeline
            let timeProgress = calculateTimeProgress(for: project)
            ProgressView(value: min(timeProgress, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: timeProgress > 1.0 ? .red : .blue))
            
            HStack {
                Text("Started \(project.startDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(timeProgress * 100))% of timeline elapsed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func keyMetricsRow(for project: Project) -> some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Tasks",
                value: "\(project.tasks.filter { $0.isCompleted }.count)/\(project.tasks.count)",
                subtitle: "Completed",
                icon: "checklist",
                color: .green
            )
            
            MetricCard(
                title: "Progress Logs",
                value: "\(getFilteredProgressLogs(for: project).count)",
                subtitle: selectedTimeframe.rawValue,
                icon: "doc.text.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Budget Used",
                value: "\(Int(calculateBudgetProgress(for: project) * 100))%",
                subtitle: "of total",
                icon: "dollarsign.circle",
                color: calculateBudgetProgress(for: project) > 1.0 ? .red : .orange
            )
        }
    }
    
    @ViewBuilder
    private func taskProgressAnalytics(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View Details") {
                    showingTaskAnalytics = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            let taskStats = calculateTaskStatistics(for: project)
            
            VStack(spacing: 12) {
                // Task completion progress
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(taskStats.completedTasks)/\(taskStats.totalTasks) tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: taskStats.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                
                // Priority breakdown
                HStack(spacing: 20) {
                    VStack {
                        Text("\(taskStats.urgentTasks)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Urgent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(taskStats.highPriorityTasks)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(taskStats.overdueTasks)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Overdue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func budgetTimelineComparison(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            let budgetProgress = calculateBudgetProgress(for: project)
            let timeProgress = calculateTimeProgress(for: project)
            let taskProgress = calculateTaskProgress(for: project)
            
            VStack(spacing: 12) {
                ProgressComparisonRow(
                    title: "Budget",
                    progress: budgetProgress,
                    color: budgetProgress > 1.0 ? .red : .blue,
                    format: .percentage
                )
                
                ProgressComparisonRow(
                    title: "Timeline",
                    progress: timeProgress,
                    color: timeProgress > 1.0 ? .red : .orange,
                    format: .percentage
                )
                
                ProgressComparisonRow(
                    title: "Tasks",
                    progress: taskProgress,
                    color: .green,
                    format: .percentage
                )
            }
            
            // Health indicator
            let healthScore = calculateProjectHealth(budget: budgetProgress, time: timeProgress, tasks: taskProgress)
            HStack {
                Image(systemName: healthScore.icon)
                    .foregroundColor(healthScore.color)
                
                Text("Project Health: \(healthScore.description)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(healthScore.color)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func recentActivityCard(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingProgressLogs = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            let recentLogs = getFilteredProgressLogs(for: project).prefix(3)
            
            if recentLogs.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentLogs), id: \.id) { log in
                        RecentActivityRow(log: log)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func progressChartsSection(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics Charts")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Task completion by category chart
            TaskCategoryChart(tasks: project.tasks)
            
            // Progress logs over time
            ProgressTimelineChart(progressLogs: getFilteredProgressLogs(for: project))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a project to view detailed progress analytics and reports")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func calculateTimeProgress(for project: Project) -> Double {
        let totalDays = project.endDate.timeIntervalSince(project.startDate) / (24 * 60 * 60)
        let elapsedDays = Date().timeIntervalSince(project.startDate) / (24 * 60 * 60)
        return totalDays > 0 ? (elapsedDays / totalDays) : 0
    }
    
    private func calculateBudgetProgress(for project: Project) -> Double {
        let totalSpent = calculateTotalSpent(for: project)
        return project.totalBudget > 0 ? (totalSpent / project.totalBudget) : 0
    }
    
    private func calculateTaskProgress(for project: Project) -> Double {
        let completedTasks = project.tasks.filter { $0.isCompleted }.count
        return project.tasks.count > 0 ? Double(completedTasks) / Double(project.tasks.count) : 0
    }
    
    private func calculateTotalSpent(for project: Project) -> Double {
        return project.receipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    private func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .active: return .green
        case .completed: return .blue
        case .onHold: return .orange
        case .cancelled: return .red
        case .planning: return .gray
        }
    }
    
    private func getFilteredProgressLogs(for project: Project) -> [ProgressLog] {
        let calendar = Calendar.current
        let now = Date()
        
        return project.progressLogs.filter { log in
            switch selectedTimeframe {
            case .day:
                return calendar.isDate(log.date, inSameDayAs: now)
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: now)?.contains(log.date) ?? false
            case .month:
                return calendar.dateInterval(of: .month, for: now)?.contains(log.date) ?? false
            case .all:
                return true
            }
        }.sorted { $0.date > $1.date }
    }
    
    private func calculateTaskStatistics(for project: Project) -> TaskStatistics {
        let tasks = project.tasks
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let urgentTasks = tasks.filter { $0.priority == .urgent }.count
        let highPriorityTasks = tasks.filter { $0.priority == .high }.count
        let overdueTasks = tasks.filter { $0.isOverdue && !$0.isCompleted }.count
        
        return TaskStatistics(
            totalTasks: tasks.count,
            completedTasks: completedTasks,
            urgentTasks: urgentTasks,
            highPriorityTasks: highPriorityTasks,
            overdueTasks: overdueTasks,
            completionRate: tasks.count > 0 ? Double(completedTasks) / Double(tasks.count) : 0
        )
    }
    
    private func calculateProjectHealth(budget: Double, time: Double, tasks: Double) -> ProjectHealth {
        let avgProgress = (budget + time + tasks) / 3.0
        
        if budget > 1.2 || time > 1.2 {
            return ProjectHealth(description: "At Risk", color: .red, icon: "exclamationmark.triangle.fill")
        } else if budget > 1.0 || time > 1.0 {
            return ProjectHealth(description: "Needs Attention", color: .orange, icon: "exclamationmark.circle.fill")
        } else if avgProgress > 0.8 {
            return ProjectHealth(description: "On Track", color: .green, icon: "checkmark.circle.fill")
        } else {
            return ProjectHealth(description: "Good", color: .blue, icon: "info.circle.fill")
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressComparisonRow: View {
    let title: String
    let progress: Double
    let color: Color
    let format: ProgressFormat
    
    enum ProgressFormat {
        case percentage
        case decimal
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatProgress(progress))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            ProgressView(value: min(progress, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
    
    private func formatProgress(_ value: Double) -> String {
        switch format {
        case .percentage:
            return "\(Int(value * 100))%"
        case .decimal:
            return String(format: "%.2f", value)
        }
    }
}

struct RecentActivityRow: View {
    let log: ProgressLog
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.workDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(log.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if log.hasPhotos {
                        Image(systemName: "photo.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text("\(log.employeeIDs.count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct TaskCategoryChart: View {
    let tasks: [ProjectTask]
    
    private var categoryCounts: [(TaskCategory, Int)] {
        let grouped = Dictionary(grouping: tasks, by: { $0.category })
        return grouped.map { (category, tasks) in
            (category, tasks.count)
        }.sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks by Category")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if categoryCounts.isEmpty {
                Text("No tasks to display")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(categoryCounts.prefix(5), id: \.0.rawValue) { category, count in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            
                            Text(category.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct ProgressTimelineChart: View {
    let progressLogs: [ProgressLog]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Over Time")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if progressLogs.isEmpty {
                Text("No progress logs to display")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Simple timeline visualization
                VStack(spacing: 4) {
                    ForEach(progressLogs.prefix(5), id: \.id) { log in
                        HStack {
                            Text(log.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Text("\(log.employeeIDs.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
}

// Placeholder for progress logs list view
struct ProgressLogsListView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let project = projectVM.selectedProject {
                    ForEach(project.progressLogs.sorted { $0.date > $1.date }) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(log.workDescription)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(log.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !log.notes.isEmpty {
                                Text(log.notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("\(log.employeeIDs.count) employee(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if log.hasPhotos {
                                    Image(systemName: "photo.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No project selected")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Progress Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct TaskStatistics {
    let totalTasks: Int
    let completedTasks: Int
    let urgentTasks: Int
    let highPriorityTasks: Int
    let overdueTasks: Int
    let completionRate: Double
}

struct ProjectHealth {
    let description: String
    let color: Color
    let icon: String
}

struct DailyProgressView_Previews: PreviewProvider {
    static var previews: some View {
        DailyProgressView()
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}