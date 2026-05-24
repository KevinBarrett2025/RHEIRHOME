import SwiftUI

struct BudgetCategoryRow: View {
    let title: String
    let spentValue: String
    let totalValue: String
    let remainingValue: String
    let progressFraction: Double
    let statusTint: Color

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.small,
            background: RheirTheme.Colors.elevatedCardBackground,
            borderColor: RheirTheme.Colors.subtleBorder
        ) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: RheirTheme.Spacing.medium) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .underline()
                        .foregroundStyle(RheirTheme.Colors.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: RheirTheme.Spacing.medium)

                    HStack(spacing: RheirTheme.Spacing.xSmall) {
                        Text(spentValue)
                        Text("/")
                        Text(totalValue)
                    }
                    .font(.subheadline)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }

                FadingProgressBar(value: progressFraction, color: statusTint)
                    .frame(height: 8)

                Text("Remaining: \(remainingValue)")
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
    }
}

#Preview("Budget Category Row") {
    VStack(spacing: RheirTheme.Spacing.medium) {
        BudgetCategoryRow(
            title: "Materials",
            spentValue: "$8,240.00",
            totalValue: "$12,500.00",
            remainingValue: "$4,260.00",
            progressFraction: 0.66,
            statusTint: .yellow
        )

        BudgetCategoryRow(
            title: "Labor",
            spentValue: "$7,900.00",
            totalValue: "$8,000.00",
            remainingValue: "$100.00",
            progressFraction: 0.99,
            statusTint: .red
        )
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
