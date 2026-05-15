import SwiftUI
import UIKit

struct TasksListView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showingNewTask = false
    @State private var showingCompletedTasks = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedTask: ProjectTask?
    @State private var taskPendingCompletion: ProjectTask?
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

    private var sectionTasks: [ProjectTask] {
        if selectedFilter == .all && !overdueTasks.isEmpty {
            return filteredTasks.filter { !$0.isOverdue || $0.isCompleted }
        }
        return filteredTasks
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Universal Header
                UniversalHeaderView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)

                taskControlBar
                
                mainContent
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search tasks...")
            .sheet(isPresented: $showingNewTask) {
                newTaskSheet
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
                    .environmentObject(projectVM)
            }
            .sheet(item: $taskPendingCompletion) { task in
                TaskCompletionEditor(task: task) { completedTask in
                    guard let project = projectVM.selectedProject else { return }
                    Task {
                        await projectVM.updateTask(completedTask, in: project.id)
                    }
                }
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
    
    private var taskControlBar: some View {
        HStack {
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
                Label(selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)
            
            Spacer()

            Button(action: { showingNewTask = true }) {
                Label("Add Task", systemImage: "plus")
            }
            .accessibilityIdentifier("tasks-add-button")
            .buttonStyle(.borderedProminent)
            .disabled(projectVM.selectedProject == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var newTaskSheet: some View {
        if let project = projectVM.selectedProject {
            TaskCreateEditView(project: project, task: nil, onSave: { task in
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
            
            if !sectionTasks.isEmpty {
                Section(sectionHeader) {
                    ForEach(sectionTasks) { task in
                        TaskRowView(task: task) {
                            selectedTask = task
                            showingTaskDetail = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !task.isCompleted {
                                Button("Complete") {
                                    taskPendingCompletion = task
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
                    WorkflowEmptyStateCard(
                        icon: "magnifyingglass.circle",
                        title: "No Matching Tasks",
                        message: "Try a different search term or clear the filter to see all project tasks.",
                        primaryActionTitle: "Clear Search",
                        primaryAction: {
                            searchText = ""
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
            return "All Other Tasks (\(sectionTasks.count))"
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
            message: "Choose a project before viewing or managing tasks.",
            actionTitle: "Go to Projects",
            action: {
                selectedTab = .projects
            }
        )
    }
    
    private var emptyTasksView: some View {
        Section {
            WorkflowEmptyStateCard(
                icon: "checklist",
                title: "No Tasks Yet",
                message: "Create your first task to organize scope, due dates, and work progress for this project.",
                primaryActionTitle: "Create First Task",
                primaryAction: {
                    showingNewTask = true
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    // MARK: - Task Actions
    
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
    
}

struct TaskRowView: View {
    let task: ProjectTask
    let onTap: () -> Void
    @EnvironmentObject var projectVM: ProjectViewModel
    
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

                    if !task.assignedEmployeeIDs.isEmpty {
                        Text(assigneeSummary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
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
        .accessibilityIdentifier("task-row-\(task.id.uuidString)")
    }
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private var assigneeSummary: String {
        let names = task.assignedEmployeeIDs.compactMap { projectVM.getTeamMember(by: $0)?.name }
        return names.isEmpty ? "Assigned worker unavailable" : "Assigned: \(names.joined(separator: ", "))"
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

struct TaskCreateEditView: View {
    let project: Project
    let task: ProjectTask?
    let onSave: (ProjectTask) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .general
    @State private var estimatedHours = 1.0
    @State private var selectedEmployeeIDs: Set<UUID> = []

    init(project: Project, task: ProjectTask?, onSave: @escaping (ProjectTask) -> Void) {
        self.project = project
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _priority = State(initialValue: task?.priority ?? .medium)
        _category = State(initialValue: task?.category ?? .general)
        _estimatedHours = State(initialValue: task?.estimatedHours ?? 1.0)
        _selectedEmployeeIDs = State(initialValue: Set(task?.assignedEmployeeIDs ?? []))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                        .accessibilityIdentifier("task-title-field")
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("task-description-field")
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

                Section("Assign Workers") {
                    let availableWorkers = projectVM.teamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }
                    if availableWorkers.isEmpty {
                        Text("No active workers available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableWorkers) { worker in
                            Button {
                                if selectedEmployeeIDs.contains(worker.id) {
                                    selectedEmployeeIDs.remove(worker.id)
                                } else {
                                    selectedEmployeeIDs.insert(worker.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name)
                                        Text(worker.jobTitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedEmployeeIDs.contains(worker.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedEmployeeIDs.contains(worker.id) ? .blue : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("task-worker-\(worker.id.uuidString)")
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
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
                    .accessibilityIdentifier("task-save-button")
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        let updatedTask = ProjectTask(
            id: task?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            isCompleted: task?.isCompleted ?? false,
            completedDate: task?.completedDate,
            priority: priority,
            category: category,
            estimatedHours: estimatedHours,
            actualHours: task?.actualHours ?? 0,
            projectID: project.id,
            budgetLineID: task?.budgetLineID,
            estimateVersionID: task?.estimateVersionID,
            phaseName: task?.phaseName,
            photoIDs: task?.photoIDs ?? [],
            assignedEmployeeIDs: Array(selectedEmployeeIDs),
            completedByEmployeeIDs: task?.completedByEmployeeIDs ?? [],
            completionNotes: task?.completionNotes ?? "",
            createdAt: task?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        onSave(updatedTask)
    }
}

struct TaskDetailView: View {
    let task: ProjectTask
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingEditTask = false
    @State private var showingCompletionSheet = false

    private var liveTask: ProjectTask {
        projectVM.selectedProject?.tasks.first(where: { $0.id == task.id }) ?? task
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(liveTask.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if liveTask.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if !liveTask.description.isEmpty {
                            Text(liveTask.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Task Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Category", value: liveTask.category.displayName, icon: liveTask.category.icon)
                        DetailRow(title: "Priority", value: liveTask.priority.displayName, icon: "exclamationmark.triangle.fill")
                        
                        if let dueDate = liveTask.dueDate {
                            DetailRow(title: "Due Date", value: dueDate.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                        }
                        
                        DetailRow(title: "Estimated Hours", value: "\(String(format: "%.1f", liveTask.estimatedHours)) hours", icon: "clock")

                        if !liveTask.assignedEmployeeIDs.isEmpty {
                            DetailRow(title: "Assigned", value: assigneeSummary, icon: "person.2.fill")
                        }
                        
                        if liveTask.isCompleted, let completedDate = liveTask.completedDate {
                            DetailRow(title: "Completed", value: completedDate.formatted(date: .abbreviated, time: .shortened), icon: "checkmark.circle.fill")
                        }

                        if liveTask.isCompleted, !liveTask.completedByEmployeeIDs.isEmpty {
                            DetailRow(title: "Completed By", value: completedBySummary, icon: "person.crop.circle.badge.checkmark")
                        }

                        if !liveTask.photoIDs.isEmpty {
                            DetailRow(title: "Photo Proof", value: "\(liveTask.photoIDs.count)", icon: "photo.on.rectangle.angled")
                        }

                        if !liveTask.completionNotes.isEmpty {
                            DetailRow(title: "Proof Notes", value: liveTask.completionNotes, icon: "note.text")
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
                        if !liveTask.isCompleted {
                            Button("Mark Complete") {
                                showingCompletionSheet = true
                            }
                        } else {
                            Button("Reopen Task") {
                                reopenTask()
                            }
                            .accessibilityIdentifier("task-reopen-button")
                        }
                        
                        Button("Edit Task") {
                            showingEditTask = true
                        }
                        .accessibilityIdentifier("task-edit-button")
                        
                        Button("Delete Task", role: .destructive) {
                            deleteTask()
                        }
                        .accessibilityIdentifier("task-delete-button")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("task-detail-menu")
                }
            }
        }
        .sheet(isPresented: $showingEditTask) {
            if let project = projectVM.selectedProject {
                TaskCreateEditView(project: project, task: liveTask) { updatedTask in
                    Task {
                        await projectVM.updateTask(updatedTask, in: project.id)
                    }
                    showingEditTask = false
                }
                .environmentObject(projectVM)
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            TaskCompletionEditor(task: liveTask) { completedTask in
                guard let project = projectVM.selectedProject else { return }
                Task {
                    await projectVM.updateTask(completedTask, in: project.id)
                }
                showingCompletionSheet = false
                dismiss()
            }
            .environmentObject(projectVM)
        }
    }
    
    private func reopenTask() {
        guard let project = projectVM.selectedProject else { return }
        
        var reopenedTask = liveTask
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
            await projectVM.deleteTask(liveTask, from: project.id)
        }
        dismiss()
    }
    
    private var assigneeSummary: String {
        let names = liveTask.assignedEmployeeIDs.compactMap { projectVM.getTeamMember(by: $0)?.name }
        return names.isEmpty ? "Unavailable" : names.joined(separator: ", ")
    }

    private var completedBySummary: String {
        let names = liveTask.completedByEmployeeIDs.compactMap { projectVM.getTeamMember(by: $0)?.name }
        return names.isEmpty ? "Unavailable" : names.joined(separator: ", ")
    }
}

private struct TaskCompletionEditor: View {
    let task: ProjectTask
    let onComplete: (ProjectTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var selectedEmployeeIDs: Set<UUID>
    @State private var completionNotes: String
    @State private var completedAt: Date
    @State private var selectedProofImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isUploadingPhoto = false
    @State private var uploadErrorMessage: String?
    @StateObject private var photoService = CloudKitPhotoService()

    init(task: ProjectTask, onComplete: @escaping (ProjectTask) -> Void) {
        self.task = task
        self.onComplete = onComplete
        _selectedEmployeeIDs = State(initialValue: Set(task.assignedEmployeeIDs))
        _completionNotes = State(initialValue: task.completionNotes)
        _completedAt = State(initialValue: task.completedDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    Text(task.title)
                        .font(.headline)
                    if !task.description.isEmpty {
                        Text(task.description)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Completed By") {
                    let activeWorkers = projectVM.teamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }
                    if activeWorkers.isEmpty {
                        Text("No active workers available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(activeWorkers) { worker in
                            Button {
                                if selectedEmployeeIDs.contains(worker.id) {
                                    selectedEmployeeIDs.remove(worker.id)
                                } else {
                                    selectedEmployeeIDs.insert(worker.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name)
                                        Text(worker.jobTitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedEmployeeIDs.contains(worker.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedEmployeeIDs.contains(worker.id) ? .green : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("task-completion-worker-\(worker.id.uuidString)")
                        }
                    }
                }

                Section("Completion Proof") {
                    DatePicker("Completed At", selection: $completedAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("Completion notes", text: $completionNotes, axis: .vertical)
                        .lineLimit(2...5)

                    if trimmedCompletionNotes.isEmpty {
                        Label("Add proof notes before completing this task.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if let selectedProofImage {
                        Image(uiImage: selectedProofImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(8)
                            .accessibilityIdentifier("task-proof-photo-preview")
                    }

                    Button {
                        showingImagePicker = true
                    } label: {
                        Label(
                            selectedProofImage == nil ? "Add Photo Proof" : "Replace Photo Proof",
                            systemImage: "camera.fill"
                        )
                    }
                    .accessibilityIdentifier("task-proof-photo-button")

                    if let uploadErrorMessage {
                        Text(uploadErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Complete") {
                        Task {
                            await completeTask()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCompleteTask || isUploadingPhoto)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, image: $selectedProofImage)
        }
    }

    private var trimmedCompletionNotes: String {
        completionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCompleteTask: Bool {
        !selectedEmployeeIDs.isEmpty && !trimmedCompletionNotes.isEmpty
    }

    private func completeTask() async {
        guard canCompleteTask else { return }

        var completedTask = task
        if let selectedProofImage {
            guard let imageData = selectedProofImage.jpegData(compressionQuality: 0.82),
                  let project = projectVM.selectedProject,
                  let organizationID = UUID(uuidString: project.organizationID) else {
                uploadErrorMessage = "Photo proof could not be prepared for upload."
                return
            }

            isUploadingPhoto = true
            defer { isUploadingPhoto = false }

            do {
                let uploadedPhoto = try await photoService.uploadTaskPhoto(
                    imageData: imageData,
                    taskID: task.id,
                    projectID: project.id,
                    organizationID: organizationID,
                    caption: trimmedCompletionNotes
                )
                completedTask.addPhoto(uploadedPhoto.id)
            } catch {
                uploadErrorMessage = "Photo proof upload failed. Try again before completing."
                return
            }
        }

        completedTask.markCompleted(
            by: Array(selectedEmployeeIDs),
            notes: trimmedCompletionNotes
        )
        completedTask.completedDate = completedAt
        onComplete(completedTask)
        dismiss()
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
            TasksListView(selectedTab: .constant(.tasks))
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
                .environmentObject(AuthViewModel(service: PreviewAuthService()))
        }
    }
}
