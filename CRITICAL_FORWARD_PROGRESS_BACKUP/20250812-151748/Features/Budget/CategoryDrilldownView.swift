import SwiftUI
import Charts

// MARK: - Category Drilldown View
struct CategoryDrilldownView: View {
    let category: CategoryType
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @State private var selectedTimeFrame: TimeFrame = .allTime
    @State private var showingReceiptList = false
    @State private var selectedSubcategory: ReceiptCategory?
    
    // Add this to the @State variables at the top
    @State private var showingBudgetIntegratedEntry = false
    @State private var suggestedCategory: ReceiptCategory?
    
    private enum TimeFrame: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case last3Months = "Last 3 Months"
        case allTime = "All Time"
        
        var days: Int? {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .last3Months: return 90
            case .allTime: return nil
            }
        }
    }
    
    enum CategoryType {
        case generalConditions
        case materials
        case labor
        case contingency
        
        var title: String {
            switch self {
            case .generalConditions: return "General Conditions"
            case .materials: return "Materials"
            case .labor: return "Labor"
            case .contingency: return "Contingency"
            }
        }
        
        var icon: String {
            switch self {
            case .generalConditions: return "building.fill"
            case .materials: return "hammer.fill"
            case .labor: return "person.2.fill"
            case .contingency: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .generalConditions: return .blue
            case .materials: return .orange
            case .labor: return .green
            case .contingency: return .red
            }
        }
        
        var budgetAmount: Double {
            switch self {
            case .generalConditions: return 0 // Will be calculated from project
            case .materials: return 0
            case .labor: return 0
            case .contingency: return 0
            }
        }
    }
    
    private var filteredBreakdown: [(ReceiptCategory, Double)] {
        let breakdown = projectVM.getDetailedSpendingBreakdown(for: categoryEnum)
        
        guard let days = selectedTimeFrame.days else {
            return breakdown
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filteredReceipts = project.receipts.filter { $0.date >= cutoffDate }
        
        // Recalculate breakdown for filtered receipts
        let filteredBreakdown = Dictionary(grouping: filteredReceipts.filter { receipt in
            getCategoryForReceipt(receipt) == categoryEnum
        }) { receipt in
            receipt.category
        }.mapValues { receipts in
            receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
        }
        
        return filteredBreakdown.sorted { $0.value > $1.value }
    }
    
    private var categoryEnum: EnhancedBudgetCategory {
        switch category {
        case .generalConditions: return .generalConditions
        case .materials: return .materials
        case .labor: return .labor
        case .contingency: return .contingency
        }
    }
    
    private var totalSpent: Double {
        filteredBreakdown.reduce(0) { $0 + $1.1 }
    }
    
    private var budgetAmount: Double {
        switch category {
        case .generalConditions: return project.generalConditions
        case .materials: return project.materialCost
        case .labor: return project.laborCost
        case .contingency: return project.contingency
        }
    }
    
    private var budgetUtilization: Double {
        budgetAmount > 0 ? (totalSpent / budgetAmount) * 100 : 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with key metrics
                    headerSection
                    
                    // Time frame selector
                    timeFrameSelector
                    
                    // Budget utilization chart
                    budgetUtilizationChart
                    
                    // Spending breakdown chart
                    spendingBreakdownChart
                    
                    // Detailed breakdown list
                    detailedBreakdownList
                    
                    // Trend analysis
                    trendAnalysisSection
                }
                .padding()
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingReceiptList) {
            if let subcategory = selectedSubcategory {
                CategoryReceiptListView(
                    category: subcategory,
                    project: project,
                    timeFrame: selectedTimeFrame
                )
                .environmentObject(projectVM)
            }
        }
        .sheet(isPresented: $showingBudgetIntegratedEntry) {
            BudgetIntegratedReceiptEntryView()
                .environmentObject(projectVM)
                .onAppear {
                    // Pre-select the category if coming from category drilldown
                    if let category = suggestedCategory {
                        // This would set the initial category in the budget-integrated entry
                        // The actual implementation would need a way to pass the suggested category
                    }
                }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category icon and title
            HStack {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundColor(category.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("for \(project.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Key metrics cards
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Spent",
                    value: totalSpent.formatAsCurrency(),
                    subtitle: "\(selectedTimeFrame.rawValue.lowercased())",
                    icon: "dollarsign.circle.fill",
                    color: totalSpent > budgetAmount ? .red : .primary
                )
                
                MetricCard(
                    title: "Budget",
                    value: budgetAmount.formatAsCurrency(),
                    subtitle: "allocated",
                    icon: "target",
                    color: .blue
                )
                
                MetricCard(
                    title: "Remaining",
                    value: (budgetAmount - totalSpent).formatAsCurrency(),
                    subtitle: "\(Int(100 - budgetUtilization))% left",
                    icon: "chart.pie.fill",
                    color: budgetUtilization > 100 ? .red : budgetUtilization > 80 ? .orange : .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Time Frame Selector
    @ViewBuilder
    private var timeFrameSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTimeFrame = timeFrame
                            }
                        } label: {
                            Text(timeFrame.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTimeFrame == timeFrame ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedTimeFrame == timeFrame ? category.color : Color(.systemGray5))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    // MARK: - Budget Utilization Chart
    @ViewBuilder
    private var budgetUtilizationChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget Utilization")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 20)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        budgetUtilization > 100 ? .red : budgetUtilization > 80 ? .orange : category.color,
                                        budgetUtilization > 100 ? .red.opacity(0.7) : budgetUtilization > 80 ? .orange.opacity(0.7) : category.color.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: min(geometry.size.width * (budgetUtilization / 100), geometry.size.width),
                                height: 20
                            )
                            .overlay(
                                // Percentage text
                                Text("\(Int(budgetUtilization))%")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .opacity(budgetUtilization > 10 ? 1 : 0)
                            )
                    }
                }
                .frame(height: 20)
                
                // Status message
                HStack {
                    Image(systemName: budgetUtilization > 100 ? "exclamationmark.triangle.fill" : budgetUtilization > 80 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(budgetUtilization > 100 ? .red : budgetUtilization > 80 ? .orange : .green)
                    
                    Text(budgetStatusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Spending Breakdown Chart
    @ViewBuilder
    private var spendingBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart(filteredBreakdown.prefix(8), id: \.0) { item in
                    BarMark(
                        x: .value("Amount", item.1),
                        y: .value("Category", item.0.rawValue)
                    )
                    .foregroundStyle(category.color.gradient)
                    .cornerRadius(4)
                }
                .frame(height: max(240, CGFloat(filteredBreakdown.prefix(8).count * 30)))
                .chartXAxis {
                    AxisMarks(format: .currency(code: "USD"))
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let category = value.as(String.self) {
                                Text(category)
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS 15
                VStack(spacing: 8) {
                    ForEach(Array(filteredBreakdown.prefix(8).enumerated()), id: \.offset) { index, item in
                        HorizontalBarView(
                            title: item.0.rawValue,
                            value: item.1,
                            maxValue: filteredBreakdown.first?.1 ?? 1,
                            color: category.color
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Detailed Breakdown List
    @ViewBuilder
    private var detailedBreakdownList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Categories")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredBreakdown.enumerated()), id: \.offset) { index, item in
                    CategoryBreakdownRow(
                        category: item.0,
                        amount: item.1,
                        percentage: totalSpent > 0 ? (item.1 / totalSpent) * 100 : 0,
                        color: category.color,
                        receiptCount: getReceiptCount(for: item.0)
                    ) {
                        selectedSubcategory = item.0
                        showingReceiptList = true
                    }
                    .contextMenu {
                        Button {
                            suggestedCategory = item.0
                            showingBudgetIntegratedEntry = true
                        } label: {
                            Label("Add Receipt to \(item.0.rawValue)", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Trend Analysis Section
    @ViewBuilder
    private var trendAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Weekly spending trend
            if #available(iOS 16.0, *) {
                let trendData = getWeeklyTrendData()
                
                Chart(trendData, id: \.week) { item in
                    LineMark(
                        x: .value("Week", item.week),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(category.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Week", item.week),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(category.color.opacity(0.1))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisValueLabel(format: .dateTime.week(.defaultDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks(format: .currency(code: "USD"))
                }
            } else {
                // Fallback trend visualization for iOS 15
                Text("Trend analysis available on iOS 16+")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Trend insights
            VStack(alignment: .leading, spacing: 8) {
                Text("Insights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(getTrendInsights(), id: \.self) { insight in
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private var budgetStatusMessage: String {
        if budgetUtilization > 100 {
            return "Over budget by \((budgetUtilization - 100).formatted(.number.precision(.fractionLength(1))))%"
        } else if budgetUtilization > 80 {
            return "Approaching budget limit"
        } else {
            return "Within budget"
        }
    }
    
    private func getCategoryForReceipt(_ receipt: Receipt) -> EnhancedBudgetCategory {
        switch receipt.category {
        case .general, .permits, .cleanup:
            return .generalConditions
        case .material, .demolition, .sitework, .foundation, .framing, .roofing, .exterior,
             .electrical, .plumbing, .hvac, .insulation, .drywall, .flooring,
             .trim, .paint, .kitchen, .bathroom, .fixtures, .appliances,
             .landscaping, .lighting, .cabinetry, .countertops, .tile, .windows, .specialty:
            return .materials
        case .contingency:
            return .contingency
        }
    }
    
    private func getReceiptCount(for category: ReceiptCategory) -> Int {
        let relevantReceipts: [Receipt]
        
        if let days = selectedTimeFrame.days {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            relevantReceipts = project.receipts.filter { $0.date >= cutoffDate && $0.category == category }
        } else {
            relevantReceipts = project.receipts.filter { $0.category == category }
        }
        
        return relevantReceipts.count
    }
    
    @available(iOS 16.0, *)
    private func getWeeklyTrendData() -> [(week: Date, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        
        var weeklyData: [(week: Date, amount: Double)] = []
        
        for i in 0..<12 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: i, to: startDate) ?? startDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            
            let weeklyAmount = project.receipts.filter { receipt in
                getCategoryForReceipt(receipt) == categoryEnum &&
                receipt.date >= weekStart && receipt.date <= weekEnd
            }.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            weeklyData.append((week: weekStart, amount: weeklyAmount))
        }
        
        return weeklyData
    }
    
    private func getTrendInsights() -> [String] {
        var insights: [String] = []
        
        if budgetUtilization > 90 {
            insights.append("Budget is nearly exhausted - consider reallocating funds")
        }
        
        if let topCategory = filteredBreakdown.first {
            let percentage = totalSpent > 0 ? (topCategory.1 / totalSpent) * 100 : 0
            if percentage > 50 {
                insights.append("\(topCategory.0.rawValue) accounts for \(Int(percentage))% of spending")
            }
        }
        
        let recentSpending = getRecentSpendingTrend()
        if recentSpending > 1.2 {
            insights.append("Spending has increased significantly in recent weeks")
        } else if recentSpending < 0.8 {
            insights.append("Spending has decreased compared to earlier periods")
        }
        
        return insights
    }
    
    private func getRecentSpendingTrend() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Compare last 2 weeks to previous 2 weeks
        let recentStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let previousEnd = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        
        let recentSpending = project.receipts.filter { receipt in
            getCategoryForReceipt(receipt) == categoryEnum &&
            receipt.date >= recentStart
        }.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
        
        let previousSpending = project.receipts.filter { receipt in
            getCategoryForReceipt(receipt) == categoryEnum &&
            receipt.date >= previousStart && receipt.date < previousEnd
        }.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
        
        return previousSpending > 0 ? recentSpending / previousSpending : 1.0
    }
}

// MARK: - Supporting Components

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct HorizontalBarView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value.formatAsCurrency())
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.gradient)
                        .frame(
                            width: geometry.size.width * (value / maxValue),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
    }
}

struct CategoryBreakdownRow: View {
    let category: ReceiptCategory
    let amount: Double
    let percentage: Double
    let color: Color
    let receiptCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(receiptCount) receipt\(receiptCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(amount.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    
                    Text("\(percentage.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Receipt List View
struct CategoryReceiptListView: View {
    let category: ReceiptCategory
    let project: Project
    let timeFrame: CategoryDrilldownView.TimeFrame
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var filteredReceipts: [Receipt] {
        var receipts = project.receipts.filter { $0.category == category }
        
        if let days = timeFrame.days {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            receipts = receipts.filter { $0.date >= cutoffDate }
        }
        
        return receipts.sorted { $0.date > $1.date }
    }
    
    private var totalAmount: Double {
        filteredReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Summary header
                VStack(spacing: 12) {
                    HStack {
                        Text(category.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(totalAmount.formatAsCurrency())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("\(filteredReceipts.count) receipt\(filteredReceipts.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(timeFrame.rawValue.lowercased())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Receipt list
                if filteredReceipts.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "receipt")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Receipts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("No receipts found for \(category.rawValue.lowercased()) in the selected time period.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                } else {
                    List(filteredReceipts) { receipt in
                        ReceiptDetailRow(receipt: receipt)
                    }
                }
            }
            .navigationTitle("Receipt Details")
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
}

struct ReceiptDetailRow: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(receipt.vendor)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(receipt.isReturn ? .red : .primary)
                    
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
                }
            }
            
            HStack {
                Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !receipt.receiptNumber.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Receipt #\(receipt.receiptNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(receipt.paymentMethod)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            
            if !receipt.notes.isEmpty {
                Text(receipt.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}