import SwiftUI

/// Simple payment method picker for quick selection
struct SimplePaymentMethodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPaymentMethod: PaymentMethod?
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    let onSelection: (PaymentMethod) -> Void
    
    @State private var searchText = ""
    
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
    
    private var favoritePaymentMethods: [PaymentMethod] {
        paymentMethodService.paymentMethodsSortedBySpending.prefix(3).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search payment methods...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                List {
                    // Quick add from search
                    if !searchText.isEmpty && !paymentMethodExists(searchText) {
                        Section {
                            Button("Add '\(searchText)' as new payment method") {
                                addNewPaymentMethod(name: searchText)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Favorites
                    if !favoritePaymentMethods.isEmpty && searchText.isEmpty {
                        Section("Favorites") {
                            ForEach(favoritePaymentMethods, id: \.id) { method in
                                PaymentMethodRow(
                                    paymentMethod: method,
                                    isSelected: selectedPaymentMethod?.id == method.id,
                                    showStats: true,
                                    onTap: {
                                        selectPaymentMethod(method)
                                    }
                                )
                            }
                        }
                    }
                    
                    // All payment methods
                    Section(searchText.isEmpty ? "All Payment Methods" : "Search Results") {
                        ForEach(filteredPaymentMethods, id: \.id) { method in
                            PaymentMethodRow(
                                paymentMethod: method,
                                isSelected: selectedPaymentMethod?.id == method.id,
                                showStats: false,
                                onTap: {
                                    selectPaymentMethod(method)
                                }
                            )
                        }
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
        }
    }
    
    private func selectPaymentMethod(_ method: PaymentMethod) {
        selectedPaymentMethod = method
        onSelection(method)
        dismiss()
    }
    
    private func paymentMethodExists(_ name: String) -> Bool {
        return paymentMethodService.paymentMethods.contains { 
            $0.name.lowercased() == name.lowercased() ||
            $0.displayName.lowercased() == name.lowercased()
        }
    }
    
    private func addNewPaymentMethod(name: String) {
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(name: name)
        selectPaymentMethod(paymentMethod)
    }
}

struct PaymentMethodRow: View {
    let paymentMethod: PaymentMethod
    let isSelected: Bool
    let showStats: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(paymentMethod.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if paymentMethod.isDefault {
                            Text("DEFAULT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(paymentMethod.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if showStats && paymentMethod.totalSpent > 0 {
                        Text("Total spent: \(paymentMethod.totalSpent.formatAsCurrency())")
                            .font(.caption)
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
    SimplePaymentMethodPickerView(
        selectedPaymentMethod: .constant(nil),
        paymentMethodService: PaymentMethodManagementService(),
        onSelection: { _ in }
    )
}