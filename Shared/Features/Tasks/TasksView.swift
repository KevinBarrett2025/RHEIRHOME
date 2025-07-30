import SwiftUI

struct TasksView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDueDate = Date()
    
    var body: some View {
        NavigationStack {
            Group {
                if let project = projectVM.selectedProject {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Header with project name
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tasks for")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(project.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                
                                // Add task button
                                Button {
                                    showingAddTask = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Task bubbles
                            if project.tasks.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No tasks yet")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    
                                    Text("Add tasks to keep track of your project progress")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Add First Task") {
                                        showingAddTask = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.top, 60)
                            } else {
                                // Bubble layout for tasks
                                TaskBubbleGrid(tasks: project.tasks) { task in
                                    toggleTaskCompletion(task)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    // No project selected
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Project Selected")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select a project from the Projects tab to view and manage tasks")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(
                    newTaskTitle: $newTaskTitle,
                    newTaskDueDate: $newTaskDueDate,
                    onSave: addNewTask
                )
            }
        }
    }
    
    private func addNewTask() {
        guard let project = projectVM.selectedProject,
              !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let newTask = ProjectTask(
            title: newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: newTaskDueDate
        )
        
        var updatedProject = project
        updatedProject.tasks.append(newTask)
        projectVM.save(updatedProject)
        
        // Reset form
        newTaskTitle = ""
        newTaskDueDate = Date()
        showingAddTask = false
    }
    
    private func toggleTaskCompletion(_ task: ProjectTask) {
        guard let project = projectVM.selectedProject,
              let taskIndex = project.tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        
        var updatedProject = project
        updatedProject.tasks[taskIndex].isCompleted.toggle()
        projectVM.save(updatedProject)
    }
}

// MARK: - Task Bubble Grid
struct TaskBubbleGrid: View {
    let tasks: [ProjectTask]
    let onToggle: (ProjectTask) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(tasks) { task in
                TaskBubble(task: task, onToggle: onToggle)
            }
        }
    }
}

// MARK: - Task Bubble
struct TaskBubble: View {
    let task: ProjectTask
    let onToggle: (ProjectTask) -> Void
    
    var body: some View {
        Button {
            onToggle(task)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(task.isCompleted ? .green : .blue)
                    
                    Spacer()
                    
                    if isOverdue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .strikethrough(task.isCompleted)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(task.dueDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : .secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(task.isCompleted ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isOverdue: Bool {
        !task.isCompleted && task.dueDate < Date()
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @Binding var newTaskTitle: String
    @Binding var newTaskDueDate: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("Due date", selection: $newTaskDueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksView()
            .environmentObject(ProjectViewModel())
    }
}
#endif