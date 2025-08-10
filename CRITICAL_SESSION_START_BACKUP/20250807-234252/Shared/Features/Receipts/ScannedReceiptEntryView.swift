import SwiftUI

struct AddReceiptView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Vendor and Payment Method Selection
    @State private var selectedVendor: Vendor?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    
    @State private var vendor: String = ""
    @State private var paymentMethod: String = ""
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ReceiptCategory = .material
    @State private var subcategory: String = ""
    @State private var notes: String = ""
    @State private var isReturn: Bool = false
    
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""

    private var canSave: Bool {
        let hasVendor = !vendor.isEmpty
        let hasPayment = !paymentMethod.isEmpty
        let hasAmount = Double(amountText) != nil
        return hasVendor && hasPayment && hasAmount
    }
    
    private var localVendors: [Vendor] {
        return viewModel.vendorService.vendorsSortedByName
    }
    
    private var localPaymentMethods: [PaymentMethod] {
        return viewModel.paymentMethodService.paymentMethodsSortedByName
    }

    var body: some View {
        NavigationStack {
            Form {
                vendorSection
                paymentMethodSection
                receiptDetailsSection
                categorySection
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
                }
            }
            .alert("Receipt Added Successfully", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(successMessage)
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
        }
    }
    
    @ViewBuilder
    private var vendorSection: some View {
        Section("Vendor") {
            // Vendor picker button
            Button(action: {
                showingVendorPicker = true
            }) {
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
            
            // Show recent vendors if any exist
            if !localVendors.isEmpty {
                DisclosureGroup("Recent Vendors") {
                    ForEach(localVendors.prefix(3)) { recentVendor in
                        Button(action: {
                            selectedVendor = recentVendor
                            vendor = recentVendor.name
                        }) {
                            HStack {
                                Text(recentVendor.name)
                                Spacer()
                                if recentVendor.totalSpent > 0 {
                                    Text(recentVendor.totalSpent.formatAsCurrency())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var paymentMethodSection: some View {
        Section("Payment Method") {
            // Payment method picker button
            Button(action: {
                showingPaymentMethodPicker = true
            }) {
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
            
            // Show recent payment methods if any exist
            if !localPaymentMethods.isEmpty {
                DisclosureGroup("Recent Payment Methods") {
                    ForEach(localPaymentMethods.prefix(3)) { recentMethod in
                        Button(action: {
                            selectedPaymentMethod = recentMethod
                            paymentMethod = recentMethod.displayName
                        }) {
                            HStack {
                                Text(recentMethod.displayName)
                                Spacer()
                                if recentMethod.totalSpent > 0 {
                                    Text(recentMethod.totalSpent.formatAsCurrency())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var receiptDetailsSection: some View {
        Section("Receipt Details") {
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)
            
            DatePicker("Date", selection: $date, displayedComponents: [.date])
            
            Toggle("Return", isOn: $isReturn)
        }
    }
    
    @ViewBuilder
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(ReceiptCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("Subcategory (optional)", text: $subcategory)
                .textContentType(.none)
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func saveReceipt() {
        guard let amountValue = Double(amountText) else { return }
        
        // Use selected vendor name, fallback to manual entry
        let vendorName = selectedVendor?.name ?? vendor
        let paymentMethodName = selectedPaymentMethod?.displayName ?? paymentMethod
        
        let receipt = Receipt(
            vendor: vendorName,
            vendorID: selectedVendor?.id,
            date: date,
            amount: amountValue,
            notes: notes,
            category: category,
            isReturn: isReturn,
            paymentMethod: paymentMethodName,
            paymentMethodID: selectedPaymentMethod?.id,
            processingStatus: .completed
        )
        
        viewModel.addReceipt(receipt)
        showSuccessMessage(receipt: receipt)
    }
    
    private func showSuccessMessage(receipt: Receipt) {
        let amountText = String(format: "%.2f", receipt.amount)
        successMessage = "Success! Receipt from \(receipt.vendor) ($\(amountText)) was added to \(receipt.category.rawValue)"
        showingSuccessAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

#if DEBUG
struct AddReceiptView_Previews: PreviewProvider {
    static var previews: some View {
        AddReceiptView()
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
            .previewDevice("iPhone 14")
            .previewDisplayName("Add Receipt")
    }
}
#endif