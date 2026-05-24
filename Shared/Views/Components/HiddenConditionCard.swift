import SwiftUI

struct HiddenConditionCard: View {
    let condition: HiddenCondition
    var onEdit: (() -> Void)?

    var body: some View {
        Group {
            if let onEdit {
                Button(action: onEdit) {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hidden-condition-card-\(condition.id.uuidString)")
            } else {
                content
            }
        }
    }

    private var content: some View {
        RheirCard(
            padding: RheirTheme.Spacing.medium,
            background: RheirTheme.Colors.cardBackground,
            borderColor: condition.status.style.border
        ) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.medium) {
                header
                impactRow
                notesPreview
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text(condition.title)
                    .font(.headline)
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(2)

                Text("Discovered \(condition.discoveredDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
            }

            Spacer(minLength: RheirTheme.Spacing.small)

            RheirStatusChip(
                label: condition.status.displayLabel,
                systemImage: condition.status.systemImage,
                style: condition.status.style
            )
        }
    }

    private var impactRow: some View {
        HStack(spacing: RheirTheme.Spacing.medium) {
            impactMetric(
                title: "Cost impact",
                value: condition.estimatedCostImpact?.formatAsCurrency() ?? "Not set",
                systemImage: "dollarsign.circle.fill",
                tint: condition.status.style.tint
            )

            Divider()
                .frame(height: 34)

            impactMetric(
                title: "Labor impact",
                value: condition.estimatedLaborHoursImpact.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) hr" } ?? "Not set",
                systemImage: "clock.badge.exclamationmark.fill",
                tint: condition.severity.tint
            )
        }
    }

    @ViewBuilder
    private var notesPreview: some View {
        if !condition.clientFacingSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text("Client summary preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.secondaryText)

                Text(condition.clientFacingSummary)
                    .font(.subheadline)
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if !condition.internalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Internal notes recorded")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RheirTheme.Colors.secondaryText)
        }
    }

    private func impactMetric(
        title: String,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension HiddenConditionStatus {
    var displayLabel: String {
        switch self {
        case .documented: return "Documented"
        case .needsReview: return "Needs Review"
        case .approvalNeeded: return "Approval Needed"
        case .approved: return "Approved"
        case .resolved: return "Resolved"
        }
    }

    var systemImage: String {
        switch self {
        case .documented: return "doc.text.fill"
        case .needsReview: return "exclamationmark.triangle.fill"
        case .approvalNeeded: return "signature"
        case .approved: return "checkmark.seal.fill"
        case .resolved: return "checkmark.circle.fill"
        }
    }

    var style: RheirStatusChip.Style {
        switch self {
        case .documented: return .neutral
        case .needsReview, .approvalNeeded: return .warning
        case .approved, .resolved: return .active
        }
    }
}

private extension HiddenConditionSeverity {
    var tint: Color {
        switch self {
        case .low: return RheirTheme.Colors.information
        case .moderate: return RheirTheme.Colors.warning
        case .high, .blocking: return RheirTheme.Colors.destructive
        }
    }
}

#Preview("Hidden Condition Card") {
    VStack(spacing: RheirTheme.Spacing.medium) {
        HiddenConditionCard(
            condition: HiddenCondition(
                title: "Water damage behind vanity wall",
                internalNotes: "Demo exposed wet blocking and soft drywall.",
                discoveredDate: Date(timeIntervalSince1970: 1_714_030_000),
                severity: .high,
                status: .approvalNeeded,
                estimatedCostImpact: 1250,
                estimatedLaborHoursImpact: 6,
                clientFacingSummary: "During demo we found hidden water damage behind the vanity wall. The damaged area should be repaired before finishes go back in."
            )
        )
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
