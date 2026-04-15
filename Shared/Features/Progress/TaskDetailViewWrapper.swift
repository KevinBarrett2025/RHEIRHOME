import SwiftUI
import OSLog

struct TaskDetailViewWrapper: View {
    let task: ProjectTask
    let project: Project
    let employees: [Employee]
    let onUpdate: (ProjectTask) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var selectedPhotoID: IdentifiableUUID?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with title and status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .strikethrough(task.isCompleted)
                            
                            Spacer()
                            
                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                        }
                        
                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Status and Priority Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Priority")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Circle()
                                    .fill(priorityColor)
                                    .frame(width: 12, height: 12)
                                Text(task.priority.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(task.dueDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(task.isOverdue && !task.isCompleted ? .red : .primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Category
                    HStack {
                        Image(systemName: task.category.icon)
                            .foregroundColor(.blue)
                        Text(task.category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Assigned Employees
                    if !task.assignedEmployeeIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assigned Employees")
                                .font(.headline)
                            
                            ForEach(assignedEmployees, id: \.id) { employee in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
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
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Photos using modern photoIDs system
                    if !task.photoIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos (\(task.photoIDs.count))")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(task.photoIDs, id: \.self) { photoID in
                                    AsyncTaskPhoto(photoID: photoID, taskID: task.id) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                selectedPhotoID = IdentifiableUUID(photoID)
                                            }
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 100)
                                            .overlay {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                            }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            showingEditView = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            TaskCreateEditView(
                project: project,
                employees: employees,
                existingTask: task,
                onSave: { updatedTask in
                    onUpdate(updatedTask)
                }
            )
        }
        .fullScreenCover(item: $selectedPhotoID) { identifiablePhotoID in
            AsyncTaskPhotoDetailView(photoID: identifiablePhotoID.id, taskID: task.id) {
                selectedPhotoID = nil
            }
        }
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this task? This action cannot be undone.")
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    private var assignedEmployees: [Employee] {
        task.assignedEmployeeIDs.compactMap { employeeID in
            employees.first { $0.id == employeeID }
        }
    }
}

// MARK: - Async Task Photo Loading Components

struct AsyncTaskPhoto<Content: View, Placeholder: View>: View {
    let photoID: UUID
    let taskID: UUID
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @StateObject private var photoService = CloudKitPhotoService()
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
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
        isLoading = true
        
        do {
            // Try to load the task photo from CloudKit
            let taskPhotos = try await photoService.fetchTaskPhotos(taskID: taskID)
            
            if let taskPhoto = taskPhotos.first(where: { $0.id == photoID }),
               let assetURL = taskPhoto.ckAssetURL {
                let imageData = try await photoService.downloadPhotoData(from: assetURL)
                
                if let uiImage = UIImage(data: imageData) {
                    await MainActor.run {
                        self.loadedImage = uiImage
                        self.isLoading = false
                    }
                }
            }
        } catch {
            Logger.cloudKitPhoto.error(
                "Failed to load task photo [taskID=\(taskID.uuidString, privacy: .private(mask: .hash)) photoID=\(photoID.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
            )
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct AsyncTaskPhotoDetailView: View {
    let photoID: UUID
    let taskID: UUID
    let onDismiss: () -> Void
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @StateObject private var photoService = CloudKitPhotoService()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let loadedImage = loadedImage {
                ZoomableImageView(image: loadedImage, onDismiss: onDismiss)
            } else if isLoading {
                ProgressView("Loading photo...")
                    .foregroundColor(.white)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Failed to load photo")
                        .foregroundColor(.gray)
                    
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
            }
        }
        .task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        isLoading = true
        
        do {
            let taskPhotos = try await photoService.fetchTaskPhotos(taskID: taskID)
            
            if let taskPhoto = taskPhotos.first(where: { $0.id == photoID }),
               let assetURL = taskPhoto.ckAssetURL {
                let imageData = try await photoService.downloadPhotoData(from: assetURL)
                
                if let uiImage = UIImage(data: imageData) {
                    await MainActor.run {
                        self.loadedImage = uiImage
                        self.isLoading = false
                    }
                }
            }
        } catch {
            Logger.cloudKitPhoto.error(
                "Failed to load task photo detail [taskID=\(taskID.uuidString, privacy: .private(mask: .hash)) photoID=\(photoID.uuidString, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .public)]"
            )
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
