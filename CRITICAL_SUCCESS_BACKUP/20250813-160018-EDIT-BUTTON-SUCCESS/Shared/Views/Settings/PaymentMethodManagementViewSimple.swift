import SwiftUI

struct PaymentMethodManagementViewSimple: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var showingAddMethod = false
    @State private var searchText = ""
    
    private var filteredPaymentMethods: [PaymentMethod] {
        if searchText.isEmpty {
            return paymentMethods.sorted { $0.displayName < $1.displayName }
        } else {
            return paymentMethods.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.type.rawValue.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.displayName < $1.displayName }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if paymentMethods.isEmpty {
                    ContentUnavailableView(
                        "No Payment Methods",
                        systemImage: "creditcard.circle",
                        description: Text("Add payment methods to track spending and categorize receipts.")
                    )
                } else {
                    List {
                        ForEach(filteredPaymentMethods) { method in
                            PaymentMethodRow(paymentMethod: method) {
                                updatePaymentMethod($0)
                            }
                        }
                        .onDelete(perform: deletePaymentMethods)
                    }
                    .searchable(text: $searchText, prompt: "Search payment methods...")
                }
            }
            .navigationTitle("Payment Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Payment Method") {
                        showingAddMethod = true
                    }
                }
            }
            .sheet(isPresented: $showingAddMethod) {
                AddPaymentMethodViewSimple { method in
                    addPaymentMethod(method)
                }
            }
            .onAppear {
                loadPaymentMethods()
            }
        }
    }
    
    // MARK: - Data Management
    
    private func loadPaymentMethods() {
        guard let orgId = authViewModel.currentOrg?.id else { return }
        
        if let data = UserDefaults.standard.data(forKey: "paymentMethods_\(orgId)"),
           let loadedMethods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
            paymentMethods = loadedMethods.filter { $0.isActive }
        }
    }
    
    private func savePaymentMethods() {
        guard let orgId = authViewModel.currentOrg?.id else { return }
        
        if let data = try? JSONEncoder().encode(paymentMethods) {
            UserDefaults.standard.set(data, forKey: "paymentMethods_\(orgId)")
        }
    }
    
    private func addPaymentMethod(_ method: PaymentMethod) {
        paymentMethods.append(method)
        savePaymentMethods()
    }
    
    private func deletePaymentMethod(_ method: PaymentMethod) {
        paymentMethods.removeAll { $0.id == method.id }
        savePaymentMethods()
    }
    
    private func updatePaymentMethod(_ method: PaymentMethod) {
        if let index = paymentMethods.firstIndex(where: { $0.id == method.id }) {
            paymentMethods[index] = method
            savePaymentMethods()
        }
    }
    
    private func deletePaymentMethods(at offsets: IndexSet) {
        let methodsToDelete = offsets.map { filteredPaymentMethods[$0] }
        
        for method in methodsToDelete {
            deletePaymentMethod(method)
        }
    }
}

struct PaymentMethodRow: View {
    let paymentMethod: PaymentMethod
    let onUpdate: (PaymentMethod) -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(paymentMethod.displayName)
                        .font(.headline)
                    
                    Text(paymentMethod.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let brand = paymentMethod.cardBrand {
                        Text(brand.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if paymentMethod.totalSpent > 0 {
                        Text(paymentMethod.totalSpent, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    if !paymentMethod.lastFourDigits.isEmpty {
                        Text("•••• \(paymentMethod.lastFourDigits)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditPaymentMethodViewSimple(paymentMethod: paymentMethod) { updatedMethod in
                onUpdate(updatedMethod)
            }
        }
    }
}

struct AddPaymentMethodViewSimple: View {
    let onSave: (PaymentMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type = PaymentType.creditCard
    @State private var cardBrand: CardBrand? = nil
    @State private var lastFourDigits = ""
    @State private var nickname = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Payment Method Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(PaymentType.allCases) { paymentType in
                            Text(paymentType.rawValue).tag(paymentType)
                        }
                    }
                }
                
                if type == .creditCard || type == .debitCard {
                    Section("Card Information") {
                        Picker("Card Brand", selection: $cardBrand) {
                            Text("Select brand...").tag(nil as CardBrand?)
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
                
                Section("Additional") {
                    TextField("Nickname (optional)", text: $nickname)
                        .textContentType(.none)
                }
            }
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let method = PaymentMethod(
                            name: name.trimmingCharacters(in: .whitespaces),
                            type: type,
                            cardBrand: cardBrand,
                            lastFourDigits: lastFourDigits.trimmingCharacters(in: .whitespaces),
                            nickname: nickname.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(method)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct EditPaymentMethodViewSimple: View {
    let paymentMethod: PaymentMethod
    let onSave: (PaymentMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var nickname: String
    @State private var isActive: Bool
    
    init(paymentMethod: PaymentMethod, onSave: @escaping (PaymentMethod) -> Void) {
        self.paymentMethod = paymentMethod
        self.onSave = onSave
        
        _name = State(initialValue: paymentMethod.name)
        _nickname = State(initialValue: paymentMethod.nickname)
        _isActive = State(initialValue: paymentMethod.isActive)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Nickname", text: $nickname)
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Payment Details") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(paymentMethod.type.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    if let brand = paymentMethod.cardBrand {
                        HStack {
                            Text("Card Brand")
                            Spacer()
                            Text(brand.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !paymentMethod.lastFourDigits.isEmpty {
                        HStack {
                            Text("Last 4 Digits")
                            Spacer()
                            Text(paymentMethod.lastFourDigits)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if paymentMethod.totalSpent > 0 {
                    Section("Spending History") {
                        HStack {
                            Text("Total Spent")
                            Spacer()
                            Text(paymentMethod.totalSpent, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }
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
                        var updatedMethod = paymentMethod
                        updatedMethod.name = name.trimmingCharacters(in: .whitespaces)
                        updatedMethod.nickname = nickname.trimmingCharacters(in: .whitespaces)
                        updatedMethod.isActive = isActive
                        
                        onSave(updatedMethod)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct PaymentMethodManagementViewSimple_Previews: PreviewProvider {
    static var previews: some View {
        PaymentMethodManagementViewSimple()
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
#endif
