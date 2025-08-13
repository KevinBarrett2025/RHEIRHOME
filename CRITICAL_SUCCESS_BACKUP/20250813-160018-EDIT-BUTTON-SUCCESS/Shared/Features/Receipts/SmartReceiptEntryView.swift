import SwiftUI

/// Smart Receipt Entry with AI-powered payment method detection and suggestions
struct SmartReceiptEntryView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Smart detection states
    @State private var isAnalyzing = false
    @State private var detectedVendor: String = ""
    @State private var detectedAmount: String = ""
    @State private var detectedPaymentMethod: PaymentMethod?
    @State private var detectedDate: Date = Date()
    @State private var suggestedCategory: ReceiptCategory = .material
    @State private var confidence: Float = 0.0
    
    // Manual input states
    @State private var selectedVendor: Vendor?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    @State private var showingEnhancedPaymentPicker = false
    
    @State private var vendor: String = ""
    @State private var paymentMethod: String = ""
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ReceiptCategory = .material
    @State private var subcategory: String = ""
    @State private var notes: String = ""
    @State private var isReturn: Bool = false
    
    // Smart suggestions
    @State private var paymentSuggestions: [PaymentMethodSuggestion] = []
    @State private var vendorSuggestions: [VendorSuggestion] = []
    
    // UI states
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var useSmartDetection = true

    struct PaymentMethodSuggestion {
        let method: PaymentMethod
        let confidence: Float
        let reason: String
    }
    
    struct VendorSuggestion {
        let vendor: Vendor
        let confidence: Float
        let reason: String
    }

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
                if useSmartDetection {
                    smartDetectionSection
                }
                
                vendorSection
                paymentMethodSection
                receiptDetailsSection
                categorySection
                notesSection
            }
            .navigationTitle("Smart Receipt Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveReceipt)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(useSmartDetection ? "Disable Smart Detection" : "Enable Smart Detection") {
                            useSmartDetection.toggle()
                        }
                        
                        Button("Use Enhanced Payment Picker") {
                            showingEnhancedPaymentPicker = true
                        }
                        
                        Button("Analyze Receipt Text") {
                            analyzeReceiptText()
                        }
                    } label: {
                        Image(systemName: "brain")
                    }
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
            .sheet(isPresented: $showingEnhancedPaymentPicker) {
                EnhancedPaymentMethodPickerView(
                    selectedPaymentMethod: $selectedPaymentMethod,
                    paymentMethodService: viewModel.paymentMethodService,
                    onSelection: { paymentMethod in
                        selectedPaymentMethod = paymentMethod
                        self.paymentMethod = paymentMethod.displayName
                    }
                )
            }
        }
        .onAppear {
            if useSmartDetection {
                generateSmartSuggestions()
            }
        }
    }
    
    @ViewBuilder
    private var smartDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("Smart Detection")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if !paymentSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Method Suggestions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(paymentSuggestions.enumerated()), id: \.offset) { index, suggestion in
                            SmartSuggestionRow(
                                title: suggestion.method.displayName,
                                subtitle: suggestion.reason,
                                confidence: suggestion.confidence,
                                icon: "creditcard.fill"
                            ) {
                                selectedPaymentMethod = suggestion.method
                                paymentMethod = suggestion.method.displayName
                            }
                        }
                    }
                }
                
                if !vendorSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vendor Suggestions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(vendorSuggestions.enumerated()), id: \.offset) { index, suggestion in
                            SmartSuggestionRow(
                                title: suggestion.vendor.name,
                                subtitle: suggestion.reason,
                                confidence: suggestion.confidence,
                                icon: "building.2.fill"
                            ) {
                                selectedVendor = suggestion.vendor
                                vendor = suggestion.vendor.name
                            }
                        }
                    }
                }
                
                if paymentSuggestions.isEmpty && vendorSuggestions.isEmpty && !isAnalyzing {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                        Text("No smart suggestions available. Enter receipt details to get suggestions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("AI-Powered Suggestions")
        }
    }
    
    @ViewBuilder
    private var vendorSection: some View {
        Section("Vendor") {
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
            if !localVendors.isEmpty && vendor.isEmpty {
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
            
            // Enhanced picker button
            Button("Use Enhanced Picker") {
                showingEnhancedPaymentPicker = true
            }
            .font(.caption)
            .foregroundColor(.purple)
            
            // Show recent payment methods if any exist
            if !localPaymentMethods.isEmpty && paymentMethod.isEmpty {
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
            HStack {
                Text("Amount")
                Spacer()
                TextField("$0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: amountText) { _, newValue in
                        if useSmartDetection {
                            generateSmartSuggestions()
                        }
                    }
            }
            
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

    // MARK: - Smart Detection Functions
    
    private func generateSmartSuggestions() {
        isAnalyzing = true
        
        Task {
            await generatePaymentMethodSuggestions()
            await generateVendorSuggestions()
            
            await MainActor.run {
                isAnalyzing = false
            }
        }
    }
    
    private func generatePaymentMethodSuggestions() async {
        // Smart payment method suggestions based on:
        // 1. Most used payment methods
        // 2. Payment methods used for similar amounts
        // 3. Payment methods used at similar vendors
        
        var suggestions: [PaymentMethodSuggestion] = []
        
        // Get most used payment methods
        let topMethods = viewModel.paymentMethodService.getTopPaymentMethods(limit: 3)
        
        for method in topMethods {
            let confidence = calculatePaymentMethodConfidence(method)
            if confidence > 0.3 {
                let reason = getPaymentMethodReason(method)
                suggestions.append(PaymentMethodSuggestion(
                    method: method,
                    confidence: confidence,
                    reason: reason
                ))
            }
        }
        
        await MainActor.run {
            paymentSuggestions = suggestions.sorted { $0.confidence > $1.confidence }
        }
    }
    
    private func generateVendorSuggestions() async {
        var suggestions: [VendorSuggestion] = []
        
        // Get vendors based on current inputs
        let topVendors = viewModel.vendorService.vendorsSortedByName.prefix(5)
        
        for vendor in topVendors {
            let confidence = calculateVendorConfidence(vendor)
            if confidence > 0.3 {
                let reason = getVendorReason(vendor)
                suggestions.append(VendorSuggestion(
                    vendor: vendor,
                    confidence: confidence,
                    reason: reason
                ))
            }
        }
        
        await MainActor.run {
            vendorSuggestions = suggestions.sorted { $0.confidence > $1.confidence }
        }
    }
    
    private func calculatePaymentMethodConfidence(_ method: PaymentMethod) -> Float {
        var confidence: Float = 0.0
        
        // Base confidence on usage frequency
        if method.totalSpent > 0 {
            confidence += 0.4
        }
        
        // Boost confidence for default payment method
        if method.isDefault {
            confidence += 0.3
        }
        
        // Boost confidence based on amount similarity
        if let amount = Double(amountText), amount > 0 {
            // This is a simplified approach - in a real app you'd analyze spending patterns
            if method.totalSpent > amount * 5 {
                confidence += 0.2
            }
        }
        
        return min(confidence, 1.0)
    }
    
    private func calculateVendorConfidence(_ vendor: Vendor) -> Float {
        var confidence: Float = 0.0
        
        // Base confidence on usage frequency
        if vendor.totalSpent > 0 {
            confidence += 0.4
        }
        
        // Boost confidence for recently used vendors
        // This is simplified - in a real app you'd track recent usage
        confidence += 0.3
        
        return min(confidence, 1.0)
    }
    
    private func getPaymentMethodReason(_ method: PaymentMethod) -> String {
        if method.isDefault {
            return "Your default payment method"
        } else if method.totalSpent > 0 {
            return "Frequently used (\(method.totalSpent.formatAsCurrency()) total)"
        } else {
            return "Available payment method"
        }
    }
    
    private func getVendorReason(_ vendor: Vendor) -> String {
        if vendor.totalSpent > 0 {
            return "Recently used (\(vendor.totalSpent.formatAsCurrency()) total)"
        } else {
            return "Available vendor"
        }
    }
    
    private func analyzeReceiptText() {
        // This would integrate with OCR/AI services in a real implementation
        isAnalyzing = true
        
        // Simulate analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isAnalyzing = false
            
            // Mock detected data
            if vendor.isEmpty {
                vendor = "Home Depot"
            }
            if amountText.isEmpty {
                amountText = "127.45"
            }
            
            generateSmartSuggestions()
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

struct SmartSuggestionRow: View {
    let title: String
    let subtitle: String
    let confidence: Float
    let icon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Confidence indicator
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(Float(index) < confidence * 5 ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SmartReceiptEntryView()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}