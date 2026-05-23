import SwiftUI

enum RheirTheme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 6
        static let card: CGFloat = 8
        static let capsule: CGFloat = 999
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.18)
        static let cardRadius: CGFloat = 8
        static let cardY: CGFloat = 4
    }

    enum Colors {
        static let cardBackground = Color(.secondarySystemBackground)
        static let elevatedCardBackground = Color(.tertiarySystemBackground)
        static let subtleBorder = Color.primary.opacity(0.10)
        static let primaryAction = Color.blue
        static let selected = Color.blue
        static let active = Color.green
        static let success = Color.green
        static let warning = Color.orange
        static let destructive = Color.red
        static let muted = Color.secondary
    }
}

struct RheirCard<Content: View>: View {
    var padding: CGFloat = RheirTheme.Spacing.large
    var background: Color = RheirTheme.Colors.cardBackground
    var borderColor: Color = RheirTheme.Colors.subtleBorder
    var showsShadow = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: RheirTheme.Radius.card, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RheirTheme.Radius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: showsShadow ? RheirTheme.Shadow.cardColor : .clear,
                radius: RheirTheme.Shadow.cardRadius,
                x: 0,
                y: RheirTheme.Shadow.cardY
            )
    }
}

struct RheirMetricCard: View {
    let label: String
    let value: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = RheirTheme.Colors.primaryAction

    var body: some View {
        RheirCard(padding: RheirTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.small) {
                HStack(spacing: RheirTheme.Spacing.small) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.headline)
                            .foregroundStyle(tint)
                    }

                    Text(label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RheirStatusChip: View {
    enum Style {
        case selected
        case active
        case shared
        case offline
        case syncing
        case pastDue
        case paid
        case unpaid
        case warning
        case neutral

        var tint: Color {
            switch self {
            case .selected, .shared, .syncing:
                return RheirTheme.Colors.selected
            case .active, .paid:
                return RheirTheme.Colors.active
            case .offline, .warning, .unpaid:
                return RheirTheme.Colors.warning
            case .pastDue:
                return RheirTheme.Colors.destructive
            case .neutral:
                return RheirTheme.Colors.muted
            }
        }
    }

    let label: String
    var systemImage: String?
    var style: Style = .neutral

    var body: some View {
        HStack(spacing: RheirTheme.Spacing.xSmall) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(style.tint)
        .padding(.horizontal, RheirTheme.Spacing.small)
        .frame(minHeight: 28)
        .background(style.tint.opacity(0.16), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct RheirSectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RheirTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: RheirTheme.Spacing.medium)

            trailing
        }
    }
}

extension RheirSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

struct RheirPrimaryActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, RheirTheme.Spacing.large)
                .background(RheirTheme.Colors.primaryAction, in: RoundedRectangle(cornerRadius: RheirTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension RheirPrimaryActionButton where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.action = action
        self.label = Text(title)
    }
}

struct RheirEmptyState<Action: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: RheirTheme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(RheirTheme.Colors.primaryAction)

            VStack(spacing: RheirTheme.Spacing.xSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            action
        }
        .frame(maxWidth: .infinity)
        .padding(RheirTheme.Spacing.xLarge)
    }
}

extension RheirEmptyState where Action == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = EmptyView()
    }
}

#Preview("RHEIR Design System") {
    VStack(spacing: RheirTheme.Spacing.large) {
        RheirSectionHeader("Today", subtitle: "Jobsite command center") {
            RheirStatusChip(label: "Active", systemImage: "circle.fill", style: .active)
        }

        RheirCard {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.medium) {
                Text("Nazareth Bathroom Remodel")
                    .font(.headline)
                RheirStatusChip(label: "Selected", systemImage: "checkmark.circle.fill", style: .selected)
            }
        }

        HStack {
            RheirMetricCard(label: "Budget", value: "$14,895", subtitle: "Active contract", systemImage: "chart.pie.fill", tint: .green)
            RheirMetricCard(label: "Due Today", value: "3", subtitle: "tasks/events", systemImage: "calendar", tint: .orange)
        }

        RheirPrimaryActionButton("Record Receipt") {}
    }
    .padding()
    .background(Color(.systemBackground))
}
