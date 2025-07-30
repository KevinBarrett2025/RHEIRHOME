import SwiftUI

struct TasksListView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingNewTask = false
    @State private var showingCompletedTasks = false
    
    private var tasks: [ProjectTask] {
        return projectVM.selectedProject?.tasks ?? []
    }
    
    private var activeTasks: [ProjectTask] {
        return tasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [ProjectTask] {
        return tasks.filter { $0.isCompleted }
    }
    
    var body: some View {
        Group {
            if let project = projectVM.selectedProject {
                tasksListView(for: project)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewTask = true }) {
                    Image(systemName: "plus")
                }
                .disabled(projectVM.selectedProject == nil)
            }
        }
        .sheet(isPresented: $showingNewTask) {
            if projectVM.selectedProject != nil {
                // Temporary placeholder - replace with TaskCreateEditView when import is resolved
                NavigationStack {
                    Text("Task Creation Placeholder")
                        .navigationTitle("New Task")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showingNewTask = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func tasksListView(for project: Project) -> some View {
        List {
            if !activeTasks.isEmpty {
                Section("Active Tasks (\(activeTasks.count))") {
                    ForEach(activeTasks.sorted { $0.priority.sortOrder < $1.priority.sortOrder }) { task in
                        NavigationLink(destination: TaskDetailPlaceholderView(task: task)) {
                            TaskRowView(task: task)
                        }
                    }
                }
            }
            
            if !completedTasks.isEmpty {
                Section("Completed Tasks (\(completedTasks.count))") {
                    ForEach(completedTasks.sorted { $0.completedDate ?? Date.distantPast > $1.completedDate ?? Date.distantPast }) { task in
                        NavigationLink(destination: TaskDetailPlaceholderView(task: task)) {
                            TaskRowView(task: task)
                        }
                    }
                }
            }
            
            if tasks.isEmpty {
                emptyTasksView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a project to view and manage tasks")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var emptyTasksView: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Tasks Yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Add tasks to organize and track work progress")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Button("Create First Task") {
                    showingNewTask = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
        }
    }
}

struct TaskRowView: View {
    let task: ProjectTask
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                    
                    Spacer()
                    
                    Image(systemName: task.category.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label(task.priority.rawValue, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(Color(task.priority.color))
                    
                    Spacer()
                    
                    if task.isOverdue && !task.isCompleted {
                        Text("OVERDUE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    } else if !task.isCompleted, let dueDate = task.dueDate {
                        Text("Due \(dueDate, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if let completed = task.completedDate {
                        Text("Completed \(completed, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            VStack {
                if task.hasPhotos {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .stroke(Color.secondary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .opacity(task.isCompleted ? 0.7 : 1.0)
    }
}

// Temporary placeholder view
struct TaskDetailPlaceholderView: View {
    let task: ProjectTask
    
    var body: some View {
        VStack {
            Text("Task Detail Placeholder")
                .font(.title)
            Text("Task: \(task.title)")
            Text("Description: \(task.description)")
        }
        .navigationTitle("Task Details")
    }
}

struct TasksListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TasksListView()
                .environmentObject(ProjectViewModel())
        }
    }
}
