import SwiftUI

struct CategoryRowView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel

    let title: String
    let spent: Double
    let total: Double
    let linkCategory: ReceiptCategory?
    let laborLink: Bool
    @Binding var selectedTab: Tab
    
    @State private var showingCategoryReceipts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .underline()
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 2) {
                    Text(formatCurrency(spent))
                    Text("/")
                    Text(formatCurrency(total))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            let fraction = total > 0 ? min(max(spent/total, 0), 1) : 0

            let barColor: Color = {
                switch fraction {
                case ..<0.5:    return .green
                case 0.5..<0.8: return .yellow
                default:        return .red
                }
            }()

            FadingProgressBar(value: fraction, color: barColor)
                .frame(height: 8)

            Text("Remaining: \(formatCurrency(total - spent))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .onTapGesture {
            if let _ = linkCategory {
                showingCategoryReceipts = true
            } else if laborLink {
                selectedTab = .labor
            }
        }
        .sheet(isPresented: $showingCategoryReceipts) {
            if let category = linkCategory, let project = projectVM.selectedProject {
                SemiTransparentCategoryView(category: category, project: project)
                    .presentationBackground(.thinMaterial)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct SemiTransparentCategoryView: View {
    let category: ReceiptCategory
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    private var categoryReceipts: [Receipt] {
        project.receipts.filter { $0.category == category }
    }
    
    private var totalSpent: Double {
        categoryReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background blur effect
                Color.clear
                
                ScrollView {
                    VStack(spacing: 20) {
                        categoryHeaderSection
                        spendingSummarySection
                        receiptsListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("\(category.rawValue) Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    @ViewBuilder
    private var categoryHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 40))
                    .foregroundColor(categoryColor(for: category))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Project: \(project.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var spendingSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Category Spending Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Total Spent", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(totalSpent))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalSpent >= 0 ? .primary : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Receipts", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(categoryReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All \(category.rawValue) Receipts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if categoryReceipts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: categoryIcon(for: category))
                        .font(.system(size: 48))
                        .foregroundColor(categoryColor(for: category).opacity(0.6))
                    
                    Text("No receipts found in this category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Add receipts to track spending in \(category.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(categoryReceipts.sorted { $0.date > $1.date }) { receipt in
                        SemiTransparentReceiptRowCard(receipt: receipt)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
    
    private func categoryColor(for category: ReceiptCategory) -> Color {
        switch category {
        case .general: return .blue
        case .material: return .green
        case .contingency: return .orange
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct SemiTransparentReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(receipt.vendor)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if receipt.isReturn {
                        Text("RETURN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !receipt.notes.isEmpty {
                    Text(receipt.notes)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                } else if !receipt.items.isEmpty {
                    Text(receipt.items.map { $0.name }.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if !receipt.paymentMethod.isEmpty {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(receipt.paymentMethod)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !receipt.receiptNumber.isEmpty {
                        if !receipt.paymentMethod.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Receipt #\(receipt.receiptNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(receipt.isReturn ? -receipt.amount : receipt.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(receipt.isReturn ? .red : .primary)
                
                if receipt.taxAmount > 0 {
                    Text("Tax: \(formatCurrency(receipt.taxAmount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}