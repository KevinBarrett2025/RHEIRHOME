import OSLog
import SwiftUI

private func receiptEditAccessibilitySlug(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

struct ReceiptEditView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    let receipt: Receipt
    
    @State private var vendor: String
    @State private var amount: String
    @State private var notes: String
    @State private var date: Date
    @State private var category: ReceiptCategory
    @State private var subcategory: String
    @State private var paymentMethod: String
    @State private var selectedPaymentMethodObj: PaymentMethod?
    @State private var receiptNumber: String
    @State private var taxAmount: String
    @State private var discountAmount: String
    @State private var tipAmount: String
    @State private var pricePerGallon: String
    @State private var isReturn: Bool
    @State private var items: [ReceiptItem]
    @State private var editingItem: ReceiptItem?
    @State private var pendingRefundPrompt: ReceiptItemRefundPrompt?
    @State private var showingPaymentMethodPicker = false
    @State private var isSaving = false
    
    init(receipt: Receipt, isPresented: Binding<Bool>) {
        self.receipt = receipt
        self._isPresented = isPresented
        self._vendor = State(initialValue: receipt.vendor)
        self._amount = State(initialValue: String(format: "%.2f", receipt.amount))
        self._notes = State(initialValue: receipt.notes)
        self._date = State(initialValue: receipt.date)
        self._category = State(initialValue: receipt.category)
        self._subcategory = State(initialValue: receipt.subcategory ?? "")
        self._paymentMethod = State(initialValue: receipt.paymentMethod)
        self._receiptNumber = State(initialValue: receipt.receiptNumber)
        self._taxAmount = State(initialValue: String(format: "%.2f", receipt.taxAmount))
        self._discountAmount = State(initialValue: String(format: "%.2f", receipt.discountAmount))
        self._tipAmount = State(initialValue: receipt.tipAmount.map { String(format: "%.2f", $0) } ?? "")
        self._pricePerGallon = State(initialValue: receipt.pricePerGallon.map { String(format: "%.3f", $0) } ?? "")
        self._isReturn = State(initialValue: receipt.isReturn)
        self._items = State(initialValue: receipt.items)
    }
    
    private var isValidForm: Bool {
        !vendor.isEmpty && !amount.isEmpty && (Double(amount) ?? 0) > 0
    }

    private var linkedRefunds: [Receipt] {
        projectVM.selectedProject?.receipts.filter { $0.isReturn && $0.sourceReceiptID == receipt.id } ?? []
    }

    private var locksFinancialHistory: Bool {
        receipt.isPartialRefund || !linkedRefunds.isEmpty
    }

    private var projectReceipts: [Receipt] {
        projectVM.selectedProject?.receipts ?? [receipt]
    }

    private var currentVendorCategory: VendorCategory {
        projectVM.vendorService.vendors.first(where: {
            $0.name.caseInsensitiveCompare(vendor) == .orderedSame
        })?.category ?? VendorCategory.inferred(from: vendor)
    }

    private var hasUnsavedFinancialChanges: Bool {
        amount != String(format: "%.2f", receipt.amount)
            || taxAmount != String(format: "%.2f", receipt.taxAmount)
            || discountAmount != String(format: "%.2f", receipt.discountAmount)
            || isReturn != receipt.isReturn
            || items != receipt.items
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Details") {
                    TextField("Vendor", text: $vendor)
                        .accessibilityIdentifier("receipt-edit-vendor")
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("receipt-edit-amount")
                    }
                    .disabled(locksFinancialHistory)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    TextField("Subcategory (optional)", text: $subcategory)
                    
                    Toggle("Return/Refund", isOn: $isReturn)
                        .disabled(locksFinancialHistory)
                }
                
                Section("Payment Details") {
                    // Payment Method Picker Button
                    Button(action: {
                        showingPaymentMethodPicker = true
                    }) {
                        HStack {
                            Text("Payment Method")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(paymentMethod.isEmpty ? "Select..." : paymentMethod)
                                .foregroundColor(paymentMethod.isEmpty ? .secondary : .blue)
                        }
                    }
                    
                    TextField("Receipt Number", text: $receiptNumber)
                    
                    HStack {
                        Text("Tax Amount")
                        Spacer()
                        TextField("0.00", text: $taxAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .disabled(locksFinancialHistory)
                    
                    HStack {
                        Text("Discount Amount")
                        Spacer()
                        TextField("0.00", text: $discountAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .disabled(locksFinancialHistory)

                    if currentVendorCategory == .restaurant || !(Double(tipAmount) ?? 0).isZero {
                        HStack {
                            Text("Tip Amount")
                            Spacer()
                            TextField("0.00", text: $tipAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("receipt-edit-tip")
                        }
                    }

                    if currentVendorCategory == .gas || !(Double(pricePerGallon) ?? 0).isZero {
                        HStack {
                            Text("Price / Gallon")
                            Spacer()
                            TextField("0.000", text: $pricePerGallon)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("receipt-edit-price-per-gallon")
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            Button {
                                guard !locksFinancialHistory else { return }
                                editingItem = item
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("Qty: \(item.quantity, specifier: "%.1f")  Total: \(item.totalPrice.formatAsCurrency())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if !item.subcategory.isEmpty {
                                            Text(item.subcategory)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if locksFinancialHistory {
                                        Image(systemName: "lock.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if canRefund(item) {
                                    Button {
                                        prepareRefund(for: item)
                                    } label: {
                                        Label("Refund", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                    .accessibilityIdentifier("receipt-edit-item-refund-\(receiptEditAccessibilitySlug(item.name))")
                                }
                            }
                            .accessibilityIdentifier("receipt-edit-item-\(receiptEditAccessibilitySlug(item.name))")
                        }
                    } header: {
                        Text("Itemized Breakdown")
                            .accessibilityIdentifier("receipt-edit-items-header")
                    } footer: {
                        Text(
                            locksFinancialHistory
                                ? "Financial line items are locked because this receipt participates in partial-refund history. Swipe remaining refundable items to record another refund."
                                : "Tap an item to review or edit the saved scan details. Swipe left on a refundable item to record a refund."
                        )
                    }
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissEditor()
                    }
                    .accessibilityIdentifier("receipt-edit-cancel")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!isValidForm || isSaving)
                    .accessibilityIdentifier("receipt-edit-save")
                }
            }
            .sheet(isPresented: $showingPaymentMethodPicker) {
                SimplePaymentMethodPickerView(
                    selectedPaymentMethod: $selectedPaymentMethodObj,
                    paymentMethodService: projectVM.paymentMethodService,
                    onSelection: { method in
                        paymentMethod = method.displayName
                        selectedPaymentMethodObj = method
                    }
                )
            }
            .sheet(item: $editingItem) { item in
                ReceiptLineItemEditView(
                    item: item,
                    onSave: { updatedItem in
                        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                            items[index] = updatedItem
                        }
                    }
                )
            }
            .alert(item: $pendingRefundPrompt) { prompt in
                Alert(
                    title: Text("Refund \(prompt.item.name)?"),
                    message: Text(prompt.message),
                    primaryButton: .destructive(Text("Refund")) {
                        recordRefund(prompt.refund)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func saveReceipt() {
        guard !isSaving else { return }
        isSaving = true

        // Calculate spending changes for vendor and payment method services
        let oldAmount = receipt.isReturn ? -receipt.amount : receipt.amount
        let newAmount = isReturn ? -(Double(amount) ?? receipt.amount) : (Double(amount) ?? receipt.amount)
        
        // Update vendor spending if vendor changed or amount changed
        if receipt.vendor != vendor || oldAmount != newAmount {
            updateVendorSpending(oldVendor: receipt.vendor, newVendor: vendor, oldAmount: oldAmount, newAmount: newAmount)
        }
        
        // Update payment method spending if payment method changed or amount changed
        if receipt.paymentMethod != paymentMethod || oldAmount != newAmount {
            updatePaymentMethodSpending(oldPaymentMethod: receipt.paymentMethod, newPaymentMethod: paymentMethod, oldAmount: oldAmount, newAmount: newAmount)
        }
        
        var updatedReceipt = receipt
        updatedReceipt.vendor = vendor
        updatedReceipt.amount = Double(amount) ?? receipt.amount
        updatedReceipt.notes = notes
        updatedReceipt.date = date
        updatedReceipt.category = category
        updatedReceipt.subcategory = subcategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedReceipt.paymentMethod = paymentMethod
        updatedReceipt.receiptNumber = receiptNumber
        updatedReceipt.taxAmount = Double(taxAmount) ?? 0
        updatedReceipt.discountAmount = Double(discountAmount) ?? 0
        updatedReceipt.tipAmount = parsedPositiveValue(from: tipAmount)
        updatedReceipt.pricePerGallon = parsedPositiveValue(from: pricePerGallon)
        updatedReceipt.isReturn = isReturn
        updatedReceipt.items = items
        
        // Update in project
        if let project = projectVM.selectedProject {
            var updatedProject = project.normalizedReceiptCopy
            if updatedProject.receipts.contains(where: { $0.id == receipt.id }) {
                updatedProject = updatedProject.upsertingReceipt(updatedReceipt)
                
                Task {
                    await projectVM.updateProject(updatedProject)
                    await MainActor.run {
                        projectVM.recomputeFilteredReceipts()
                        dismissEditor()
                        isSaving = false

                        Logger.receiptWorkflow.notice(
                            "Receipt updated [vendor=\(vendor, privacy: .public) amount=\(newAmount, format: .fixed(precision: 2))]"
                        )
                    }
                }

                return
            }
        }

        isSaving = false
    }

    private func dismissEditor() {
        isPresented = false
        dismiss()
    }

    private func canRefund(_ item: ReceiptItem) -> Bool {
        receipt.supportsPartialRefunds
            && !receipt.isReturn
            && !hasUnsavedFinancialChanges
            && receipt.remainingRefundableQuantity(for: item, in: projectReceipts) > 0
    }

    private func prepareRefund(for item: ReceiptItem) {
        let remainingQuantity = receipt.remainingRefundableQuantity(for: item, in: projectReceipts)
        guard remainingQuantity > 0,
              let refund = receipt.makePartialRefund(
                selections: [ReceiptRefundSelection(itemID: item.id, quantity: remainingQuantity)],
                existingReceipts: projectReceipts
              )
        else {
            return
        }

        pendingRefundPrompt = ReceiptItemRefundPrompt(item: item, refund: refund)
    }

    private func recordRefund(_ refund: Receipt) {
        guard let project = projectVM.selectedProject else { return }

        Task {
            await projectVM.addReceipt(refund, to: project.id)
            await MainActor.run {
                updateDirectorySpending(for: refund)
                projectVM.recomputeFilteredReceipts()
                projectVM.saveOrganizationSpecificBackup()
                dismissEditor()
                Logger.receiptWorkflow.notice(
                    "Recorded line-item receipt refund [source=\(receipt.id, privacy: .private(mask: .hash)) amount=\(refund.amount, format: .fixed(precision: 2)) item=\(refund.items.first?.name ?? "unknown", privacy: .private(mask: .hash))]"
                )
            }
        }
    }

    private func updateDirectorySpending(for receipt: Receipt) {
        let signedAmount = receipt.signedAmount

        let vendor = projectVM.vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: receipt.likelyVendorCategory
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

    private func parsedPositiveValue(from text: String) -> Double? {
        guard let value = Double(text), value > 0 else { return nil }
        return value
    }
    
    private func updateVendorSpending(oldVendor: String, newVendor: String, oldAmount: Double, newAmount: Double) {
        // Remove spending from old vendor if changed
        if !oldVendor.isEmpty && oldVendor != newVendor {
            let oldVendorObj = projectVM.vendorService.findOrCreateVendor(name: oldVendor, category: .other)
            if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == oldVendorObj.id }) {
                projectVM.vendorService.vendors[index].totalSpent -= oldAmount
                projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
            }
        }
        
        // Add/update spending to new vendor
        if !newVendor.isEmpty {
            let newVendorObj = projectVM.vendorService.findOrCreateVendor(name: newVendor, category: .other)
            if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == newVendorObj.id }) {
                if oldVendor == newVendor {
                    // Same vendor, just update the amount difference
                    projectVM.vendorService.vendors[index].totalSpent += (newAmount - oldAmount)
                } else {
                    // New vendor, add the full new amount
                    projectVM.vendorService.vendors[index].totalSpent += newAmount
                }
                projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
            }
        }
    }
    
    private func updatePaymentMethodSpending(oldPaymentMethod: String, newPaymentMethod: String, oldAmount: Double, newAmount: Double) {
        // Remove spending from old payment method if changed
        if !oldPaymentMethod.isEmpty && oldPaymentMethod != newPaymentMethod {
            let oldMethodObj = projectVM.paymentMethodService.findOrCreatePaymentMethod(name: oldPaymentMethod, type: .other)
            if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == oldMethodObj.id }) {
                projectVM.paymentMethodService.paymentMethods[index].totalSpent -= oldAmount
                projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
            }
        }
        
        // Add/update spending to new payment method
        if !newPaymentMethod.isEmpty {
            let newMethodObj = projectVM.paymentMethodService.findOrCreatePaymentMethod(name: newPaymentMethod, type: .other)
            if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == newMethodObj.id }) {
                if oldPaymentMethod == newPaymentMethod {
                    // Same payment method, just update the amount difference
                    projectVM.paymentMethodService.paymentMethods[index].totalSpent += (newAmount - oldAmount)
                } else {
                    // New payment method, add the full new amount
                    projectVM.paymentMethodService.paymentMethods[index].totalSpent += newAmount
                }
                projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
            }
        }
    }
}

private struct ReceiptItemRefundPrompt: Identifiable {
    let id = UUID()
    let item: ReceiptItem
    let refund: Receipt

    var message: String {
        var parts = ["Refund \(refund.amount.formatAsCurrency()) for this line item"]

        if refund.taxAmount > 0 {
            parts.append("including \(refund.taxAmount.formatAsCurrency()) tax")
        }

        if refund.discountAmount > 0 {
            parts.append("after reversing \(refund.discountAmount.formatAsCurrency()) discount")
        }

        return parts.joined(separator: " ") + "."
    }
}

private struct ReceiptLineItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ReceiptItem
    let onSave: (ReceiptItem) -> Void

    @State private var name: String
    @State private var quantity: String
    @State private var unitPrice: String
    @State private var totalPrice: String
    @State private var category: ReceiptCategory
    @State private var subcategory: String
    @State private var sku: String
    @State private var notes: String

    init(item: ReceiptItem, onSave: @escaping (ReceiptItem) -> Void) {
        self.item = item
        self.onSave = onSave
        self._name = State(initialValue: item.name)
        self._quantity = State(initialValue: String(format: "%.2f", item.quantity))
        self._unitPrice = State(initialValue: String(format: "%.2f", item.unitPrice))
        self._totalPrice = State(initialValue: String(format: "%.2f", item.totalPrice))
        self._category = State(initialValue: item.category)
        self._subcategory = State(initialValue: item.subcategory)
        self._sku = State(initialValue: item.sku)
        self._notes = State(initialValue: item.notes)
    }

    private var isValidForm: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(quantity) ?? 0) > 0
            && ((Double(totalPrice) ?? 0) > 0 || (Double(unitPrice) ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Line Item") {
                    TextField("Item Name", text: $name)
                        .accessibilityIdentifier("receipt-edit-line-item-name")

                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0.00", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("receipt-edit-line-item-quantity")
                    }

                    HStack {
                        Text("Unit Price")
                        Spacer()
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("receipt-edit-line-item-unit-price")
                    }

                    HStack {
                        Text("Total Price")
                        Spacer()
                        TextField("0.00", text: $totalPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("receipt-edit-line-item-total-price")
                    }
                }

                Section("Classification") {
                    Picker("Category", selection: $category) {
                        ForEach(ReceiptCategory.allCases) { receiptCategory in
                            Text(receiptCategory.rawValue).tag(receiptCategory)
                        }
                    }
                    .accessibilityIdentifier("receipt-edit-line-item-category")

                    TextField("Subcategory", text: $subcategory)
                        .accessibilityIdentifier("receipt-edit-line-item-subcategory")

                    TextField("SKU", text: $sku)
                        .accessibilityIdentifier("receipt-edit-line-item-sku")
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("receipt-edit-line-item-notes")
                }
            }
            .navigationTitle("Edit Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("receipt-edit-line-item-cancel")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValidForm)
                    .accessibilityIdentifier("receipt-edit-line-item-save")
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubcategory = subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSKU = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let parsedQuantity = max(Double(quantity) ?? item.quantity, 0.01)
        let parsedUnitPrice = max(Double(unitPrice) ?? item.unitPrice, 0)
        let fallbackTotal = parsedQuantity * parsedUnitPrice
        let parsedTotalPrice = max(Double(totalPrice) ?? fallbackTotal, 0.01)

        onSave(
            ReceiptItem(
                id: item.id,
                name: trimmedName,
                quantity: parsedQuantity,
                unitPrice: parsedUnitPrice,
                totalPrice: parsedTotalPrice,
                category: category,
                subcategory: trimmedSubcategory,
                sku: trimmedSKU,
                notes: trimmedNotes
            )
        )

        dismiss()
    }
}

struct ReceiptEditView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleReceipt = Receipt(
            vendor: "Home Depot",
            date: Date(),
            amount: 156.78,
            notes: "Lumber for framing",
            category: .material,
            paymentMethod: "Chase Visa"
        )
        
        ReceiptEditView(receipt: sampleReceipt, isPresented: .constant(true))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
