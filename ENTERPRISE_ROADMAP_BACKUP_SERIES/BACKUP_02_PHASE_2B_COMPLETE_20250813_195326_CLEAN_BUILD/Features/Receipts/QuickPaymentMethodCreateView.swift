import SwiftUI

struct QuickPaymentMethodCreateView: View {
    let onPaymentMethodCreated: (PaymentMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type: PaymentType = .creditCard
    @State private var cardBrand: CardBrand = .visa
    @State private var lastFourDigits = ""
    @State private var nickname = ""
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Payment Method Name", text: $name)
                        .textContentType(.creditCardName)
                    
                    Picker("Type", selection: $type) {
                        ForEach(PaymentType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: paymentIcon(for: type))
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }
                
                if type == .creditCard || type == .debitCard {
                    Section("Card Details") {
                        Picker("Card Brand", selection: $cardBrand) {
                            ForEach(CardBrand.allCases, id: \.self) { brand in
                                Text(brand.rawValue).tag(brand)
                            }
                        }
                        
                        TextField("Last 4 Digits", text: $lastFourDigits)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFourDigits) { _, newValue in
                                // Limit to 4 digits
                                lastFourDigits = String(newValue.prefix(4))
                            }
                    }
                }
                
                Section("Optional") {
                    TextField("Nickname (optional)", text: $nickname)
                        .textContentType(.nickname)
                }
                
                Section {
                    Text("Examples: 'Chase Visa', 'Wells Fargo Checking', 'Personal Cash', etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Tips")
                }
            }
            .navigationTitle("New Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let paymentMethod = PaymentMethod(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: type,
                            cardBrand: (type == .creditCard || type == .debitCard) ? cardBrand : nil,
                            lastFourDigits: lastFourDigits.trimmingCharacters(in: .whitespacesAndNewlines),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onPaymentMethodCreated(paymentMethod)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func paymentIcon(for type: PaymentType) -> String {
        switch type {
        case .creditCard, .debitCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

#Preview {
    QuickPaymentMethodCreateView { paymentMethod in
        print("Created payment method: \(paymentMethod.displayName)")
    }
}