import SwiftUI

struct TaskCompletionView: View {
    let task: ProjectTask
    let employees: [Employee]
    let onComplete: (ProjectTask) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmployeeIDs: Set<UUID> = []
    @State private var completionNotes = ""
    @State private var completionDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.headline)
                        
                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: task.category.icon)
                                .foregroundColor(.blue)
                            Text(task.category.rawValue)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Circle()
                                .fill(priorityColor)
                                .frame(width: 12, height: 12)
                            Text(task.priority.rawValue)
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Task Details")
                }
                
                Section("Who completed this task?") {
                    if employees.isEmpty {
                        Text("No employees available")
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
                    
                    if selectedEmployeeIDs.isEmpty {
                        Text("Please select at least one employee")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Completion Details") {
                    DatePicker("Completed on", selection: $completionDate, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Add notes about the completion...", text: $completionNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if !task.imageDatas.isEmpty {
                    Section("Task Photos") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(task.imageDatas.enumerated()), id: \.offset) { index, imageData in
                                    if let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }

                if !task.description.isEmpty {
                    Text(task.description)
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
                        completeTask()
                    }
                    .disabled(selectedEmployeeIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Pre-select assigned employees if any
            selectedEmployeeIDs = Set(task.assignedEmployeeIDs)
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
    
    private func completeTask() {
        var completedTask = task
        completedTask.markCompleted(
            by: Array(selectedEmployeeIDs),
            notes: completionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        completedTask.completedDate = completionDate
        
        onComplete(completedTask)
        dismiss()
    }
}

#if DEBUG
struct TaskCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        TaskCompletionView(
            task: ProjectTask(
                title: "Fix bathroom plumbing",
                description: "Replace the leaky pipe under the sink",
                dueDate: Date(),
                priority: .high,
                category: .plumbing
            ),
            employees: [
                Employee(name: "John Doe", jobTitle: "Plumber"),
                Employee(name: "Jane Smith", jobTitle: "Assistant")
            ]
        ) { _ in }
    }
}
#endif
