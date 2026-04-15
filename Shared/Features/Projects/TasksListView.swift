import SwiftUI

struct TasksListView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showingNewTask = false
    @State private var showingCompletedTasks = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTask: ProjectTask?
    @State private var showingTaskDetail = false
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case overdue = "Overdue"
        case highPriority = "High Priority"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .active: return "clock"
            case .completed: return "checkmark.circle"
            case .overdue: return "exclamationmark.triangle"
            case .highPriority: return "exclamationmark.3"
            }
        }
    }
    
    private var tasks: [ProjectTask] {
        return projectVM.selectedProject?.tasks ?? []
    }
    
    private var filteredTasks: [ProjectTask] {
        var taskList = tasks
        
        // Apply search filter
        if !searchText.isEmpty {
            taskList = taskList.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            taskList = taskList.filter { !$0.isCompleted }
        case .completed:
            taskList = taskList.filter { $0.isCompleted }
        case .overdue:
            taskList = taskList.filter { $0.isOverdue && !$0.isCompleted }
        case .highPriority:
            taskList = taskList.filter { $0.priority == .high || $0.priority == .urgent }
        }
        
        return taskList.sorted { task1, task2 in
            // Sort by priority first, then by due date
            if task1.priority.sortOrder != task2.priority.sortOrder {
                return task1.priority.sortOrder < task2.priority.sortOrder
            }
            
            // Then by completion status
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            
            // Finally by due date
            if let date1 = task1.dueDate, let date2 = task2.dueDate {
                return date1 < date2
            } else if task1.dueDate != nil {
                return true
            } else if task2.dueDate != nil {
                return false
            }
            
            return task1.title < task2.title
        }
    }
    
    private var activeTasks: [ProjectTask] {
        return tasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [ProjectTask] {
        return tasks.filter { $0.isCompleted }
    }
    
    private var overdueTasks: [ProjectTask] {
        return tasks.filter { $0.isOverdue && !$0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Universal Header
                UniversalHeaderView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                
                mainContent
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingNewTask) {
                newTaskSheet
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
                    .environmentObject(projectVM)
            }
        }
    }
    
    private var mainContent: some View {
        Group {
            if let project = projectVM.selectedProject {
                tasksListView(for: project)
            } else {
                emptyStateView
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                ForEach(TaskFilter.allCases, id: \.rawValue) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack {
                            Image(systemName: filter.icon)
                            Text(filter.rawValue)
                            if selectedFilter == filter {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            
            Button(action: { showingNewTask = true }) {
                Image(systemName: "plus")
            }
            .disabled(projectVM.selectedProject == nil)
        }
    }
    
    @ViewBuilder
    private var newTaskSheet: some View {
        if let project = projectVM.selectedProject {
            TaskCreateEditView(project: project, onSave: { task in
                Task {
                    await projectVM.addTask(task, to: project.id)
                }
                showingNewTask = false
            })
            .environmentObject(projectVM)
        }
    }
    
    private func tasksListView(for project: Project) -> some View {
        List {
            if !overdueTasks.isEmpty && selectedFilter == .all {
                Section("⚠️ Overdue Tasks (\(overdueTasks.count))") {
                    ForEach(overdueTasks) { task in
                        TaskRowView(task: task) {
                            selectedTask = task
                            showingTaskDetail = true
                        }
                    }
                }
            }
            
            if !filteredTasks.isEmpty {
                Section(sectionHeader) {
                    ForEach(filteredTasks) { task in
                        TaskRowView(task: task) {
                            selectedTask = task
                            showingTaskDetail = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !task.isCompleted {
                                Button("Complete") {
                                    markTaskCompleted(task)
                                }
                                .tint(.green)
                            }
                            
                            Button("Delete") {
                                deleteTask(task)
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if task.isCompleted {
                                Button("Reopen") {
                                    reopenTask(task)
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            
            if filteredTasks.isEmpty && !searchText.isEmpty {
                Section {
                    Text("No tasks match your search")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else if tasks.isEmpty {
                emptyTasksView
            }
            
            // Task summary section
            if !tasks.isEmpty {
                Section("Summary") {
                    TaskSummaryView(
                        totalTasks: tasks.count,
                        completedTasks: completedTasks.count,
                        overdueTasks: overdueTasks.count
                    )
                }
            }
        }
    }
    
    private var sectionHeader: String {
        switch selectedFilter {
        case .all:
            return "All Tasks (\(filteredTasks.count))"
        case .active:
            return "Active Tasks (\(filteredTasks.count))"
        case .completed:
            return "Completed Tasks (\(filteredTasks.count))"
        case .overdue:
            return "Overdue Tasks (\(filteredTasks.count))"
        case .highPriority:
            return "High Priority Tasks (\(filteredTasks.count))"
        }
    }
    
    private var emptyStateView: some View {
        ProjectSelectionRequiredView(
            title: "Select a Project",
            message: "Choose a project before viewing or managing tasks."
        )
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
    
    // MARK: - Task Actions
    
    private func markTaskCompleted(_ task: ProjectTask) {
        guard let currentUserID = getCurrentUserID(),
              let project = projectVM.selectedProject else { return }
        
        var completedTask = task
        completedTask.markCompleted(by: [UUID(uuidString: currentUserID) ?? UUID()], notes: "Marked complete")
        
        Task {
            await projectVM.updateTask(completedTask, in: project.id)
        }
    }
    
    private func reopenTask(_ task: ProjectTask) {
        guard let project = projectVM.selectedProject else { return }
        
        var reopenedTask = task
        reopenedTask.isCompleted = false
        reopenedTask.completedDate = nil
        reopenedTask.completedByEmployeeIDs = []
        reopenedTask.completionNotes = ""
        reopenedTask.updatedAt = Date()
        
        Task {
            await projectVM.updateTask(reopenedTask, in: project.id)
        }
    }
    
    private func deleteTask(_ task: ProjectTask) {
        guard let project = projectVM.selectedProject else { return }
        
        Task {
            await projectVM.deleteTask(task, from: project.id)
        }
    }
    
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
}

struct TaskRowView: View {
    let task: ProjectTask
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: task.category.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if task.hasPhotos {
                                Image(systemName: "photo.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        // Priority indicator
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(task.priority.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(priorityColor(task.priority))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(task.priority).opacity(0.2))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        // Due date / completion status
                        if task.isOverdue && !task.isCompleted {
                            HStack(spacing: 2) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.caption2)
                                Text("OVERDUE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.red)
                        } else if !task.isCompleted, let dueDate = task.dueDate {
                            Text("Due \(dueDate, style: .date)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if let completed = task.completedDate {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("Completed \(completed, style: .date)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
                
                VStack {
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

struct TaskSummaryView: View {
    let totalTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    
    private var completionPercentage: Double {
        totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(completedTasks)/\(totalTasks)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Overdue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(overdueTasks)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(overdueTasks > 0 ? .red : .secondary)
                }
            }
            
            ProgressView(value: completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Temporary placeholder views - these will be replaced with actual implementations
struct TaskCreateEditView: View {
    let project: Project
    let onSave: (ProjectTask) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .general
    @State private var estimatedHours = 1.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName)
                                .tag(priority)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    HStack {
                        Text("Estimated Hours")
                        Spacer()
                        TextField("Hours", value: $estimatedHours, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createTask() {
        let task = ProjectTask(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            category: category,
            estimatedHours: estimatedHours,
            projectID: project.id
        )
        
        onSave(task)
    }
}

struct TaskDetailView: View {
    let task: ProjectTask
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingEditTask = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Task Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Category", value: task.category.displayName, icon: task.category.icon)
                        DetailRow(title: "Priority", value: task.priority.displayName, icon: "exclamationmark.triangle.fill")
                        
                        if let dueDate = task.dueDate {
                            DetailRow(title: "Due Date", value: dueDate.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                        }
                        
                        DetailRow(title: "Estimated Hours", value: "\(String(format: "%.1f", task.estimatedHours)) hours", icon: "clock")
                        
                        if task.isCompleted, let completedDate = task.completedDate {
                            DetailRow(title: "Completed", value: completedDate.formatted(date: .abbreviated, time: .shortened), icon: "checkmark.circle.fill")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !task.isCompleted {
                            Button("Mark Complete") {
                                markTaskCompleted()
                            }
                        } else {
                            Button("Reopen Task") {
                                reopenTask()
                            }
                        }
                        
                        Button("Edit Task") {
                            showingEditTask = true
                        }
                        
                        Button("Delete Task", role: .destructive) {
                            deleteTask()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditTask) {
            // Placeholder for edit view
            Text("Edit Task Placeholder")
        }
    }
    
    private func markTaskCompleted() {
        guard let currentUserID = getCurrentUserID(),
              let project = projectVM.selectedProject else { return }
        
        var completedTask = task
        completedTask.markCompleted(by: [UUID(uuidString: currentUserID) ?? UUID()], notes: "Marked complete")
        
        Task {
            await projectVM.updateTask(completedTask, in: project.id)
        }
        dismiss()
    }
    
    private func reopenTask() {
        guard let project = projectVM.selectedProject else { return }
        
        var reopenedTask = task
        reopenedTask.isCompleted = false
        reopenedTask.completedDate = nil
        reopenedTask.completedByEmployeeIDs = []
        reopenedTask.completionNotes = ""
        reopenedTask.updatedAt = Date()
        
        Task {
            await projectVM.updateTask(reopenedTask, in: project.id)
        }
        dismiss()
    }
    
    private func deleteTask() {
        guard let project = projectVM.selectedProject else { return }
        
        Task {
            await projectVM.deleteTask(task, from: project.id)
        }
        dismiss()
    }
    
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct TasksListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TasksListView()
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        }
    }
}
