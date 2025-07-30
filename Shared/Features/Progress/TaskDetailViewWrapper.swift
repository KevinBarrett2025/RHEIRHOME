import SwiftUI

struct TaskDetailViewWrapper: View {
    let task: ProjectTask
    let project: Project
    let employees: [Employee]
    let onUpdate: (ProjectTask) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var selectedImageIndex: IdentifiableInt?
    
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
                    
                    // Photos
                    if !task.imageDatas.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(task.imageDatas.enumerated()), id: \.offset) { index, imageData in
                                    if let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                selectedImageIndex = IdentifiableInt(index)
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
        .fullScreenCover(item: $selectedImageIndex) { identifiableIndex in
            if let imageData = task.imageDatas[safe: identifiableIndex.id],
               let uiImage = UIImage(data: imageData) {
                ZoomableImageView(image: uiImage) {
                    selectedImageIndex = nil
                }
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
        case .critical: return .red
        }
    }
    
    private var assignedEmployees: [Employee] {
        task.assignedEmployeeIDs.compactMap { employeeID in
            employees.first { $0.id == employeeID }
        }
    }
}