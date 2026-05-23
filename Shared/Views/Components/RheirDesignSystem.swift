import SwiftUI
import UIKit

enum RheirTheme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let card: CGFloat = 20
        static let button: CGFloat = 18
        static let capsule: CGFloat = 999
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.14)
        static let cardRadius: CGFloat = 14
        static let cardY: CGFloat = 8
    }

    enum Colors {
        static let appBackground = Color.rheir(light: 0xF7F2EA, dark: 0x0C0F0F)
        static let cardBackground = Color.rheir(light: 0xFFFDF8, dark: 0x151A18)
        static let elevatedCardBackground = Color.rheir(light: 0xFFFCF6, dark: 0x1F2522)
        static let insetBackground = Color.rheir(light: 0xFFFFFF, dark: 0x161B19)
        static let subtleBorder = Color.rheir(light: 0xE4DCCF, dark: 0x2D3430)

        static let primaryText = Color.rheir(light: 0x171717, dark: 0xF2F0EA)
        static let secondaryText = Color.rheir(light: 0x6E6A62, dark: 0xB8B2A7)
        static let tertiaryText = Color.rheir(light: 0x8A857B, dark: 0x7E7A72)

        static let primaryAction = Color.rheir(light: 0xB37A35, dark: 0xC89A6B)
        static let primaryActionPressed = Color.rheir(light: 0x8D5D24, dark: 0xA97947)
        static let information = Color.rheir(light: 0x3E6F8F, dark: 0x6E8AA3)
        static let success = Color.rheir(light: 0x4F7F5F, dark: 0x6FA77B)
        static let warning = Color.rheir(light: 0xC58A32, dark: 0xD69A46)
        static let destructive = Color.rheir(light: 0xB85A3C, dark: 0xC76E4D)
        static let neutral = Color.rheir(light: 0xD8D0C3, dark: 0x2D3430)

        static let selected = information
        static let active = success
        static let muted = tertiaryText
    }
}

private extension Color {
    static func rheir(light: UInt, dark: UInt) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
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
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
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
                return RheirTheme.Colors.information
            case .active, .paid:
                return RheirTheme.Colors.success
            case .offline, .warning, .unpaid:
                return RheirTheme.Colors.warning
            case .pastDue:
                return RheirTheme.Colors.destructive
            case .neutral:
                return RheirTheme.Colors.muted
            }
        }

        var background: Color {
            switch self {
            case .neutral:
                return RheirTheme.Colors.neutral.opacity(0.38)
            default:
                return tint.opacity(0.16)
            }
        }

        var border: Color {
            switch self {
            case .neutral:
                return RheirTheme.Colors.subtleBorder
            default:
                return tint.opacity(0.28)
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
        .background(style.background, in: Capsule())
        .overlay(
            Capsule()
                .stroke(style.border, lineWidth: 1)
        )
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
                    .foregroundStyle(RheirTheme.Colors.primaryText)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
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
        }
        .buttonStyle(RheirButtonStyle())
    }
}

struct RheirButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var foreground: Color = RheirTheme.Colors.insetBackground
    var background: Color = RheirTheme.Colors.primaryAction
    var pressedBackground: Color = RheirTheme.Colors.primaryActionPressed
    var cornerRadius: CGFloat = RheirTheme.Radius.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .padding(.horizontal, RheirTheme.Spacing.large)
            .background(
                configuration.isPressed ? pressedBackground : background,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                    .foregroundStyle(RheirTheme.Colors.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
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

#Preview("RHEIR Design System - Light") {
    RheirDesignSystemPreview()
        .preferredColorScheme(.light)
}

#Preview("RHEIR Design System - Dark") {
    RheirDesignSystemPreview()
        .preferredColorScheme(.dark)
}

private struct RheirDesignSystemPreview: View {
    var body: some View {
        VStack(spacing: RheirTheme.Spacing.large) {
            RheirSectionHeader("Today", subtitle: "Jobsite command center") {
                RheirStatusChip(label: "Active", systemImage: "circle.fill", style: .active)
            }

            RheirCard {
                VStack(alignment: .leading, spacing: RheirTheme.Spacing.medium) {
                    Text("Nazareth Bathroom Remodel")
                        .font(.headline)
                        .foregroundStyle(RheirTheme.Colors.primaryText)
                    RheirStatusChip(label: "Selected", systemImage: "checkmark.circle.fill", style: .selected)
                }
            }

            HStack {
                RheirMetricCard(
                    label: "Budget",
                    value: "$14,895",
                    subtitle: "Active contract",
                    systemImage: "chart.pie.fill",
                    tint: RheirTheme.Colors.success
                )
                RheirMetricCard(
                    label: "Due Today",
                    value: "3",
                    subtitle: "tasks/events",
                    systemImage: "calendar",
                    tint: RheirTheme.Colors.warning
                )
            }

            RheirPrimaryActionButton("Record Receipt") {}
        }
        .padding()
        .background(RheirTheme.Colors.appBackground)
    }
}
