import SwiftUI
import UIKit
import PhotosUI
import OSLog

private struct TaskPhotoIndexSelection: Identifiable {
    let id = UUID()
    let index: Int
}

private struct TaskPhotoGallerySelection: Identifiable {
    let id = UUID()
    let title: String
    let taskID: UUID
    let pages: [TaskPhotoStoryPage]
    let initialIndex: Int
}

enum TaskPhotoGroup {
    case before
    case after

    var title: String {
        switch self {
        case .before:
            return "Before Photos"
        case .after:
            return "After Photos"
        }
    }

    func storyTitle(for taskTitle: String) -> String {
        "\(title) — \(taskTitle)"
    }

    var storySubtitle: String {
        switch self {
        case .before:
            return "Scope reference before work starts"
        case .after:
            return "Completion proof after work is finished"
        }
    }

    var systemImage: String {
        switch self {
        case .before:
            return "camera.viewfinder"
        case .after:
            return "checkmark.seal"
        }
    }

    var deleteAccessibilityPrefix: String {
        switch self {
        case .before:
            return "task-before-photo-delete"
        case .after:
            return "task-after-photo-delete"
        }
    }
}

enum TaskPhotoStoryPage: Identifiable, Equatable {
    case title(id: String, title: String, subtitle: String, systemImage: String)
    case photo(UUID)

    var id: String {
        switch self {
        case .title(let id, _, _, _):
            return id
        case .photo(let photoID):
            return "photo-\(photoID.uuidString)"
        }
    }
}

enum TaskPhotoStoryPageBuilder {
    static func pages(for task: ProjectTask) -> [TaskPhotoStoryPage] {
        var pages: [TaskPhotoStoryPage] = []

        if !task.photoIDs.isEmpty {
            pages.append(titlePage(for: .before, taskTitle: task.title))
            pages.append(contentsOf: task.photoIDs.map(TaskPhotoStoryPage.photo))
        }

        if !task.completionPhotoIDs.isEmpty {
            pages.append(titlePage(for: .after, taskTitle: task.title))
            pages.append(contentsOf: task.completionPhotoIDs.map(TaskPhotoStoryPage.photo))
        }

        return pages
    }

    static func initialIndex(for group: TaskPhotoGroup, photoIndex: Int, in task: ProjectTask) -> Int {
        switch group {
        case .before:
            guard !task.photoIDs.isEmpty else { return 0 }
            return min(max(photoIndex, 0), task.photoIDs.count - 1) + 1
        case .after:
            let beforeOffset = task.photoIDs.isEmpty ? 0 : task.photoIDs.count + 1
            guard !task.completionPhotoIDs.isEmpty else { return beforeOffset }
            return beforeOffset + 1 + min(max(photoIndex, 0), task.completionPhotoIDs.count - 1)
        }
    }

    private static func titlePage(for group: TaskPhotoGroup, taskTitle: String) -> TaskPhotoStoryPage {
        .title(
            id: "\(group)-title",
            title: group.storyTitle(for: taskTitle),
            subtitle: group.storySubtitle,
            systemImage: group.systemImage
        )
    }
}

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
            if !tasks.isEmpty {
                Section("Summary") {
                    TaskSummaryView(
                        totalTasks: tasks.count,
                        completedTasks: completedTasks.count,
                        overdueTasks: overdueTasks.count
                    )
                    .accessibilityIdentifier("tasks-summary-card")
                }
            }

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
            TaskPriorityRow(
                title: task.title,
                isCompleted: task.isCompleted,
                description: task.description.isEmpty ? nil : task.description,
                assigneeSummary: task.assignedEmployeeIDs.isEmpty ? nil : assigneeSummary,
                categorySystemImage: task.category.icon,
                showsPhotoIndicator: task.hasPhotos,
                priorityBadge: priorityBadge,
                statusBadge: statusBadge
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("task-row-\(task.id.uuidString)")
    }

    private var priorityBadge: TaskPriorityRow.PriorityBadge {
        TaskPriorityRow.PriorityBadge(
            label: task.priority.displayName,
            systemImage: "exclamationmark.triangle.fill",
            style: priorityStyle
        )
    }

    private var priorityStyle: RheirStatusChip.Style {
        switch task.priority {
        case .low: return .paid
        case .medium: return .selected
        case .high: return .warning
        case .urgent: return .pastDue
        }
    }

    private var statusBadge: TaskPriorityRow.StatusBadge? {
        if task.isOverdue && !task.isCompleted {
            return TaskPriorityRow.StatusBadge(
                label: Text("OVERDUE"),
                systemImage: "clock.badge.exclamationmark",
                style: .pastDue
            )
        } else if !task.isCompleted, let dueDate = task.dueDate {
            return TaskPriorityRow.StatusBadge(
                label: Text("Due \(dueDate, style: .date)"),
                systemImage: nil,
                style: .neutral
            )
        } else if let completed = task.completedDate {
            return TaskPriorityRow.StatusBadge(
                label: Text("Completed \(completed, style: .date)"),
                systemImage: "checkmark.circle.fill",
                style: .paid
            )
        }

        return nil
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
    @StateObject private var photoService = CloudKitPhotoService()
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .general
    @State private var estimatedHours = 1.0
    @State private var selectedEmployeeIDs: Set<UUID> = []
    @State private var selectedBeforeImages: [UIImage] = []
    @State private var selectedBeforePhotoItems: [PhotosPickerItem] = []
    @State private var selectedBeforeImageGallery: TaskPhotoIndexSelection?
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    @State private var isUploadingPhotos = false
    @State private var uploadErrorMessage: String?
    private let taskID: UUID

    init(project: Project, task: ProjectTask?, onSave: @escaping (ProjectTask) -> Void) {
        self.project = project
        self.task = task
        self.onSave = onSave
        self.taskID = task?.id ?? UUID()
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

                beforePhotosSection
                
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
                        Task {
                            await saveTask()
                        }
                    }
                    .accessibilityIdentifier("task-save-button")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUploadingPhotos)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, image: $cameraImage)
        }
        .onChange(of: selectedBeforePhotoItems) { _, newItems in
            Task {
                await appendImages(from: newItems)
            }
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            selectedBeforeImages.append(image)
            cameraImage = nil
        }
        .fullScreenCover(item: $selectedBeforeImageGallery) { selection in
            TaskLocalPhotoGalleryView(
                title: "Before Photos",
                images: selectedBeforeImages,
                initialIndex: selection.index
            ) {
                selectedBeforeImageGallery = nil
            }
        }
    }

    private var beforePhotosSection: some View {
        Section("Before Photos") {
            Text("Add photos that explain the work scope before the task starts.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let task, !task.photoIDs.isEmpty {
                Text("\(task.photoIDs.count) saved before photo\(task.photoIDs.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !selectedBeforeImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedBeforeImages.enumerated()), id: \.offset) { index, image in
                            TaskLocalPhotoThumbnail(
                                image: image,
                                openAccessibilityIdentifier: "task-before-photo-thumbnail-\(index)",
                                deleteAccessibilityIdentifier: "task-before-photo-delete-\(index)",
                                onOpen: {
                                    selectedBeforeImageGallery = TaskPhotoIndexSelection(index: index)
                                },
                                onDelete: {
                                    selectedBeforeImages.remove(at: index)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("task-before-photo-preview")
            }

            Button {
                showingCamera = true
            } label: {
                Label("Take Before Photo", systemImage: "camera.fill")
            }
            .accessibilityIdentifier("task-before-camera-button")
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            PhotosPicker(
                selection: $selectedBeforePhotoItems,
                maxSelectionCount: 12,
                matching: .images
            ) {
                Label("Choose Before Photos", systemImage: "photo.on.rectangle.angled")
                    .accessibilityIdentifier("task-before-library-button")
            }
            .accessibilityIdentifier("task-before-library-button")

            if isUploadingPhotos {
                Label("Saving photos locally...", systemImage: "externaldrive.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !selectedBeforeImages.isEmpty {
                Label("Photos save locally first. Cloud sync continues in the background.", systemImage: "icloud.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let uploadErrorMessage {
                Text(uploadErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func saveTask() async {
        var photoIDs = task?.photoIDs ?? []

        if !selectedBeforeImages.isEmpty {
            guard let organizationID = UUID(uuidString: project.organizationID) else {
                uploadErrorMessage = "Before photos could not be prepared for upload."
                return
            }

            isUploadingPhotos = true
            defer { isUploadingPhotos = false }

            do {
                let savedPhotos = try saveImagesLocallyAndStartCloudSync(
                    selectedBeforeImages,
                    taskID: taskID,
                    projectID: project.id,
                    organizationID: organizationID,
                    caption: "Before task photo"
                )
                photoIDs.append(contentsOf: savedPhotos.map(\.id))
            } catch {
                uploadErrorMessage = "Before photos could not be saved locally. Try again."
                return
            }
        }

        let updatedTask = ProjectTask(
            id: taskID,
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
            photoIDs: uniquePhotoIDs(photoIDs),
            completionPhotoIDs: task?.completionPhotoIDs ?? [],
            assignedEmployeeIDs: Array(selectedEmployeeIDs),
            completedByEmployeeIDs: task?.completedByEmployeeIDs ?? [],
            completionNotes: task?.completionNotes ?? "",
            createdAt: task?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        onSave(updatedTask)
    }

    private func uniquePhotoIDs(_ photoIDs: [UUID]) -> [UUID] {
        var seenPhotoIDs = Set<UUID>()
        return photoIDs.filter { seenPhotoIDs.insert($0).inserted }
    }

    private func appendImages(from items: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loadedImages.append(image)
            }
        }

        await MainActor.run {
            selectedBeforeImages.append(contentsOf: loadedImages)
            selectedBeforePhotoItems = []
        }
    }

    private func saveImagesLocallyAndStartCloudSync(
        _ images: [UIImage],
        taskID: UUID,
        projectID: UUID,
        organizationID: UUID,
        caption: String
    ) throws -> [TaskPhoto] {
        var savedPhotos: [TaskPhoto] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.82) else {
                throw CocoaError(.fileWriteUnknown)
            }

            let savedPhoto = try photoService.storeTaskPhotoLocally(
                imageData: imageData,
                taskID: taskID,
                projectID: projectID,
                organizationID: organizationID,
                fileName: "task_\(taskID.uuidString)_before_\(index)_\(Date().timeIntervalSince1970).jpg",
                caption: caption
            )
            savedPhotos.append(savedPhoto)
            syncTaskPhotoInBackground(savedPhoto)
        }
        return savedPhotos
    }

    private func syncTaskPhotoInBackground(_ taskPhoto: TaskPhoto) {
        Task {
            do {
                _ = try await photoService.uploadStoredTaskPhoto(taskPhoto)
            } catch {
                Logger.cloudKitPhoto.error(
                    "Task photo CloudKit sync failed [photo=\(taskPhoto.id.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
                )
            }
        }
    }
}

struct TaskDetailView: View {
    let task: ProjectTask
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showingEditTask = false
    @State private var showingCompletionSheet = false
    @State private var selectedPhotoGallery: TaskPhotoGallerySelection?
    @StateObject private var photoService = CloudKitPhotoService()

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

                        if !liveTask.completionNotes.isEmpty {
                            DetailRow(title: "Proof Notes", value: liveTask.completionNotes, icon: "note.text")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if !liveTask.photoIDs.isEmpty {
                        TaskPhotoGridSection(
                            title: "Before Photos",
                            subtitle: "Work-scope reference",
                            photoIDs: liveTask.photoIDs,
                            taskID: liveTask.id,
                            deleteAccessibilityPrefix: TaskPhotoGroup.before.deleteAccessibilityPrefix,
                            onOpenPhoto: { index in
                                selectedPhotoGallery = TaskPhotoGallerySelection(
                                    title: "Task Photos",
                                    taskID: liveTask.id,
                                    pages: TaskPhotoStoryPageBuilder.pages(for: liveTask),
                                    initialIndex: TaskPhotoStoryPageBuilder.initialIndex(for: .before, photoIndex: index, in: liveTask)
                                )
                            },
                            onDeletePhoto: { photoID in
                                deleteSavedPhoto(photoID, from: .before)
                            }
                        )
                    }

                    if !liveTask.completionPhotoIDs.isEmpty {
                        TaskPhotoGridSection(
                            title: "After Photos",
                            subtitle: "Completion proof",
                            photoIDs: liveTask.completionPhotoIDs,
                            taskID: liveTask.id,
                            deleteAccessibilityPrefix: TaskPhotoGroup.after.deleteAccessibilityPrefix,
                            onOpenPhoto: { index in
                                selectedPhotoGallery = TaskPhotoGallerySelection(
                                    title: "Task Photos",
                                    taskID: liveTask.id,
                                    pages: TaskPhotoStoryPageBuilder.pages(for: liveTask),
                                    initialIndex: TaskPhotoStoryPageBuilder.initialIndex(for: .after, photoIndex: index, in: liveTask)
                                )
                            },
                            onDeletePhoto: { photoID in
                                deleteSavedPhoto(photoID, from: .after)
                            }
                        )
                    }
                    
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
        .safeAreaInset(edge: .bottom) {
            if !liveTask.isCompleted {
                markCompleteBar
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
        .fullScreenCover(item: $selectedPhotoGallery) { selection in
            TaskRemotePhotoGalleryView(
                title: selection.title,
                pages: selection.pages,
                initialIndex: selection.initialIndex
            ) {
                selectedPhotoGallery = nil
            }
        }
    }

    private var markCompleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showingCompletionSheet = true
            } label: {
                Label("Mark Complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .accessibilityIdentifier("task-detail-mark-complete-button")
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
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

    private func deleteSavedPhoto(_ photoID: UUID, from group: TaskPhotoGroup) {
        guard let project = projectVM.selectedProject else { return }

        var updatedTask = liveTask
        switch group {
        case .before:
            updatedTask.removePhoto(photoID)
        case .after:
            updatedTask.removeCompletionPhoto(photoID)
        }

        Task {
            await projectVM.updateTask(updatedTask, in: project.id)
            do {
                try await photoService.deleteTaskPhotos(photoIDs: [photoID])
            } catch {
                Logger.cloudKitPhoto.error(
                    "Failed to delete task photo asset [task=\(updatedTask.id.uuidString, privacy: .private(mask: .hash)) photo=\(photoID.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
                )
            }
        }
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
    @State private var selectedProofImages: [UIImage] = []
    @State private var selectedProofPhotoItems: [PhotosPickerItem] = []
    @State private var selectedProofImageGallery: TaskPhotoIndexSelection?
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
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

                    if !selectedProofImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(selectedProofImages.enumerated()), id: \.offset) { index, image in
                                    TaskLocalPhotoThumbnail(
                                        image: image,
                                        openAccessibilityIdentifier: "task-proof-photo-thumbnail-\(index)",
                                        deleteAccessibilityIdentifier: "task-proof-photo-delete-\(index)",
                                        onOpen: {
                                            selectedProofImageGallery = TaskPhotoIndexSelection(index: index)
                                        },
                                        onDelete: {
                                            selectedProofImages.remove(at: index)
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("task-proof-photo-preview")
                    }

                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take After Photo", systemImage: "camera.fill")
                    }
                    .accessibilityIdentifier("task-proof-photo-button")
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                    PhotosPicker(
                        selection: $selectedProofPhotoItems,
                        maxSelectionCount: 12,
                        matching: .images
                    ) {
                        Label("Choose After Photos", systemImage: "photo.on.rectangle.angled")
                            .accessibilityIdentifier("task-proof-library-button")
                    }
                    .accessibilityIdentifier("task-proof-library-button")

                    if isUploadingPhoto {
                        Label("Saving photos locally...", systemImage: "externaldrive.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !selectedProofImages.isEmpty {
                        Label("Photos save locally first. Cloud sync continues in the background.", systemImage: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

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
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, image: $cameraImage)
        }
        .onChange(of: selectedProofPhotoItems) { _, newItems in
            Task {
                await appendImages(from: newItems)
            }
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            selectedProofImages.append(image)
            cameraImage = nil
        }
        .fullScreenCover(item: $selectedProofImageGallery) { selection in
            TaskLocalPhotoGalleryView(
                title: "After Photos",
                images: selectedProofImages,
                initialIndex: selection.index
            ) {
                selectedProofImageGallery = nil
            }
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
        if !selectedProofImages.isEmpty {
            guard let project = projectVM.selectedProject,
                  let organizationID = UUID(uuidString: project.organizationID) else {
                uploadErrorMessage = "Photo proof could not be prepared for upload."
                return
            }

            isUploadingPhoto = true
            defer { isUploadingPhoto = false }

            do {
                let savedPhotos = try saveImagesLocallyAndStartCloudSync(
                    selectedProofImages,
                    taskID: task.id,
                    projectID: project.id,
                    organizationID: organizationID,
                    caption: trimmedCompletionNotes
                )
                for savedPhoto in savedPhotos {
                    completedTask.addCompletionPhoto(savedPhoto.id)
                }
            } catch {
                uploadErrorMessage = "Photo proof could not be saved locally. Try again."
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

    private func appendImages(from items: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loadedImages.append(image)
            }
        }

        await MainActor.run {
            selectedProofImages.append(contentsOf: loadedImages)
            selectedProofPhotoItems = []
        }
    }

    private func saveImagesLocallyAndStartCloudSync(
        _ images: [UIImage],
        taskID: UUID,
        projectID: UUID,
        organizationID: UUID,
        caption: String
    ) throws -> [TaskPhoto] {
        var savedPhotos: [TaskPhoto] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.82) else {
                throw CocoaError(.fileWriteUnknown)
            }

            let savedPhoto = try photoService.storeTaskPhotoLocally(
                imageData: imageData,
                taskID: taskID,
                projectID: projectID,
                organizationID: organizationID,
                fileName: "task_\(taskID.uuidString)_after_\(index)_\(Date().timeIntervalSince1970).jpg",
                caption: caption
            )
            savedPhotos.append(savedPhoto)
            syncTaskPhotoInBackground(savedPhoto)
        }
        return savedPhotos
    }

    private func syncTaskPhotoInBackground(_ taskPhoto: TaskPhoto) {
        Task {
            do {
                _ = try await photoService.uploadStoredTaskPhoto(taskPhoto)
            } catch {
                Logger.cloudKitPhoto.error(
                    "Task photo CloudKit sync failed [photo=\(taskPhoto.id.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
                )
            }
        }
    }
}

private struct TaskPhotoGridSection: View {
    let title: String
    let subtitle: String
    let photoIDs: [UUID]
    let taskID: UUID
    let deleteAccessibilityPrefix: String
    let onOpenPhoto: (Int) -> Void
    let onDeletePhoto: (UUID) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(photoIDs.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(photoIDs.enumerated()), id: \.element) { index, photoID in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            onOpenPhoto(index)
                        } label: {
                            TaskAsyncPhoto(photoID: photoID, taskID: taskID) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 92)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(8)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 92)
                                    .overlay {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("task-photo-\(photoID.uuidString)")
                        .overlay(alignment: .bottomLeading) {
                            TaskPhotoSyncBadge(photoID: photoID)
                                .padding(5)
                        }

                        TaskPhotoDeleteButton(accessibilityIdentifier: "\(deleteAccessibilityPrefix)-\(index)") {
                            onDeletePhoto(photoID)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct TaskPhotoSyncBadge: View {
    let photoID: UUID

    @State private var statusText: String?
    @StateObject private var photoService = CloudKitPhotoService()

    var body: some View {
        Group {
            if let statusText {
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(Capsule().fill(statusText == "Sync failed" ? Color.red.opacity(0.88) : Color.black.opacity(0.68)))
            }
        }
        .task {
            refreshStatus()
        }
    }

    private func refreshStatus() {
        guard let localPhoto = try? photoService.localTaskPhoto(photoID: photoID),
              !localPhoto.isUploaded else {
            statusText = nil
            return
        }

        statusText = localPhoto.uploadProgress < 0 ? "Sync failed" : "Sync pending"
    }
}

private struct TaskLocalPhotoThumbnail: View {
    let image: UIImage
    let openAccessibilityIdentifier: String
    let deleteAccessibilityIdentifier: String
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipped()
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(openAccessibilityIdentifier)

            TaskPhotoDeleteButton(accessibilityIdentifier: deleteAccessibilityIdentifier, action: onDelete)
        }
        .frame(width: 88, height: 88)
    }
}

private struct TaskPhotoDeleteButton: View {
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.red)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                .padding(4)
                .background(Circle().fill(Color(.systemBackground).opacity(0.85)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete photo")
        .accessibilityIdentifier(accessibilityIdentifier)
        .offset(x: 7, y: -7)
    }
}

private struct TaskAsyncPhoto<Content: View, Placeholder: View>: View {
    let photoID: UUID
    let taskID: UUID
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @StateObject private var photoService = CloudKitPhotoService()

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task {
            await loadPhoto()
        }
    }

    private func loadPhoto() async {
        do {
            guard let image = try await photoService.downloadTaskPhoto(photoID: photoID) else { return }
            await MainActor.run {
                loadedImage = image
            }
        } catch {
            Logger.cloudKitPhoto.error(
                "Failed to load task photo [task=\(taskID.uuidString, privacy: .private(mask: .hash)) photo=\(photoID.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
            )
        }
    }
}

private struct TaskLocalPhotoGalleryView: View {
    let title: String
    let images: [UIImage]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var selectedIndex: Int

    init(title: String, images: [UIImage], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.title = title
        self.images = images
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: TaskLocalPhotoGalleryView.clampedIndex(initialIndex, count: images.count))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if images.isEmpty {
                TaskPhotoGalleryUnavailableView(onDismiss: onDismiss)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZoomableImageView(image: image, showsDismissButton: false, allowsPageSwipeAtMinimumZoom: true)
                            .tag(index)
                            .ignoresSafeArea()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            }

            TaskPhotoGalleryChrome(
                title: title,
                selectedIndex: selectedIndex,
                count: images.count,
                onDismiss: onDismiss
            )
        }
    }

    private static func clampedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }
}

private struct TaskRemotePhotoGalleryView: View {
    let title: String
    let pages: [TaskPhotoStoryPage]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var selectedIndex: Int
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var failedPhotoIDs: Set<UUID> = []
    @StateObject private var photoService = CloudKitPhotoService()

    init(title: String, pages: [TaskPhotoStoryPage], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.title = title
        self.pages = pages
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _selectedIndex = State(initialValue: TaskRemotePhotoGalleryView.clampedIndex(initialIndex, count: pages.count))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if pages.isEmpty {
                TaskPhotoGalleryUnavailableView(onDismiss: onDismiss)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        switch page {
                        case .title(_, let title, let subtitle, let systemImage):
                            TaskPhotoStoryTitleCard(
                                title: title,
                                subtitle: subtitle,
                                systemImage: systemImage
                            )
                            .tag(index)
                        case .photo(let photoID):
                            TaskPhotoGalleryPage(
                                image: loadedImages[photoID],
                                didFail: failedPhotoIDs.contains(photoID),
                                onDismiss: onDismiss
                            )
                            .tag(index)
                            .task {
                                await loadPhoto(photoID)
                            }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
            }

            TaskPhotoGalleryChrome(
                title: title,
                selectedIndex: selectedIndex,
                count: pages.count,
                onDismiss: onDismiss
            )
        }
    }

    private static func clampedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    private func loadPhoto(_ photoID: UUID) async {
        guard loadedImages[photoID] == nil, !failedPhotoIDs.contains(photoID) else { return }

        do {
            guard let image = try await photoService.downloadTaskPhoto(photoID: photoID) else {
                await MainActor.run {
                    _ = failedPhotoIDs.insert(photoID)
                }
                return
            }

            await MainActor.run {
                loadedImages[photoID] = image
            }
        } catch {
            Logger.cloudKitPhoto.error(
                "Failed to load task gallery photo [photo=\(photoID.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
            )
            await MainActor.run {
                _ = failedPhotoIDs.insert(photoID)
            }
        }
    }
}

private struct TaskPhotoGalleryPage: View {
    let image: UIImage?
    let didFail: Bool
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if let image {
                ZoomableImageView(image: image, showsDismissButton: false, allowsPageSwipeAtMinimumZoom: true)
                    .ignoresSafeArea()
            } else if didFail {
                TaskPhotoGalleryUnavailableView(onDismiss: onDismiss)
            } else {
                ProgressView("Loading photo...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
    }
}

private struct TaskPhotoStoryTitleCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

private struct TaskPhotoGalleryUnavailableView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 56))
                .foregroundColor(.gray)
            Text("Photo could not be loaded")
                .foregroundColor(.gray)
            Button("Close") {
                onDismiss()
            }
            .foregroundColor(.white)
        }
    }
}

private struct TaskPhotoGalleryChrome: View {
    let title: String
    let selectedIndex: Int
    let count: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    if count > 0 {
                        Text("\(selectedIndex + 1) of \(count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("zoomable-image-close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.78), .black.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )

            Spacer()
        }
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
