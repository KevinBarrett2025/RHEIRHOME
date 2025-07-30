import SwiftUI

struct TaskCreateView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var projectVM: ProjectViewModel
    
    let project: Project
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var estimatedHours: Double = 1.0
    @State private var dueDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // Default to 1 week from now
    @State private var category: TaskCategory = .general
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Properties") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    
                    HStack {
                        Text("Estimated Hours")
                        Spacer()
                        TextField("Hours", value: $estimatedHours, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func createTask() {
        let newTask = ProjectTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            category: category,
            estimatedHours: estimatedHours,
            dueDate: dueDate,
            projectID: project.id
        )
        
        projectVM.addTask(newTask)
        isPresented = false
    }
}

// MARK: - Task Supporting Types
enum TaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum TaskCategory: String, CaseIterable, Codable {
    case general = "general"
    case planning = "planning"
    case materials = "materials"
    case electrical = "electrical"
    case plumbing = "plumbing"
    case hvac = "hvac"
    case flooring = "flooring"
    case painting = "painting"
    case cleanup = "cleanup"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .planning: return "Planning"
        case .materials: return "Materials"
        case .electrical: return "Electrical"
        case .plumbing: return "Plumbing"
        case .hvac: return "HVAC"
        case .flooring: return "Flooring"
        case .painting: return "Painting"
        case .cleanup: return "Cleanup"
        }
    }
}

#Preview {
    TaskCreateView(
        isPresented: .constant(true),
        project: Project(
            name: "Sample Project",
            client: "Test Client",
            totalBudget: 10000,
            materialCost: 5000,
            laborCost: 3000,
            generalConditions: 1000,
            contingency: 1000,
            profit: 0,
            startDate: Date(),
            endDate: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
    )
    .environmentObject(ProjectViewModel())
}