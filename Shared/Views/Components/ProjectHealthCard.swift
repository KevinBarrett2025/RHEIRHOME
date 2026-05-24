import SwiftUI

struct ProjectHealthCard: View {
    let project: Project
    let summary: ProjectOperationsSummary

    init(project: Project, summary: ProjectOperationsSummary? = nil) {
        self.project = project
        self.summary = summary ?? project.operationsSummary()
    }

    private var health: Health {
        if summary.overdueTaskCount > 0 {
            return .overdue
        }

        if summary.actionableItemCount > 0 {
            return .needsReview
        }

        return .onTrack
    }

    private var clientName: String {
        let trimmedName = project.resolvedClientProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Client not set" : trimmedName
    }

    private var actionSummaryText: String {
        let count = summary.actionableItemCount
        if count == 0 {
            return "No command items flagged"
        }

        return "\(count) command item\(count == 1 ? "" : "s") need\(count == 1 ? "s" : "") attention"
    }

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.large,
            background: RheirTheme.Colors.cardBackground,
            borderColor: health.accent.opacity(0.32)
        ) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.medium) {
                header
                budgetStrip
                attentionFooter
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fast-ship-current-project-card")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: RheirTheme.Radius.medium, style: .continuous)
                    .fill(health.accent.opacity(0.14))
                Image(systemName: health.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(health.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text("Current Project")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.secondaryText)

                Text(project.name)
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

            RheirStatusChip(
                label: health.label,
                systemImage: health.chipSystemImage,
                style: health.style
            )
        }
    }

    private var budgetStrip: some View {
        HStack(spacing: RheirTheme.Spacing.large) {
            summaryValue(
                label: "Remaining",
                value: project.remainingBudget.formatAsCurrency(),
                systemImage: "banknote.fill",
                tint: project.remainingBudget < 0 ? RheirTheme.Colors.destructive : RheirTheme.Colors.success
            )

            Divider()
                .overlay(RheirTheme.Colors.subtleBorder)

            summaryValue(
                label: "Budget",
                value: project.totalBudget.formatAsCurrency(),
                systemImage: "briefcase.fill",
                tint: RheirTheme.Colors.information
            )
        }
        .frame(minHeight: 44)
    }

    private var attentionFooter: some View {
        Label(actionSummaryText, systemImage: summary.actionableItemCount == 0 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(summary.actionableItemCount == 0 ? RheirTheme.Colors.success : health.accent)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 28, alignment: .leading)
    }

    private func summaryValue(label: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: RheirTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension ProjectHealthCard {
    enum Health {
        case onTrack
        case needsReview
        case overdue

        var label: String {
            switch self {
            case .onTrack:
                return "On Track"
            case .needsReview:
                return "Needs Review"
            case .overdue:
                return "Overdue"
            }
        }

        var systemImage: String {
            switch self {
            case .onTrack:
                return "checkmark.seal.fill"
            case .needsReview:
                return "exclamationmark.circle.fill"
            case .overdue:
                return "exclamationmark.triangle.fill"
            }
        }

        var chipSystemImage: String {
            switch self {
            case .onTrack:
                return "checkmark.circle.fill"
            case .needsReview:
                return "exclamationmark.circle.fill"
            case .overdue:
                return "exclamationmark.triangle.fill"
            }
        }

        var accent: Color {
            switch self {
            case .onTrack:
                return RheirTheme.Colors.success
            case .needsReview:
                return RheirTheme.Colors.warning
            case .overdue:
                return RheirTheme.Colors.destructive
            }
        }

        var style: RheirStatusChip.Style {
            switch self {
            case .onTrack:
                return .active
            case .needsReview:
                return .warning
            case .overdue:
                return .pastDue
            }
        }
    }
}

#Preview("Project Health Card") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_800_057_600)
    let startOfToday = calendar.startOfDay(for: now)
    var project = Project(
        name: "Nazareth Bathroom Remodel",
        client: "Miller Family",
        totalBudget: 42_000,
        materialCost: 12_400,
        laborCost: 6_200,
        generalConditions: 2_100,
        startDate: startOfToday,
        endDate: startOfToday.addingTimeInterval(10 * 86_400),
        organizationID: "preview",
        shoppingListItems: [
            ProjectShoppingListItem(title: "Contractor bags")
        ]
    )
    project.tasks = [
        ProjectTask(
            title: "Confirm vanity delivery",
            dueDate: startOfToday.addingTimeInterval(-86_400),
            category: .materials,
            projectID: project.id
        )
    ]

    return ScrollView {
        ProjectHealthCard(
            project: project,
            summary: project.operationsSummary(on: now, calendar: calendar)
        )
        .padding()
    }
    .background(RheirTheme.Colors.appBackground)
}
