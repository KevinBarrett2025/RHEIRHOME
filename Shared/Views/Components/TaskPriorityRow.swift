import SwiftUI

struct TaskPriorityRow: View {
    struct PriorityBadge {
        let label: String
        let systemImage: String
        let style: RheirStatusChip.Style
    }

    struct StatusBadge {
        let label: Text
        let systemImage: String?
        let style: RheirStatusChip.Style
    }

    let title: String
    let isCompleted: Bool
    let description: String?
    let assigneeSummary: String?
    let categorySystemImage: String
    let showsPhotoIndicator: Bool
    let priorityBadge: PriorityBadge
    let statusBadge: StatusBadge?

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.medium,
            background: RheirTheme.Colors.cardBackground,
            borderColor: RheirTheme.Colors.subtleBorder,
            showsShadow: false
        ) {
            HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: RheirTheme.Spacing.small) {
                    header
                    supportingText
                    footer
                }

                Spacer(minLength: RheirTheme.Spacing.small)
                completionIndicator
            }
            .opacity(isCompleted ? 0.72 : 1.0)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: RheirTheme.Spacing.small) {
            Text(title)
                .font(.headline)
                .strikethrough(isCompleted)
                .foregroundStyle(isCompleted ? RheirTheme.Colors.secondaryText : RheirTheme.Colors.primaryText)
                .lineLimit(2)

            Spacer(minLength: RheirTheme.Spacing.small)

            HStack(spacing: RheirTheme.Spacing.xSmall) {
                Image(systemName: categorySystemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.secondaryText)

                if showsPhotoIndicator {
                    Image(systemName: "photo.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.information)
                }
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var supportingText: some View {
        if let description, !description.isEmpty {
            Text(description)
                .font(.caption)
                .foregroundStyle(RheirTheme.Colors.secondaryText)
                .lineLimit(2)
        }

        if let assigneeSummary, !assigneeSummary.isEmpty {
            Text(assigneeSummary)
                .font(.caption2)
                .foregroundStyle(RheirTheme.Colors.secondaryText)
                .lineLimit(1)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: RheirTheme.Spacing.small) {
            RheirStatusChip(
                label: priorityBadge.label,
                systemImage: priorityBadge.systemImage,
                style: priorityBadge.style
            )

            Spacer(minLength: RheirTheme.Spacing.small)

            if let statusBadge {
                HStack(spacing: RheirTheme.Spacing.xSmall) {
                    if let systemImage = statusBadge.systemImage {
                        Image(systemName: systemImage)
                            .font(.caption2.weight(.semibold))
                    }

                    statusBadge.label
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(statusBadge.style.tint)
                .lineLimit(1)
            }
        }
    }

    private var completionIndicator: some View {
        Group {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(RheirTheme.Colors.success)
            } else {
                Circle()
                    .stroke(RheirTheme.Colors.secondaryText, lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Task Priority Row") {
    VStack(spacing: RheirTheme.Spacing.medium) {
        TaskPriorityRow(
            title: "Frame pantry wall",
            isCompleted: false,
            description: "Frame the new pantry opening before inspection.",
            assigneeSummary: "Assigned: Sam Carter",
            categorySystemImage: "wrench.and.screwdriver",
            showsPhotoIndicator: true,
            priorityBadge: .init(
                label: "High",
                systemImage: "exclamationmark.triangle.fill",
                style: .warning
            ),
            statusBadge: .init(
                label: Text("OVERDUE"),
                systemImage: "clock.badge.exclamationmark",
                style: .pastDue
            )
        )

        TaskPriorityRow(
            title: "Protect finished floors",
            isCompleted: true,
            description: nil,
            assigneeSummary: "Assigned: Mia Lopez",
            categorySystemImage: "checklist",
            showsPhotoIndicator: false,
            priorityBadge: .init(
                label: "Medium",
                systemImage: "exclamationmark.triangle.fill",
                style: .selected
            ),
            statusBadge: .init(
                label: Text("Completed Jan 9, 2025"),
                systemImage: "checkmark.circle.fill",
                style: .paid
            )
        )
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
