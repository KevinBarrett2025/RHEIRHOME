import OSLog
import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditReceipt = false
    @State private var showingDeleteAlert = false
    @State private var showingImageViewer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Receipt Header
                receiptHeaderSection
                
                // Receipt Details
                receiptDetailsSection
                
                // Photos Section
                if receipt.hasPhotos || receipt.hasReceiptImage {
                    photosSection
                }
                
                // Items Section
                if !receipt.items.isEmpty {
                    itemsSection
                }
                
                // Action Buttons
                actionButtonsSection
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Receipt") {
                        showingEditReceipt = true
                    }
                    
                    Button("Delete Receipt", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditReceipt) {
            ReceiptEditView(receipt: receipt, isPresented: $showingEditReceipt)
                .environmentObject(projectVM)
        }
        .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
        } message: {
            Text("Are you sure you want to delete this receipt from \(receipt.vendor) for \(receipt.amount.formatAsCurrency())? This action cannot be undone.")
        }
        .sheet(isPresented: $showingImageViewer) {
            if let receiptImage = receipt.receiptImage {
                ZoomableImageView(image: receiptImage) {
                    showingImageViewer = false
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Edit Receipt") {
                    showingEditReceipt = true
                }
                .accessibilityIdentifier("receipt-detail-edit-action")
                .font(.subheadline.bold())
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 1))
                
                Button("Delete Receipt") {
                    showingDeleteAlert = true
                }
                .accessibilityIdentifier("receipt-detail-delete-action")
                .font(.subheadline.bold())
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func deleteReceipt() {
        guard let project = projectVM.selectedProject else { return }
        
        var updatedProject = project
        updatedProject.receipts.removeAll { $0.id == receipt.id }
        
        // Update vendor and payment method spending totals
        updateVendorSpending(for: receipt, isRemoving: true)
        updatePaymentMethodSpending(for: receipt, isRemoving: true)
        
        Task {
            await projectVM.updateProject(updatedProject)
            await MainActor.run {
                projectVM.recomputeFilteredReceipts()
                
                // Navigate back
                dismiss()
                
                Logger.receiptWorkflow.notice(
                    "Receipt deleted [vendor=\(receipt.vendor, privacy: .public) amount=\(receipt.amount, format: .fixed(precision: 2))]"
                )
            }
        }
    }
    
    private func updateVendorSpending(for receipt: Receipt, isRemoving: Bool) {
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        // Find the vendor and update spending
        let vendor = projectVM.vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: .other // Will be detected properly by the service
        )
        
        if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == vendor.id }) {
            projectVM.vendorService.vendors[index].totalSpent += adjustmentAmount
            // Don't let spending go negative
            projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
        }
    }
    
    private func updatePaymentMethodSpending(for receipt: Receipt, isRemoving: Bool) {
        guard !receipt.paymentMethod.isEmpty else { return }
        
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        // Find the payment method and update spending
        let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: .other // Will be detected properly by the service
        )
        
        if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
            projectVM.paymentMethodService.paymentMethods[index].totalSpent += adjustmentAmount
            // Don't let spending go negative
            projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
        }
    }
    
    @ViewBuilder
    private var receiptHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(receipt.vendor)
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("receipt-detail-vendor")
                
                if receipt.isReturn {
                    Text("RETURN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(receipt.isReturn ? .red : .primary)
                    .accessibilityIdentifier("receipt-detail-amount")
            }
            
            HStack {
                Text(receipt.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(receipt.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .accessibilityIdentifier("receipt-detail-category")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var receiptDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !receipt.paymentMethod.isEmpty {
                detailRow("Payment Method", value: receipt.paymentMethod)
            }
            
            if !receipt.receiptNumber.isEmpty {
                detailRow("Receipt Number", value: receipt.receiptNumber)
            }
            
            if receipt.taxAmount > 0 {
                detailRow("Tax Amount", value: receipt.taxAmount.formatAsCurrency())
            }
            
            if receipt.discountAmount > 0 {
                detailRow("Discount", value: receipt.discountAmount.formatAsCurrency())
            }
            
            if !receipt.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(receipt.notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Receipt Image")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Receipt Image Display
            if let receiptImage = receipt.receiptImage {
                VStack(spacing: 12) {
                    Image(uiImage: receiptImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                    
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.green)
                        Text("Receipt image loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("View Full Size") {
                            showingImageViewer = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            } else if !receipt.photoIDs.isEmpty {
                // Fallback for CloudKit photos - will implement with CloudKitPhotoService later
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(receipt.photoIDs, id: \.self) { photoID in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
            } else {
                // No photos available
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No receipt image available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Items (\(receipt.items.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(receipt.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if !item.sku.isEmpty {
                            Text("SKU: \(item.sku)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Qty: \(item.quantity, specifier: "%.1f") @ \(item.unitPrice.formatAsCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(item.totalPrice.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 8)
                
                if item != receipt.items.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
struct ReceiptDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleReceipt = Receipt(
            vendor: "Home Depot",
            date: Date(),
            amount: 125.47,
            notes: "Sample receipt for preview",
            category: .material,
            paymentMethod: "Credit Card"
        )
        
        NavigationView {
            ReceiptDetailView(receipt: sampleReceipt)
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
                .environmentObject(AuthViewModel(service: PreviewAuthService()))
        }
    }
}
#endif
