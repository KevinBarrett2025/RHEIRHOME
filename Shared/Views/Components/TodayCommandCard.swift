import SwiftUI

struct TodayCommandCard: View {
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

    private var priorityItems: [PriorityItem] {
        var items: [PriorityItem] = []

        if summary.overdueTaskCount > 0 {
            items.append(
                PriorityItem(
                    title: "\(summary.overdueTaskCount) overdue task\(summary.overdueTaskCount == 1 ? "" : "s")",
                    detail: "Needs field attention",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: RheirTheme.Colors.destructive
                )
            )
        }

        if summary.dueTodayTaskCount > 0 || summary.dueTodayCalendarEventCount > 0 {
            let count = summary.dueTodayTaskCount + summary.dueTodayCalendarEventCount
            items.append(
                PriorityItem(
                    title: "\(count) due today",
                    detail: "Tasks and calendar work",
                    systemImage: "calendar.badge.clock",
                    tint: RheirTheme.Colors.warning
                )
            )
        }

        if summary.markedReturnItemCount > 0 {
            items.append(
                PriorityItem(
                    title: "\(summary.markedReturnItemCount) return item\(summary.markedReturnItemCount == 1 ? "" : "s")",
                    detail: "Receipt line items marked for return",
                    systemImage: "arrow.uturn.left.circle.fill",
                    tint: RheirTheme.Colors.warning
                )
            )
        }

        if summary.openShoppingItemCount > 0 {
            items.append(
                PriorityItem(
                    title: "\(summary.openShoppingItemCount) shopping item\(summary.openShoppingItemCount == 1 ? "" : "s") open",
                    detail: "\(summary.completedShoppingItemCount) already purchased",
                    systemImage: "cart.fill",
                    tint: RheirTheme.Colors.information
                )
            )
        }

        if summary.openChecklistItemCount > 0 {
            items.append(
                PriorityItem(
                    title: "\(summary.openChecklistItemCount) checklist item\(summary.openChecklistItemCount == 1 ? "" : "s") open",
                    detail: "\(summary.completedChecklistItemCount) checked off",
                    systemImage: "checklist",
                    tint: RheirTheme.Colors.information
                )
            )
        }

        if summary.upcomingCalendarEventCount > 0, let nextCalendarEvent = summary.nextCalendarEvent {
            items.append(
                PriorityItem(
                    title: "\(summary.upcomingCalendarEventCount) upcoming event\(summary.upcomingCalendarEventCount == 1 ? "" : "s")",
                    detail: "Next: \(nextCalendarEvent.title)",
                    systemImage: "calendar",
                    tint: RheirTheme.Colors.information
                )
            )
        }

        return items
    }

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.large,
            background: RheirTheme.Colors.elevatedCardBackground
        ) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.large) {
                header
                budgetStrip
                prioritiesSection
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today-command-card")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RheirTheme.Spacing.small) {
            HStack(alignment: .center, spacing: RheirTheme.Spacing.medium) {
                Label("Today Command", systemImage: "hammer.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.primaryAction)

                Spacer(minLength: RheirTheme.Spacing.medium)

                RheirStatusChip(
                    label: health.label,
                    systemImage: health.systemImage,
                    style: health.style
                )
            }

            Text(project.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(RheirTheme.Colors.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var budgetStrip: some View {
        HStack(spacing: RheirTheme.Spacing.large) {
            summaryValue(
                label: "Budget Remaining",
                value: project.remainingBudget.formatAsCurrency(),
                systemImage: "banknote.fill",
                tint: project.remainingBudget < 0 ? RheirTheme.Colors.destructive : RheirTheme.Colors.success
            )

            Divider()
                .overlay(RheirTheme.Colors.subtleBorder)

            summaryValue(
                label: "Project Budget",
                value: project.totalBudget.formatAsCurrency(),
                systemImage: "briefcase.fill",
                tint: RheirTheme.Colors.information
            )
        }
        .frame(minHeight: 48)
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: RheirTheme.Spacing.medium) {
            Text("Today's Priorities")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RheirTheme.Colors.primaryText)

            if priorityItems.isEmpty {
                HStack(spacing: RheirTheme.Spacing.medium) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(RheirTheme.Colors.success)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                        Text("No command items today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RheirTheme.Colors.primaryText)
                        Text("No overdue tasks, return items, open shopping, or checklist items need attention.")
                            .font(.caption)
                            .foregroundStyle(RheirTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(minHeight: 44)
            } else {
                VStack(spacing: RheirTheme.Spacing.small) {
                    ForEach(priorityItems.prefix(5)) { item in
                        priorityRow(item)
                    }
                }
            }
        }
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
        .frame(minHeight: 44)
    }

    private func priorityRow(_ item: PriorityItem) -> some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
    }
}

private extension TodayCommandCard {
    struct PriorityItem: Identifiable {
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color

        var id: String {
            "\(systemImage)-\(title)-\(detail)"
        }
    }

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
                return "checkmark.circle.fill"
            case .needsReview:
                return "exclamationmark.circle.fill"
            case .overdue:
                return "exclamationmark.triangle.fill"
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

#Preview("Today Command Card") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_800_057_600)
    let startOfToday = calendar.startOfDay(for: now)
    var project = Project(
        name: "Nazareth Bathroom Remodel",
        client: "Client",
        totalBudget: 42_000,
        materialCost: 12_400,
        laborCost: 6_200,
        generalConditions: 2_100,
        startDate: startOfToday,
        endDate: startOfToday.addingTimeInterval(10 * 86_400),
        organizationID: "preview",
        projectChecklists: [
            ProjectChecklist(
                title: "Rough-in prep",
                category: .tools,
                items: [
                    ProjectChecklistItem(title: "Voltage tester"),
                    ProjectChecklistItem(title: "Wire staples", isComplete: true)
                ]
            )
        ],
        projectCalendarEvents: [
            ProjectCalendarEvent(
                title: "Fixture delivery",
                kind: .deliveryOrder,
                startDate: startOfToday.addingTimeInterval(12 * 3_600),
                status: .scheduled
            )
        ],
        shoppingListItems: [
            ProjectShoppingListItem(title: "Contractor bags"),
            ProjectShoppingListItem(title: "Dust masks", isPurchased: true)
        ]
    )
    project.tasks = [
        ProjectTask(
            title: "Confirm vanity delivery",
            dueDate: startOfToday.addingTimeInterval(14 * 3_600),
            category: .materials,
            projectID: project.id
        )
    ]

    return ScrollView {
        TodayCommandCard(
            project: project,
            summary: project.operationsSummary(on: now, calendar: calendar)
        )
        .padding()
    }
    .background(RheirTheme.Colors.appBackground)
    .preferredColorScheme(.light)
}
