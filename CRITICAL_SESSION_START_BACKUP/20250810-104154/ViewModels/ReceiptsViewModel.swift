import Foundation
import Combine

@MainActor
class ReceiptsViewModel: ObservableObject {
    @Published private var project: Project
    private let saveProject: (Project) -> Void

    /// Inject the currently selected project and a callback to persist changes
    init(project: Project, saveAction: @escaping (Project) -> Void) {
        self.project = project
        self.saveProject = saveAction
    }

    /// All receipts for this project
    var receipts: [Receipt] {
        project.receipts
    }

    /// Total spent per category
    var spentGeneral: Double {
        project.receipts
            .filter { $0.category == .general }
            .map(\.amount)
            .reduce(0, +)
    }

    var spentMaterial: Double {
        project.receipts
            .filter { $0.category == .material }
            .map(\.amount)
            .reduce(0, +)
    }

    var spentLabor: Double {
        project.loggedHours
            .map { $0.hours * $0.rate }
            .reduce(0, +)
    }

    var spentContingency: Double {
        project.receipts
            .filter { $0.category == .contingency }
            .map(\.amount)
            .reduce(0, +)
    }

    func add(_ receipt: Receipt) {
        project.receipts.append(receipt)
        saveProject(project)
    }

    func update(_ receipt: Receipt) {
        guard let idx = project.receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
        project.receipts[idx] = receipt
        saveProject(project)
    }

    func delete(at offsets: IndexSet) {
        project.receipts.remove(atOffsets: offsets)
        saveProject(project)
    }
}
