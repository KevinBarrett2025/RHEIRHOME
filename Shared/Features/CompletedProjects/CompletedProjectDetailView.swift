import SwiftUI

struct CompletedProjectDetailView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(project.client)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Project Details
                    VStack(alignment: .leading, spacing: 16) {
                        ProjectDetailSection(title: "Project Information") {
                            ProjectDetailRow(label: "Status", value: project.status.rawValue)
                            ProjectDetailRow(label: "Start Date", value: project.startDate.formatted(date: .abbreviated, time: .omitted))
                            ProjectDetailRow(label: "End Date", value: project.endDate.formatted(date: .abbreviated, time: .omitted))
                            if let clientAddress = project.clientAddress, !clientAddress.isEmpty {
                                ProjectDetailRow(label: "Address", value: clientAddress)
                            }
                        }
                        
                        ProjectDetailSection(title: "Budget Summary") {
                            ProjectDetailRow(label: "Total Budget", value: project.totalBudget.formatted(.currency(code: "USD")))
                            ProjectDetailRow(label: "Material Cost", value: project.materialCost.formatted(.currency(code: "USD")))
                            ProjectDetailRow(label: "Labor Cost", value: project.laborCost.formatted(.currency(code: "USD")))
                            ProjectDetailRow(label: "General Conditions", value: project.generalConditions.formatted(.currency(code: "USD")))
                            ProjectDetailRow(label: "Contingency", value: project.contingency.formatted(.currency(code: "USD")))
                        }
                        
                        // Project Notes
                        if !project.description.isEmpty {
                            ProjectDetailSection(title: "Notes") {
                                Text(project.description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Project Statistics
                        ProjectDetailSection(title: "Project Statistics") {
                            ProjectDetailRow(label: "Total Tasks", value: "\(project.tasks.count)")
                            ProjectDetailRow(label: "Completed Tasks", value: "\(project.tasks.filter { $0.isCompleted }.count)")
                            ProjectDetailRow(label: "Total Receipts", value: "\(project.receipts.count)")
                            ProjectDetailRow(label: "Progress Logs", value: "\(project.progressLogs.count)")
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Project Details")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ProjectDetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct ProjectDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct CompletedProjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            clientEmail: "john.doe@email.com",
            clientPhone: "(555) 123-4567",
            clientAddress: "123 Main St, Anytown, CA 12345",
            description: "This is a sample completed project with notes",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        CompletedProjectDetailView(project: sampleProject)
    }
}