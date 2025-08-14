import SwiftUI

struct CategoryProgressView: View {
    let title: String
    let spent: Double
    let total: Double

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(spent / total, 0), 1)
    }

    private var tintColor: Color {
        switch fraction {
        case 0..<0.8:   return .green
        case 0.8...1.0: return .yellow
        default:        return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline).bold()

            ProgressView(value: fraction)
                .tint(tintColor)

            HStack {
                Text("$\(spent, specifier: "%.2f")")
                Spacer()
                Text("$\(total, specifier: "%.2f")")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

#if DEBUG
struct CategoryProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
          CategoryProgressView(title: "Materials", spent: 4000, total: 10000)
          CategoryProgressView(title: "Labor", spent: 8500, total: 10000)
          CategoryProgressView(title: "Contingency", spent: 1200, total: 1000)
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Category Progress Examples")
    }
}
#endif
