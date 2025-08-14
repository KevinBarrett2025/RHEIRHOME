// ProfitBarView.swift
import SwiftUI

struct ProfitBarView: View {
    let totalBudget: Double
    let spentCosts: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profit Remaining")
                .font(.callout)
                .fontWeight(.semibold)
                .underline()

            HStack {
                Text((totalBudget - spentCosts).formatAsCurrency())
                Spacer()
                Text(totalBudget.formatAsCurrency())
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            let rawFraction: Double = totalBudget > 0
                ? (totalBudget - spentCosts) / totalBudget
                : 0

            Group {
                if rawFraction >= 0 {
                    let fill = min(rawFraction, 1)
                    let color: Color = {
                        switch fill {
                        case ..<0.8:  return .green
                        case 0.8...1: return .yellow
                        default:      return .red
                        }
                    }()
                    FadingProgressBar(
                        value: fill,
                        color: color,
                        fadeFraction: 0.95
                    )
                } else {
                    FadingProgressBar(
                        value: 1,
                        color: .red,
                        fadeFraction: 0.95
                    )
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
    }
}
