import SwiftUI
import Charts

struct SpendingReportView: View {
    let project: Project
    let organization: Organization
    
    @State private var selectedTimeframe: TimeFrame = .all
    @State private var selectedReportType: ReportType = .category
    @State private var vendors: [Vendor] = []
    
    private var spendingReport: SpendingReport {
        generateSpendingReport(for: project, vendors: vendors)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        SummaryCard(
                            title: "Total Spent",
                            value: spendingReport.totalSpent,
                            icon: "dollarsign.circle.fill",
                            color: .blue
                        )
                        
                        SummaryCard(
                            title: "Receipts",
                            value: Double(spendingReport.receiptCount),
                            icon: "receipt.fill",
                            color: .green,
                            format: .number
                        )
                        
                        SummaryCard(
                            title: "Tax Paid",
                            value: spendingReport.totalTax,
                            icon: "percent",
                            color: .orange
                        )
                        
                        SummaryCard(
                            title: "Discounts",
                            value: spendingReport.totalDiscounts,
                            icon: "tag.fill",
                            color: .red
                        )
                    }
                    
                    // Chart Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Spending Breakdown")
                                .font(.headline)
                            
                            Spacer()
                            
                            Picker("Report Type", selection: $selectedReportType) {
                                ForEach(ReportType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 200)
                        }
                        
                        switch selectedReportType {
                        case .category:
                            CategoryBreakdown(data: spendingReport.categorySpending)
                        case .vendor:
                            VendorBreakdown(data: spendingReport.vendorSpending)
                        case .paymentMethod:
                            PaymentMethodBreakdown(data: spendingReport.paymentMethodSpending)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Budget Comparison
                    BudgetComparisonView(project: project, spendingReport: spendingReport)
                    
                    // Top Vendors
                    TopVendorsView(vendorSpending: spendingReport.vendorSpending, vendors: vendors)
                    
                    // Recent Activity
                    RecentActivityView(project: project)
                }
                .padding()
            }
            .navigationTitle("Spending Report")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadVendors()
            }
        }
    }
    
    private func loadVendors() {
        if let data = UserDefaults.standard.data(forKey: "vendors_\(organization.id)"),
           let decoded = try? JSONDecoder().decode([Vendor].self, from: data) {
            vendors = decoded
        }
    }
    
    /// Generate spending report for a project using REAL PROJECT DATA
    private func generateSpendingReport(for project: Project, vendors: [Vendor]) -> SpendingReport {
        let receipts = project.receipts
        
        // Calculate category spending from actual receipts
        let categorySpending = Dictionary(grouping: receipts, by: { $0.category })
            .mapValues { receipts in
                receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            }
        
        // Calculate vendor spending from actual receipts
        let vendorSpending = Dictionary(grouping: receipts, by: { $0.vendor })
            .mapValues { receipts in
                receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            }
        
        // Calculate payment method spending from actual receipts
        let paymentMethodSpending = Dictionary(grouping: receipts.filter { !$0.paymentMethod.isEmpty }, by: { $0.paymentMethod })
            .mapValues { receipts in
                receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            }
        
        // Calculate totals from actual data
        let totalSpent = receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
        let totalTax = receipts.reduce(0) { $0 + $1.taxAmount }
        let totalDiscounts = receipts.reduce(0) { $0 + $1.discountAmount }
        
        return SpendingReport(
            totalSpent: totalSpent,
            categorySpending: categorySpending,
            vendorSpending: vendorSpending,
            paymentMethodSpending: paymentMethodSpending,
            totalTax: totalTax,
            totalDiscounts: totalDiscounts,
            receiptCount: receipts.count,
            returnCount: receipts.filter { $0.isReturn }.count
        )
    }
}

/// Spending report structure
struct SpendingReport {
    let totalSpent: Double
    let categorySpending: [ReceiptCategory: Double]
    let vendorSpending: [String: Double]
    let paymentMethodSpending: [String: Double]
    let totalTax: Double
    let totalDiscounts: Double
    let receiptCount: Int
    let returnCount: Int
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    var format: FormatStyle = .currency(code: "USD")
    
    enum FormatStyle {
        case currency(code: String)
        case number
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            switch format {
            case .currency(let code):
                Text(value, format: .currency(code: code))
                    .font(.title2)
                    .fontWeight(.semibold)
            case .number:
                Text(Int(value), format: .number)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct CategoryBreakdown: View {
    let data: [ReceiptCategory: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if data.isEmpty {
                Text("No spending data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            } else {
                ForEach(Array(data.keys), id: \.self) { category in
                    HStack {
                        Rectangle()
                            .fill(colorForCategory(category))
                            .frame(width: 4, height: 20)
                        
                        Text(category.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(data[category] ?? 0, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .frame(minHeight: 120)
    }
    
    private func colorForCategory(_ category: ReceiptCategory) -> Color {
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
}

struct VendorBreakdown: View {
    let data: [String: Double]
    
    private var topVendors: [(String, Double)] {
        Array(data.sorted { $0.value > $1.value }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if topVendors.isEmpty {
                Text("No vendor data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            } else {
                ForEach(topVendors, id: \.0) { vendor, amount in
                    HStack {
                        Rectangle()
                            .fill(.blue.gradient)
                            .frame(width: 4, height: 20)
                        
                        Text(vendor)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(amount, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .frame(minHeight: 120)
    }
}

struct PaymentMethodBreakdown: View {
    let data: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if data.isEmpty {
                Text("No payment method data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            } else {
                ForEach(Array(data.keys), id: \.self) { method in
                    HStack {
                        Rectangle()
                            .fill(.purple)
                            .frame(width: 4, height: 20)
                        
                        Text(method)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(data[method] ?? 0, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .frame(minHeight: 120)
    }
}

struct BudgetComparisonView: View {
    let project: Project
    let spendingReport: SpendingReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget vs Actual")
                .font(.headline)
            
            VStack(spacing: 8) {
                BudgetRow(
                    category: "Materials",
                    budgeted: project.materialCost,
                    actual: spendingReport.categorySpending[.material] ?? 0
                )
                
                BudgetRow(
                    category: "General Conditions",
                    budgeted: project.generalConditions,
                    actual: spendingReport.categorySpending[.general] ?? 0
                )
                
                BudgetRow(
                    category: "Contingency",
                    budgeted: project.contingency,
                    actual: spendingReport.categorySpending[.contingency] ?? 0
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BudgetRow: View {
    let category: String
    let budgeted: Double
    let actual: Double
    
    private var percentage: Double {
        guard budgeted > 0 else { return 0 }
        return actual / budgeted
    }
    
    private var isOverBudget: Bool {
        actual > budgeted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(actual, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundColor(isOverBudget ? .red : .primary)
                
                Text("/ \(budgeted, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: min(percentage, 1.0))
                .tint(isOverBudget ? .red : .blue)
            
            if isOverBudget {
                Text("Over budget by \(actual - budgeted, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct TopVendorsView: View {
    let vendorSpending: [String: Double]
    let vendors: [Vendor]
    
    private var topVendors: [(String, Double)] {
        Array(vendorSpending.sorted { $0.value > $1.value }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Vendors")
                .font(.headline)
            
            if topVendors.isEmpty {
                Text("No vendor spending data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(topVendors, id: \.0) { vendorName, amount in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vendorName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let vendor = vendors.first(where: { $0.name == vendorName }) {
                                Text(vendor.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(amount, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentActivityView: View {
    let project: Project
    
    private var recentReceipts: [Receipt] {
        project.receipts
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            if recentReceipts.isEmpty {
                Text("No recent receipts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentReceipts) { receipt in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(receipt.vendor)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(receipt.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(receipt.amount, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(receipt.isReturn ? .red : .primary)
                            
                            Text(receipt.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

public enum TimeFrame: String, CaseIterable, Identifiable {
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"
    case all = "All Time"
    
    public var id: Self { self }
}

public enum ReportType: String, CaseIterable, Identifiable {
    case category = "Category"
    case vendor = "Vendor"
    case paymentMethod = "Payment"
    
    public var id: Self { self }
}

#if DEBUG
struct SpendingReportView_Previews: PreviewProvider {
    static var previews: some View {
        SpendingReportView(
            project: Project(
                name: "Sample Project",
                client: "Sample Client",
                totalBudget: 10000,
                materialCost: 5000,
                laborCost: 3000,
                generalConditions: 1000,
                contingency: 1000,
                profit: 0,
                startDate: Date(),
                endDate: Date()
            ),
            organization: Organization(
                id: "sample",
                name: "Sample Organization"
            )
        )
    }
}
#endif