import SwiftUI

struct LaborWorkerCard: View {
    struct Status {
        let label: String
        let style: RheirStatusChip.Style
    }

    let name: String
    let initials: String
    let hoursText: String
    let rateText: String
    let unpaidText: String?
    let status: Status
    let nameAccessibilityIdentifier: String
    let cardAccessibilityIdentifier: String
    let onTap: () -> Void

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.large,
            background: RheirTheme.Colors.cardBackground,
            borderColor: RheirTheme.Colors.subtleBorder,
            showsShadow: true
        ) {
            HStack(alignment: .center, spacing: RheirTheme.Spacing.medium) {
                avatar
                workerDetails
                Spacer(minLength: RheirTheme.Spacing.small)
                trailingStatus
            }
            .frame(minHeight: 52)
        }
        .contentShape(RoundedRectangle(cornerRadius: RheirTheme.Radius.card, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(cardAccessibilityIdentifier)
        .accessibilityAddTraits(.isButton)
    }

    private var avatar: some View {
        Circle()
            .fill(RheirTheme.Colors.information)
            .frame(width: 42, height: 42)
            .overlay(
                Text(initials)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RheirTheme.Colors.insetBackground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            )
            .accessibilityHidden(true)
    }

    private var workerDetails: some View {
        VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RheirTheme.Colors.primaryText)
                .lineLimit(1)
                .accessibilityIdentifier(nameAccessibilityIdentifier)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: RheirTheme.Spacing.xSmall) {
                    Text(hoursText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.information)

                    Text("• \(rateText)")
                        .font(.caption)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                if let unpaidText {
                    Text(unpaidText)
                        .font(.caption)
                        .foregroundStyle(RheirTheme.Colors.warning)
                        .lineLimit(1)
                }
            }
        }
    }

    private var trailingStatus: some View {
        VStack(alignment: .trailing, spacing: RheirTheme.Spacing.xSmall) {
            RheirStatusChip(label: status.label, style: status.style)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RheirTheme.Colors.tertiaryText)
        }
    }
}

#Preview("Labor Worker Card") {
    VStack(spacing: RheirTheme.Spacing.medium) {
        LaborWorkerCard(
            name: "Sam Carter",
            initials: "S",
            hoursText: "8.0 hrs",
            rateText: "$52.00/hr Framing",
            unpaidText: "$336.00 unpaid",
            status: .init(label: "Pay", style: .unpaid),
            nameAccessibilityIdentifier: "preview-labor-worker-name",
            cardAccessibilityIdentifier: "preview-labor-worker-card",
            onTap: {}
        )

        LaborWorkerCard(
            name: "Mia Lopez",
            initials: "M",
            hoursText: "3.0 hrs",
            rateText: "$34.00/hr Labor",
            unpaidText: nil,
            status: .init(label: "Paid", style: .paid),
            nameAccessibilityIdentifier: "preview-paid-worker-name",
            cardAccessibilityIdentifier: "preview-paid-worker-card",
            onTap: {}
        )
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
