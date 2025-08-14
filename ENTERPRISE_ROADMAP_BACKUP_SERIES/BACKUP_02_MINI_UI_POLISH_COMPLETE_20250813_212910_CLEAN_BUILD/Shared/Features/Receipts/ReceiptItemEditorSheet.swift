import SwiftUI

struct ReceiptItemEditorSheet: View {
    @Binding var item: EnhancedReceiptItem
    let onSave: (EnhancedReceiptItem) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingCategoryPicker = false
    @State private var isNewItem: Bool
    
    @State private var name: String
    @State private var quantityText: String
    @State private var unitPriceText: String
    @State private var category: DetailedReceiptCategory
    @State private var sku: String
    @State private var notes: String
    
    init(item: Binding<EnhancedReceiptItem>, onSave: @escaping (EnhancedReceiptItem) -> Void, onDelete: @escaping () -> Void) {
        self._item = item
        self.onSave = onSave
        self.onDelete = onDelete
        
        // Determine if this is a new item
        let itemValue = item.wrappedValue
        self.isNewItem = itemValue.name.isEmpty
        
        // Initialize state variables
        self._name = State(initialValue: itemValue.name)
        self._quantityText = State(initialValue: itemValue.quantity == 1.0 ? "1" : "\(itemValue.quantity)")
        self._unitPriceText = State(initialValue: itemValue.unitPrice == 0 ? "" : "\(itemValue.unitPrice)")
        self._category = State(initialValue: itemValue.category)
        self._sku = State(initialValue: itemValue.sku)
        self._notes = State(initialValue: itemValue.notes)
    }
    
    private var quantity: Double {
        Double(quantityText) ?? 1.0
    }
    
    private var unitPrice: Double {
        Double(unitPriceText) ?? 0.0
    }
    
    private var totalPrice: Double {
        quantity * unitPrice
    }
    
    private var canSave: Bool {
        !name.isEmpty && unitPrice > 0 && quantity > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                itemDetailsSection
                pricingSection
                categorySection
                additionalInfoSection
                
                if !isNewItem {
                    deleteSection
                }
            }
            .navigationTitle(isNewItem ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                DetailedCategoryPickerSheet(selectedCategory: $category)
            }
        }
    }
    
    @ViewBuilder
    private var itemDetailsSection: some View {
        Section("Item Details") {
            TextField("Item Name", text: $name)
                .textContentType(.none)
            
            if !sku.isEmpty || !name.isEmpty {
                TextField("SKU/Product Code (optional)", text: $sku)
                    .textContentType(.none)
            }
        }
    }
    
    @ViewBuilder
    private var pricingSection: some View {
        Section {
            HStack {
                Text("Quantity")
                Spacer()
                TextField("1", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            
            HStack {
                Text("Unit Price")
                Spacer()
                TextField("$0.00", text: $unitPriceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            
            HStack {
                Text("Total Price")
                    .fontWeight(.semibold)
                Spacer()
                Text(totalPrice.formatAsCurrency())
                    .fontWeight(.semibold)
                    .foregroundColor(totalPrice > 0 ? .primary : .secondary)
            }
        } header: {
            Text("Pricing")
        } footer: {
            if totalPrice > 0 {
                Text("Quantity × Unit Price = \(quantity.formatted()) × \(unitPrice.formatAsCurrency()) = \(totalPrice.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var categorySection: some View {
        Section("Category") {
            Button(action: { showingCategoryPicker = true }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .foregroundColor(.primary)
                        
                        Text("→ \(category.budgetCategory.rawValue)")
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
        }
    }
    
    @ViewBuilder
    private var additionalInfoSection: some View {
        Section("Additional Info") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button("Delete Item") {
                onDelete()
                dismiss()
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private func saveItem() {
        let updatedItem = EnhancedReceiptItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            category: category,
            sku: sku.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onSave(updatedItem)
        dismiss()
    }
}

// MARK: - AI Suggestions Sheet

struct AISuggestionsSheet: View {
    let suggestions: [AIReceiptSuggestion]
    let onApply: (AIReceiptSuggestion) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(suggestions) { suggestion in
                    AISuggestionRow(suggestion: suggestion) {
                        onApply(suggestion)
                        dismiss()
                    }
                }
            }
            .navigationTitle("AI Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AISuggestionRow: View {
    let suggestion: AIReceiptSuggestion
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Analysis Result")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                        
                        Text("Confidence: \(Int(suggestion.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Apply") {
                            onApply()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Items:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(suggestion.suggestedItems) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundColor(item.category.color)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(item.category.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(item.totalPrice.formatAsCurrency())
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            if !suggestion.suggestedVendor.isEmpty || !suggestion.suggestedPaymentMethod.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    if !suggestion.suggestedVendor.isEmpty {
                        Text("Vendor: \(suggestion.suggestedVendor)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !suggestion.suggestedPaymentMethod.isEmpty {
                        Text("Payment: \(suggestion.suggestedPaymentMethod)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ReceiptItemEditorSheet(
        item: .constant(EnhancedReceiptItem(
            name: "2x4 Lumber",
            quantity: 10,
            unitPrice: 3.47,
            totalPrice: 34.70,
            category: .framing
        )),
        onSave: { _ in },
        onDelete: { }
    )
}

#Preview("AI Suggestions") {
    AISuggestionsSheet(
        suggestions: [
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
        ],
        onApply: { _ in }
    )
}