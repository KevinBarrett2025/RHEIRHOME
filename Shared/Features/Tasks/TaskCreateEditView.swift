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
    
    // Photo management
    @State private var taskImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingDeleteAlert = false
    @State private var imageToDelete: Int?
    @StateObject private var cameraPerm = CameraPermission()
    
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
            _dueDate = State(initialValue: task.dueDate ?? Date())
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
                    photoManagementSection
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
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    sourceType: imagePickerSource,
                    image: Binding(
                        get: { nil },
                        set: { if let img = $0 { taskImages.append(img) } }
                    )
                )
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    imageToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let index = imageToDelete {
                        taskImages.remove(at: index)
                        imageToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this photo?")
            }
            .alert("Camera Access Needed", isPresented: $cameraPerm.showSettingsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Settings") { cameraPerm.openSettings() }
            } message: {
                Text("Please allow camera access in Settings to take photos for this task.")
            }
        }
    }
    
    @ViewBuilder
    private var photoManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if taskImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("Add Before/After Photos")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Document task progress and completion with photos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(taskImages.indices, id: \.self) { index in
                            taskPhotoView(image: taskImages[index], index: index)
                        }
                        
                        // Add more photos button
                        addPhotoButtons
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            if taskImages.isEmpty {
                photoActionButtons
            }
        }
    }
    
    @ViewBuilder
    private func taskPhotoView(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            // Delete button with small X
            Button {
                imageToDelete = index
                showingDeleteAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .red)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            }
            .offset(x: 6, y: -6)
        }
    }
    
    @ViewBuilder
    private var addPhotoButtons: some View {
        HStack(spacing: 12) {
            // Camera button
            Button {
                requestCameraAccess()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Camera")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Photo library button
            Button {
                imagePickerSource = .photoLibrary
                showingImagePicker = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Photos")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .frame(width: 80, height: 80)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var photoActionButtons: some View {
        HStack(spacing: 16) {
            Button {
                requestCameraAccess()
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
            
            Button {
                imagePickerSource = .photoLibrary
                showingImagePicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Actions
    
    private func requestCameraAccess() {
        cameraPerm.requestAccess { granted in
            guard granted,
                  UIImagePickerController.isSourceTypeAvailable(.camera) else { 
                return 
            }
            imagePickerSource = .camera
            showingImagePicker = true
        }
    }
    
    private func saveTask() {
        // TODO: Upload images and get photo IDs
        let photoIDs: [UUID] = [] // Will be populated when photo service is implemented
        
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
            projectID: project?.id ?? UUID(),
            photoIDs: photoIDs,
            assignedEmployeeIDs: Array(selectedEmployeeIDs),
            completedByEmployeeIDs: existingTask?.completedByEmployeeIDs ?? [],
            completionNotes: existingTask?.completionNotes ?? "",
            createdAt: existingTask?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        print("✅ Task '\(task.title)' saved with \(taskImages.count) photos (upload pending)")
        onSave(task)
        dismiss()
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
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