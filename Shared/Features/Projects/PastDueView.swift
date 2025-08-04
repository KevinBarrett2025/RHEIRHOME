import SwiftUI

struct PastDueView: View {
    @EnvironmentObject var viewModel: ProjectViewModel

    /// All the tasks on the selected project whose dueDate is before now and not yet completed.
    private var overdue: [ProjectTask] {
        guard let project = viewModel.selectedProject else { return [] }
        return project.tasks.filter { task in
            !task.isCompleted && 
            task.dueDate != nil && 
            task.dueDate! < Date()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if overdue.isEmpty {
                    Text("No past due tasks!")
                        .foregroundColor(.gray)
                } else {
                    Section("Past Due") {
                        ForEach(overdue) { task in
                            HStack {
                                Text(task.title)
                                Spacer()
                                if let dueDate = task.dueDate {
                                    Text(dueDate, format: .dateTime.month().day().year())
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Past Due")
        }
    }
}

struct PastDueView_Previews: PreviewProvider {
    static var previews: some View {
        PastDueView()
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}