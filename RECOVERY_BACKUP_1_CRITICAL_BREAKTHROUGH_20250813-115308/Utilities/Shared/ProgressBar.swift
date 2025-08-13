//
//  ProgressBar.swift
//  Rheir
//
//  Created by Kevin Barrett on 5/4/25.
//

import SwiftUI

/// A horizontal progress bar that goes green → yellow → red as `value` goes from 0→1→above.
struct ProgressBar: View {
    /// A value between 0.0 and 1.0 (anything above 1.0 will saturate at red).
    let value: Double

    private var barColor: Color {
        if value < 0.8 {
            return .green
        } else if value <= 1.0 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(value, 0), 1)
            let fillWidth = clamped * geometry.size.width

            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 10)

                // Filled portion
                Rectangle()
                    .fill(barColor)
                    .frame(width: fillWidth, height: 10)
            }
            .cornerRadius(5)
        }
        .frame(height: 10) // fixes overall height
    }
}
/// A horizontal “profit” bar that fills left→right with a green gradient,
/// from dark at full profit to pale as profit shrinks.
struct ProfitBar: View {
    /// A value between 0.0 and 1.0 (anything above 1.0 will just fill solid dark green;
    /// below 0.0 shows zero fill).
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(fraction, 0), 1)
            let fillWidth = geo.size.width * CGFloat(clamped)

            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                  .fill(Color.gray.opacity(0.3))
                  .frame(height: geo.size.height)

                // Gradient fill
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.green,               // full-profit color
                        Color.green.opacity(0.3)   // low-profit color
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fillWidth, height: geo.size.height)
            }
            .cornerRadius(geo.size.height / 2)
        }
        .frame(height: 12)
    }
}
