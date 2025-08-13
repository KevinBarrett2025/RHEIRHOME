import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    let task: ProjectTask
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Task Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Priority Badge
                        Text(task.priority.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(task.priority.color.opacity(0.2))
                            .foregroundColor(task.priority.color)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Task Details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Status", value: task.isCompleted ? "Completed" : "In Progress")
                    DetailRow(label: "Category", value: task.category.displayName)
                    DetailRow(label: "Estimated Hours", value: "\(task.estimatedHours, specifier: "%.1f") hours")
                    
                    if let dueDate = task.dueDate {
                        DetailRow(label: "Due Date", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    
                    if let completedDate = task.completedDate {
                        DetailRow(label: "Completed", value: completedDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    if task.actualHours > 0 {
                        DetailRow(label: "Actual Hours", value: "\(task.actualHours, specifier: "%.1f") hours")
                    }
                }
                
                Divider()
                
                // Photos Section
                if !task.photoIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos (\(task.photoIDs.count))")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(task.photoIDs, id: \.self) { photoID in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Task") {
                        showingEditSheet = true
                    }
                    
                    if !task.isCompleted {
                        Button("Mark Complete") {
                            completeTask()
                        }
                    }
                    
                    Button("Delete Task", role: .destructive) {
                        deleteTask()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskCreateEditView(
                project: projectVM.selectedProject,
                employees: projectVM.teamMembers,
                existingTask: task
            ) { updatedTask in
                projectVM.updateTask(updatedTask)
                showingEditSheet = false
            }
            .environmentObject(projectVM)
        }
    }
    
    private func completeTask() {
        var updatedTask = task
        updatedTask.isCompleted = true
        updatedTask.completedDate = Date()
        projectVM.updateTask(updatedTask)
    }
    
    private func deleteTask() {
        projectVM.deleteTask(task)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        TaskDetailView(
            task: ProjectTask(
                title: "Install Kitchen Cabinets",
                description: "Install upper and lower kitchen cabinets according to design specifications",
                priority: .high,
                category: .general,
                estimatedHours: 8.0,
                dueDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                projectID: UUID()
            )
        )
    }
    .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}