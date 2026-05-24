import SwiftUI

struct ProjectOverviewHeroCard: View {
    let projectName: String
    let clientName: String
    let statusLabel: String
    let statusTint: Color
    let spentValue: String
    let spentTint: Color
    let budgetUsedValue: String
    let budgetUsedTint: Color
    let remainingValue: String
    let remainingTint: Color

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.large,
            background: RheirTheme.Colors.cardBackground,
            borderColor: statusTint.opacity(0.28)
        ) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.large) {
                header
                budgetSummary
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: RheirTheme.Radius.medium, style: .continuous)
                    .fill(RheirTheme.Colors.information.opacity(0.14))
                Image(systemName: "folder.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.information)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text(projectName)
                    .font(.headline)
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Label(clientName, systemImage: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: RheirTheme.Spacing.medium)

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: RheirTheme.Spacing.xSmall) {
            Circle()
                .fill(statusTint)
                .frame(width: 8, height: 8)

            Text(statusLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(RheirTheme.Colors.secondaryText)
        .padding(.horizontal, RheirTheme.Spacing.small)
        .frame(minHeight: 28)
        .background(statusTint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(statusTint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var budgetSummary: some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.small) {
            overviewMetric(
                title: "Spent",
                value: spentValue,
                tint: spentTint,
                alignment: .leading
            )

            Divider()
                .overlay(RheirTheme.Colors.subtleBorder)

            overviewMetric(
                title: "Budget Used",
                value: budgetUsedValue,
                tint: budgetUsedTint,
                alignment: .center
            )

            Divider()
                .overlay(RheirTheme.Colors.subtleBorder)

            overviewMetric(
                title: "Remaining",
                value: remainingValue,
                tint: remainingTint,
                alignment: .trailing
            )
        }
        .frame(minHeight: 56)
        .padding(RheirTheme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: RheirTheme.Radius.medium, style: .continuous)
                .fill(RheirTheme.Colors.insetBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RheirTheme.Radius.medium, style: .continuous)
                .stroke(RheirTheme.Colors.subtleBorder, lineWidth: 1)
        )
    }

    private func overviewMetric(title: String, value: String, tint: Color, alignment: MetricAlignment) -> some View {
        VStack(alignment: alignment.horizontalAlignment, spacing: RheirTheme.Spacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RheirTheme.Colors.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }
}

private extension ProjectOverviewHeroCard {
    enum MetricAlignment {
        case leading
        case center
        case trailing

        var horizontalAlignment: HorizontalAlignment {
            switch self {
            case .leading:
                return .leading
            case .center:
                return .center
            case .trailing:
                return .trailing
            }
        }

        var frameAlignment: Alignment {
            switch self {
            case .leading:
                return .leading
            case .center:
                return .center
            case .trailing:
                return .trailing
            }
        }
    }
}

#Preview("Project Overview Hero Card") {
    ScrollView {
        ProjectOverviewHeroCard(
            projectName: "Nazareth Bathroom Remodel",
            clientName: "Miller Family",
            statusLabel: "Active",
            statusTint: RheirTheme.Colors.success,
            spentValue: "$18,420.00",
            spentTint: RheirTheme.Colors.primaryText,
            budgetUsedValue: "44%",
            budgetUsedTint: RheirTheme.Colors.success,
            remainingValue: "$23,580.00",
            remainingTint: RheirTheme.Colors.success
        )
        .padding()
    }
    .background(RheirTheme.Colors.appBackground)
}
