import SwiftUI

struct DailyProgressView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Reports & Analytics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                    
                    if let project = projectVM.selectedProject {
                        projectReportsView(for: project)
                    } else {
                        emptyStateView
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func projectReportsView(for project: Project) -> some View {
        VStack(spacing: 20) {
            projectSummaryCard(for: project)
            budgetProgressCard(for: project)
            timelineCard(for: project)
            tasksProgressCard(for: project)
        }
        .padding()
    }
    
    @ViewBuilder
    private func projectSummaryCard(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Progress Logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(project.progressLogs.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Receipts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(project.receipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(project.tasks.filter { $0.isCompleted }.count)/\(project.tasks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func budgetProgressCard(for project: Project) -> some View {
        let totalSpent = calculateTotalSpent(for: project)
        let remaining = project.totalBudget - totalSpent
        let progressPercentage = project.totalBudget > 0 ? (totalSpent / project.totalBudget) : 0
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalSpent.formatAsCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(remaining.formatAsCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(remaining >= 0 ? .green : .red)
                }
            }
            
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: progressPercentage > 1.0 ? .red : .blue))
            
            Text("\(Int(progressPercentage * 100))% of budget used")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func timelineCard(for project: Project) -> some View {
        let totalDays = project.endDate.timeIntervalSince(project.startDate) / (24 * 60 * 60)
        let elapsedDays = Date().timeIntervalSince(project.startDate) / (24 * 60 * 60)
        let timeProgress = totalDays > 0 ? (elapsedDays / totalDays) : 0
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(project.startDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Due")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(project.endDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            ProgressView(value: min(timeProgress, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: timeProgress > 1.0 ? .red : .orange))
            
            Text("\(Int(timeProgress * 100))% of timeline elapsed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func tasksProgressCard(for project: Project) -> some View {
        let completedTasks = project.tasks.filter { $0.isCompleted }.count
        let totalTasks = project.tasks.count
        let taskProgress = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(completedTasks)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalTasks - completedTasks)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            
            if totalTasks > 0 {
                ProgressView(value: taskProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                
                Text("\(Int(taskProgress * 100))% of tasks completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No tasks created yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
            
            Text("Select a project to view reports and analytics")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private func calculateTotalSpent(for project: Project) -> Double {
        return project.receipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
}

struct DailyProgressView_Previews: PreviewProvider {
    static var previews: some View {
        DailyProgressView()
            .environmentObject(ProjectViewModel())
    }
}