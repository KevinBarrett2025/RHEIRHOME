import SwiftUI
import OSLog

struct ScannedReceiptEntryView: View {
    @Binding var isPresented: Bool
    let project: Project
    let analysisResult: ReceiptAnalysisResult
    let scannedImage: UIImage
    let onReceiptSaved: (() -> Void)?
    
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Vendor and Payment Method Selection
    @State private var selectedVendor: Vendor?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    
    // Editable fields pre-filled from AI analysis
    @State private var vendor: String = ""
    @State private var paymentMethod: String = ""
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ReceiptCategory = .material
    @State private var subcategory: String = ""
    @State private var notes: String = ""
    @State private var isReturn: Bool = false
    @State private var receiptNumber: String = ""
    @State private var taxAmount: Double = 0.0
    @State private var discountAmount: Double = 0.0
    
    // UI states
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingImagePreview = false
    @State private var showingItemDetails = false
    
    private var canSave: Bool {
        let hasVendor = !vendor.isEmpty
        let hasPayment = !paymentMethod.isEmpty
        let hasAmount = Double(amountText) != nil
        return hasVendor && hasPayment && hasAmount
    }
    
    private var confidenceColor: Color {
        if analysisResult.confidence >= 0.8 { return .green }
        else if analysisResult.confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                aiAnalysisSection
                vendorSection
                paymentMethodSection
                receiptDetailsSection
                categorySection
                itemsSection
                notesSection
                imagePreviewSection
            }
            .navigationTitle("AI-Scanned Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                prefillFromAnalysis()
            }
            .alert("Receipt Added Successfully", isPresented: $showingSuccessAlert) {
                Button("OK") { 
                    onReceiptSaved?()  // Call completion callback before dismissing
                    isPresented = false
                }
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: $showingVendorPicker) {
                SimpleVendorPickerView(
                    selectedVendor: $selectedVendor,
                    vendorService: projectVM.vendorService,
                    onSelection: { vendor in
                        selectedVendor = vendor
                        self.vendor = vendor.name
                    }
                )
            }
            .sheet(isPresented: $showingPaymentMethodPicker) {
                SimplePaymentMethodPickerView(
                    selectedPaymentMethod: $selectedPaymentMethod,
                    paymentMethodService: projectVM.paymentMethodService,
                    onSelection: { paymentMethod in
                        selectedPaymentMethod = paymentMethod
                        self.paymentMethod = paymentMethod.displayName
                    }
                )
            }
            .sheet(isPresented: $showingImagePreview) {
                ImagePreviewView(image: scannedImage)
            }
            .sheet(isPresented: $showingItemDetails) {
                ItemDetailsView(items: analysisResult.items)
            }
        }
    }
    
    @ViewBuilder
    private var aiAnalysisSection: some View {
        Section {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Analysis Complete")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    HStack {
                        Text("Confidence:")
                        Text("\(Int(analysisResult.confidence * 100))%")
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
                        
                        Spacer()
                        
                        if analysisResult.confidence < 0.7 {
                            Text("Please review carefully")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Button("View Items") {
                    showingItemDetails = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        } header: {
            Text("🤖 AI Processing Results")
        }
    }
    
    @ViewBuilder
    private var vendorSection: some View {
        Section("Vendor") {
            HStack {
                TextField("Vendor Name", text: $vendor)
                    .textFieldStyle(.roundedBorder)
                
                Button("📋") {
                    showingVendorPicker = true
                }
                .buttonStyle(.bordered)
            }
            
            if !analysisResult.vendor.isEmpty && analysisResult.vendor != vendor {
                Text("AI detected: \(analysisResult.vendor)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
    
    @ViewBuilder
    private var paymentMethodSection: some View {
        Section("Payment Method") {
            HStack {
                TextField("Payment Method", text: $paymentMethod)
                    .textFieldStyle(.roundedBorder)
                
                Button("💳") {
                    showingPaymentMethodPicker = true
                }
                .buttonStyle(.bordered)
            }
            
            // Show AI detected payment method details
            if let paymentDetails = analysisResult.paymentMethodDetails {
                VStack(alignment: .leading, spacing: 4) {
                    if let cardBrand = paymentDetails.cardBrand, !cardBrand.isEmpty {
                        HStack {
                            Text("Card Brand:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(cardBrand)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    if let lastFour = paymentDetails.lastFourDigits, !lastFour.isEmpty {
                        HStack {
                            Text("Last 4 Digits:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•••• \(lastFour)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    if let accountInfo = paymentDetails.accountInfo, !accountInfo.isEmpty {
                        HStack {
                            Text("Account Info:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(accountInfo)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 4)
                .padding(.top, 4)
            }
            
            if !analysisResult.paymentMethod.isEmpty && analysisResult.paymentMethod != paymentMethod {
                Text("AI detected: \(analysisResult.paymentMethod)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
    
    @ViewBuilder
    private var receiptDetailsSection: some View {
        Section("Receipt Details") {
            HStack {
                Text("Amount:")
                Spacer()
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
            
            if taxAmount > 0 {
                HStack {
                    Text("Tax:")
                    Spacer()
                    Text(taxAmount.formatAsCurrency())
                        .foregroundColor(.secondary)
                }
            }
            
            if discountAmount > 0 {
                HStack {
                    Text("Discount:")
                    Spacer()
                    Text("-\(discountAmount.formatAsCurrency())")
                        .foregroundColor(.green)
                }
            }
            
            DatePicker("Date", selection: $date, displayedComponents: [.date])
            
            // Show if AI detected a different date
            if let aiDetectedDate = analysisResult.receiptDate {
                HStack {
                    Text("AI detected date:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(aiDetectedDate, style: .date)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    Spacer()
                    Button("Use AI Date") {
                        date = aiDetectedDate
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.leading, 4)
            }
            
            if !receiptNumber.isEmpty {
                HStack {
                    Text("Receipt #:")
                    Spacer()
                    Text(receiptNumber)
                        .foregroundColor(.secondary)
                }
            }
            
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
            
            if !analysisResult.category.isEmpty {
                Text("AI suggested: \(analysisResult.category)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            
            TextField("Subcategory (optional)", text: $subcategory)
                .textContentType(.none)
        }
    }
    
    @ViewBuilder
    private var itemsSection: some View {
        if !analysisResult.items.isEmpty {
            Section {
                Button(action: {
                    showingItemDetails = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(analysisResult.items.count) Items Detected")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Tap to view itemized breakdown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Show first few items as preview
                ForEach(Array(analysisResult.items.prefix(3).enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.name)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(item.quantity))x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.totalPrice.formatAsCurrency())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading)
                }
                
                if analysisResult.items.count > 3 {
                    Text("... and \(analysisResult.items.count - 3) more items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading)
                }
            } header: {
                Text("📋 Itemized Breakdown")
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
    
    @ViewBuilder
    private var imagePreviewSection: some View {
        Section("Scanned Image") {
            Button(action: {
                showingImagePreview = true
            }) {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                    
                    Text("View Original Receipt")
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func prefillFromAnalysis() {
        vendor = analysisResult.vendor
        paymentMethod = analysisResult.paymentMethod
        amountText = String(format: "%.2f", analysisResult.amount)
        taxAmount = analysisResult.taxAmount
        discountAmount = analysisResult.discountAmount
        receiptNumber = analysisResult.receiptNumber
        isReturn = analysisResult.isReturn
        
        // Use AI-detected date if available, otherwise use current date
        if let aiDate = analysisResult.receiptDate {
            date = aiDate
        } else {
            date = Date()
        }
        
        // Map AI category to receipt category
        if let receiptCategory = ReceiptCategory.allCases.first(where: { 
            $0.rawValue.lowercased() == analysisResult.category.lowercased() 
        }) {
            category = receiptCategory
        }
        
        // Auto-match existing vendors and payment methods based on AI details
        autoMatchVendorAndPaymentMethod()
    }
    
    private func autoMatchVendorAndPaymentMethod() {
        // Try to match existing vendor
        if let matchedVendor = projectVM.vendorService.vendorsSortedByName.first(where: { 
            $0.name.lowercased().contains(analysisResult.vendor.lowercased()) ||
            analysisResult.vendor.lowercased().contains($0.name.lowercased())
        }) {
            selectedVendor = matchedVendor
            vendor = matchedVendor.name
        }
        
        // Try to match existing payment method with enhanced logic
        if let paymentDetails = analysisResult.paymentMethodDetails,
           let lastFour = paymentDetails.lastFourDigits,
           !lastFour.isEmpty {
            // First try to match by last 4 digits
            if let matchedByDigits = projectVM.paymentMethodService.paymentMethodsSortedByName.first(where: {
                $0.lastFourDigits == lastFour
            }) {
                selectedPaymentMethod = matchedByDigits
                paymentMethod = matchedByDigits.displayName
                return
            }
            
            // Then try to match by card brand and last 4 digits
            if let cardBrand = paymentDetails.cardBrand {
                if let matchedByBrandAndDigits = projectVM.paymentMethodService.paymentMethodsSortedByName.first(where: {
                    $0.cardBrand?.rawValue.lowercased() == cardBrand.lowercased() && 
                    $0.lastFourDigits == lastFour
                }) {
                    selectedPaymentMethod = matchedByBrandAndDigits
                    paymentMethod = matchedByBrandAndDigits.displayName
                    return
                }
            }
        }
        
        // Fallback to name-based matching
        if let matchedPaymentMethod = projectVM.paymentMethodService.paymentMethodsSortedByName.first(where: {
            $0.displayName.lowercased().contains(analysisResult.paymentMethod.lowercased()) ||
            analysisResult.paymentMethod.lowercased().contains($0.displayName.lowercased()) ||
            ($0.cardBrand?.rawValue.lowercased().contains(analysisResult.paymentMethod.lowercased()) ?? false)
        }) {
            selectedPaymentMethod = matchedPaymentMethod
            paymentMethod = matchedPaymentMethod.displayName
        }
    }
    
    private func saveReceipt() {
        guard let amountValue = Double(amountText) else { return }
        
        let receipt = Receipt(
            vendor: vendor,
            vendorID: selectedVendor?.id.uuidString,
            date: date,
            amount: amountValue,
            notes: notes,
            category: category,
            isReturn: isReturn,
            paymentMethod: paymentMethod,
            paymentMethodID: selectedPaymentMethod?.id.uuidString,
            paymentMethodDetails: analysisResult.paymentMethodDetails,
            taxAmount: taxAmount > 0 ? taxAmount : 0.0,
            discountAmount: discountAmount > 0 ? discountAmount : 0.0,
            receiptNumber: receiptNumber.isEmpty ? "" : receiptNumber,
            processingStatus: .completed,
            aiAnalysis: AIAnalysisData(
                confidence: analysisResult.confidence,
                detectedVendor: analysisResult.vendor,
                detectedCategory: analysisResult.category,
                detectedPaymentMethod: analysisResult.paymentMethod,
                itemCount: analysisResult.items.count
            ),
            receiptImageData: scannedImage.jpegData(compressionQuality: 0.8)
        )
        
        // CRITICAL FIX: Use the correct async method with project ID
        Task {
            await projectVM.addReceipt(receipt, to: project.id)
            
            // CRITICAL FIX: Sync vendor and payment method to organization settings
            await syncReceiptDataToCompanySettings(receipt: receipt)
            
            // Save organization-specific backup to ensure persistence
            projectVM.saveOrganizationSpecificBackup()
            
            await MainActor.run {
                showSuccessMessage(receipt: receipt)
            }
        }
    }
    
    // MARK: - Company Settings Integration
    
    private func syncReceiptDataToCompanySettings(receipt: Receipt) async {
        // Sync vendor to organization's vendor directory
        if !receipt.vendor.isEmpty {
            let vendor = projectVM.vendorService.findOrCreateVendor(
                name: receipt.vendor,
                category: mapReceiptCategoryToVendorCategory(receipt.category)
            )
            
            // Update vendor spending
            let amount = receipt.isReturn ? -receipt.amount : receipt.amount
            if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == vendor.id }) {
                projectVM.vendorService.vendors[index].totalSpent += amount
                projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
            }
            
            Logger.receiptWorkflow.notice(
                "AI-enhanced vendor sync completed [vendor=\(vendor.name, privacy: .private(mask: .hash)) items=\(analysisResult.items.count, privacy: .public)]"
            )
        }
        
        // Sync payment method to organization's payment method directory
        if !receipt.paymentMethod.isEmpty {
            let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
                name: receipt.paymentMethod,
                type: mapReceiptPaymentMethodToType(receipt.paymentMethod)
            )
            
            // Update payment method spending
            let amount = receipt.isReturn ? -receipt.amount : receipt.amount
            if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
                projectVM.paymentMethodService.paymentMethods[index].totalSpent += amount
                projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
            }
            
            Logger.receiptWorkflow.notice(
                "AI-enhanced payment method sync completed [paymentMethod=\(paymentMethod.displayName, privacy: .private(mask: .hash))]"
            )
        }
        
        Logger.receiptWorkflow.notice(
            "AI-powered receipt data synced to company settings [confidence=\(Int(analysisResult.confidence * 100), privacy: .public)]"
        )
    }
    
    private func mapReceiptCategoryToVendorCategory(_ receiptCategory: ReceiptCategory) -> VendorCategory {
        switch receiptCategory {
        case .material: return .hardware
        case .electrical: return .electrical
        case .plumbing: return .plumbing
        case .paint: return .paint
        case .general: return .other
        case .kitchen: return .other
        case .bathroom: return .other
        case .flooring: return .other
        case .hvac: return .other
        case .demolition: return .other
        case .permits: return .professional
        case .contingency: return .other
        default: return .other
        }
    }
    
    private func mapReceiptPaymentMethodToType(_ paymentMethodName: String) -> PaymentType {
        let lowercased = paymentMethodName.lowercased()
        if lowercased.contains("credit") || lowercased.contains("visa") || lowercased.contains("mastercard") || lowercased.contains("amex") {
            return .creditCard
        } else if lowercased.contains("debit") {
            return .debitCard
        } else if lowercased.contains("cash") {
            return .cash
        } else if lowercased.contains("check") {
            return .check
        } else if lowercased.contains("transfer") || lowercased.contains("bank") {
            return .bankTransfer
        } else {
            return .other
        }
    }

    private func showSuccessMessage(receipt: Receipt) {
        let amountText = String(format: "%.2f", receipt.amount)
        let confidenceText = "\(Int(analysisResult.confidence * 100))%"
        successMessage = "🤖 AI-processed receipt saved!\n\n💰 \(receipt.vendor): $\(amountText)\n📊 Category: \(receipt.category.rawValue)\n🎯 Confidence: \(confidenceText)"
        showingSuccessAlert = true
    }
    
    // Add initializer for backward compatibility
    init(isPresented: Binding<Bool>, 
         project: Project, 
         analysisResult: ReceiptAnalysisResult, 
         scannedImage: UIImage, 
         onReceiptSaved: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.project = project
        self.analysisResult = analysisResult
        self.scannedImage = scannedImage
        self.onReceiptSaved = onReceiptSaved
    }
}

// MARK: - Supporting Views

struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            .navigationTitle("Scanned Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ItemDetailsView: View {
    let items: [ReceiptItemResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name)
                                .font(.headline)
                            Spacer()
                            Text(item.totalPrice.formatAsCurrency())
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Qty: \(Int(item.quantity))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("Unit: \(item.unitPrice.formatAsCurrency())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(item.category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Receipt Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct ScannedReceiptEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,  
            
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        )
        
        let sampleAnalysis = ReceiptAnalysisResult(
            vendor: "Home Depot",
            category: "Materials",
            amount: 127.49,
            taxAmount: 9.56,
            discountAmount: 5.00,
            paymentMethod: "Credit Card",
            receiptNumber: "12345",
            items: [
                ReceiptItemResult(name: "2x4 Lumber", quantity: 10, unitPrice: 3.49, totalPrice: 34.90, category: "Materials"),
                ReceiptItemResult(name: "Wood Screws", quantity: 1, unitPrice: 12.99, totalPrice: 12.99, category: "Materials")
            ],
            isReturn: false,
            confidence: 0.87
        )
        
        ScannedReceiptEntryView(
            isPresented: .constant(true),
            project: sampleProject,
            analysisResult: sampleAnalysis,
            scannedImage: UIImage(systemName: "photo")!,
            onReceiptSaved: nil
        )
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
#endif
