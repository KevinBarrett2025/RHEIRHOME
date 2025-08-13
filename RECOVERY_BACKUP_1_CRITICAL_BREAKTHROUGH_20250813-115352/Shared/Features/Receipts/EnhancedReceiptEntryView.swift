import SwiftUI

/// Enhanced Receipt Entry with Phase 2I features:
/// - Per-item categorization
/// - Only granular categories (no Materials/General Conditions roll-ups)
/// - AI-powered receipt splitting
/// - Vendor SKU enrichment (future)
struct EnhancedReceiptEntryView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Receipt basic info
    @State private var vendor: String = ""
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var paymentMethod: String = ""
    @State private var notes: String = ""
    @State private var isReturn: Bool = false
    
    // Enhanced categorization
    @State private var receiptItems: [EnhancedReceiptItem] = []
    @State private var defaultCategory: DetailedReceiptCategory = .framing
    @State private var showingCategoryPicker = false
    @State private var showingItemEditor = false
    @State private var editingItemIndex: Int? = nil
    
    // Vendor and payment method selection
    @State private var selectedVendor: Vendor?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    
    // AI Processing
    @State private var isProcessingWithAI = false
    @State private var aiSuggestions: [AIReceiptSuggestion] = []
    @State private var showingAISuggestions = false
    
    // UI state
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""

    private var canSave: Bool {
        let hasVendor = !vendor.isEmpty
        let hasPayment = !paymentMethod.isEmpty
        let hasAmount = totalAmount > 0
        return hasVendor && hasPayment && hasAmount
    }
    
    private var totalAmount: Double {
        if receiptItems.isEmpty {
            return Double(amountText) ?? 0
        } else {
            return receiptItems.reduce(0) { $0 + $1.totalPrice }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                vendorSection
                paymentMethodSection
                receiptDetailsSection
                
                if receiptItems.isEmpty {
                    simpleCategorySection
                } else {
                    itemizedSection
                }
                
                aiProcessingSection
                notesSection
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveReceipt)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .alert("Receipt Added Successfully", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: $showingCategoryPicker) {
                DetailedCategoryPickerSheet(selectedCategory: $defaultCategory)
            }
            .sheet(isPresented: $showingItemEditor) {
                if let index = editingItemIndex {
                    ReceiptItemEditorSheet(
                        item: $receiptItems[index],
                        onSave: { updatedItem in
                            receiptItems[index] = updatedItem
                            editingItemIndex = nil
                        },
                        onDelete: {
                            receiptItems.remove(at: index)
                            editingItemIndex = nil
                        }
                    )
                } else {
                    ReceiptItemEditorSheet(
                        item: .constant(EnhancedReceiptItem(
                            name: "",
                            quantity: 1.0,
                            unitPrice: 0,
                            totalPrice: 0,
                            category: defaultCategory
                        )),
                        onSave: { newItem in
                            receiptItems.append(newItem)
                        },
                        onDelete: {}
                    )
                }
            }
            .sheet(isPresented: $showingVendorPicker) {
                SimpleVendorPickerView(
                    selectedVendor: $selectedVendor,
                    vendorService: viewModel.vendorService,
                    onSelection: { vendor in
                        selectedVendor = vendor
                        self.vendor = vendor.name
                    }
                )
            }
            .sheet(isPresented: $showingPaymentMethodPicker) {
                SimplePaymentMethodPickerView(
                    selectedPaymentMethod: $selectedPaymentMethod,
                    paymentMethodService: viewModel.paymentMethodService,
                    onSelection: { paymentMethod in
                        selectedPaymentMethod = paymentMethod
                        self.paymentMethod = paymentMethod.displayName
                    }
                )
            }
            .sheet(isPresented: $showingAISuggestions) {
                AISuggestionsSheet(
                    suggestions: aiSuggestions,
                    onApply: { suggestion in
                        applyAISuggestion(suggestion)
                    }
                )
            }
        }
    }
    
    // MARK: - Form Sections
    
    @ViewBuilder
    private var vendorSection: some View {
        Section("Vendor") {
            Button(action: { showingVendorPicker = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let selectedVendor = selectedVendor {
                            Text(selectedVendor.name)
                                .foregroundColor(.primary)
                            Text(selectedVendor.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !vendor.isEmpty {
                            Text(vendor)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select Vendor")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var paymentMethodSection: some View {
        Section("Payment Method") {
            Button(action: { showingPaymentMethodPicker = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let selectedPaymentMethod = selectedPaymentMethod {
                            Text(selectedPaymentMethod.displayName)
                                .foregroundColor(.primary)
                            Text(selectedPaymentMethod.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !paymentMethod.isEmpty {
                            Text(paymentMethod)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select Payment Method")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var receiptDetailsSection: some View {
        Section("Receipt Details") {
            HStack {
                Text("Amount")
                Spacer()
                TextField("$0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            
            DatePicker("Date", selection: $date, displayedComponents: [.date])
            
            Toggle("Return", isOn: $isReturn)
        }
    }
    
    @ViewBuilder
    private var simpleCategorySection: some View {
        Section("Category") {
            Button(action: { showingCategoryPicker = true }) {
                HStack {
                    Image(systemName: defaultCategory.icon)
                        .foregroundColor(defaultCategory.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(defaultCategory.rawValue)
                            .foregroundColor(.primary)
                        
                        Text("→ \(defaultCategory.budgetCategory.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Button("Add Item Breakdown") {
                addInitialItem()
            }
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var itemizedSection: some View {
        Section {
            ForEach(Array(receiptItems.enumerated()), id: \.offset) { index, item in
                ReceiptItemRow(item: item) {
                    editingItemIndex = index
                    showingItemEditor = true
                }
            }
            .onDelete { indexSet in
                receiptItems.remove(atOffsets: indexSet)
            }
            
            Button("Add Item") {
                editingItemIndex = nil
                showingItemEditor = true
            }
            .foregroundColor(.blue)
            
        } header: {
            HStack {
                Text("Itemized Breakdown")
                Spacer()
                Text("Total: \(totalAmount.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var aiProcessingSection: some View {
        Section("AI Enhancement") {
            if isProcessingWithAI {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing receipt...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Analyze with AI") {
                    processWithAI()
                }
                .foregroundColor(.purple)
                
                if !aiSuggestions.isEmpty {
                    Button("View AI Suggestions (\(aiSuggestions.count))") {
                        showingAISuggestions = true
                    }
                    .foregroundColor(.purple)
                }
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Helper Methods
    
    private func addInitialItem() {
        let amount = Double(amountText) ?? 0
        receiptItems = [EnhancedReceiptItem(
            name: "Receipt Total",
            quantity: 1.0,
            unitPrice: amount,
            totalPrice: amount,
            category: defaultCategory
        )]
        amountText = "" // Clear single amount since we're now itemized
    }
    
    private func processWithAI() {
        isProcessingWithAI = true
        
        // Simulate AI processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessingWithAI = false
            
            // Mock AI suggestions
            aiSuggestions = [
                AIReceiptSuggestion(
                    suggestedItems: [
                        EnhancedReceiptItem(
                            name: "2x4 Lumber (8ft)",
                            quantity: 10,
                            unitPrice: 3.47,
                            totalPrice: 34.70,
                            category: .framing
                        ),
                        EnhancedReceiptItem(
                            name: "Wood Screws (3\")",
                            quantity: 1,
                            unitPrice: 12.99,
                            totalPrice: 12.99,
                            category: .framing
                        )
                    ],
                    confidence: 0.92,
                    suggestedVendor: "Home Depot",
                    suggestedPaymentMethod: "Visa ••••1234"
                )
            ]
            
            showingAISuggestions = true
        }
    }
    
    private func applyAISuggestion(_ suggestion: AIReceiptSuggestion) {
        receiptItems = suggestion.suggestedItems
        if !suggestion.suggestedVendor.isEmpty && vendor.isEmpty {
            vendor = suggestion.suggestedVendor
        }
        showingAISuggestions = false
    }
    
    private func saveReceipt() {
        let finalItems: [ReceiptItem] = receiptItems.map { item in
            ReceiptItem(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                category: item.category.toLegacyCategory(),
                sku: item.sku,
                notes: item.notes
            )
        }
        
        let receipt = Receipt(
            vendor: selectedVendor?.name ?? vendor,
            vendorID: selectedVendor?.id.uuidString,
            date: date,
            amount: totalAmount,
            notes: notes,
            category: receiptItems.isEmpty ? defaultCategory.toLegacyCategory() : finalItems.first?.category ?? .material,
            isReturn: isReturn,
            paymentMethod: selectedPaymentMethod?.displayName ?? paymentMethod,
            paymentMethodID: selectedPaymentMethod?.id.uuidString,
            processingStatus: .completed
        )
        
        var finalReceipt = receipt
        finalReceipt.items = finalItems
        
        viewModel.addReceipt(finalReceipt)
        showSuccessMessage(receipt: finalReceipt)
    }
    
    private func showSuccessMessage(receipt: Receipt) {
        let categoryText = receiptItems.isEmpty ? defaultCategory.rawValue : "itemized"
        successMessage = "Added \(receipt.vendor) receipt (\(totalAmount.formatAsCurrency())) to \(categoryText) category"
        showingSuccessAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Supporting Data Structures

struct EnhancedReceiptItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double
    var category: DetailedReceiptCategory
    var sku: String = ""
    var notes: String = ""
    var brand: String = ""
    var confidence: Double = 1.0
}

struct AIReceiptSuggestion: Identifiable {
    let id = UUID()
    let suggestedItems: [EnhancedReceiptItem]
    let confidence: Double
    let suggestedVendor: String
    let suggestedPaymentMethod: String
}

// MARK: - Supporting Views

struct ReceiptItemRow: View {
    let item: EnhancedReceiptItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: item.category.icon)
                    .foregroundColor(item.category.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(item.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if item.quantity != 1.0 {
                            Text("• Qty: \(item.quantity.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.totalPrice.formatAsCurrency())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if item.quantity > 1 {
                        Text("\(item.unitPrice.formatAsCurrency())/ea")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        EnhancedReceiptEntryView()
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}