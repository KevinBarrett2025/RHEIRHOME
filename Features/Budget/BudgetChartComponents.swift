import SwiftUI

// MARK: - Budget Chart Components

struct BudgetPieChart: View {
    let categories: [(String, Double, Color)]
    let total: Double
    
    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                    PieSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        radius: radius * 0.8
                    )
                    .fill(category.2)
                    .position(center)
                }
                
                // Center circle for donut effect
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: radius * 0.6, height: radius * 0.6)
                    .position(center)
                
                // Center text
                VStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(total.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .position(center)
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let previousSum = categories.prefix(index).reduce(0) { $0 + $1.1 }
        return Angle(degrees: (previousSum / total) * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let currentSum = categories.prefix(index + 1).reduce(0) { $0 + $1.1 }
        return Angle(degrees: (currentSum / total) * 360 - 90)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    let backgroundColor: Color = Color(.systemGray5)
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress)
                    .animation(.easeInOut(duration: 1.0), value: animatedProgress)
            }
        }
        .onAppear {
            animatedProgress = min(progress, 1.0)
        }
        .onChange(of: progress) { newProgress in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = min(newProgress, 1.0)
            }
        }
    }
}

struct SparklineChart: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue
            
            Path { path in
                guard data.count > 1 else { return }
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                    let y = geometry.size.height * (1 - normalizedValue)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .overlay(
                // Data points
                HStack {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        let normalizedValue = (data.max() ?? 1) > 0 ? (value - (data.min() ?? 0)) / ((data.max() ?? 1) - (data.min() ?? 0)) : 0.5
                        
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(
                                x: CGFloat(index) * (geometry.size.width / CGFloat(data.count - 1)),
                                y: geometry.size.height * (1 - normalizedValue)
                            )
                    }
                }
            )
        }
    }
}

struct GaugeChart: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let title: String
    
    private var normalizedValue: Double {
        min(max(value / maxValue, 0), 1)
    }
    
    private var angle: Double {
        normalizedValue * 180 // Half circle
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Background arc
                Arc(startAngle: .degrees(0), endAngle: .degrees(180))
                    .stroke(Color(.systemGray5), lineWidth: 8)
                
                // Progress arc
                Arc(startAngle: .degrees(0), endAngle: .degrees(angle))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                
                // Value text
                VStack {
                    Text(value.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text("of \(maxValue.formatAsCurrency())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 100)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
    }
}

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        return path
    }
}

struct TrendIndicator: View {
    let trend: Double // -1 to 1, where negative is down, positive is up
    let title: String
    let subtitle: String
    
    private var trendColor: Color {
        if trend > 0.1 {
            return .green
        } else if trend < -0.1 {
            return .red
        } else {
            return .secondary
        }
    }
    
    private var trendIcon: String {
        if trend > 0.1 {
            return "arrow.up.right"
        } else if trend < -0.1 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                
                Text("\(abs(trend * 100).formatted(.number.precision(.fractionLength(1))))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(trendColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BudgetHealthIndicator: View {
    let spent: Double
    let budget: Double
    let title: String
    
    private var utilization: Double {
        budget > 0 ? spent / budget : 0
    }
    
    private var healthStatus: (String, Color, String) {
        if utilization > 1.0 {
            return ("Over Budget", .red, "exclamationmark.triangle.fill")
        } else if utilization > 0.9 {
            return ("Critical", .orange, "exclamationmark.circle.fill")
        } else if utilization > 0.8 {
            return ("Warning", .yellow, "exclamationmark.circle")
        } else if utilization > 0.5 {
            return ("On Track", .green, "checkmark.circle.fill")
        } else {
            return ("Healthy", .green, "checkmark.circle.fill")
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: healthStatus.2)
                        .foregroundColor(healthStatus.1)
                    
                    Text(healthStatus.0)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(healthStatus.1)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Spent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(spent.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                AnimatedProgressBar(
                    progress: utilization,
                    color: healthStatus.1
                )
                .frame(height: 8)
                
                HStack {
                    Text("Budget")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(budget.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}