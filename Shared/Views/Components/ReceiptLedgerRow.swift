import SwiftUI

struct ReceiptLedgerRow: View {
    struct StatusBadge {
        let label: String
        let style: RheirStatusChip.Style
    }

    struct ExceptionBadge: Identifiable {
        let id: String
        let label: String
        let systemImage: String
        let tint: Color
        let accessibilityIdentifier: String
    }

    struct PaymentInfo {
        let method: String
        let systemImage: String
        var cardBrand: String?
        var lastFourDigits: String?
    }

    let vendor: String
    let statusBadge: StatusBadge?
    let categoryLabel: String
    let categorySystemImage: String
    let categoryAccessibilityIdentifier: String
    let dateText: String
    let amountText: String
    let amountTint: Color
    let amountAccessibilityIdentifier: String
    let taxText: String?
    let notes: String?
    let categoryContextSummary: String?
    let refundSummary: String?
    let refundSummaryAccessibilityIdentifier: String?
    let exceptionBadges: [ExceptionBadge]
    let paymentInfo: PaymentInfo?
    let receiptNumberText: String?
    let imageActionAccessibilityIdentifier: String
    let onImageView: (() -> Void)?

    var body: some View {
        RheirCard(
            padding: RheirTheme.Spacing.large,
            background: RheirTheme.Colors.cardBackground,
            borderColor: RheirTheme.Colors.subtleBorder,
            showsShadow: true
        ) {
            VStack(spacing: RheirTheme.Spacing.medium) {
                header
                notesSection
                categoryContextSection
                exceptionSummarySection
                refundSummarySection
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RheirTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.small) {
                HStack(spacing: RheirTheme.Spacing.small) {
                    Text(vendor)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let statusBadge {
                        RheirStatusChip(label: statusBadge.label, style: statusBadge.style)
                    }
                }

                HStack(spacing: RheirTheme.Spacing.small) {
                    Image(systemName: categorySystemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.information)

                    Text(categoryLabel)
                        .font(.subheadline)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                        .lineLimit(1)
                        .accessibilityIdentifier(categoryAccessibilityIdentifier)

                    Spacer(minLength: RheirTheme.Spacing.small)

                    Text(dateText)
                        .font(.subheadline)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: RheirTheme.Spacing.small)

            VStack(alignment: .trailing, spacing: RheirTheme.Spacing.xSmall) {
                Text(amountText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(amountTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .accessibilityIdentifier(amountAccessibilityIdentifier)

                if let taxText {
                    Text(taxText)
                        .font(.caption)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes, !notes.isEmpty {
            HStack {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var categoryContextSection: some View {
        if let categoryContextSummary, !categoryContextSummary.isEmpty {
            HStack {
                Text(categoryContextSummary)
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var exceptionSummarySection: some View {
        if !exceptionBadges.isEmpty {
            VStack(alignment: .leading, spacing: RheirTheme.Spacing.xSmall) {
                HStack(spacing: RheirTheme.Spacing.xSmall) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.warning)

                    Text("Receipt Exceptions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.primaryText)

                    Spacer()
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 120), spacing: RheirTheme.Spacing.xSmall, alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: RheirTheme.Spacing.xSmall
                ) {
                    ForEach(exceptionBadges) { badge in
                        HStack(spacing: RheirTheme.Spacing.xSmall) {
                            Image(systemName: badge.systemImage)
                                .font(.caption2.weight(.semibold))

                            Text(badge.label)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .accessibilityIdentifier(badge.accessibilityIdentifier)
                        }
                        .foregroundStyle(badge.tint)
                        .padding(.horizontal, RheirTheme.Spacing.small)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(badge.tint.opacity(0.12))
                        )
                    }
                }
            }
            .padding(RheirTheme.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: RheirTheme.Radius.small, style: .continuous)
                    .fill(RheirTheme.Colors.warning.opacity(0.08))
            )
        }
    }

    @ViewBuilder
    private var refundSummarySection: some View {
        if let refundSummary, !refundSummary.isEmpty {
            HStack(spacing: RheirTheme.Spacing.small) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(RheirTheme.Colors.warning)

                Text(refundSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RheirTheme.Colors.warning)
                    .accessibilityIdentifier(refundSummaryAccessibilityIdentifier ?? "")

                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: RheirTheme.Spacing.medium) {
            if let paymentInfo {
                HStack(spacing: RheirTheme.Spacing.small) {
                    Image(systemName: paymentInfo.systemImage)
                        .font(.caption)
                        .foregroundStyle(RheirTheme.Colors.secondaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(paymentInfo.method)
                            .font(.caption)
                            .foregroundStyle(RheirTheme.Colors.secondaryText)

                        if paymentInfo.cardBrand != nil || paymentInfo.lastFourDigits != nil {
                            HStack(spacing: RheirTheme.Spacing.xSmall) {
                                if let cardBrand = paymentInfo.cardBrand, !cardBrand.isEmpty {
                                    Text(cardBrand)
                                        .font(.caption2)
                                        .foregroundStyle(RheirTheme.Colors.information)
                                }

                                if let lastFour = paymentInfo.lastFourDigits, !lastFour.isEmpty {
                                    Text("•••• \(lastFour)")
                                        .font(.caption2)
                                        .foregroundStyle(RheirTheme.Colors.secondaryText)
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: RheirTheme.Spacing.small)

            if let onImageView {
                Button(action: onImageView) {
                    Label("View", systemImage: "photo.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RheirTheme.Colors.information)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(imageActionAccessibilityIdentifier)
            }

            if let receiptNumberText, !receiptNumberText.isEmpty {
                Text(receiptNumberText)
                    .font(.caption)
                    .foregroundStyle(RheirTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

#Preview("Receipt Ledger Row") {
    VStack(spacing: RheirTheme.Spacing.medium) {
        ReceiptLedgerRow(
            vendor: "Home Depot",
            statusBadge: nil,
            categoryLabel: "Materials",
            categorySystemImage: "cube.box",
            categoryAccessibilityIdentifier: "preview-category",
            dateText: Date().formatted(date: .abbreviated, time: .omitted),
            amountText: "$248.19",
            amountTint: RheirTheme.Colors.primaryText,
            amountAccessibilityIdentifier: "preview-amount",
            taxText: "Tax: $14.22",
            notes: "Framing lumber and fasteners",
            categoryContextSummary: nil,
            refundSummary: nil,
            refundSummaryAccessibilityIdentifier: nil,
            exceptionBadges: [],
            paymentInfo: ReceiptLedgerRow.PaymentInfo(
                method: "Chase Visa",
                systemImage: "creditcard.fill",
                cardBrand: "Visa",
                lastFourDigits: "4242"
            ),
            receiptNumberText: "Receipt #HD-1042",
            imageActionAccessibilityIdentifier: "preview-image",
            onImageView: {}
        )

        ReceiptLedgerRow(
            vendor: "Flooring Supply",
            statusBadge: .init(label: "PARTIAL REFUND", style: .warning),
            categoryLabel: "Materials",
            categorySystemImage: "cube.box",
            categoryAccessibilityIdentifier: "preview-refund-category",
            dateText: Date().formatted(date: .abbreviated, time: .omitted),
            amountText: "$780.00",
            amountTint: RheirTheme.Colors.primaryText,
            amountAccessibilityIdentifier: "preview-refund-amount",
            taxText: nil,
            notes: nil,
            categoryContextSummary: "2 material items: Tile, grout",
            refundSummary: "Refunded $120.00 in 1 linked refund",
            refundSummaryAccessibilityIdentifier: "preview-refund-summary",
            exceptionBadges: [
                .init(
                    id: "return",
                    label: "Return qty 2",
                    systemImage: "arrow.uturn.backward",
                    tint: RheirTheme.Colors.warning,
                    accessibilityIdentifier: "preview-exception-return"
                ),
                .init(
                    id: "missing",
                    label: "Missing qty 1",
                    systemImage: "shippingbox",
                    tint: RheirTheme.Colors.destructive,
                    accessibilityIdentifier: "preview-exception-missing"
                )
            ],
            paymentInfo: nil,
            receiptNumberText: nil,
            imageActionAccessibilityIdentifier: "preview-refund-image",
            onImageView: nil
        )
    }
    .padding()
    .background(RheirTheme.Colors.appBackground)
}
