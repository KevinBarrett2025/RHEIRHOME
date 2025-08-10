import SwiftUI

struct AnimatedScannerIcon: View {
    @State private var scanOffset: CGFloat = -10
    @State private var opacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // Receipt document
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 16, height: 20)
                .overlay(
                    // Receipt text lines
                    VStack(spacing: 1.5) {
                        Rectangle().fill(Color.black.opacity(0.6)).frame(width: 12, height: 1)
                        Rectangle().fill(Color.black.opacity(0.4)).frame(width: 10, height: 0.8)
                        Rectangle().fill(Color.black.opacity(0.5)).frame(width: 13, height: 0.8)
                        Rectangle().fill(Color.black.opacity(0.4)).frame(width: 9, height: 0.8)
                        Rectangle().fill(Color.black.opacity(0.6)).frame(width: 11, height: 1)
                    }
                    .offset(y: 2)
                )
            
            // Animated scan line
            Rectangle()
                .fill(Color.red.opacity(opacity))
                .frame(width: 18, height: 1.5)
                .blur(radius: 0.3)
                .offset(y: scanOffset)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 1.6)
            .repeatForever(autoreverses: true)
        ) {
            scanOffset = 10
        }
        
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            opacity = 1.0
        }
    }
}

struct AnimatedScannerIcon_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 56, height: 56)
            AnimatedScannerIcon()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
