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
        BudgetCategoryRow(
            title: title,
            spentValue: formatCurrency(spent),
            totalValue: formatCurrency(total),
            remainingValue: formatCurrency(total - spent),
            progressFraction: progressFraction,
            statusTint: barColor
        )
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

    private var progressFraction: Double {
        total > 0 ? min(max(spent/total, 0), 1) : 0
    }

    private var barColor: Color {
        switch progressFraction {
        case ..<0.5:    return .green
        case 0.5..<0.8: return .yellow
        default:        return .red
        }
    }
}

struct SemiTransparentCategoryView: View {
    let category: ReceiptCategory
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    // NEW: Map receipt category to enhanced budget category and get all related categories
    private var relevantReceiptCategories: [ReceiptCategory] {
        // Map the passed category to its budget category group
        let budgetCategory = mapToBudgetCategory(category)
        return getReceiptCategories(for: budgetCategory)
    }
    
    private var categoryReceipts: [Receipt] {
        project.receipts.filter { receipt in
            // FIXED: Check if receipt category is in the relevant group, not just exact match
            if relevantReceiptCategories.contains(receipt.category) {
                return true
            }
            
            // Also check receipt items for more granular categorization
            if !receipt.items.isEmpty {
                return receipt.items.contains { item in
                    relevantReceiptCategories.contains(item.category)
                }
            }
            
            return false
        }
    }
    
    private var totalSpent: Double {
        categoryReceipts.reduce(0) { acc, receipt in
            var receiptTotal: Double = 0
            
            if !receipt.items.isEmpty {
                // Calculate from items that match relevant categories
                receiptTotal = receipt.items.reduce(0) { itemAcc, item in
                    if relevantReceiptCategories.contains(item.category) {
                        let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                        return itemAcc + amount
                    }
                    return itemAcc
                }
            } else {
                // Use full receipt amount if category matches
                if relevantReceiptCategories.contains(receipt.category) {
                    receiptTotal = receipt.isReturn ? -receipt.amount : receipt.amount
                }
            }
            
            return acc + receiptTotal
        }
    }
    
    // Add the enhanced budget category mapping methods (using existing enum from ProjectViewModel+Filters)
    private func mapToBudgetCategory(_ receiptCategory: ReceiptCategory) -> EnhancedBudgetCategory {
        switch receiptCategory {
        // Materials mapping - ALL material-related categories
        case .material, .demolition, .sitework, .foundation, .framing, .roofing, .exterior,
             .electrical, .plumbing, .hvac, .insulation, .drywall, .flooring,
             .trim, .paint, .kitchen, .bathroom, .fixtures, .appliances,
             .landscaping, .lighting, .cabinetry, .countertops, .tile, .windows, .specialty:
            return .materials
            
        // General Conditions mapping
        case .general, .permits, .cleanup:
            return .generalConditions
            
        // Contingency mapping
        case .contingency:
            return .contingency
        }
    }
    
    private func getReceiptCategories(for budgetCategory: EnhancedBudgetCategory) -> [ReceiptCategory] {
        return ReceiptCategory.allCases.filter { receiptCategory in
            mapToBudgetCategory(receiptCategory) == budgetCategory
        }
    }
    
    // Update the header to show the budget category name instead of specific receipt category
    private var displayCategoryName: String {
        let budgetCategory = mapToBudgetCategory(category)
        return budgetCategory.rawValue
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
            .navigationTitle("\(displayCategoryName) Receipts")
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
                Image(systemName: budgetCategoryIcon(for: mapToBudgetCategory(category)))
                    .font(.system(size: 40))
                    .foregroundColor(budgetCategoryColor(for: mapToBudgetCategory(category)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayCategoryName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Project: \(project.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Show breakdown of subcategories if multiple
                    if relevantReceiptCategories.count > 1 {
                        Text("Includes: \(getSubcategoryNames())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // Helper to show what subcategories are included
    private func getSubcategoryNames() -> String {
        let activeCategories = relevantReceiptCategories.filter { cat in
            categoryReceipts.contains { receipt in
                receipt.category == cat || receipt.items.contains { $0.category == cat }
            }
        }
        
        if activeCategories.count <= 3 {
            return activeCategories.map { $0.rawValue }.joined(separator: ", ")
        } else {
            let first3 = activeCategories.prefix(3).map { $0.rawValue }.joined(separator: ", ")
            return "\(first3) and \(activeCategories.count - 3) more"
        }
    }
    
    // Updated icons and colors for budget categories
    private func budgetCategoryIcon(for budgetCategory: EnhancedBudgetCategory) -> String {
        switch budgetCategory {
        case .materials: return "cube.box.fill"
        case .generalConditions: return "building.2.fill" 
        case .labor: return "person.2.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
    
    private func budgetCategoryColor(for budgetCategory: EnhancedBudgetCategory) -> Color {
        switch budgetCategory {
        case .materials: return .green
        case .generalConditions: return .blue
        case .labor: return .orange
        case .contingency: return .red
        }
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
            
            // Show subcategory breakdown if multiple categories
            if relevantReceiptCategories.count > 1 {
                subcategoryBreakdownSection
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var subcategoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subcategory Breakdown")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ForEach(getSubcategorySpending(), id: \.0) { categoryName, amount in
                HStack {
                    Text(categoryName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatCurrency(amount))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // Helper to get spending by subcategory
    private func getSubcategorySpending() -> [(String, Double)] {
        var categorySpending: [ReceiptCategory: Double] = [:]
        
        for receipt in categoryReceipts {
            if !receipt.items.isEmpty {
                for item in receipt.items {
                    if relevantReceiptCategories.contains(item.category) {
                        let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                        categorySpending[item.category, default: 0] += amount
                    }
                }
            } else {
                if relevantReceiptCategories.contains(receipt.category) {
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    categorySpending[receipt.category, default: 0] += amount
                }
            }
        }
        
        return categorySpending
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { ($0.key.rawValue, $0.value) }
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All \(displayCategoryName) Receipts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if categoryReceipts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: budgetCategoryIcon(for: mapToBudgetCategory(category)))
                        .font(.system(size: 48))
                        .foregroundColor(budgetCategoryColor(for: mapToBudgetCategory(category)).opacity(0.6))
                    
                    Text("No receipts found in this category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Add receipts to track spending in \(displayCategoryName.lowercased())")
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
                        EnhancedSemiTransparentReceiptRowCard(
                            receipt: receipt,
                            relevantCategories: Set(relevantReceiptCategories)
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // ... existing helper methods remain the same ...
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        
        // PHASE 2F: Complete renovation phase icons
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
        
        // PHASE 2F: Complete renovation phase colors
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
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// Enhanced receipt row that shows which specific categories contributed to spending
struct EnhancedSemiTransparentReceiptRowCard: View {
    let receipt: Receipt
    let relevantCategories: Set<ReceiptCategory>
    @State private var showingReceiptDetail = false
    
    var body: some View {
        Button {
            showingReceiptDetail = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(receipt.vendor)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
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
                    
                    // Show item breakdown if available and relevant
                    if !receipt.items.isEmpty {
                        let relevantItems = receipt.items.filter { relevantCategories.contains($0.category) }
                        if !relevantItems.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(relevantItems.prefix(3), id: \.id) { item in
                                    HStack {
                                        Text("• \(item.name)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(item.totalPrice.formatAsCurrency())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if relevantItems.count > 3 {
                                    Text("... and \(relevantItems.count - 3) more items")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                    } else if !receipt.notes.isEmpty {
                        Text(receipt.notes)
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
                        
                        // Show the specific category that made this receipt relevant
                        if relevantCategories.contains(receipt.category) {
                            if !receipt.paymentMethod.isEmpty {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(receipt.category.rawValue)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if !receipt.receiptNumber.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Receipt #\(receipt.receiptNumber)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Calculate the relevant amount from this receipt
                    let relevantAmount = calculateRelevantAmount()
                    
                    Text(formatCurrency(receipt.isReturn ? -relevantAmount : relevantAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(receipt.isReturn ? .red : .primary)
                    
                    if receipt.taxAmount > 0 {
                        Text("Tax: \(formatCurrency(receipt.taxAmount))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show total vs relevant if different
                    if relevantAmount != receipt.amount {
                        Text("(\(formatCurrency(receipt.amount)) total)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // Edit indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingReceiptDetail) {
            ReceiptDetailView(receipt: receipt)
        }
    }
    
    private func calculateRelevantAmount() -> Double {
        if !receipt.items.isEmpty {
            // Sum only items in relevant categories
            return receipt.items.reduce(0) { total, item in
                if relevantCategories.contains(item.category) {
                    return total + item.totalPrice
                }
                return total
            }
        } else {
            // Use full receipt amount if category matches
            return relevantCategories.contains(receipt.category) ? receipt.amount : 0
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
