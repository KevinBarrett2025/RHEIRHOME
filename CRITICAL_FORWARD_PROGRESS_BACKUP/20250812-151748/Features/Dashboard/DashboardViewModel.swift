import Foundation

class DashboardViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectId: UUID?

    var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return projects.first { $0.id == id }
    }

    var budgetHealth: String {
        guard let project = selectedProject else { return "Green" }
        let total = project.totalBudget
        guard total > 0 else { return "Green" } // Avoid division by zero
        let spent = project.materialCost + project.laborCost + project.generalConditions
        if spent / total < 0.8 {
            return "Green"
        } else if spent / total <= 1.0 {
            return "Yellow"
        } else {
            return "Red"
        }
    }

    func selectProject(withId id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectId = id
    }
}
