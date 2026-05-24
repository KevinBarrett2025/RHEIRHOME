import SwiftUI

struct QuickActionTile: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var accent: Color = RheirTheme.Colors.primaryAction
    var trailingSystemImage: String? = "chevron.right"
    var accessibilityIdentifier: String?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                tileContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .modifier(QuickActionAccessibilityIdentifier(identifier: accessibilityIdentifier))
        } else {
            tileContent
                .accessibilityElement(children: .combine)
                .modifier(QuickActionAccessibilityIdentifier(identifier: accessibilityIdentifier))
        }
    }

    private var tileContent: some View {
        RheirCard(
            padding: RheirTheme.Spacing.medium,
            background: RheirTheme.Colors.cardBackground
        ) {
            HStack(spacing: RheirTheme.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: RheirTheme.Radius.medium, style: .continuous)
                        .fill(accent.opacity(0.16))
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(accent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RheirTheme.Colors.primaryText)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(RheirTheme.Colors.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: RheirTheme.Spacing.small)

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                }
            }
            .frame(minHeight: 52)
        }
        .contentShape(RoundedRectangle(cornerRadius: RheirTheme.Radius.card, style: .continuous))
    }
}

private struct QuickActionAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#Preview("Quick Action Tile") {
    VStack(spacing: RheirTheme.Spacing.large) {
        QuickActionTile(
            title: "Business Resources",
            subtitle: "Workers, vendors, and payment methods used across projects.",
            systemImage: "person.crop.rectangle.stack.fill",
            accent: RheirTheme.Colors.information,
            accessibilityIdentifier: "preview-business-resources-entry"
        ) {}

        QuickActionTile(
            title: "Review Returns",
            subtitle: "Receipt line items marked for return.",
            systemImage: "arrow.uturn.left.circle.fill",
            accent: RheirTheme.Colors.warning
        ) {}
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
