import SwiftUI
import OSLog
import Combine

struct PaymentMethodManagementView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddPaymentMethod = false
    @State private var showingEditPaymentMethod: PaymentMethod? = nil
    @State private var searchText = ""
    @State private var selectedType: PaymentType? = nil
    @State private var showingDeleteAlert = false
    @State private var paymentMethodToDelete: PaymentMethod? = nil
    
    private var paymentMethodService: PaymentMethodManagementService {
        projectViewModel.paymentMethodService
    }
    
    private var filteredPaymentMethods: [PaymentMethod] {
        paymentMethodService.paymentMethods
            .filter { method in
                (searchText.isEmpty || method.name.localizedCaseInsensitiveContains(searchText) || 
                 method.displayName.localizedCaseInsensitiveContains(searchText)) &&
                (selectedType == nil || method.type == selectedType) &&
                method.isActive
            }
            .sorted { $0.totalSpent > $1.totalSpent }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search and filter section
                searchAndFilterSection
                
                // Payment methods list
                paymentMethodsList
            }
            .navigationTitle("Payment Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        showingAddPaymentMethod = true
                    }
                }
            }
            .sheet(isPresented: $showingAddPaymentMethod) {
                AddPaymentMethodServiceView(paymentMethodService: paymentMethodService)
            }
            .sheet(item: $showingEditPaymentMethod) { method in
                EditPaymentMethodServiceView(paymentMethod: method, paymentMethodService: paymentMethodService)
            }
            .alert("Delete Payment Method", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let method = paymentMethodToDelete {
                        deletePaymentMethod(method)
                    }
                }
            } message: {
                if let method = paymentMethodToDelete {
                    Text("Are you sure you want to delete '\(method.displayName)'? This action cannot be undone.")
                }
            }
            .onAppear {
                syncPaymentMethodsWithReceipts()
            }
        }
    }
    
    @ViewBuilder
    private var searchAndFilterSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search payment methods...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Menu("Filter") {
                Button("All Types") {
                    selectedType = nil
                }
                
                Divider()
                
                ForEach(PaymentType.allCases) { type in
                    Button(type.rawValue) {
                        selectedType = type
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var paymentMethodsList: some View {
        if filteredPaymentMethods.isEmpty {
            // Empty state
            VStack(spacing: 20) {
                Image(systemName: "creditcard")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("No Payment Methods")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(searchText.isEmpty ? 
                     "Add payment methods to track your spending across different accounts and cards." :
                     "No payment methods match your search criteria.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if searchText.isEmpty {
                    Button("Add First Payment Method") {
                        showingAddPaymentMethod = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredPaymentMethods) { method in
                    PaymentMethodServiceRowView(paymentMethod: method) {
                        showingEditPaymentMethod = method
                    } onDelete: {
                        paymentMethodToDelete = method
                        showingDeleteAlert = true
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search payment methods...")
        }
    }
    
    private func deletePaymentMethod(_ method: PaymentMethod) {
        paymentMethodService.removePaymentMethod(method)
        paymentMethodToDelete = nil
    }
    
    private func syncPaymentMethodsWithReceipts() {
        // Ensure all payment methods from receipts are properly represented in the service
        // This syncs the data shown in BudgetBreakdownView with PaymentMethodManagementView
        
        guard let project = projectViewModel.selectedProject else { return }
        
        Logger.company.info("Synchronizing payment methods with selected-project receipt data.")
        
        // First, clean up any duplicate payment methods
        paymentMethodService.cleanupDuplicatePaymentMethods()
        
        // Reset all payment method totals to 0 first to recalculate from scratch
        for i in 0..<paymentMethodService.paymentMethods.count {
            paymentMethodService.paymentMethods[i].totalSpent = 0.0
        }
        
        // Group receipts by payment method name to calculate totals
        let receiptsByPaymentMethod = Dictionary(grouping: project.receipts) { receipt in
            receipt.paymentMethod.lowercased().trimmingCharacters(in: .whitespaces)
        }
        
        // Update spending totals for each payment method
        for (paymentMethodName, receipts) in receiptsByPaymentMethod {
            guard !paymentMethodName.isEmpty else { continue }
            
            let totalSpent = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            if totalSpent > 0 {
                // Find or create the payment method (this handles name/nickname matching)
                let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(
                    name: receipts.first?.paymentMethod ?? paymentMethodName,
                    type: determinePaymentType(from: paymentMethodName)
                )
                
                // Update the total spending to match the actual receipt data
                if let index = paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
                    paymentMethodService.paymentMethods[index].totalSpent = totalSpent
                    Logger.company.debug(
                        "Updated payment-method spending from receipts [paymentMethod=\(paymentMethod.id.uuidString, privacy: .private(mask: .hash)), totalSpent=\(totalSpent, privacy: .public)]"
                    )
                }
            }
        }
        
        // Save the updated payment methods
        for i in 0..<paymentMethodService.paymentMethods.count {
            paymentMethodService.savePaymentMethod(paymentMethodService.paymentMethods[i])
        }
        
        Logger.company.notice(
            "Completed payment-method receipt sync [activePaymentMethods=\(paymentMethodService.paymentMethods.filter { $0.totalSpent > 0 }.count, privacy: .public)]"
        )
    }
    
    // Helper function to guess payment type from payment method name
    private func determinePaymentType(from paymentMethodName: String) -> PaymentType {
        let lowercased = paymentMethodName.lowercased()
        
        if lowercased.contains("visa") || lowercased.contains("mastercard") || 
           lowercased.contains("amex") || lowercased.contains("discover") ||
           lowercased.contains("credit") || lowercased.contains("card") {
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
}

// MARK: - Service-Based Row View
struct PaymentMethodServiceRowView: View {
    let paymentMethod: PaymentMethod
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Payment method icon
            Image(systemName: iconForPaymentType(paymentMethod.type))
                .foregroundColor(colorForPaymentType(paymentMethod.type))
                .frame(width: 28, height: 28)
            
            // Payment method details
            VStack(alignment: .leading, spacing: 4) {
                Text(paymentMethod.displayName)
                    .font(.headline)
                
                HStack {
                    Text(paymentMethod.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let brand = paymentMethod.cardBrand {
                        Text("• \(brand.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !paymentMethod.lastFourDigits.isEmpty {
                    Text("•••• \(paymentMethod.lastFourDigits)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show when it was added
                Text("Added \(paymentMethod.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Spending info and actions
            VStack(alignment: .trailing, spacing: 4) {
                Text(paymentMethod.totalSpent.formatAsCurrency())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Total Spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button("Edit") {
                        onEdit()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForPaymentType(_ type: PaymentType) -> String {
        switch type {
        case .creditCard:
            return "creditcard.fill"
        case .debitCard:
            return "creditcard"
        case .cash:
            return "dollarsign.circle.fill"
        case .check:
            return "doc.text.fill"
        case .bankTransfer:
            return "building.columns.fill"
        case .other:
            return "questionmark.circle.fill"
        }
    }
    
    private func colorForPaymentType(_ type: PaymentType) -> Color {
        switch type {
        case .creditCard:
            return .blue
        case .debitCard:
            return .green
        case .cash:
            return .orange
        case .check:
            return .purple
        case .bankTransfer:
            return .indigo
        case .other:
            return .gray
        }
    }
}

// MARK: - Service-Based Add View
struct AddPaymentMethodServiceView: View {
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type = PaymentType.creditCard
    @State private var cardBrand: CardBrand? = nil
    @State private var lastFourDigits = ""
    @State private var nickname = ""
    @State private var accountNumber = ""
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Method Information") {
                    TextField("Payment Method Name", text: $name)
                        .textContentType(.none)
                    
                    Picker("Type", selection: $type) {
                        ForEach(PaymentType.allCases) { paymentType in
                            Label(paymentType.rawValue, systemImage: iconForType(paymentType))
                                .tag(paymentType)
                        }
                    }
                    
                    TextField("Nickname (optional)", text: $nickname)
                        .textContentType(.nickname)
                }
                
                if type == .creditCard || type == .debitCard {
                    Section("Card Information") {
                        Picker("Card Brand", selection: $cardBrand) {
                            Text("Select brand").tag(nil as CardBrand?)
                            ForEach(CardBrand.allCases) { brand in
                                Text(brand.rawValue).tag(brand as CardBrand?)
                            }
                        }
                        
                        TextField("Last 4 Digits", text: $lastFourDigits)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFourDigits) { _, newValue in
                                lastFourDigits = String(newValue.prefix(4))
                            }
                    }
                }
                
                if type == .check || type == .bankTransfer {
                    Section("Account Information") {
                        TextField("Account Number (last 4 digits)", text: $accountNumber)
                            .keyboardType(.numberPad)
                            .onChange(of: accountNumber) { _, newValue in
                                accountNumber = String(newValue.prefix(4))
                            }
                    }
                }
                
                Section {
                    Text("Examples: 'Chase Freedom', 'Wells Fargo Checking', 'Petty Cash'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Examples")
                }
            }
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePaymentMethod()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func savePaymentMethod() {
        let paymentMethod = PaymentMethod(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            cardBrand: cardBrand,
            lastFourDigits: lastFourDigits.trimmingCharacters(in: .whitespaces),
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespaces)
        )
        
        paymentMethodService.savePaymentMethod(paymentMethod)
        dismiss()
    }
    
    private func iconForType(_ type: PaymentType) -> String {
        switch type {
        case .creditCard, .debitCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Service-Based Edit View
struct EditPaymentMethodServiceView: View {
    let paymentMethod: PaymentMethod
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var nickname = ""
    @State private var lastFourDigits = ""
    @State private var accountNumber = ""
    @State private var cardBrand: CardBrand? = nil
    @State private var type: PaymentType = .creditCard
    @State private var isActive = true
    @State private var showingDeleteAlert = false
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Method Information") {
                    TextField("Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(PaymentType.allCases) { paymentType in
                            Label(paymentType.rawValue, systemImage: iconForType(paymentType))
                                .tag(paymentType)
                        }
                    }
                    
                    TextField("Nickname", text: $nickname)
                }
                
                if type == .creditCard || type == .debitCard {
                    Section("Card Information") {
                        Picker("Card Brand", selection: $cardBrand) {
                            Text("Select brand").tag(nil as CardBrand?)
                            ForEach(CardBrand.allCases) { brand in
                                Text(brand.rawValue).tag(brand as CardBrand?)
                            }
                        }
                        
                        TextField("Last 4 Digits", text: $lastFourDigits)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFourDigits) { _, newValue in
                                lastFourDigits = String(newValue.prefix(4))
                            }
                    }
                }
                
                if type == .check || type == .bankTransfer {
                    Section("Account Information") {
                        TextField("Account Number (last 4 digits)", text: $accountNumber)
                            .keyboardType(.numberPad)
                            .onChange(of: accountNumber) { _, newValue in
                                accountNumber = String(newValue.prefix(4))
                            }
                    }
                }
                
                Section("Status") {
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Spent")
                        Spacer()
                        Text(paymentMethod.totalSpent.formatAsCurrency())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date Added")
                        Spacer()
                        Text(paymentMethod.dateAdded, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Delete Payment Method", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Edit Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updatePaymentMethod()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Delete Payment Method", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deletePaymentMethod()
                }
            } message: {
                Text("Are you sure you want to delete '\(paymentMethod.displayName)'? This action cannot be undone.")
            }
            .onAppear {
                name = paymentMethod.name
                nickname = paymentMethod.nickname
                lastFourDigits = paymentMethod.lastFourDigits
                accountNumber = paymentMethod.accountNumber
                cardBrand = paymentMethod.cardBrand
                type = paymentMethod.type
                isActive = paymentMethod.isActive
            }
        }
    }
    
    private func updatePaymentMethod() {
        var updatedPaymentMethod = paymentMethod
        updatedPaymentMethod.name = name.trimmingCharacters(in: .whitespaces)
        updatedPaymentMethod.nickname = nickname.trimmingCharacters(in: .whitespaces)
        updatedPaymentMethod.lastFourDigits = lastFourDigits.trimmingCharacters(in: .whitespaces)
        updatedPaymentMethod.accountNumber = accountNumber.trimmingCharacters(in: .whitespaces)
        updatedPaymentMethod.cardBrand = cardBrand
        updatedPaymentMethod.type = type
        updatedPaymentMethod.isActive = isActive
        
        paymentMethodService.savePaymentMethod(updatedPaymentMethod)
        dismiss()
    }
    
    private func deletePaymentMethod() {
        paymentMethodService.removePaymentMethod(paymentMethod)
        dismiss()
    }
    
    private func iconForType(_ type: PaymentType) -> String {
        switch type {
        case .creditCard, .debitCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

#if DEBUG
struct PaymentMethodManagementView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentMethodManagementView()
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}
#endif
