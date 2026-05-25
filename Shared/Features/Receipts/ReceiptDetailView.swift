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
    @State private var linkedReceiptToView: Receipt?
    @State private var reconciliationEditorContext: ReceiptExceptionReconciliationEditorContext?
    @State private var showingDeleteAlert = false
    @State private var showingReverseRefundAlert = false
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

                if currentReceipt.isPartialRefund || !currentReceipt.linkedRefunds(in: projectReceipts).isEmpty {
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

                    if currentReceipt.isPartialRefund {
                        Button("Reverse Refund", role: .destructive) {
                            showingReverseRefundAlert = true
                        }
                        .accessibilityIdentifier("receipt-detail-menu-reverse-refund")
                    } else {
                        Button("Delete Receipt", role: .destructive) {
                            showingDeleteAlert = true
                        }
                        .accessibilityIdentifier("receipt-detail-menu-delete")
                    }
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
        .sheet(item: $reconciliationEditorContext) { context in
            ReceiptExceptionReconciliationEditorView(context: context) { reconciliation in
                saveReconciliation(reconciliation)
            }
        }
        .navigationDestination(item: $linkedReceiptToView) { linkedReceipt in
            ReceiptDetailView(receipt: linkedReceipt)
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
        .alert("Reverse Refund?", isPresented: $showingReverseRefundAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reverse Refund", role: .destructive) {
                reverseRefund()
            }
        } message: {
            Text("This removes the linked refund receipt and restores those items as refundable on the original receipt.")
        }
        .sheet(isPresented: $showingImageViewer) {
            if let receiptImage = currentReceipt.receiptImage {
                ZoomableImageView(image: receiptImage) {
                    showingImageViewer = false
                }
            }
        }
    }

    private func reverseRefund() {
        let refund = currentReceipt
        guard refund.isPartialRefund,
              let project = projectVM.selectedProject
        else { return }

        var updatedProject = project
        updatedProject.receipts.removeAll { $0.id == refund.id }
        updatedProject.lastModifiedDate = Date()

        updateVendorSpending(for: refund, isRemoving: true)
        updatePaymentMethodSpending(for: refund, isRemoving: true)

        Task {
            await projectVM.updateProject(updatedProject)
            projectVM.saveOrganizationSpecificBackup()

            await MainActor.run {
                projectVM.recomputeFilteredReceipts()
                dismiss()

                Logger.receiptWorkflow.notice(
                    "Receipt refund reversed [refund=\(refund.id, privacy: .private(mask: .hash)) source=\(refund.sourceReceiptID ?? "unknown", privacy: .private(mask: .hash)) amount=\(refund.amount, format: .fixed(precision: 2))]"
                )
            }
        }
    }
    
    private func deleteReceipt() {
        let activeReceipt = currentReceipt
        guard let project = projectVM.selectedProject else { return }
        
        var updatedProject = project
        updatedProject.receipts.removeAll { $0.id == activeReceipt.id }
        ReceiptImageStore.shared.removeImage(named: activeReceipt.receiptImageName)
        
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

    private func reconciliations(for item: ReceiptItem) -> [ReceiptExceptionReconciliation] {
        projectVM.selectedProject?
            .receiptExceptionReconciliations(
                forSourceReceiptID: currentReceipt.id,
                sourceItemID: item.id
            ) ?? []
    }

    private func startAddingReconciliation(for item: ReceiptItem) {
        reconciliationEditorContext = ReceiptExceptionReconciliationEditorContext(
            sourceReceiptID: currentReceipt.id,
            item: item,
            existingReconciliation: nil
        )
    }

    private func startEditingReconciliation(
        _ reconciliation: ReceiptExceptionReconciliation,
        for item: ReceiptItem
    ) {
        reconciliationEditorContext = ReceiptExceptionReconciliationEditorContext(
            sourceReceiptID: currentReceipt.id,
            item: item,
            existingReconciliation: reconciliation
        )
    }

    private func saveReconciliation(_ reconciliation: ReceiptExceptionReconciliation) {
        guard let projectID = projectVM.selectedProject?.id else { return }

        Task {
            await projectVM.addOrUpdateReceiptExceptionReconciliation(reconciliation, in: projectID)
        }
    }

    private func removeReconciliation(_ reconciliation: ReceiptExceptionReconciliation) {
        guard let projectID = projectVM.selectedProject?.id else { return }

        Task {
            await projectVM.removeReceiptExceptionReconciliation(reconciliation.id, from: projectID)
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

            if let tipAmount = receipt.tipAmount, tipAmount > 0 {
                detailRow("Tip", value: tipAmount.formatAsCurrency())
                    .accessibilityIdentifier("receipt-detail-tip")
            }

            if let pricePerGallon = receipt.pricePerGallon, pricePerGallon > 0 {
                detailRow("Price / Gallon", value: String(format: "$%.3f", pricePerGallon))
                    .accessibilityIdentifier("receipt-detail-price-per-gallon")
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

                Button(role: .destructive) {
                    showingReverseRefundAlert = true
                } label: {
                    Label("Reverse Refund", systemImage: "arrow.uturn.backward.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("receipt-detail-reverse-refund")
            } else {
                refundMetricRow(
                    title: "Refunded To Date",
                    value: refundedAmount.formatAsCurrency(),
                    identifier: "receipt-detail-refunded-total"
                )
                refundMetricRow(
                    title: "Remaining Refundable",
                    value: remainingAmount.formatAsCurrency(),
                    identifier: "receipt-detail-refundable-remaining"
                )

                if !linkedRefunds.isEmpty {
                    detailRow("Partial Refunds", value: "\(linkedRefunds.count)")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Linked Refund Receipts")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(linkedRefunds.sorted { $0.date > $1.date }) { refund in
                            Button {
                                linkedReceiptToView = refund
                            } label: {
                                ReceiptLinkedRefundDetailRow(refund: refund)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("receipt-detail-linked-refund-\(receiptDetailAccessibilitySlug(refund.items.first?.name ?? refund.id))")
                        }
                    }
                    .padding(.top, 4)
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
                        .accessibilityIdentifier("receipt-detail-image-preview")
                    
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
                ReceiptDetailItemRow(
                    receipt: receipt,
                    item: item,
                    projectReceipts: projectReceipts,
                    reconciliations: reconciliations(for: item),
                    onAddReconciliation: {
                        startAddingReconciliation(for: item)
                    },
                    onEditReconciliation: { reconciliation in
                        startEditingReconciliation(reconciliation, for: item)
                    },
                    onRemoveReconciliation: { reconciliation in
                        removeReconciliation(reconciliation)
                    }
                )
                
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

    private func refundMetricRow(title: String, value: String, identifier: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct ReceiptLinkedRefundDetailRow: View {
    let refund: Receipt

    private var itemSummary: String {
        guard !refund.items.isEmpty else { return "Linked refund" }

        let names = refund.items.prefix(2).map(\.name).joined(separator: ", ")
        let remainder = refund.items.count > 2 ? " +\(refund.items.count - 2) more" : ""
        return "\(names)\(remainder)"
    }

    private var accessibilitySlug: String {
        receiptDetailAccessibilitySlug(refund.items.first?.name ?? refund.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red.opacity(0.8))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
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
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }

                Text(itemSummary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

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
        .accessibilityIdentifier("receipt-detail-linked-refund-\(accessibilitySlug)")
    }
}

private struct ReceiptDetailItemRow: View {
    let receipt: Receipt
    let item: ReceiptItem
    let projectReceipts: [Receipt]
    let reconciliations: [ReceiptExceptionReconciliation]
    let onAddReconciliation: () -> Void
    let onEditReconciliation: (ReceiptExceptionReconciliation) -> Void
    let onRemoveReconciliation: (ReceiptExceptionReconciliation) -> Void

    private var refundedQuantity: Double {
        receipt.refundedQuantity(for: item.id, in: projectReceipts)
    }

    private var remainingQuantity: Double {
        receipt.remainingRefundableQuantity(for: item, in: projectReceipts)
    }

    private var hasRefund: Bool {
        refundedQuantity > 0
    }

    private var isFullyRefunded: Bool {
        hasRefund && remainingQuantity <= 0.000_001
    }

    private var statusText: String {
        isFullyRefunded ? "REFUNDED" : "PARTIAL REFUND"
    }

    private var statusColor: Color {
        isFullyRefunded ? .red : .orange
    }

    private var rowAccentColor: Color {
        if hasRefund { return statusColor }
        if !reconciliations.isEmpty { return .green }
        if item.hasMissingException || item.exceptionMetadata?.status == .disputeNeeded { return .orange }
        if item.exceptionMetadata?.status == .resolved { return .green }
        return .blue
    }

    private var accessibilitySlug: String {
        receiptDetailAccessibilitySlug(item.name)
    }

    private var isHighlighted: Bool {
        hasRefund || item.hasAnyLineItemException || !reconciliations.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 2)
                    .fill(rowAccentColor.opacity(0.85))
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .accessibilityIdentifier("receipt-detail-item-\(accessibilitySlug)")

                    if hasRefund {
                        Text(statusText)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(statusColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityIdentifier("receipt-detail-item-refund-status-\(accessibilitySlug)")
                    }
                }

                if !item.sku.isEmpty {
                    Text("SKU: \(item.sku)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Qty: \(item.quantity, specifier: "%.1f") @ \(item.unitPrice.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if hasRefund {
                    Text("Returned \(refundedQuantity, specifier: "%.1f") of \(item.quantity, specifier: "%.1f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .accessibilityIdentifier("receipt-detail-item-refunded-quantity-\(accessibilitySlug)")
                }

                if item.hasAnyLineItemException {
                    lineItemExceptionChips
                }

                if item.hasAnyLineItemException || !reconciliations.isEmpty {
                    reconciliationSection
                }
            }

            Spacer()

            Text(item.totalPrice.formatAsCurrency())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(hasRefund ? statusColor : .primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isHighlighted ? 10 : 0)
        .background(
            Group {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(rowAccentColor.opacity(0.08))
                }
            }
        )
        .overlay(
            Group {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rowAccentColor.opacity(0.28), lineWidth: 1)
                }
            }
        )
    }

    @ViewBuilder
    private var lineItemExceptionChips: some View {
        let returnQuantity = item.returnExceptionQuantity
        let missingQuantity = item.missingExceptionQuantity

        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    exceptionChipViews(returnQuantity: returnQuantity, missingQuantity: missingQuantity)
                }

                VStack(alignment: .leading, spacing: 5) {
                    exceptionChipViews(returnQuantity: returnQuantity, missingQuantity: missingQuantity)
                }
            }

            if let notes = item.exceptionMetadata?.notes.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("receipt-detail-item-exception-notes-\(accessibilitySlug)")
            }
        }
    }

    @ViewBuilder
    private func exceptionChipViews(returnQuantity: Double, missingQuantity: Double) -> some View {
        if returnQuantity > 0 {
            exceptionChip(
                text: "Return qty \(quantityLabel(returnQuantity))",
                color: .orange,
                identifier: "receipt-detail-item-return-quantity-\(accessibilitySlug)"
            )
        }

        if missingQuantity > 0 {
            exceptionChip(
                text: "Missing qty \(quantityLabel(missingQuantity))",
                color: .red,
                identifier: "receipt-detail-item-missing-quantity-\(accessibilitySlug)"
            )
        }

        if item.exceptionMetadata?.status == .disputeNeeded {
            exceptionChip(
                text: "Needs Dispute",
                color: .orange,
                identifier: "receipt-detail-item-exception-status-\(accessibilitySlug)"
            )
        } else if item.exceptionMetadata?.status == .resolved {
            exceptionChip(
                text: "Resolved",
                color: .green,
                identifier: "receipt-detail-item-exception-status-\(accessibilitySlug)"
            )
        }
    }

    private func exceptionChip(text: String, color: Color, identifier: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var reconciliationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !reconciliations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(reconciliations) { reconciliation in
                        reconciliationRecordRow(reconciliation)
                    }
                }
            }

            if item.hasAnyLineItemException {
                Button {
                    onAddReconciliation()
                } label: {
                    Label("Record outcome", systemImage: "checklist.checked")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("receipt-detail-item-reconciliation-add-\(accessibilitySlug)")
            }
        }
        .padding(.top, 2)
    }

    private func reconciliationRecordRow(_ reconciliation: ReceiptExceptionReconciliation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                exceptionChip(
                    text: reconciliationOutcomeLabel(reconciliation.outcome),
                    color: .green,
                    identifier: "receipt-detail-item-reconciliation-outcome-\(accessibilitySlug)"
                )

                Text("\(reconciliationKindLabel(reconciliation.kind)) qty \(quantityLabel(reconciliation.quantity))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .accessibilityIdentifier("receipt-detail-item-reconciliation-quantity-\(accessibilitySlug)")

                Spacer()

                Button {
                    onEditReconciliation(reconciliation)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit reconciliation outcome")
                .accessibilityIdentifier("receipt-detail-item-reconciliation-edit-\(accessibilitySlug)")

                Button(role: .destructive) {
                    onRemoveReconciliation(reconciliation)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove reconciliation outcome")
                .accessibilityIdentifier("receipt-detail-item-reconciliation-remove-\(accessibilitySlug)")
            }

            if let resolvedDate = reconciliation.resolvedDate {
                Text("Resolved \(resolvedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("receipt-detail-item-reconciliation-date-\(accessibilitySlug)")
            }

            let trimmedNotes = reconciliation.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                Text(trimmedNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("receipt-detail-item-reconciliation-notes-\(accessibilitySlug)")
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func quantityLabel(_ quantity: Double) -> String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func reconciliationKindLabel(_ kind: ReceiptExceptionReconciliationKind) -> String {
        switch kind {
        case .returnQuantity:
            return "Return"
        case .missingQuantity:
            return "Missing"
        }
    }

    private func reconciliationOutcomeLabel(_ outcome: ReceiptExceptionReconciliationOutcome) -> String {
        switch outcome {
        case .refundReceipt:
            return "Refund receipt"
        case .storeCredit:
            return "Store credit"
        case .replacement:
            return "Replacement"
        case .disputeResolved:
            return "Dispute resolved"
        case .noCredit:
            return "No credit"
        case .other:
            return "Other"
        }
    }
}

private struct ReceiptExceptionReconciliationEditorContext: Identifiable {
    let id: UUID
    let sourceReceiptID: String
    let item: ReceiptItem
    let existingReconciliation: ReceiptExceptionReconciliation?

    init(
        sourceReceiptID: String,
        item: ReceiptItem,
        existingReconciliation: ReceiptExceptionReconciliation?
    ) {
        self.id = existingReconciliation?.id ?? UUID()
        self.sourceReceiptID = sourceReceiptID
        self.item = item
        self.existingReconciliation = existingReconciliation
    }
}

private struct ReceiptExceptionReconciliationEditorView: View {
    let context: ReceiptExceptionReconciliationEditorContext
    let onSave: (ReceiptExceptionReconciliation) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: ReceiptExceptionReconciliationKind
    @State private var quantity: String
    @State private var outcome: ReceiptExceptionReconciliationOutcome
    @State private var usesResolvedDate: Bool
    @State private var resolvedDate: Date
    @State private var notes: String

    init(
        context: ReceiptExceptionReconciliationEditorContext,
        onSave: @escaping (ReceiptExceptionReconciliation) -> Void
    ) {
        self.context = context
        self.onSave = onSave

        let existing = context.existingReconciliation
        let defaultKind = context.item.missingExceptionQuantity > 0 && context.item.returnExceptionQuantity <= 0
            ? ReceiptExceptionReconciliationKind.missingQuantity
            : ReceiptExceptionReconciliationKind.returnQuantity
        let defaultQuantity: Double
        switch existing?.kind ?? defaultKind {
        case .returnQuantity:
            defaultQuantity = existing?.quantity ?? max(context.item.returnExceptionQuantity, 1)
        case .missingQuantity:
            defaultQuantity = existing?.quantity ?? max(context.item.missingExceptionQuantity, 1)
        }

        self._kind = State(initialValue: existing?.kind ?? defaultKind)
        self._quantity = State(initialValue: Self.quantityText(defaultQuantity))
        self._outcome = State(initialValue: existing?.outcome ?? .disputeResolved)
        self._usesResolvedDate = State(initialValue: existing?.resolvedDate != nil)
        self._resolvedDate = State(initialValue: existing?.resolvedDate ?? Date())
        self._notes = State(initialValue: existing?.notes ?? "")
    }

    private var parsedQuantity: Double {
        min(max(Double(quantity) ?? 0, 0), max(context.item.quantity, 0))
    }

    private var canSave: Bool {
        parsedQuantity > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Line Item") {
                    Text(context.item.name)
                        .font(.headline)
                    Text("Receipt quantity: \(quantityLabel(context.item.quantity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Picker("Exception", selection: $kind) {
                        Text("Return quantity").tag(ReceiptExceptionReconciliationKind.returnQuantity)
                        Text("Missing quantity").tag(ReceiptExceptionReconciliationKind.missingQuantity)
                    }
                    .accessibilityIdentifier("receipt-reconciliation-kind-picker")

                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0.00", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("receipt-reconciliation-quantity")
                    }

                    Picker("Outcome", selection: $outcome) {
                        ForEach(ReceiptExceptionReconciliationOutcome.allCases, id: \.self) { candidate in
                            Text(outcomeLabel(candidate)).tag(candidate)
                        }
                    }
                    .accessibilityIdentifier("receipt-reconciliation-outcome-picker")

                    Toggle("Resolved date", isOn: $usesResolvedDate)
                        .accessibilityIdentifier("receipt-reconciliation-resolved-date-toggle")

                    if usesResolvedDate {
                        DatePicker("Date", selection: $resolvedDate, displayedComponents: .date)
                            .accessibilityIdentifier("receipt-reconciliation-resolved-date")
                    }

                    TextField("Outcome notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("receipt-reconciliation-notes")
                } header: {
                    Text("Manual Outcome")
                } footer: {
                    Text("This records what happened after the exception. It does not create refunds or change receipt and budget totals.")
                }
            }
            .navigationTitle(context.existingReconciliation == nil ? "Record Outcome" : "Update Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("receipt-reconciliation-cancel")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("receipt-reconciliation-save")
                }
            }
        }
    }

    private func save() {
        let existing = context.existingReconciliation
        let now = Date()
        let reconciliation = ReceiptExceptionReconciliation(
            id: existing?.id ?? context.id,
            sourceReceiptID: context.sourceReceiptID,
            sourceItemID: context.item.id,
            kind: kind,
            quantity: parsedQuantity,
            outcome: outcome,
            refundReceiptID: existing?.refundReceiptID,
            refundItemID: existing?.refundItemID,
            resolvedDate: usesResolvedDate ? resolvedDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? now,
            updatedAt: existing?.updatedAt ?? now
        )

        onSave(reconciliation)
        dismiss()
    }

    private func quantityLabel(_ quantity: Double) -> String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func quantityText(_ quantity: Double) -> String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func outcomeLabel(_ outcome: ReceiptExceptionReconciliationOutcome) -> String {
        switch outcome {
        case .refundReceipt:
            return "Refund receipt"
        case .storeCredit:
            return "Store credit"
        case .replacement:
            return "Replacement"
        case .disputeResolved:
            return "Dispute resolved"
        case .noCredit:
            return "No credit"
        case .other:
            return "Other"
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
                        refundMetricRow(
                            title: "Item Subtotal",
                            value: refundSubtotal(for: previewRefund).formatAsCurrency(),
                            identifier: "receipt-refund-preview-subtotal"
                        )
                        refundMetricRow(
                            title: "Tax Refunded",
                            value: previewRefund.taxAmount.formatAsCurrency(),
                            identifier: "receipt-refund-preview-tax"
                        )
                        refundMetricRow(
                            title: "Discount Reversed",
                            value: previewRefund.discountAmount.formatAsCurrency(),
                            identifier: "receipt-refund-preview-discount"
                        )
                        refundMetricRow(
                            title: "Refund Total",
                            value: previewRefund.amount.formatAsCurrency(),
                            identifier: "receipt-refund-preview-total"
                        )
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
                        .accessibilityIdentifier("receipt-refund-item-\(receiptDetailAccessibilitySlug(item.name))")

                    Text("\(item.category.rawValue) · \(available, specifier: "%.2f") available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.totalPrice.formatAsCurrency())
                    .font(.subheadline.weight(.semibold))
            }

            HStack {
                Text("Return Qty")
                    .font(.subheadline)

                Spacer()

                Button {
                    adjustSelectedQuantity(for: item, by: -refundStep(for: item))
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(selected <= 0)
                .accessibilityLabel("Decrease \(item.name) refund quantity")
                .accessibilityIdentifier("receipt-refund-decrement-\(receiptDetailAccessibilitySlug(item.name))")

                Text("\(selected, specifier: "%.2f")")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 46)
                    .multilineTextAlignment(.center)

                Button {
                    adjustSelectedQuantity(for: item, by: refundStep(for: item))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(selected >= available)
                .accessibilityLabel("Increase \(item.name) refund quantity")
                .accessibilityIdentifier("receipt-refund-increment-\(receiptDetailAccessibilitySlug(item.name))")
            }
        }
        .padding(.vertical, 4)
    }

    private func adjustSelectedQuantity(for item: ReceiptItem, by delta: Double) {
        let available = sourceReceipt.remainingRefundableQuantity(for: item, in: projectReceipts)
        let current = selectedQuantities[item.id] ?? 0
        selectedQuantities[item.id] = min(max(0, current + delta), available)
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

    private func refundMetricRow(title: String, value: String, identifier: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(identifier)
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
