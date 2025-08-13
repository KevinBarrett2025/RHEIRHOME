// BudgetView.swift
import SwiftUI

struct BudgetView: View {
    let totalBudget: Double
    let materialCost: Double
    let laborCost: Double
    let generalConditions: Double
    let contingency: Double

    var body: some View {
        Form {
            Section(header: Text("Budget Breakdown")) {
                budgetRow(label: "Total Budget", value: totalBudget)
                budgetRow(label: "Materials", value: materialCost)
                budgetRow(label: "Labor", value: laborCost)
                budgetRow(label: "General Conditions", value: generalConditions)
                budgetRow(label: "Contingency", value: contingency)
            }
        }
        .navigationTitle("Budget")
    }

    @ViewBuilder
    private func budgetRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
        }
    }
}

#if DEBUG
struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BudgetView(
                totalBudget: 25_000,
                materialCost: 8_000,
                laborCost: 5_000,
                generalConditions: 2_500,
                contingency: 1_500
            )
        }
        .previewDevice("iPhone 14 Pro")
        .previewDisplayName("Budget Breakdown")
    }
}
#endif
