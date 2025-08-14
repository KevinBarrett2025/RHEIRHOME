import SwiftUI

// MARK: - Renovation Phase Card
public struct RenovationPhaseCard: View {
    let category: ReceiptCategory
    let spent: Double
    let budgeted: Double
    let project: Project
    let action: () -> Void
    @EnvironmentObject private var intelligenceService: SimpleIntelligenceService
    
    private var progress: Double {
        guard budgeted > 0 else { return 0 }
        return min(spent / budgeted, 1.0)
    }
    
    private var isOverBudget: Bool {
        spent > budgeted && budgeted > 0
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: categoryIcon(for: category))
                        .font(.title2)
                        .foregroundColor(categoryColor(for: category))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        if category.hasPhaseScheduling {
                            Text("Phase \(category.renovationSequence)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isOverBudget {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Progress section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Spent: \(spent.formatAsCurrency())")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if budgeted > 0 {
                            Text("Budget: \(budgeted.formatAsCurrency())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: isOverBudget ? .red : categoryColor(for: category)))
                        .scaleEffect(x: 1, y: 0.8)
                    
                    HStack {
                        let completion = intelligenceService.estimatePhaseCompletion(category, spent: spent, budgeted: budgeted)
                        Text("\(Int(completion * 100))% complete")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if budgeted > 0 {
                            let remaining = budgeted - spent
                            Text(remaining > 0 ? "Remaining: \(remaining.formatAsCurrency())" : "Over by: \((-remaining).formatAsCurrency())")
                                .font(.caption2)
                                .foregroundColor(remaining > 0 ? .secondary : .red)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 180, height: 120)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        case .permits: return "doc.text.fill"
        case .demolition: return "hammer.fill"
        case .sitework: return "arrow.up.and.down.and.arrow.left.and.right"
        case .foundation: return "building.columns.fill"
        case .framing: return "square.grid.3x3.square"
        case .roofing: return "house.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .insulation: return "thermometer"
        case .drywall: return "rectangle.3.group"
        case .paint: return "paintbrush.fill"
        case .flooring: return "square.grid.4x3.fill"
        case .tile: return "grid"
        case .cabinetry: return "cabinet.fill"
        case .countertops: return "rectangle.on.rectangle"
        case .appliances: return "refrigerator.fill"
        case .fixtures: return "lightbulb.fill"
        case .lighting: return "lamp.ceiling.fill"
        case .trim: return "rectangle.portrait.and.arrow.right"
        case .windows: return "macwindow"
        case .exterior: return "house.and.flag.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub.fill"
        case .landscaping: return "leaf.fill"
        case .cleanup: return "trash.fill"
        case .specialty: return "star.fill"
        }
    }
    
    private func categoryColor(for category: ReceiptCategory) -> Color {
        switch category {
        case .general: return .blue
        case .material: return .green
        case .contingency: return .orange
        case .permits: return .purple
        case .demolition: return .red
        case .sitework: return .brown
        case .foundation: return .gray
        case .framing: return .yellow
        case .roofing: return .blue
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .hvac: return .cyan
        case .insulation: return .orange
        case .drywall: return .gray
        case .paint: return .red
        case .flooring: return .brown
        case .tile: return .indigo
        case .cabinetry: return .brown
        case .countertops: return .gray
        case .appliances: return .blue
        case .fixtures: return .yellow
        case .lighting: return .yellow
        case .trim: return .brown
        case .windows: return .blue
        case .exterior: return .green
        case .kitchen: return .orange
        case .bathroom: return .blue
        case .landscaping: return .green
        case .cleanup: return .gray
        case .specialty: return .secondary
        }
    }
}

// MARK: - Intelligence Insight Card
public struct IntelligenceInsightCard: View {
    let insight: IntelligenceInsight
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.type.icon)
                .font(.title3)
                .foregroundColor(insight.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(insight.actionTitle) {
                // TODO: Handle insight action
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1))
        }
        .padding()
        .background(insight.type.color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Add Phase Card
public struct AddPhaseCard: View {
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                Text("Add Phase")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text("Start tracking a new renovation phase")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(width: 180, height: 120)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Detail View
public struct CategoryDetailView: View {
    let category: ReceiptCategory
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var categoryReceipts: [Receipt] {
        project.receipts.filter { $0.category == category }
    }
    
    private var totalSpent: Double {
        categoryReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    categoryHeaderSection
                    spendingSummarySection
                    receiptsListSection
                }
                .padding()
            }
            .navigationTitle("\(category.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
                    
                    if category.hasPhaseScheduling {
                        Text("Renovation Phase \(category.renovationSequence)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var spendingSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Phase Spending Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Total Spent", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalSpent.formatAsCurrency())
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    
                    Text("No receipts found in this phase")
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
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(categoryReceipts.sorted { $0.date > $1.date }) { receipt in
                        ReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        case .permits: return "doc.text.fill"
        case .demolition: return "hammer.fill"
        case .sitework: return "arrow.up.and.down.and.arrow.left.and.right"
        case .foundation: return "building.columns.fill"
        case .framing: return "square.grid.3x3.square"
        case .roofing: return "house.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .insulation: return "thermometer"
        case .drywall: return "rectangle.3.group"
        case .paint: return "paintbrush.fill"
        case .flooring: return "square.grid.4x3.fill"
        case .tile: return "grid"
        case .cabinetry: return "cabinet.fill"
        case .countertops: return "rectangle.on.rectangle"
        case .appliances: return "refrigerator.fill"
        case .fixtures: return "lightbulb.fill"
        case .lighting: return "lamp.ceiling.fill"
        case .trim: return "rectangle.portrait.and.arrow.right"
        case .windows: return "macwindow"
        case .exterior: return "house.and.flag.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub.fill"
        case .landscaping: return "leaf.fill"
        case .cleanup: return "trash.fill"
        case .specialty: return "star.fill"
        }
    }
    
    private func categoryColor(for category: ReceiptCategory) -> Color {
        switch category {
        case .general: return .blue
        case .material: return .green
        case .contingency: return .orange
        case .permits: return .purple
        case .demolition: return .red
        case .sitework: return .brown
        case .foundation: return .gray
        case .framing: return .yellow
        case .roofing: return .blue
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .hvac: return .cyan
        case .insulation: return .orange
        case .drywall: return .gray
        case .paint: return .red
        case .flooring: return .brown
        case .tile: return .indigo
        case .cabinetry: return .brown
        case .countertops: return .gray
        case .appliances: return .blue
        case .fixtures: return .yellow
        case .lighting: return .yellow
        case .trim: return .brown
        case .windows: return .blue
        case .exterior: return .green
        case .kitchen: return .orange
        case .bathroom: return .blue
        case .landscaping: return .green
        case .cleanup: return .gray
        case .specialty: return .secondary
        }
    }
}

// MARK: - Receipt Row Card Component
public struct ReceiptRowCard: View {
    let receipt: Receipt
    
    public var body: some View {
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
                Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(receipt.isReturn ? .red : .primary)
                
                if receipt.taxAmount > 0 {
                    Text("Tax: \(receipt.taxAmount.formatAsCurrency())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}