import SwiftUI

struct CategoryReceiptsView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var selectedTab: Tab
    let selectedCategory: ReceiptCategory
    @State private var receiptToEdit: Receipt? = nil
    @State private var showingDeleteAlert = false
    @State private var receiptToDelete: Receipt? = nil
    
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
        }
        .presentationBackground(.thinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
            projectVM.selectedReceiptCategory = selectedCategory
            projectVM.recomputeFilteredReceipts()
        }
    }
    
    @ViewBuilder
    private var categoryHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: categoryIcon(for: selectedCategory))
                    .font(.system(size: 40))
                    .foregroundColor(categoryColor(for: selectedCategory))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCategory.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Project: \(projectVM.selectedProject?.name ?? "")")
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
                    
                    Text(projectVM.totalSpent(for: selectedCategory).formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(projectVM.totalSpent(for: selectedCategory) >= 0 ? .primary : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Receipts", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(projectVM.filteredReceipts.filter { $0.category == selectedCategory }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Vendor breakdown for this category
            if !projectVM.filteredReceipts.filter { $0.category == selectedCategory }.isEmpty {
                let vendorBreakdown = projectVM.calculateVendorBreakdown(for: selectedCategory)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Vendors in This Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(vendorBreakdown.prefix(5), id: \.vendor) { item in
                        HStack {
                            Text(item.vendor)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(item.amount.formatAsCurrency())
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("(\(item.receiptCount))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        if projectVM.filteredReceipts.filter { $0.category == selectedCategory }.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: categoryIcon(for: selectedCategory))
                    .font(.system(size: 48))
                    .foregroundColor(categoryColor(for: selectedCategory).opacity(0.6))
                
                Text("No receipts in this category")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Add receipts to track spending in \(selectedCategory.rawValue.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                HStack {
                    Text("All \(selectedCategory.rawValue) Receipts")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                
                LazyVStack(spacing: 8) {
                    ForEach(projectVM.filteredReceipts.filter { $0.category == selectedCategory }.sorted { $0.date > $1.date }) { receipt in
                        SemiTransparentReceiptRow(receipt: receipt) {
                            // Edit action
                            receiptToEdit = receipt
                        } deleteAction: {
                            // Delete action
                            showingDeleteAlert = true
                            receiptToDelete = receipt
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func deleteReceipt(_ receipt: Receipt) {
        guard let project = projectVM.selectedProject else { 
            receiptToDelete = nil
            return 
        }
        
        var updatedProject = project
        updatedProject.receipts.removeAll { $0.id == receipt.id }
        
        // Update vendor and payment method spending totals
        updateVendorSpending(for: receipt, isRemoving: true)
        updatePaymentMethodSpending(for: receipt, isRemoving: true)
        
        projectVM.save(updatedProject)
        projectVM.recomputeFilteredReceipts()
        
        receiptToDelete = nil
        
        print("🗑️ Deleted receipt from \(receipt.vendor) for \(receipt.amount.formatAsCurrency())")
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
}

struct SemiTransparentReceiptRow: View {
    let receipt: Receipt
    let editAction: () -> Void
    let deleteAction: () -> Void
    
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                editAction()
            }
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                deleteAction()
            }
        }
        .onTapGesture {
            // Optional: Add tap to view details or edit
        }
    }
}

#Preview {
    CategoryReceiptsView(
        selectedCategory: .material,
        selectedTab: .constant(.receipts)
    )
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}