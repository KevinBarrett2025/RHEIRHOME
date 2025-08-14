import SwiftUI

struct PaymentMethodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPaymentMethod: PaymentMethod?
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    let onSelection: (PaymentMethod) -> Void
    
    @State private var searchText = ""
    @State private var showingAddPaymentMethod = false
    @State private var newPaymentMethodName = ""
    @State private var newPaymentMethodType: PaymentType = .creditCard
    
    private var filteredPaymentMethods: [PaymentMethod] {
        let methods = paymentMethodService.paymentMethodsSortedByName
        
        if searchText.isEmpty {
            return methods
        } else {
            return methods.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Search/Add section
                Section {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.secondary)
                        TextField("Search or enter new payment method", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    
                    if !searchText.isEmpty && !paymentMethodExists(searchText) {
                        Button("Add '\(searchText)' as new payment method") {
                            addNewPaymentMethod(name: searchText)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Existing payment methods
                if !filteredPaymentMethods.isEmpty {
                    Section("Select Payment Method") {
                        ForEach(filteredPaymentMethods) { paymentMethod in
                            PaymentMethodRowView(
                                paymentMethod: paymentMethod,
                                isSelected: selectedPaymentMethod?.id == paymentMethod.id
                            ) {
                                selectedPaymentMethod = paymentMethod
                                onSelection(paymentMethod)
                                dismiss()
                            }
                        }
                    }
                }
                
                // Type shortcuts
                Section("Add by Type") {
                    ForEach(PaymentType.allCases) { type in
                        Button(type.rawValue) {
                            newPaymentMethodType = type
                            showingAddPaymentMethod = true
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Select Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search payment methods")
        }
        .alert("Add New Payment Method", isPresented: $showingAddPaymentMethod) {
            TextField("Payment Method Name", text: $newPaymentMethodName)
            Button("Add") {
                if !newPaymentMethodName.isEmpty {
                    addNewPaymentMethod(name: newPaymentMethodName, type: newPaymentMethodType)
                    newPaymentMethodName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newPaymentMethodName = ""
            }
        } message: {
            Text("Enter the name for the new \(newPaymentMethodType.rawValue.lowercased())")
        }
    }
    
    private func paymentMethodExists(_ name: String) -> Bool {
        return paymentMethodService.paymentMethods.contains { 
            $0.name.lowercased() == name.lowercased() ||
            $0.displayName.lowercased() == name.lowercased()
        }
    }
    
    private func addNewPaymentMethod(name: String, type: PaymentType = .other) {
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(name: name, type: type)
        selectedPaymentMethod = paymentMethod
        onSelection(paymentMethod)
        dismiss()
    }
}

struct PaymentMethodRowView: View {
    let paymentMethod: PaymentMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(paymentMethod.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(paymentMethod.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if paymentMethod.totalSpent > 0 {
                        Text("Total spent: \(paymentMethod.totalSpent.formatAsCurrency())")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaymentMethodPickerView(
        selectedPaymentMethod: .constant(nil),
        paymentMethodService: PaymentMethodManagementService(),
        onSelection: { _ in }
    )
}