import SwiftUI

struct TaskCompletionSheet: View {
    let task: ProjectTask
    let onComplete: (ProjectTask) -> Void
    @EnvironmentObject var viewModel: ProjectViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmployeeIDs: Set<UUID> = []
    @State private var completionNotes = ""
    @State private var completionTime = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task Summary Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Complete Task")
                                .font(.headline)
                            Text(task.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Form {
                    Section("Who completed this task?") {
                        if viewModel.employees.isEmpty {
                            Text("No employees available")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.employees) { employee in
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
                                            .foregroundColor(.green)
                                            .font(.title2)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                            .font(.title2)
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
                        DatePicker("Completed at", selection: $completionTime, displayedComponents: [.date, .hourAndMinute])
                        
                        TextField("Add completion notes (optional)", text: $completionNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        completeTask()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark Complete")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedEmployeeIDs.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(selectedEmployeeIDs.isEmpty)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Pre-select assigned employees if any
            selectedEmployeeIDs = Set(task.assignedEmployeeIDs)
        }
    }
    
    private func completeTask() {
        var completedTask = task
        completedTask.markCompleted(
            by: Array(selectedEmployeeIDs),
            notes: completionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        completedTask.completedDate = completionTime
        
        onComplete(completedTask)
        dismiss()
    }
}

#if DEBUG
struct TaskCompletionSheet_Previews: PreviewProvider {
    static var previews: some View {
        TaskCompletionSheet(
            task: ProjectTask(
                title: "Fix bathroom plumbing",
                description: "Replace the leaky pipe under the sink",
                dueDate: Date(),
                priority: .high,
                category: .plumbing
            )
        ) { _ in }
        .environmentObject(ProjectViewModel())
    }
}
#endif