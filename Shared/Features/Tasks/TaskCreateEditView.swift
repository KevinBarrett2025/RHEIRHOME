import SwiftUI

struct TaskCreateEditView: View {
    let project: Project?
    let employees: [TeamMember]
    let onSave: (ProjectTask) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .general
    @State private var selectedEmployeeIDs: Set<UUID> = []
    
    // Existing task for editing
    let existingTask: ProjectTask?
    
    init(
        project: Project?,
        employees: [TeamMember],
        existingTask: ProjectTask? = nil,
        onSave: @escaping (ProjectTask) -> Void
    ) {
        self.project = project
        self.employees = employees
        self.existingTask = existingTask
        self.onSave = onSave
        
        // Initialize with existing task data if editing
        if let task = existingTask {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description)
            _dueDate = State(initialValue: task.dueDate)
            _priority = State(initialValue: task.priority)
            _category = State(initialValue: task.category)
            _selectedEmployeeIDs = State(initialValue: Set(task.assignedEmployeeIDs))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Priority & Category") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priorityColor(for: priority))
                                    .frame(width: 12, height: 12)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section("Assign Team Members") {
                    if employees.isEmpty {
                        Text("No team members available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(employees) { employee in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(employee.name)
                                        .font(.body)
                                    if !employee.jobTitle.isEmpty {
                                        Text(employee.jobTitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedEmployeeIDs.contains(employee.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedEmployeeIDs.contains(employee.id) {
                                    selectedEmployeeIDs.remove(employee.id)
                                } else {
                                    selectedEmployeeIDs.insert(employee.id)
                                }
                            }
                        }
                    }
                }
                
                Section("Photos") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("Photo support coming soon")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveTask() {
        // Create task
        let task = ProjectTask(
            id: existingTask?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            isCompleted: existingTask?.isCompleted ?? false,
            completedDate: existingTask?.completedDate,
            priority: priority,
            category: category,
            photoIDs: existingTask?.photoIDs ?? [],
            assignedEmployeeIDs: Array(selectedEmployeeIDs),
            completedByEmployeeIDs: existingTask?.completedByEmployeeIDs ?? [],
            completionNotes: existingTask?.completionNotes ?? "",
            createdAt: existingTask?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        print("✅ Task '\(task.title)' saved (photo integration pending)")
        onSave(task)
        dismiss()
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

#if DEBUG
struct TaskCreateEditView_Previews: PreviewProvider {
    static var previews: some View {
        TaskCreateEditView(
            project: nil,
            employees: [
                TeamMember(name: "John Doe", jobTitle: "Electrician"),
                TeamMember(name: "Jane Smith", jobTitle: "Plumber")
            ]
        ) { _ in }
    }
}
#endif
