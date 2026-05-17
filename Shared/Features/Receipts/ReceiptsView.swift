import SwiftUI
import OSLog
import UIKit

private enum ReceiptUITestLaunch {
    static let modeKey = "RHEIR_UI_TEST_MODE"
    static let scannedReceiptReviewMode = "scanned_receipt_review"
}

private func receiptsAccessibilitySlug(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

struct ReceiptCardScope {
    let category: ReceiptCategory
    let amount: Double
    let items: [ReceiptItem]
}

private enum ReceiptRefundFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case refundedPurchases = "Refunded"
    case refundReceipts = "Refund Receipts"
    case notRefunded = "No Refunds"

    var id: Self { self }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .refundedPurchases: return "arrow.uturn.backward.circle"
        case .refundReceipts: return "minus.circle"
        case .notRefunded: return "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .all: return .blue
        case .refundedPurchases: return .orange
        case .refundReceipts: return .red
        case .notRefunded: return .green
        }
    }

    var summaryTitle: String {
        switch self {
        case .all: return "All Receipts"
        case .refundedPurchases: return "Refunded Purchases"
        case .refundReceipts: return "Refund Receipts"
        case .notRefunded: return "Receipts Without Refunds"
        }
    }

    func includes(_ receipt: Receipt, in allReceipts: [Receipt]) -> Bool {
        switch self {
        case .all:
            return true
        case .refundedPurchases:
            return !receipt.isReturn && receipt.refundedAmount(in: allReceipts) > 0
        case .refundReceipts:
            return receipt.isReturn
        case .notRefunded:
            return !receipt.isReturn && receipt.refundedAmount(in: allReceipts) <= 0
        }
    }
}

private struct ReceiptPaymentFilterOption: Identifiable {
    let key: String
    let title: String
    let receiptCount: Int
    let netTotal: Double

    var id: String { key }
}

private struct ReceiptFilterSummary {
    let title: String
    let receiptCount: Int
    let grossSpent: Double
    let refundedAmount: Double
    let netTotal: Double
}

private func receiptPaymentFilterKey(for receipt: Receipt) -> String {
    if let paymentMethodID = receipt.paymentMethodID, !paymentMethodID.isEmpty {
        return "id:\(paymentMethodID)"
    }

    if let details = receipt.paymentMethodDetails {
        let brand = details.cardBrand?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let lastFour = details.lastFourDigits?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !brand.isEmpty || !lastFour.isEmpty {
            return "card:\(brand):\(lastFour)"
        }
    }

    let method = receipt.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
    return method.isEmpty ? "method:unspecified" : "method:\(method.lowercased())"
}

private func receiptPaymentDisplayName(for receipt: Receipt) -> String {
    if let details = receipt.paymentMethodDetails {
        let brand = details.cardBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastFour = details.lastFourDigits?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !brand.isEmpty, !lastFour.isEmpty {
            return "\(brand) •••• \(lastFour)"
        }
        if !brand.isEmpty {
            return brand
        }
    }

    let method = receipt.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
    return method.isEmpty ? "Unspecified" : method
}

private func visibleParentReceiptRows(from receipts: [Receipt]) -> [Receipt] {
    let visibleReceiptIDs = Set(receipts.map(\.id))

    return receipts.filter { receipt in
        guard receipt.isPartialRefund,
              let sourceReceiptID = receipt.sourceReceiptID
        else {
            return true
        }

        return !visibleReceiptIDs.contains(sourceReceiptID)
    }
}

private func linkedRefundRows(
    for receipt: Receipt,
    in receipts: [Receipt],
    category: ReceiptCategory? = nil
) -> [Receipt] {
    receipt
        .linkedRefunds(in: receipts)
        .filter { refund in
            guard let category else { return true }
            return refund.hasScopedCategory(category)
        }
        .sorted { $0.date > $1.date }
}

struct ReceiptsView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showingNewReceipt = false
    @State private var scannerSession: ReceiptScannerSession?
    @State private var receiptToView: Receipt? = nil
    @State private var receiptToEdit: Receipt? = nil
    @State private var showingDeleteAlert = false
    @State private var receiptToDelete: Receipt? = nil
    @State private var selectedViewMode: ReceiptViewMode = .all
    @State private var selectedCategory: ReceiptCategory? = nil
    @State private var selectedRefundFilter: ReceiptRefundFilter = .all
    @State private var selectedPaymentFilterKey: String?
    @State private var searchText = ""
    @State private var expandedVendorGroups: Set<String> = []
    @State private var didSeedUITestScannerReview = false
    @AppStorage("hideReceiptScannerIntro") private var hideReceiptScannerIntro = false
    
    private enum ReceiptViewMode: String, CaseIterable {
        case all = "All"
        case categories = "Categories"
        case recent = "Recent"
        case byVendor = "By Vendor"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .categories: return "folder.fill"
            case .recent: return "clock.fill"
            case .byVendor: return "building.2.fill"
            }
        }
    }
    
    private var allProjectReceipts: [Receipt] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.normalizedReceiptCopy.receipts
    }

    private var searchMatchedReceipts: [Receipt] {
        var filteredReceipts = allProjectReceipts

        if !searchText.isEmpty {
            filteredReceipts = filteredReceipts.filter { receipt in
                receipt.vendor.localizedCaseInsensitiveContains(searchText) ||
                receipt.notes.localizedCaseInsensitiveContains(searchText) ||
                receipt.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return filteredReceipts
    }

    private var refundFilteredReceipts: [Receipt] {
        searchMatchedReceipts.filter { receipt in
            selectedRefundFilter.includes(receipt, in: allProjectReceipts)
        }
    }

    private var baseReceipts: [Receipt] {
        var filteredReceipts = refundFilteredReceipts

        if let selectedPaymentFilterKey {
            filteredReceipts = filteredReceipts.filter {
                receiptPaymentFilterKey(for: $0) == selectedPaymentFilterKey
            }
        }

        return filteredReceipts.sorted { $0.date > $1.date }
    }

    private var receipts: [Receipt] {
        guard let selectedCategory else { return baseReceipts }

        return baseReceipts.filter { receipt in
            receipt.hasScopedCategory(selectedCategory)
        }
    }
    
    private var receiptsByCategory: [ReceiptCategory: [Receipt]] {
        Dictionary(
            uniqueKeysWithValues: activeCategories.map { category in
                (
                    category,
                    baseReceipts.filter { receipt in
                        receipt.hasScopedCategory(category)
                    }
                )
            }
        )
    }
    
    private var receiptsByVendor: [String: [Receipt]] {
        Dictionary(grouping: receipts) { $0.vendor.lowercased() }
    }

    private var projectReceiptsForLinks: [Receipt] {
        allProjectReceipts
    }

    private var paymentFilterOptions: [ReceiptPaymentFilterOption] {
        Dictionary(grouping: refundFilteredReceipts, by: receiptPaymentFilterKey(for:))
            .map { key, receipts in
                let title = receipts
                    .map(receiptPaymentDisplayName(for:))
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    .first ?? "Unspecified"
                let netTotal = receipts.reduce(0.0) { $0 + $1.signedAmount }
                return ReceiptPaymentFilterOption(
                    key: key,
                    title: title,
                    receiptCount: receipts.count,
                    netTotal: netTotal
                )
            }
            .sorted { lhs, rhs in
                if lhs.netTotal == rhs.netTotal {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.netTotal > rhs.netTotal
            }
    }

    private var selectedPaymentFilterOption: ReceiptPaymentFilterOption? {
        guard let selectedPaymentFilterKey else { return nil }
        return paymentFilterOptions.first { $0.key == selectedPaymentFilterKey }
    }

    private var activeReceiptFilterSummary: ReceiptFilterSummary? {
        guard selectedRefundFilter != .all || selectedPaymentFilterKey != nil else { return nil }

        let grossSpent = receipts
            .filter { !$0.isReturn }
            .reduce(0.0) { $0 + max(0, $1.amount) }
        let directRefunds = receipts
            .filter(\.isReturn)
            .reduce(0.0) { $0 + max(0, $1.amount) }
        let linkedRefundsForPurchases = receipts
            .filter { !$0.isReturn }
            .reduce(0.0) { $0 + $1.refundedAmount(in: allProjectReceipts) }
        let refundedAmount = max(directRefunds, linkedRefundsForPurchases)
        let netTotal = receipts.reduce(0.0) { $0 + $1.signedAmount }
        let title: String

        if let paymentOption = selectedPaymentFilterOption, selectedRefundFilter != .all {
            title = "\(selectedRefundFilter.summaryTitle) · \(paymentOption.title)"
        } else if let paymentOption = selectedPaymentFilterOption {
            title = paymentOption.title
        } else {
            title = selectedRefundFilter.summaryTitle
        }

        return ReceiptFilterSummary(
            title: title,
            receiptCount: visibleParentReceiptRows(from: receipts).count,
            grossSpent: grossSpent,
            refundedAmount: refundedAmount,
            netTotal: netTotal
        )
    }
    
    // Get categories that actually have receipts
    private var activeCategories: [ReceiptCategory] {
        if let selectedCategory {
            return [selectedCategory]
        }

        return Array(
            Set(
                baseReceipts.flatMap { receipt in
                    Array(receipt.representedCategories)
                }
            )
        )
        .sorted { $0.rawValue < $1.rawValue }
    }

    private var hasScannerAIAccess: Bool {
        authVM.currentOrg?.subscriptionTier != .free
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Universal Header
                UniversalHeaderView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
                
                if projectVM.selectedProject != nil {
                    // Custom tab bar for view modes
                    viewModeSelector
                    
                    // Search bar
                    searchBar

                    if !allProjectReceipts.isEmpty {
                        filterChipsBar
                    }
                    
                    // Category filter (when categories mode is selected)
                    if selectedViewMode == .categories {
                        categoryFilterBar
                    }
                    
                    // Main content
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Enhanced FAB buttons
                if projectVM.selectedProject != nil {
                    enhancedFABButtons
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewReceipt) {
                if let project = projectVM.selectedProject {
                    ManualReceiptEntryView(isPresented: $showingNewReceipt, project: project)
                        .environmentObject(projectVM)
                }
            }
            .sheet(item: $scannerSession) { session in
                ReceiptScannerView(
                    isPresented: Binding(
                        get: { scannerSession?.id == session.id },
                        set: { isPresented in
                            if !isPresented && scannerSession?.id == session.id {
                                scannerSession = nil
                            }
                        }
                    ),
                    session: session
                )
                .environmentObject(projectVM)
            }
            .navigationDestination(item: $receiptToView) { receipt in
                ReceiptDetailView(receipt: receipt)
                    .environmentObject(projectVM)
            }
            .sheet(item: $receiptToEdit) { receipt in
                ReceiptEditView(receipt: receipt, isPresented: Binding(
                    get: { receiptToEdit != nil },
                    set: { if !$0 { receiptToEdit = nil } }
                ))
                .environmentObject(projectVM)
            }
            .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    receiptToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let receipt = receiptToDelete {
                        deleteReceipt(receipt)
                    }
                }
            } message: {
                if let receipt = receiptToDelete {
                    Text("Are you sure you want to delete the receipt from \(receipt.vendor) for \(receipt.amount.formatAsCurrency())? This action cannot be undone.")
                }
            }
            .onAppear {
                applyUITestScannerReviewSeedIfNeeded()
            }
            .onChange(of: selectedTab) { _, _ in
                applyUITestScannerReviewSeedIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private var viewModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(ReceiptViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedViewMode = mode
                            if mode != .categories {
                                selectedCategory = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.caption)
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedViewMode == mode ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(selectedViewMode == mode ? .white : .primary)
                    }
                    .accessibilityIdentifier("receipts-view-mode-\(receiptsAccessibilitySlug(mode.rawValue))")
                    .accessibilityValue(selectedViewMode == mode ? "selected" : "not selected")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search receipts...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityIdentifier("receipts-search-field")
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
                .accessibilityIdentifier("receipts-search-clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ReceiptRefundFilter.allCases) { filter in
                    filterChip(
                        title: filter.rawValue,
                        subtitle: refundFilterSubtitle(for: filter),
                        icon: filter.icon,
                        isSelected: selectedRefundFilter == filter,
                        tint: filter.tint
                    ) {
                        selectedRefundFilter = filter
                    }
                    .accessibilityIdentifier("receipts-refund-filter-\(receiptsAccessibilitySlug(filter.rawValue))")
                    .accessibilityValue(selectedRefundFilter == filter ? "selected" : "not selected")
                }

                if !paymentFilterOptions.isEmpty {
                    Divider()
                        .frame(height: 28)

                    filterChip(
                        title: "All Payments",
                        subtitle: "\(refundFilteredReceipts.count)",
                        icon: "creditcard",
                        isSelected: selectedPaymentFilterKey == nil,
                        tint: .blue
                    ) {
                        selectedPaymentFilterKey = nil
                    }
                    .accessibilityIdentifier("receipts-payment-filter-all")
                    .accessibilityValue(selectedPaymentFilterKey == nil ? "selected" : "not selected")

                    ForEach(paymentFilterOptions) { option in
                        filterChip(
                            title: option.title,
                            subtitle: option.netTotal.formatAsCurrency(),
                            icon: "creditcard.fill",
                            isSelected: selectedPaymentFilterKey == option.key,
                            tint: .purple
                        ) {
                            selectedPaymentFilterKey = option.key
                        }
                        .accessibilityIdentifier("receipts-payment-filter-\(receiptsAccessibilitySlug(option.title))")
                        .accessibilityValue(selectedPaymentFilterKey == option.key ? "selected" : "not selected")
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityIdentifier("receipts-filter-chips")
        .padding(.bottom, 8)
    }

    private func filterChip(
        title: String,
        subtitle: String?,
        icon: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? tint : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func refundFilterSubtitle(for filter: ReceiptRefundFilter) -> String {
        let matchingReceipts = searchMatchedReceipts.filter {
            filter.includes($0, in: allProjectReceipts)
        }

        switch filter {
        case .all:
            return "\(searchMatchedReceipts.count)"
        case .refundedPurchases:
            let refundedTotal = matchingReceipts.reduce(0.0) {
                $0 + $1.refundedAmount(in: allProjectReceipts)
            }
            return refundedTotal.formatAsCurrency()
        case .refundReceipts:
            let refundTotal = matchingReceipts.reduce(0.0) { $0 + max(0, $1.amount) }
            return refundTotal.formatAsCurrency()
        case .notRefunded:
            return "\(matchingReceipts.count)"
        }
    }
    
    @ViewBuilder
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories button
                Button {
                    selectedCategory = nil
                } label: {
                    Text("All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedCategory == nil ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(selectedCategory == nil ? .white : .primary)
                }
                .accessibilityIdentifier("receipts-category-filter-all")
                .accessibilityValue(selectedCategory == nil ? "selected" : "not selected")
                
                ForEach(activeCategories, id: \.self) { category in
                    Button {
                        selectedCategory = selectedCategory == category ? nil : category
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: categoryIcon(for: category))
                                .font(.caption2)
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedCategory == category ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                    }
                    .accessibilityIdentifier("receipts-category-filter-\(receiptsAccessibilitySlug(category.rawValue))")
                    .accessibilityValue(selectedCategory == category ? "selected" : "not selected")
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if receipts.isEmpty {
            if selectedCategory != nil || !searchText.isEmpty {
                WorkflowEmptyStateCard(
                    icon: "magnifyingglass.circle",
                    title: "No Matching Receipts",
                    message: filteredEmptyStateMessage,
                    primaryActionTitle: selectedCategory != nil ? "View All Receipts" : "Clear Search",
                    primaryAction: {
                        selectedCategory = nil
                        searchText = ""
                    }
                )
                .padding()
            } else {
                emptyReceiptsView
            }
        } else {
            contentForSelectedMode
        }
    }
    
    @ViewBuilder
    private var contentForSelectedMode: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let activeReceiptFilterSummary {
                    ReceiptFilterSummaryCard(summary: activeReceiptFilterSummary)
                }

                switch selectedViewMode {
                case .all, .recent:
                    allReceiptsContent
                case .categories:
                    categorizedReceiptsContent
                case .byVendor:
                    vendorGroupedContent
                }
            }
            .padding()
            .padding(.bottom, 120) // Space for FAB buttons
        }
    }
    
    @ViewBuilder
    private var allReceiptsContent: some View {
        ForEach(visibleParentReceiptRows(from: receipts)) { receipt in
            ReceiptCardGroup(
                receipt: receipt,
                scope: scope(for: receipt, category: selectedCategory),
                linkedRefunds: linkedRefundRows(
                    for: receipt,
                    in: projectReceiptsForLinks,
                    category: selectedCategory
                ),
                onView: {
                    receiptToView = receipt
                },
                onEdit: {
                    receiptToEdit = receipt
                },
                onDelete: {
                    receiptToDelete = receipt
                    showingDeleteAlert = true
                },
                onRefundView: { refund in
                    receiptToView = refund
                }
            )
        }
    }
    
    @ViewBuilder
    private var categorizedReceiptsContent: some View {
        if selectedCategory == nil {
            // Show category summary cards
            ForEach(activeCategories, id: \.self) { category in
                let categoryReceipts = receiptsByCategory[category] ?? []
                let totalSpent = categoryReceipts.reduce(0) { acc, receipt in
                    acc + receipt.scopedAmount(for: category)
                }
                
                CategorySummaryCard(
                    category: category,
                    receiptCount: categoryReceipts.count,
                    totalSpent: totalSpent,
                    onTap: {
                        selectedCategory = category
                    }
                )
            }
        } else {
            // Show receipts for selected category
            if let selectedCategory {
                let categoryReceipts = receipts
                let totalSpent = categoryReceipts.reduce(0) { acc, receipt in
                    acc + receipt.scopedAmount(for: selectedCategory)
                }

                CategoryDrilldownHeaderCard(
                    category: selectedCategory,
                    receiptCount: categoryReceipts.count,
                    totalSpent: totalSpent
                )

                ForEach(visibleParentReceiptRows(from: receipts)) { receipt in
                    ReceiptCardGroup(
                        receipt: receipt,
                        scope: scope(for: receipt, category: selectedCategory),
                        linkedRefunds: linkedRefundRows(
                            for: receipt,
                            in: projectReceiptsForLinks,
                            category: selectedCategory
                        ),
                        onView: {
                            receiptToView = receipt
                        },
                        onEdit: {
                            receiptToEdit = receipt
                        },
                        onDelete: {
                            receiptToDelete = receipt
                            showingDeleteAlert = true
                        },
                        onRefundView: { refund in
                            receiptToView = refund
                        }
                    )
                    .id("\(receipt.id)-\(receiptsAccessibilitySlug(selectedCategory.rawValue))")
                }
                .id("receipts-category-drilldown-\(selectedCategory.rawValue)")
            }
        }
    }
    
    @ViewBuilder
    private var vendorGroupedContent: some View {
        ForEach(receiptsByVendor.keys.sorted(), id: \.self) { vendorKey in
            let vendorReceipts = receiptsByVendor[vendorKey] ?? []
            let vendorName = vendorReceipts.first?.vendor ?? vendorKey
            let totalSpent = vendorReceipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            let vendorGroupID = vendorKey
            
            VendorGroupCard(
                vendorName: vendorName,
                receipts: vendorReceipts,
                totalSpent: totalSpent,
                isExpanded: expandedVendorGroups.contains(vendorGroupID),
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if expandedVendorGroups.contains(vendorGroupID) {
                            expandedVendorGroups.remove(vendorGroupID)
                        } else {
                            expandedVendorGroups.insert(vendorGroupID)
                        }
                    }
                },
                onReceiptView: { receipt in
                    receiptToView = receipt
                },
                onReceiptEdit: { receipt in
                    receiptToEdit = receipt
                },
                onReceiptDelete: { receipt in
                    receiptToDelete = receipt
                    showingDeleteAlert = true
                }
            )
        }
    }
    
    @ViewBuilder
    private var enhancedFABButtons: some View {
        HStack(spacing: 20) {
            Spacer()
            
            // Manual entry FAB
            Button {
                showingNewReceipt = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Manual")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .indigo]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .accessibilityIdentifier("receipts-fab-manual")
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingNewReceipt)
            
            // Scan receipt FAB
            Button {
                presentScanner()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Scan")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .accessibilityIdentifier("receipts-fab-scan")
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scannerSession != nil)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver"
        case .material: return "cube.box"
        case .contingency: return "exclamationmark.triangle"
        case .permits: return "doc.text"
        case .demolition: return "hammer"
        case .electrical: return "bolt"
        case .plumbing: return "drop"
        case .hvac: return "wind"
        case .paint: return "paintbrush"
        case .flooring: return "square.grid.4x3"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub"
        default: return "tag"
        }
    }
    
    private func deleteReceipt(_ receipt: Receipt) {
        guard let selectedProject = projectVM.selectedProject else { 
            receiptToDelete = nil
            return 
        }
        
        Logger.receiptWorkflow.notice(
            "Deleting receipt [vendor=\(receipt.vendor, privacy: .private(mask: .hash)) amount=\(receipt.amount, privacy: .public)]"
        )
        
        var updatedProject = selectedProject
        updatedProject.receipts.removeAll { $0.id == receipt.id }
        updatedProject.lastModifiedDate = Date()
        
        // Update vendor and payment method spending totals
        updateVendorSpending(for: receipt, isRemoving: true)
        updatePaymentMethodSpending(for: receipt, isRemoving: true)
        
        Task {
            await projectVM.updateProject(updatedProject)
            
            // CRITICAL: Save organization-specific backup to ensure persistence
            projectVM.saveOrganizationSpecificBackup()
            
            await MainActor.run {
                projectVM.recomputeFilteredReceipts()
            }
        }
        
        receiptToDelete = nil
        
        Logger.receiptWorkflow.notice(
            "Receipt deleted and persisted [receiptID=\(receipt.id, privacy: .private(mask: .hash))]"
        )
    }
    
    private func updateVendorSpending(for receipt: Receipt, isRemoving: Bool) {
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        let vendor = projectVM.vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: .other
        )
        
        if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == vendor.id }) {
            projectVM.vendorService.vendors[index].totalSpent += adjustmentAmount
            projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
        }
    }
    
    private func updatePaymentMethodSpending(for receipt: Receipt, isRemoving: Bool) {
        guard !receipt.paymentMethod.isEmpty else { return }
        
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: .other
        )
        
        if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
            projectVM.paymentMethodService.paymentMethods[index].totalSpent += adjustmentAmount
            projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
        }
    }

    private func presentScanner() {
        guard let project = projectVM.selectedProject else {
            return
        }

        scannerSession = ReceiptScannerSession(
            project: project,
            hideIntro: hideReceiptScannerIntro,
            hasAIAccess: hasScannerAIAccess
        )
    }

    private func applyUITestScannerReviewSeedIfNeeded() {
        guard !didSeedUITestScannerReview else {
            return
        }
        guard ProcessInfo.processInfo.environment[ReceiptUITestLaunch.modeKey] == ReceiptUITestLaunch.scannedReceiptReviewMode else {
            return
        }
        guard selectedTab == .receipts else {
            return
        }
        guard let project = projectVM.selectedProject else {
            return
        }
        guard project.normalizedReceiptCopy.receipts.isEmpty else {
            didSeedUITestScannerReview = true
            return
        }

        let seededSession = ReceiptScannerSession(
            project: project,
            hideIntro: true,
            hasAIAccess: true
        )
        seededSession.setDocumentScannerPresented(false)
        seededSession.scannedImage = makeUITestScannedReceiptImage()
        seededSession.analysisResult = makeUITestScannedReceiptAnalysis()
        seededSession.setCurrentStep(.complete)
        seededSession.showingAnalysisView = true
        seededSession.receiptSaveCompleted = false

        scannerSession = seededSession
        didSeedUITestScannerReview = true
    }

    private func makeUITestScannedReceiptAnalysis() -> ReceiptAnalysisResult {
        ReceiptAnalysisResult(
            vendor: "UI Test Scanned Vendor",
            category: ReceiptCategory.material.rawValue,
            amount: 89.76,
            taxAmount: 7.26,
            discountAmount: 0,
            paymentMethod: "Visa",
            paymentMethodDetails: PaymentMethodDetails(cardBrand: "Visa", lastFourDigits: "4242", accountInfo: nil),
            receiptNumber: "SCAN-4242",
            receiptDate: Date(timeIntervalSince1970: 1_735_171_200),
            items: [
                ReceiptItemResult(
                    name: "Primer",
                    quantity: 2,
                    unitPrice: 19.99,
                    totalPrice: 39.98,
                    category: ReceiptCategory.material.rawValue
                ),
                ReceiptItemResult(
                    name: "Brush Set",
                    quantity: 1,
                    unitPrice: 42.52,
                    totalPrice: 42.52,
                    category: ReceiptCategory.material.rawValue
                )
            ],
            isReturn: false,
            confidence: 0.91
        )
    }

    private func makeUITestScannedReceiptImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 640))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 640))

            UIColor(white: 0.92, alpha: 1).setFill()
            context.fill(CGRect(x: 24, y: 24, width: 272, height: 592))

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            NSString(string: "UI Test Supply").draw(at: CGPoint(x: 40, y: 52), withAttributes: textAttributes)

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
            NSString(string: "Primer x2        $39.98").draw(at: CGPoint(x: 40, y: 120), withAttributes: bodyAttributes)
            NSString(string: "Brush Set x1     $42.52").draw(at: CGPoint(x: 40, y: 156), withAttributes: bodyAttributes)
            NSString(string: "Tax              $7.26").draw(at: CGPoint(x: 40, y: 224), withAttributes: bodyAttributes)
            NSString(string: "Total            $89.76").draw(at: CGPoint(x: 40, y: 276), withAttributes: bodyAttributes)
            NSString(string: "Receipt # SCAN-4242").draw(at: CGPoint(x: 40, y: 328), withAttributes: bodyAttributes)
        }
    }
    
    private var emptyStateView: some View {
        ProjectSelectionRequiredView(
            title: "Select a Project",
            message: "Choose a project from the Projects tab before viewing receipts.",
            actionTitle: "Go to Projects",
            action: {
                selectedTab = .projects
            }
        )
    }
    
    private var emptyReceiptsView: some View {
        WorkflowEmptyStateCard(
            icon: "receipt",
            title: "No Receipts Yet",
            message: "Scan a receipt or add one manually to start tracking project costs.",
            primaryActionTitle: "Scan Receipt",
            primaryAction: {
                presentScanner()
            },
            primaryActionIdentifier: "receipts-empty-scan",
            secondaryActionTitle: "Manual Entry",
            secondaryAction: {
                showingNewReceipt = true
            },
            secondaryActionIdentifier: "receipts-empty-manual-entry"
        )
        .padding()
    }

    private var filteredEmptyStateMessage: String {
        if let selectedCategory {
            return "No receipts found in the \(selectedCategory.rawValue) category. Clear the filters to see every saved receipt."
        }

        return "Try a different vendor, note, or item search."
    }

    private func scope(for receipt: Receipt, category: ReceiptCategory?) -> ReceiptCardScope? {
        guard let category else { return nil }
        return ReceiptCardScope(
            category: category,
            amount: receipt.scopedAmount(for: category),
            items: receipt.scopedItems(for: category)
        )
    }
}

// MARK: - Supporting View Components

struct ReceiptCardGroup: View {
    let receipt: Receipt
    let scope: ReceiptCardScope?
    let linkedRefunds: [Receipt]
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRefundView: (Receipt) -> Void

    @State private var isShowingLinkedRefunds = false

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(receipt.vendor)
    }

    private var linkedRefundTotal: Double {
        linkedRefunds.reduce(0.0) { $0 + max(0, $1.amount) }
    }

    private var linkedRefundSummary: String {
        let receiptLabel = linkedRefunds.count == 1 ? "receipt" : "receipts"
        return "\(linkedRefunds.count) linked refund \(receiptLabel) • \(linkedRefundTotal.formatAsCurrency()) refunded"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EnhancedReceiptCard(
                receipt: receipt,
                scope: scope,
                linkedRefunds: linkedRefunds,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete
            )

            if !linkedRefunds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingLinkedRefunds.toggle()
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: isShowingLinkedRefunds ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Refund receipts")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Text(isShowingLinkedRefunds ? linkedRefundSummary : "\(linkedRefundSummary) • tap to view")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.leading, 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("receipt-card-linked-refunds-toggle-\(accessibilitySlug)")
                    .accessibilityValue(isShowingLinkedRefunds ? "expanded" : "collapsed")

                    if isShowingLinkedRefunds {
                        ForEach(linkedRefunds) { refund in
                            LinkedRefundReceiptCard(refund: refund) {
                                onRefundView(refund)
                            }
                            .padding(.leading, 18)
                        }
                    }
                }
            }
        }
    }
}

struct LinkedRefundReceiptCard: View {
    let refund: Receipt
    let onView: () -> Void

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(refund.vendor)
    }

    private var itemSlug: String {
        receiptsAccessibilitySlug(refund.items.first?.name ?? refund.id)
    }

    private var itemSummary: String {
        guard !refund.items.isEmpty else { return "Linked refund" }

        let names = refund.items.prefix(2).map(\.name).joined(separator: ", ")
        let remainder = refund.items.count > 2 ? " +\(refund.items.count - 2) more" : ""
        return "\(names)\(remainder)"
    }

    var body: some View {
        Button(action: onView) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Refund")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(refund.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(refund.signedAmount.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }

                    Text(itemSummary)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if refund.taxAmount > 0 {
                        Text("Includes \(refund.taxAmount.formatAsCurrency()) tax")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.red.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("receipt-card-linked-refund-\(accessibilitySlug)-\(itemSlug)")
    }
}

struct EnhancedReceiptCard: View {
    let receipt: Receipt
    let scope: ReceiptCardScope?
    let linkedRefunds: [Receipt]
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingFullImage = false

    init(
        receipt: Receipt,
        scope: ReceiptCardScope? = nil,
        linkedRefunds: [Receipt] = [],
        onView: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.receipt = receipt
        self.scope = scope
        self.linkedRefunds = linkedRefunds
        self.onView = onView
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(receipt.vendor)
    }

    private var scopedAccessibilitySuffix: String {
        guard let scope else { return "" }
        return "-\(receiptsAccessibilitySlug(scope.category.rawValue))"
    }

    private var displayedCategory: ReceiptCategory {
        scope?.category ?? receipt.category
    }

    private var displayedAmount: Double {
        scope?.amount ?? receipt.signedAmount
    }

    private var matchedItems: [ReceiptItem] {
        scope?.items ?? []
    }

    private var categoryContextSummary: String? {
        guard let scope, !matchedItems.isEmpty else { return nil }

        let previewNames = matchedItems.prefix(2).map(\.name).joined(separator: ", ")
        let remainderCount = matchedItems.count - min(matchedItems.count, 2)
        let remainderText = remainderCount > 0 ? " +\(remainderCount) more" : ""
        let itemLabel = matchedItems.count == 1 ? "item" : "items"

        return "\(matchedItems.count) \(scope.category.rawValue.lowercased()) \(itemLabel): \(previewNames)\(remainderText)"
    }

    private var linkedRefundTotal: Double {
        linkedRefunds.reduce(0.0) { $0 + max(0, $1.amount) }
    }

    private var refundBadgeText: String? {
        guard !receipt.isReturn, linkedRefundTotal > 0 else { return nil }
        return linkedRefundTotal >= receipt.amount - 0.000_001 ? "REFUNDED" : "PARTIAL REFUND"
    }
    
    var body: some View {
        Button(action: onView) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(receipt.vendor)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if receipt.isReturn {
                                Text("RETURN")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            } else if let refundBadgeText {
                                Text(refundBadgeText)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(linkedRefundTotal >= receipt.amount - 0.000_001 ? Color.red : Color.orange)
                                    .cornerRadius(6)
                            }
                        }
                        
                        HStack {
                            Image(systemName: categoryIcon(for: displayedCategory))
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(displayedCategory.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("receipt-card-category-\(accessibilitySlug)\(scopedAccessibilitySuffix)")
                            
                            Spacer()
                            
                            Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(displayedAmount.formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(displayedAmount < 0 ? .red : .primary)
                            .accessibilityIdentifier("receipt-card-amount-\(accessibilitySlug)\(scopedAccessibilitySuffix)")
                        
                        if receipt.taxAmount > 0 {
                            Text("Tax: \(receipt.taxAmount.formatAsCurrency())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !receipt.notes.isEmpty {
                    HStack {
                        Text(receipt.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()
                    }
                }

                if let categoryContextSummary {
                    HStack {
                        Text(categoryContextSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()
                    }
                }

                if linkedRefundTotal > 0, !receipt.isReturn {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundColor(.orange)
                        Text("Refunded \(linkedRefundTotal.formatAsCurrency()) in \(linkedRefunds.count) linked refund\(linkedRefunds.count == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .accessibilityIdentifier("receipt-card-refunded-total-\(accessibilitySlug)")
                        Spacer()
                    }
                }
                
                // Enhanced payment method display with card details
                HStack {
                    if !receipt.paymentMethod.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: paymentMethodIcon(for: receipt.paymentMethod))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(receipt.paymentMethod)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let paymentDetails = receipt.paymentMethodDetails {
                                    HStack(spacing: 4) {
                                        if let cardBrand = paymentDetails.cardBrand {
                                            Text(cardBrand)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if let lastFour = paymentDetails.lastFourDigits, !lastFour.isEmpty {
                                            Text("•••• \(lastFour)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if receipt.hasReceiptImage {
                        Button {
                            showingFullImage = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("View")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if !receipt.receiptNumber.isEmpty {
                        Text("Receipt #\(receipt.receiptNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityIdentifier("receipt-card-view-image-\(accessibilitySlug)")
                        .buttonStyle(.borderless)
                    }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .accessibilityIdentifier("receipt-card-\(receipt.vendor)")
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if receipt.hasReceiptImage {
                Button("View Receipt Image") {
                    showingFullImage = true
                }
            }
            
            Button("Edit") {
                onEdit()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showingFullImage) {
            if receipt.hasReceiptImage {
                if let receiptImage = receipt.receiptImage {
                    ZoomableImageView(image: receiptImage) {
                        showingFullImage = false
                    }
                    .ignoresSafeArea()
                } else {
                    Text("Receipt image unavailable")
                        .padding()
                }
            }
        }
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver"
        case .material: return "cube.box"
        case .contingency: return "exclamationmark.triangle"
        case .permits: return "doc.text"
        case .demolition: return "hammer"
        case .electrical: return "bolt"
        case .plumbing: return "drop"
        case .hvac: return "wind"
        case .paint: return "paintbrush"
        case .flooring: return "square.grid.4x3"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub"
        default: return "tag"
        }
    }
    
    private func paymentMethodIcon(for paymentMethod: String) -> String {
        let method = paymentMethod.lowercased()
        if method.contains("credit") || method.contains("visa") || method.contains("mastercard") || method.contains("amex") || method.contains("discover") {
            return "creditcard.fill"
        } else if method.contains("debit") {
            return "creditcard"
        } else if method.contains("cash") {
            return "dollarsign.circle.fill"
        } else if method.contains("check") {
            return "checkmark.rectangle.fill"
        } else {
            return "creditcard"
        }
    }
}

struct CategoryDrilldownHeaderCard: View {
    let category: ReceiptCategory
    let receiptCount: Int
    let totalSpent: Double

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(category.rawValue)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: categoryIcon(for: category))
                .font(.title3.weight(.semibold))
                .foregroundColor(categoryColor(for: category))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(categoryColor(for: category).opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(category.rawValue) Total")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("\(receiptCount) receipt\(receiptCount == 1 ? "" : "s") with \(category.rawValue) spend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("receipts-category-drilldown-count-\(accessibilitySlug)")
            }

            Spacer()

            Text(totalSpent.formatAsCurrency())
                .font(.title3.weight(.bold))
                .foregroundColor(totalSpent < 0 ? .red : .primary)
                .accessibilityIdentifier("receipts-category-drilldown-total-\(accessibilitySlug)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        case .permits: return "doc.text.fill"
        case .demolition: return "hammer.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .paint: return "paintbrush.fill"
        case .flooring: return "square.grid.4x3.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub.fill"
        default: return "tag.fill"
        }
    }

    private func categoryColor(for category: ReceiptCategory) -> Color {
        switch category {
        case .general: return .blue
        case .material: return .green
        case .contingency: return .orange
        case .permits: return .purple
        case .demolition: return .red
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .hvac: return .cyan
        case .paint: return .pink
        case .flooring: return .brown
        case .kitchen: return .orange
        case .bathroom: return .teal
        default: return .secondary
        }
    }
}

struct CategorySummaryCard: View {
    let category: ReceiptCategory
    let receiptCount: Int
    let totalSpent: Double
    let onTap: () -> Void

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(category.rawValue)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: categoryIcon(for: category))
                            .font(.title2)
                            .foregroundColor(categoryColor(for: category))
                        
                        Text(category.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("\(receiptCount) receipt\(receiptCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("receipts-category-summary-count-\(accessibilitySlug)")
                        
                        Spacer()
                        
                        Text(totalSpent.formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(totalSpent >= 0 ? .primary : .red)
                            .accessibilityIdentifier("receipts-category-summary-total-\(accessibilitySlug)")
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .accessibilityIdentifier("receipts-category-summary-\(accessibilitySlug)")
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver.fill"
        case .material: return "cube.box.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        case .permits: return "doc.text.fill"
        case .demolition: return "hammer.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .paint: return "paintbrush.fill"
        case .flooring: return "square.grid.4x3.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub.fill"
        default: return "tag.fill"
        }
    }
    
    private func categoryColor(for category: ReceiptCategory) -> Color {
        switch category {
        case .general: return .blue
        case .material: return .green
        case .contingency: return .orange
        case .permits: return .purple
        case .demolition: return .red
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .hvac: return .cyan
        case .paint: return .pink
        case .flooring: return .brown
        case .kitchen: return .orange
        case .bathroom: return .teal
        default: return .secondary
        }
    }
}

struct ScopedReceiptCard: View {
    let receipt: Receipt
    let category: ReceiptCategory
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingFullImage = false

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(receipt.vendor)
    }

    private var categorySlug: String {
        receiptsAccessibilitySlug(category.rawValue)
    }

    private var scopedAmount: Double {
        receipt.scopedAmount(for: category)
    }

    private var matchedItems: [ReceiptItem] {
        receipt.scopedItems(for: category)
    }

    private var scopedSummary: String? {
        guard !matchedItems.isEmpty else { return nil }

        let previewNames = matchedItems.prefix(2).map(\.name).joined(separator: ", ")
        let remainderCount = matchedItems.count - min(matchedItems.count, 2)
        let remainderText = remainderCount > 0 ? " +\(remainderCount) more" : ""
        let itemLabel = matchedItems.count == 1 ? "item" : "items"

        return "\(matchedItems.count) \(category.rawValue.lowercased()) \(itemLabel): \(previewNames)\(remainderText)"
    }

    var body: some View {
        Button(action: onView) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(receipt.vendor)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            if receipt.isReturn {
                                Text("RETURN")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                        }

                        HStack {
                            Image(systemName: "tag")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("receipt-card-category-\(accessibilitySlug)-\(categorySlug)")

                            Spacer()

                            Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(scopedAmount.formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scopedAmount < 0 ? .red : .primary)
                            .accessibilityIdentifier("receipt-card-amount-\(accessibilitySlug)-\(categorySlug)")

                        if receipt.taxAmount > 0 {
                            Text("Tax: \(receipt.taxAmount.formatAsCurrency())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !receipt.notes.isEmpty {
                    HStack {
                        Text(receipt.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()
                    }
                }

                if let scopedSummary {
                    HStack {
                        Text(scopedSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()
                    }
                }

                HStack {
                    if !receipt.paymentMethod.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(receipt.paymentMethod)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if receipt.hasReceiptImage {
                        Button {
                            showingFullImage = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("View")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !receipt.receiptNumber.isEmpty {
                        Text("Receipt #\(receipt.receiptNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("receipt-card-view-image-\(accessibilitySlug)")
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .accessibilityIdentifier("receipt-card-\(receipt.vendor)-\(categorySlug)")
        .buttonStyle(.plain)
        .contextMenu {
            if receipt.hasReceiptImage {
                Button("View Receipt Image") {
                    showingFullImage = true
                }
            }

            Button("Edit") {
                onEdit()
            }

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showingFullImage) {
            if receipt.hasReceiptImage {
                if let receiptImage = receipt.receiptImage {
                    ZoomableImageView(image: receiptImage) {
                        showingFullImage = false
                    }
                    .ignoresSafeArea()
                } else {
                    Text("Receipt image unavailable")
                        .padding()
                }
            }
        }
    }
}

private struct ReceiptFilterSummaryCard: View {
    let summary: ReceiptFilterSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)

                    Text("\(summary.receiptCount) visible receipt\(summary.receiptCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("receipts-filter-summary-count")
                }

                Spacer()

                Text(summary.netTotal.formatAsCurrency())
                    .font(.title3.weight(.bold))
                    .foregroundColor(summary.netTotal < 0 ? .red : .primary)
                    .accessibilityIdentifier("receipts-filter-summary-net")
            }

            HStack(spacing: 12) {
                filterMetric(
                    title: "Purchases",
                    value: summary.grossSpent.formatAsCurrency(),
                    color: .primary,
                    identifier: "receipts-filter-summary-purchases"
                )

                filterMetric(
                    title: "Refunded",
                    value: summary.refundedAmount.formatAsCurrency(),
                    color: .red,
                    identifier: "receipts-filter-summary-refunded"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func filterMetric(title: String, value: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct VendorGroupCard: View {
    let vendorName: String
    let receipts: [Receipt]
    let totalSpent: Double
    let isExpanded: Bool
    let onToggle: () -> Void
    let onReceiptView: (Receipt) -> Void
    let onReceiptEdit: (Receipt) -> Void
    let onReceiptDelete: (Receipt) -> Void

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(vendorName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Make the full vendor summary row tappable so expansion remains reachable
            // even when the trailing corner is visually close to floating action buttons.
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendorName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(receipts.count) receipt\(receipts.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("receipts-vendor-group-count-\(accessibilitySlug)")
                    }
                    
                    Spacer()
                    
                    Text(totalSpent.formatAsCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(totalSpent >= 0 ? .primary : .red)
                        .accessibilityIdentifier("receipts-vendor-group-total-\(accessibilitySlug)")

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("receipts-vendor-group-\(accessibilitySlug)")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            
            // Expandable receipts list
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(visibleParentReceiptRows(from: receipts.sorted { $0.date > $1.date })) { receipt in
                        ReceiptCardGroup(
                            receipt: receipt,
                            scope: nil,
                            linkedRefunds: linkedRefundRows(for: receipt, in: receipts),
                            onView: { onReceiptView(receipt) },
                            onEdit: { onReceiptEdit(receipt) },
                            onDelete: { onReceiptDelete(receipt) },
                            onRefundView: { refund in onReceiptView(refund) }
                        )
                        .padding(.horizontal, 12)
                    }
                }
                .accessibilityIdentifier("receipts-vendor-group-list-\(accessibilitySlug)")
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptsView(selectedTab: .constant(.receipts))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
