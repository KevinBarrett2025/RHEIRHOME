import SwiftUI

struct CompletedProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Client: \(project.client)")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Completed")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(project.endDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Budget Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Budget Summary")
                        .font(.headline)
                    
                    budgetRow("Total Budget", amount: project.totalBudget)
                    budgetRow("Materials", amount: project.materialCost)
                    budgetRow("Labor", amount: project.laborCost)
                    budgetRow("General Conditions", amount: project.generalConditions)
                    budgetRow("Contingency", amount: project.contingency)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Project Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Statistics")
                        .font(.headline)
                    
                    statisticRow("Tasks Completed", value: "\(project.tasks.filter { $0.isCompleted }.count) / \(project.tasks.count)")
                    statisticRow("Total Receipts", value: "\(project.receipts.count)")
                    statisticRow("Progress Logs", value: "\(project.progressLogs.count)")
                    statisticRow("Total Hours", value: String(format: "%.1f", project.loggedHours.reduce(0) { $0 + $1.hours }))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Notes
                if !project.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(project.notes)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func budgetRow(_ title: String, amount: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("$\(amount, specifier: "%.2f")")
                .fontWeight(.medium)
        }
    }
    
    private func statisticRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct CompletedProjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            profit: 0,
            startDate: Date(),
            endDate: Date(),
            status: .completed
        )
        
        NavigationStack {
            CompletedProjectDetailView(project: sampleProject)
                .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
        }
    }
}