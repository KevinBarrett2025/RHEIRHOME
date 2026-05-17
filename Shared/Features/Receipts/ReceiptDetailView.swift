import OSLog
import SwiftUI

private func receiptDetailAccessibilitySlug(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingReceipt: Receipt?
    @State private var refundingReceipt: Receipt?
    @State private var showingDeleteAlert = false
    @State private var showingImageViewer = false

    private var currentReceipt: Receipt {
        projectVM.selectedProject?.receipts.first(where: { $0.id == receipt.id }) ?? receipt
    }

    private var projectReceipts: [Receipt] {
        projectVM.selectedProject?.receipts ?? [currentReceipt]
    }

    private var sourceReceiptForCurrentRefund: Receipt? {
        guard let sourceReceiptID = currentReceipt.sourceReceiptID else { return nil }
        return projectReceipts.first { $0.id == sourceReceiptID }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Receipt Header
                receiptHeaderSection
                
                // Receipt Details
                receiptDetailsSection

                if currentReceipt.supportsPartialRefunds || currentReceipt.isPartialRefund {
                    refundSummarySection
                }
                
                // Photos Section
                if currentReceipt.hasPhotos || currentReceipt.hasReceiptImage {
                    photosSection
                }
                
                // Items Section
                if !currentReceipt.items.isEmpty {
                    itemsSection
                }

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
                        editingReceipt = currentReceipt
                    }
                    .accessibilityIdentifier("receipt-detail-menu-edit")

                    if currentReceipt.supportsPartialRefunds,
                       currentReceipt.remainingRefundableAmount(in: projectReceipts) > 0 {
                        Button("Record Partial Refund") {
                            refundingReceipt = currentReceipt
                        }
                        .accessibilityIdentifier("receipt-detail-menu-partial-refund")
                    }
                    
                    Button("Delete Receipt", role: .destructive) {
                        showingDeleteAlert = true
                    }
                    .accessibilityIdentifier("receipt-detail-menu-delete")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("receipt-detail-actions-menu")
                .accessibilityLabel("Receipt Actions")
            }
        }
        .sheet(item: $editingReceipt) { editableReceipt in
            ReceiptEditView(
                receipt: editableReceipt,
                isPresented: Binding(
                    get: { editingReceipt != nil },
                    set: { isPresented in
                        if !isPresented {
                            editingReceipt = nil
                        }
                    }
                )
            )
                .environmentObject(projectVM)
        }
        .sheet(item: $refundingReceipt) { sourceReceipt in
            PartialReceiptRefundView(
                sourceReceipt: sourceReceipt,
                projectReceipts: projectReceipts,
                isPresented: Binding(
                    get: { refundingReceipt != nil },
                    set: { isPresented in
                        if !isPresented {
                            refundingReceipt = nil
                        }
                    }
                )
            )
            .environmentObject(projectVM)
        }
        .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
        } message: {
            Text("Are you sure you want to delete this receipt from \(currentReceipt.vendor) for \(currentReceipt.amount.formatAsCurrency())? This action cannot be undone.")
        }
        .sheet(isPresented: $showingImageViewer) {
            if let receiptImage = currentReceipt.receiptImage {
                ZoomableImageView(image: receiptImage) {
                    showingImageViewer = false
                }
            }
        }
    }
    
    private func deleteReceipt() {
        let activeReceipt = currentReceipt
        guard let project = projectVM.selectedProject else { return }
        
        var updatedProject = project
        updatedProject.receipts.removeAll { $0.id == activeReceipt.id }
        
        // Update vendor and payment method spending totals
        updateVendorSpending(for: activeReceipt, isRemoving: true)
        updatePaymentMethodSpending(for: activeReceipt, isRemoving: true)
        
        Task {
            await projectVM.updateProject(updatedProject)
            await MainActor.run {
                projectVM.recomputeFilteredReceipts()
                
                // Navigate back
                dismiss()
                
                Logger.receiptWorkflow.notice(
                    "Receipt deleted [vendor=\(activeReceipt.vendor, privacy: .public) amount=\(activeReceipt.amount, format: .fixed(precision: 2))]"
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
        let receipt = currentReceipt

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
        let receipt = currentReceipt

        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !receipt.paymentMethod.isEmpty {
                detailRow("Payment Method", value: receipt.paymentMethod)
            }

            if let subcategory = receipt.subcategory, !subcategory.isEmpty {
                detailRow("Subcategory", value: subcategory)
                    .accessibilityIdentifier("receipt-detail-subcategory")
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
    private var refundSummarySection: some View {
        let receipt = currentReceipt
        let linkedRefunds = receipt.linkedRefunds(in: projectReceipts)
        let refundedAmount = receipt.refundedAmount(in: projectReceipts)
        let remainingAmount = receipt.remainingRefundableAmount(in: projectReceipts)

        VStack(alignment: .leading, spacing: 14) {
            Text(receipt.isPartialRefund ? "Refund Link" : "Refund Summary")
                .font(.headline)
                .fontWeight(.semibold)

            if receipt.isPartialRefund {
                detailRow("Original Receipt", value: sourceReceiptLabel(for: receipt))
                detailRow("Refund Type", value: "Partial refund")
            } else {
                detailRow("Refunded To Date", value: refundedAmount.formatAsCurrency())
                detailRow("Remaining Refundable", value: remainingAmount.formatAsCurrency())

                if !linkedRefunds.isEmpty {
                    detailRow("Partial Refunds", value: "\(linkedRefunds.count)")
                }

                if remainingAmount > 0 {
                    Button {
                        refundingReceipt = receipt
                    } label: {
                        Label("Record Partial Refund", systemImage: "arrow.uturn.backward.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("receipt-detail-partial-refund-button")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func sourceReceiptLabel(for refund: Receipt) -> String {
        guard let sourceReceipt = sourceReceiptForCurrentRefund else {
            return refund.sourceReceiptID ?? "Unknown"
        }

        if !sourceReceipt.receiptNumber.isEmpty {
            return "\(sourceReceipt.vendor) · \(sourceReceipt.receiptNumber)"
        }

        return "\(sourceReceipt.vendor) · \(sourceReceipt.date.formatted(date: .abbreviated, time: .omitted))"
    }
    
    @ViewBuilder
    private var photosSection: some View {
        let receipt = currentReceipt

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
        let receipt = currentReceipt

        VStack(alignment: .leading, spacing: 16) {
            Text("Items (\(receipt.items.count))")
                .font(.headline)
                .fontWeight(.semibold)
                .accessibilityIdentifier("receipt-detail-items-header")
            
            ForEach(receipt.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .accessibilityIdentifier("receipt-detail-item-\(receiptDetailAccessibilitySlug(item.name))")
                        
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

private struct PartialReceiptRefundView: View {
    let sourceReceipt: Receipt
    let projectReceipts: [Receipt]
    @Binding var isPresented: Bool

    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var refundDate = Date()
    @State private var refundReceiptNumber = ""
    @State private var notes = ""
    @State private var selectedQuantities: [UUID: Double] = [:]
    @State private var isSaving = false
    @State private var saveError: String?

    private var refundableItems: [ReceiptItem] {
        sourceReceipt.items.filter {
            sourceReceipt.remainingRefundableQuantity(for: $0, in: projectReceipts) > 0
        }
    }

    private var selections: [ReceiptRefundSelection] {
        selectedQuantities.compactMap { itemID, quantity in
            quantity > 0 ? ReceiptRefundSelection(itemID: itemID, quantity: quantity) : nil
        }
    }

    private var previewRefund: Receipt? {
        sourceReceipt.makePartialRefund(
            selections: selections,
            existingReceipts: projectReceipts,
            refundDate: refundDate,
            receiptNumber: refundReceiptNumber,
            notes: notes
        )
    }

    private var canSave: Bool {
        previewRefund != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Return Details") {
                    DatePicker("Refund Date", selection: $refundDate, displayedComponents: .date)
                    TextField("Return receipt number (optional)", text: $refundReceiptNumber)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Select Returned Items") {
                    ForEach(refundableItems) { item in
                        refundItemRow(for: item)
                    }
                }

                Section("Refund Summary") {
                    if let previewRefund {
                        detailRow("Item Subtotal", value: refundSubtotal(for: previewRefund).formatAsCurrency())
                        detailRow("Tax Refunded", value: previewRefund.taxAmount.formatAsCurrency())
                        detailRow("Discount Reversed", value: previewRefund.discountAmount.formatAsCurrency())
                        detailRow("Refund Total", value: previewRefund.amount.formatAsCurrency())
                    } else {
                        Text("Select at least one refundable item.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Partial Refund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissEditor()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Refund") {
                        saveRefund()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func refundItemRow(for item: ReceiptItem) -> some View {
        let available = sourceReceipt.remainingRefundableQuantity(for: item, in: projectReceipts)
        let selected = selectedQuantities[item.id] ?? 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)

                    Text("\(item.category.rawValue) · \(available, specifier: "%.2f") available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.totalPrice.formatAsCurrency())
                    .font(.subheadline.weight(.semibold))
            }

            Stepper(
                value: quantityBinding(for: item),
                in: 0...available,
                step: refundStep(for: item)
            ) {
                Text("Return Qty: \(selected, specifier: "%.2f")")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func quantityBinding(for item: ReceiptItem) -> Binding<Double> {
        Binding(
            get: { selectedQuantities[item.id] ?? 0 },
            set: { selectedQuantities[item.id] = min(max(0, $0), sourceReceipt.remainingRefundableQuantity(for: item, in: projectReceipts)) }
        )
    }

    private func refundStep(for item: ReceiptItem) -> Double {
        item.quantity.truncatingRemainder(dividingBy: 1) == 0 ? 1 : 0.25
    }

    private func refundSubtotal(for receipt: Receipt) -> Double {
        receipt.items.reduce(0.0) { $0 + $1.totalPrice }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func saveRefund() {
        guard !isSaving,
              let refund = previewRefund,
              let project = projectVM.selectedProject
        else {
            return
        }

        isSaving = true
        saveError = nil

        Task {
            await projectVM.addReceipt(refund, to: project.id)
            await MainActor.run {
                updateDirectorySpending(for: refund)
                projectVM.recomputeFilteredReceipts()
                projectVM.saveOrganizationSpecificBackup()
                dismissEditor()
                Logger.receiptWorkflow.notice(
                    "Recorded partial receipt refund [source=\(sourceReceipt.id, privacy: .private(mask: .hash)) amount=\(refund.amount, format: .fixed(precision: 2)) lines=\(refund.items.count, privacy: .public)]"
                )
            }
        }
    }

    private func updateDirectorySpending(for receipt: Receipt) {
        let signedAmount = receipt.signedAmount

        let vendor = projectVM.vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: .other
        )
        if let vendorIndex = projectVM.vendorService.vendors.firstIndex(where: { $0.id == vendor.id }) {
            projectVM.vendorService.vendors[vendorIndex].totalSpent += signedAmount
            projectVM.vendorService.vendors[vendorIndex].totalSpent = max(
                0,
                projectVM.vendorService.vendors[vendorIndex].totalSpent
            )
        }

        guard !receipt.paymentMethod.isEmpty else { return }

        let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: .other
        )
        if let paymentIndex = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
            projectVM.paymentMethodService.paymentMethods[paymentIndex].totalSpent += signedAmount
            projectVM.paymentMethodService.paymentMethods[paymentIndex].totalSpent = max(
                0,
                projectVM.paymentMethodService.paymentMethods[paymentIndex].totalSpent
            )
        }
    }

    private func dismissEditor() {
        isPresented = false
        dismiss()
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
