import SwiftUI
import OSLog

private func receiptsAccessibilitySlug(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

struct ReceiptsView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showingNewReceipt = false
    @State private var showingScanner = false
    @State private var receiptToView: Receipt? = nil
    @State private var receiptToEdit: Receipt? = nil
    @State private var showingDeleteAlert = false
    @State private var receiptToDelete: Receipt? = nil
    @State private var selectedViewMode: ReceiptViewMode = .all
    @State private var selectedCategory: ReceiptCategory? = nil
    @State private var searchText = ""
    
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
    
    private var receipts: [Receipt] {
        guard let project = projectVM.selectedProject else { return [] }
        
        var filteredReceipts = project.receipts
        
        // Apply search filter
        if !searchText.isEmpty {
            filteredReceipts = filteredReceipts.filter { receipt in
                receipt.vendor.localizedCaseInsensitiveContains(searchText) ||
                receipt.notes.localizedCaseInsensitiveContains(searchText) ||
                receipt.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        if let selectedCategory = selectedCategory {
            filteredReceipts = filteredReceipts.filter { receipt in
                receipt.category == selectedCategory ||
                receipt.items.contains { $0.category == selectedCategory }
            }
        }
        
        return filteredReceipts.sorted { $0.date > $1.date }
    }
    
    private var receiptsByCategory: [ReceiptCategory: [Receipt]] {
        Dictionary(grouping: receipts) { $0.category }
    }
    
    private var receiptsByVendor: [String: [Receipt]] {
        Dictionary(grouping: receipts) { $0.vendor.lowercased() }
    }
    
    // Get categories that actually have receipts
    private var activeCategories: [ReceiptCategory] {
        Array(Set(receipts.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
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
                    
                    // Category filter (when categories mode is selected)
                    if selectedViewMode == .categories {
                        categoryFilterBar
                    }
                    
                    // Main content
                    mainContent
                } else {
                    emptyStateView
                }
                
                Spacer()
                
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
            .sheet(isPresented: $showingScanner) {
                if let project = projectVM.selectedProject {
                    ReceiptScannerView(isPresented: $showingScanner, project: project)
                        .environmentObject(projectVM)
                }
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
                // Filtered empty state
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Matching Receipts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if selectedCategory != nil {
                        Text("No receipts found in the \(selectedCategory!.rawValue) category")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("View All Receipts") {
                            selectedCategory = nil
                            searchText = ""
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Try adjusting your search terms")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Clear Search") {
                            searchText = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
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
        ForEach(receipts) { receipt in
            EnhancedReceiptCard(
                receipt: receipt,
                onView: {
                    receiptToView = receipt
                },
                onEdit: {
                    receiptToEdit = receipt
                },
                onDelete: {
                    receiptToDelete = receipt
                    showingDeleteAlert = true
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
                    acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
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
            ForEach(receipts) { receipt in
                EnhancedReceiptCard(
                    receipt: receipt,
                    onView: {
                        receiptToView = receipt
                    },
                    onEdit: {
                        receiptToEdit = receipt
                    },
                    onDelete: {
                        receiptToDelete = receipt
                        showingDeleteAlert = true
                    }
                )
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
            
            VendorGroupCard(
                vendorName: vendorName,
                receipts: vendorReceipts,
                totalSpent: totalSpent,
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
                showingScanner = true
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
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingScanner)
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
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Receipts Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start tracking expenses by adding receipts")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button {
                        showingScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Receipt")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("receipts-empty-scan")
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        showingNewReceipt = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Manual Entry")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("receipts-empty-manual-entry")
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}

// MARK: - Supporting View Components

struct EnhancedReceiptCard: View {
    let receipt: Receipt
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingFullImage = false
    
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
                            Image(systemName: categoryIcon(for: receipt.category))
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(receipt.category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(receipt.isReturn ? .red : .primary)
                        
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
                // Temporarily disabled - ReceiptImageViewer compilation issue
                // ReceiptImageViewer(receipt: receipt)
                Text("Receipt Image Viewer Coming Soon")
                    .padding()
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

struct VendorGroupCard: View {
    let vendorName: String
    let receipts: [Receipt]
    let totalSpent: Double
    let onReceiptView: (Receipt) -> Void
    let onReceiptEdit: (Receipt) -> Void
    let onReceiptDelete: (Receipt) -> Void
    @State private var isExpanded = false

    private var accessibilitySlug: String {
        receiptsAccessibilitySlug(vendorName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Vendor header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(totalSpent.formatAsCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(totalSpent >= 0 ? .primary : .red)
                            .accessibilityIdentifier("receipts-vendor-group-total-\(accessibilitySlug)")
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("receipts-vendor-group-\(accessibilitySlug)")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .buttonStyle(PlainButtonStyle())
            
            // Expandable receipts list
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(receipts.sorted { $0.date > $1.date }) { receipt in
                        EnhancedReceiptCard(
                            receipt: receipt,
                            onView: { onReceiptView(receipt) },
                            onEdit: { onReceiptEdit(receipt) },
                            onDelete: { onReceiptDelete(receipt) }
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
