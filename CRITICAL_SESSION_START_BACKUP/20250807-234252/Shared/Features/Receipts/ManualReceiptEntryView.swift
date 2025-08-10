import SwiftUI

// MARK: - Inline Simple Vendor Picker
struct SimpleVendorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedVendor: Vendor?
    @ObservedObject var vendorService: VendorManagementService
    let onSelection: (Vendor) -> Void
    
    @State private var searchText = ""
    @State private var showingAddNew = false
    @State private var newVendorName = ""
    @State private var newVendorCategory: VendorCategory = .other
    
    private var filteredVendors: [Vendor] {
        let vendors = vendorService.vendorsSortedByName
        
        if searchText.isEmpty {
            return vendors
        } else {
            return vendors.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var canCreateNew: Bool {
        !searchText.isEmpty && !vendorExists(searchText)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Add Section - Always visible at the top
                Section {
                    Button(action: {
                        showingAddNew = true
                    }) {
                        Label("Add New Vendor", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                    .listRowBackground(Color.blue.opacity(0.1))
                }
                
                // Search section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search vendors", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    
                    // Quick create from search
                    if canCreateNew {
                        Button("Add '\(searchText)' as new vendor") {
                            quickAddVendor(name: searchText)
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    }
                }
                
                // Recently Used / Favorites (top 5 most spent)
                if searchText.isEmpty {
                    let topVendors = vendorService.getTopVendors(limit: 5)
                    if !topVendors.isEmpty {
                        Section("Most Used") {
                            ForEach(topVendors) { vendor in
                                VendorPickerRowView(
                                    vendor: vendor,
                                    isSelected: selectedVendor?.id == vendor.id,
                                    showSpending: true
                                ) {
                                    selectVendor(vendor)
                                }
                            }
                        }
                    }
                }
                
                // All vendors
                if !filteredVendors.isEmpty {
                    Section(searchText.isEmpty ? "All Vendors" : "Search Results") {
                        ForEach(filteredVendors) { vendor in
                            VendorPickerRowView(
                                vendor: vendor,
                                isSelected: selectedVendor?.id == vendor.id,
                                showSpending: searchText.isEmpty
                            ) {
                                selectVendor(vendor)
                            }
                        }
                    }
                }
                
                // Empty state
                if filteredVendors.isEmpty && !searchText.isEmpty && !canCreateNew {
                    Section {
                        Text("No vendors found")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Select Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search vendors")
            .sheet(isPresented: $showingAddNew) {
                AddVendorFormView(
                    vendorName: $newVendorName,
                    vendorCategory: $newVendorCategory,
                    vendorService: vendorService,
                    onAdd: { vendor in
                        selectVendor(vendor)
                        showingAddNew = false
                    },
                    onCancel: {
                        showingAddNew = false
                        newVendorName = ""
                        newVendorCategory = .other
                    }
                )
            }
        }
    }
    
    private func vendorExists(_ name: String) -> Bool {
        return vendorService.vendors.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    private func selectVendor(_ vendor: Vendor) {
        selectedVendor = vendor
        onSelection(vendor)
        dismiss()
    }
    
    private func quickAddVendor(name: String) {
        let vendor = vendorService.findOrCreateVendor(name: name, category: .other)
        selectVendor(vendor)
    }
}

// MARK: - Vendor Row Component
struct VendorPickerRowView: View {
    let vendor: Vendor
    let isSelected: Bool
    let showSpending: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(vendor.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if showSpending && vendor.totalSpent > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(vendor.totalSpent.formatAsCurrency())
                                .font(.caption)
                                .foregroundColor(.green)
                        }
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

// MARK: - Add Vendor Form
struct AddVendorFormView: View {
    @Binding var vendorName: String
    @Binding var vendorCategory: VendorCategory
    @ObservedObject var vendorService: VendorManagementService
    let onAdd: (Vendor) -> Void
    let onCancel: () -> Void
    
    private var isValidForm: Bool {
        !vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vendor Information") {
                    TextField("Vendor Name", text: $vendorName)
                        .textFieldStyle(.plain)
                    
                    Picker("Category", selection: $vendorCategory) {
                        ForEach(VendorCategory.allCases) { category in
                            Label(category.rawValue, systemImage: categoryIcon(for: category))
                                .tag(category)
                        }
                    }
                }
                
                Section {
                    Text("The vendor will be added to your organization's vendor directory and can be used for future receipts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addVendor()
                    }
                    .disabled(!isValidForm)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addVendor() {
        let cleanName = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let vendor = vendorService.findOrCreateVendor(name: cleanName, category: vendorCategory)
        onAdd(vendor)
    }
    
    private func categoryIcon(for category: VendorCategory) -> String {
        switch category {
        case .hardware: return "hammer.fill"
        case .lumber: return "tree.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .paint: return "paintbrush.fill"
        case .rental: return "wrench.and.screwdriver.fill"
        case .grocery: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .gas: return "fuelpump.fill"
        case .automotive: return "car.fill"
        case .professional: return "briefcase.fill"
        case .office: return "folder.fill"
        case .other: return "building.2.fill"
        }
    }
}

// MARK: - Inline Simple Payment Method Picker
struct SimplePaymentMethodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPaymentMethod: PaymentMethod?
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    let onSelection: (PaymentMethod) -> Void
    
    @State private var searchText = ""
    @State private var showingAddNew = false
    @State private var newMethodName = ""
    @State private var newMethodType: PaymentType = .creditCard
    @State private var newMethodNickname = ""
    
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
    
    private var canCreateNew: Bool {
        !searchText.isEmpty && !paymentMethodExists(searchText)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Add Section - Always visible at the top
                Section {
                    Button(action: {
                        showingAddNew = true
                    }) {
                        Label("Add New Payment Method", systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                    .listRowBackground(Color.green.opacity(0.1))
                }
                
                // Search section
                Section {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.secondary)
                        TextField("Search payment methods", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    
                    // Quick create from search
                    if canCreateNew {
                        Button("Add '\(searchText)' as new payment method") {
                            quickAddPaymentMethod(name: searchText)
                        }
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    }
                }
                
                // Recently Used / Favorites (top 5 most spent)
                if searchText.isEmpty {
                    let topMethods = paymentMethodService.getTopPaymentMethods(limit: 5)
                    if !topMethods.isEmpty {
                        Section("Most Used") {
                            ForEach(topMethods) { paymentMethod in
                                PaymentMethodPickerRowView(
                                    paymentMethod: paymentMethod,
                                    isSelected: selectedPaymentMethod?.id == paymentMethod.id,
                                    showSpending: true
                                ) {
                                    selectPaymentMethod(paymentMethod)
                                }
                            }
                        }
                    }
                }
                
                // All payment methods
                if !filteredPaymentMethods.isEmpty {
                    Section(searchText.isEmpty ? "All Payment Methods" : "Search Results") {
                        ForEach(filteredPaymentMethods) { paymentMethod in
                            PaymentMethodPickerRowView(
                                paymentMethod: paymentMethod,
                                isSelected: selectedPaymentMethod?.id == paymentMethod.id,
                                showSpending: searchText.isEmpty
                            ) {
                                selectPaymentMethod(paymentMethod)
                            }
                        }
                    }
                }
                
                // Empty state
                if filteredPaymentMethods.isEmpty && !searchText.isEmpty && !canCreateNew {
                    Section {
                        Text("No payment methods found")
                            .foregroundColor(.secondary)
                            .italic()
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
            .sheet(isPresented: $showingAddNew) {
                AddPaymentMethodFormView(
                    methodName: $newMethodName,
                    methodType: $newMethodType,
                    methodNickname: $newMethodNickname,
                    paymentMethodService: paymentMethodService,
                    onAdd: { paymentMethod in
                        selectPaymentMethod(paymentMethod)
                        showingAddNew = false
                    },
                    onCancel: {
                        showingAddNew = false
                        newMethodName = ""
                        newMethodType = .creditCard
                        newMethodNickname = ""
                    }
                )
            }
        }
    }
    
    private func paymentMethodExists(_ name: String) -> Bool {
        return paymentMethodService.paymentMethods.contains { 
            $0.name.lowercased() == name.lowercased() ||
            $0.displayName.lowercased() == name.lowercased()
        }
    }
    
    private func selectPaymentMethod(_ paymentMethod: PaymentMethod) {
        selectedPaymentMethod = paymentMethod
        onSelection(paymentMethod)
        dismiss()
    }
    
    private func quickAddPaymentMethod(name: String) {
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(name: name, type: .other)
        selectPaymentMethod(paymentMethod)
    }
}

// MARK: - Payment Method Row Component
struct PaymentMethodPickerRowView: View {
    let paymentMethod: PaymentMethod
    let isSelected: Bool
    let showSpending: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(paymentMethod.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(paymentMethod.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !paymentMethod.nickname.isEmpty && paymentMethod.nickname != paymentMethod.name {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(paymentMethod.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if showSpending && paymentMethod.totalSpent > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(paymentMethod.totalSpent.formatAsCurrency())
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Payment Method Form
struct AddPaymentMethodFormView: View {
    @Binding var methodName: String
    @Binding var methodType: PaymentType
    @Binding var methodNickname: String
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    let onAdd: (PaymentMethod) -> Void
    let onCancel: () -> Void
    
    private var isValidForm: Bool {
        !methodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Payment Method Information") {
                    TextField("Payment Method Name", text: $methodName)
                        .textFieldStyle(.plain)
                    
                    TextField("Nickname (Optional)", text: $methodNickname)
                        .textFieldStyle(.plain)
                    
                    Picker("Type", selection: $methodType) {
                        ForEach(PaymentType.allCases) { type in
                            Label(type.rawValue, systemImage: typeIcon(for: type))
                                .tag(type)
                        }
                    }
                }
                
                Section {
                    Text("The payment method will be added to your organization's directory and can be used for future receipts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPaymentMethod()
                    }
                    .disabled(!isValidForm)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addPaymentMethod() {
        let cleanName = methodName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNickname = methodNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let paymentMethod = PaymentMethod(
            name: cleanName,
            type: methodType,
            nickname: cleanNickname.isEmpty ? cleanName : cleanNickname
        )
        
        paymentMethodService.savePaymentMethod(paymentMethod)
        onAdd(paymentMethod)
    }
    
    private func typeIcon(for type: PaymentType) -> String {
        switch type {
        case .creditCard, .debitCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Manual Receipt Entry View
struct ManualReceiptEntryView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    let project: Project
    
    // Vendor and Payment Method Selection
    @State private var selectedVendor: Vendor?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    
    @State private var vendor = ""
    @State private var amount = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var category: ReceiptCategory = .material
    @State private var paymentMethod = ""
    @State private var receiptNumber = ""
    @State private var taxAmount = ""
    @State private var discountAmount = ""
    @State private var isReturn = false
    
    private var isValidForm: Bool {
        !vendor.isEmpty && !amount.isEmpty && (Double(amount) ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Details") {
                    // Vendor Selection
                    Button(action: {
                        showingVendorPicker = true
                    }) {
                        HStack {
                            Text("Vendor")
                                .foregroundColor(.primary)
                            Spacer()
                            if let selectedVendor = selectedVendor {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(selectedVendor.name)
                                        .foregroundColor(.blue)
                                    Text(selectedVendor.category.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if !vendor.isEmpty {
                                Text(vendor)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Select Vendor")
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ReceiptCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    
                    Toggle("Return/Refund", isOn: $isReturn)
                }
                
                Section("Payment Details") {
                    // Payment Method Selection
                    Button(action: {
                        showingPaymentMethodPicker = true
                    }) {
                        HStack {
                            Text("Payment Method")
                                .foregroundColor(.primary)
                            Spacer()
                            if let selectedPaymentMethod = selectedPaymentMethod {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(selectedPaymentMethod.displayName)
                                        .foregroundColor(.blue)
                                    Text(selectedPaymentMethod.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if !paymentMethod.isEmpty {
                                Text(paymentMethod)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Select Payment Method")
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                    
                    HStack {
                        Text("Discount Amount")
                        Spacer()
                        TextField("0.00", text: $discountAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!isValidForm)
                }
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
        }
    }
    
    private func saveReceipt() {
        // Use selected vendor name, fallback to manual entry
        let vendorName = selectedVendor?.name ?? vendor
        let paymentMethodName = selectedPaymentMethod?.displayName ?? paymentMethod
        
        let receipt = Receipt(
            vendor: vendorName,
            vendorID: selectedVendor?.id,
            date: date,
            amount: Double(amount) ?? 0,
            notes: notes,
            category: category,
            isReturn: isReturn,
            paymentMethod: paymentMethodName,
            paymentMethodID: selectedPaymentMethod?.id,
            taxAmount: Double(taxAmount) ?? 0,
            discountAmount: Double(discountAmount) ?? 0,
            receiptNumber: receiptNumber
        )
        
        // Use the proper ProjectViewModel method
        projectVM.addReceipt(receipt)
        
        isPresented = false
    }
}

struct ManualReceiptEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            profit: 0,
            startDate: Date(),
            endDate: Date()
        )
        
        ManualReceiptEntryView(isPresented: .constant(true), project: sampleProject)
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}