//
//  FadingProgressBar.swift
//  RHEIR
//
//  Created by Kevin Barrett on 5/22/25.
//

import Foundation

//
//  FadingProgressBar.swift
//  RheirMultiplatformApp
//
//  Created by Kevin Barrett on 5/4/25.
//

import SwiftUI

/// A horizontal progress bar that fades out to transparent at the trailing edge.
/// - `value`: fraction from 0.0…1.0 (clamped); values >1 saturate at full length.
/// - `color`: the solid color at the leading edge.
/// - `fadeFraction`: 0…1 portion of the bar that remains fully solid; the rest fades to zero alpha.
struct FadingProgressBar: View {
    var value: Double
    var color: Color
    var fadeFraction: Double = 0.9

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // background track
                Capsule()
                    .fill(Color.gray.opacity(0.1))

                // gradient fill
                let clampedValue = min(max(value, 0), 1)
                let solidEnd = min(max(fadeFraction, 0), 1)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: color, location: 0.0),
                        .init(color: color, location: solidEnd),
                        .init(color: color.opacity(0), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * CGFloat(clampedValue))
                .clipShape(Capsule())
            }
        }
        .clipShape(Capsule())
    }
}

// MARK: – Preview

struct FadingProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            FadingProgressBar(value: 0.25, color: .green)
                .frame(height: 8)
            FadingProgressBar(value: 0.6, color: .yellow)
                .frame(height: 8)
            FadingProgressBar(value: 1.2, color: .red)
                .frame(height: 8)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
