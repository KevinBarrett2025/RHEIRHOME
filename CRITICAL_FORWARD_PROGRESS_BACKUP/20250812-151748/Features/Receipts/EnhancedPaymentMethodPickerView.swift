import SwiftUI

/// Enhanced Payment Method Picker with improved UX, favorites, and smart suggestions
struct EnhancedPaymentMethodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPaymentMethod: PaymentMethod?
    @ObservedObject var paymentMethodService: PaymentMethodManagementService
    let onSelection: (PaymentMethod) -> Void
    
    @State private var searchText = ""
    @State private var showingAddPaymentMethod = false
    @State private var selectedTab: PaymentTab = .favorites
    @State private var newPaymentMethodName = ""
    @State private var newPaymentMethodType: PaymentType = .creditCard
    @State private var newCardBrand: CardBrand? = nil
    @State private var showingCardBrandPicker = false
    
    enum PaymentTab: String, CaseIterable {
        case favorites = "Favorites"
        case recent = "Recent"
        case all = "All"
        case add = "Add New"
        
        var icon: String {
            switch self {
            case .favorites: return "star.fill"
            case .recent: return "clock.fill"
            case .all: return "creditcard.fill"
            case .add: return "plus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .favorites: return .yellow
            case .recent: return .blue
            case .all: return .green
            case .add: return .purple
            }
        }
    }
    
    private var favoritePaymentMethods: [PaymentMethod] {
        paymentMethodService.paymentMethodsSortedBySpending.prefix(3).map { $0 }
    }
    
    private var recentPaymentMethods: [PaymentMethod] {
        paymentMethodService.paymentMethodsSortedByName.filter { 
            $0.totalSpent > 0 
        }.prefix(5).map { $0 }
    }
    
    private var filteredPaymentMethods: [PaymentMethod] {
        let methods = paymentMethodService.paymentMethodsSortedByName
        
        if searchText.isEmpty {
            return methods
        } else {
            return methods.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.nickname.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        tabContent
                    }
                    .padding()
                }
            }
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add New") {
                        selectedTab = .add
                    }
                    .foregroundColor(.purple)
                }
            }
        }
        .sheet(isPresented: $showingCardBrandPicker) {
            CardBrandPickerView(selectedBrand: $newCardBrand)
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
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
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PaymentTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                            
                            // Show counts
                            if tab == .favorites {
                                Text("(\(favoritePaymentMethods.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if tab == .recent {
                                Text("(\(recentPaymentMethods.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if tab == .all {
                                Text("(\(paymentMethodService.paymentMethods.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : tab.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? tab.color : tab.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .favorites:
            favoritesContent
        case .recent:
            recentContent
        case .all:
            allPaymentMethodsContent
        case .add:
            addNewPaymentMethodContent
        }
    }
    
    @ViewBuilder
    private var favoritesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Most Used Payment Methods")
                .font(.headline)
                .foregroundColor(.yellow)
            
            if favoritePaymentMethods.isEmpty {
                EmptyStateView(
                    icon: "star", 
                    title: "No Favorites Yet", 
                    subtitle: "Your most used payment methods will appear here"
                )
            } else {
                ForEach(favoritePaymentMethods, id: \.id) { method in
                    EnhancedPaymentMethodRow(
                        paymentMethod: method,
                        isSelected: selectedPaymentMethod?.id == method.id,
                        showUsageStats: true,
                        onTap: {
                            selectPaymentMethod(method)
                        }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Used Payment Methods")
                .font(.headline)
                .foregroundColor(.blue)
            
            if recentPaymentMethods.isEmpty {
                EmptyStateView(
                    icon: "clock", 
                    title: "No Recent Activity", 
                    subtitle: "Payment methods you've used recently will appear here"
                )
            } else {
                ForEach(recentPaymentMethods, id: \.id) { method in
                    EnhancedPaymentMethodRow(
                        paymentMethod: method,
                        isSelected: selectedPaymentMethod?.id == method.id,
                        showUsageStats: true,
                        onTap: {
                            selectPaymentMethod(method)
                        }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var allPaymentMethodsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Payment Methods")
                .font(.headline)
                .foregroundColor(.green)
            
            if !searchText.isEmpty && !paymentMethodExists(searchText) {
                QuickAddPaymentMethodCard(name: searchText) {
                    addNewPaymentMethod(name: searchText)
                }
            }
            
            ForEach(filteredPaymentMethods, id: \.id) { method in
                EnhancedPaymentMethodRow(
                    paymentMethod: method,
                    isSelected: selectedPaymentMethod?.id == method.id,
                    showUsageStats: false,
                    onTap: {
                        selectPaymentMethod(method)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var addNewPaymentMethodContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add New Payment Method")
                .font(.headline)
                .foregroundColor(.purple)
            
            // Quick add buttons for common types
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Add")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(PaymentType.allCases.prefix(6), id: \.self) { type in
                        QuickAddTypeButton(type: type) {
                            quickAddPaymentMethod(type: type)
                        }
                    }
                }
            }
            
            Divider()
            
            // Custom add form
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Payment Method")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Name")
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("Enter payment method name", text: $newPaymentMethodName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Type")
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("Type", selection: $newPaymentMethodType) {
                            ForEach(PaymentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if newPaymentMethodType == .creditCard || newPaymentMethodType == .debitCard {
                        HStack {
                            Text("Brand")
                                .font(.subheadline)
                                .frame(width: 80, alignment: .leading)
                            
                            Button(newCardBrand?.displayName ?? "Select Brand") {
                                showingCardBrandPicker = true
                            }
                            .foregroundColor(.blue)
                            
                            Spacer()
                        }
                    }
                    
                    Button("Add Payment Method") {
                        addCustomPaymentMethod()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPaymentMethodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func selectPaymentMethod(_ method: PaymentMethod) {
        selectedPaymentMethod = method
        onSelection(method)
        dismiss()
    }
    
    private func paymentMethodExists(_ name: String) -> Bool {
        return paymentMethodService.paymentMethods.contains { 
            $0.name.lowercased() == name.lowercased() ||
            $0.displayName.lowercased() == name.lowercased() ||
            $0.nickname.lowercased() == name.lowercased()
        }
    }
    
    private func addNewPaymentMethod(name: String, type: PaymentType = .other) {
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(name: name, type: type)
        selectPaymentMethod(paymentMethod)
    }
    
    private func quickAddPaymentMethod(type: PaymentType) {
        newPaymentMethodType = type
        newPaymentMethodName = ""
        newCardBrand = nil
        
        // Set a default name based on type
        switch type {
        case .cash:
            newPaymentMethodName = "Cash"
        case .creditCard:
            newPaymentMethodName = "Credit Card"
        case .debitCard:
            newPaymentMethodName = "Debit Card"
        case .check:
            newPaymentMethodName = "Check"
        case .bankTransfer:
            newPaymentMethodName = "Bank Transfer"
        case .digitalWallet:
            newPaymentMethodName = "Digital Wallet"
        case .other:
            newPaymentMethodName = "Other"
        }
        
        addCustomPaymentMethod()
    }
    
    private func addCustomPaymentMethod() {
        guard !newPaymentMethodName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let paymentMethod = PaymentMethod(
            name: newPaymentMethodName,
            type: newPaymentMethodType,
            cardBrand: newCardBrand,
            nickname: newPaymentMethodName
        )
        
        paymentMethodService.savePaymentMethod(paymentMethod)
        selectPaymentMethod(paymentMethod)
    }
}

// MARK: - Supporting Views

struct EnhancedPaymentMethodRow: View {
    let paymentMethod: PaymentMethod
    let isSelected: Bool
    let showUsageStats: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Payment method icon
                PaymentMethodIcon(
                    type: paymentMethod.type,
                    cardBrand: paymentMethod.cardBrand
                )
                .frame(width: 40, height: 40)
                
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
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(paymentMethod.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if showUsageStats && paymentMethod.totalSpent > 0 {
                        Text("Total spent: \(paymentMethod.totalSpent.formatAsCurrency())")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PaymentMethodIcon: View {
    let type: PaymentType
    let cardBrand: CardBrand?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor.opacity(0.2))
            
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
        }
    }
    
    private var iconName: String {
        if let brand = cardBrand {
            switch brand {
            case .visa: return "creditcard.fill"
            case .mastercard: return "creditcard.fill"
            case .americanExpress: return "creditcard.fill"
            case .discover: return "creditcard.fill"
            case .chase: return "building.columns.fill"
            case .wellsFargo: return "building.columns.fill"
            case .bankOfAmerica: return "building.columns.fill"
            case .citi: return "building.columns.fill"
            case .capital: return "building.columns.fill"
            }
        }
        
        switch type {
        case .cash: return "dollarsign.circle.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .digitalWallet: return "iphone"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        if let brand = cardBrand {
            switch brand {
            case .visa: return .blue
            case .mastercard: return .red
            case .americanExpress: return .green
            case .discover: return .orange
            case .chase: return .blue
            case .wellsFargo: return .red
            case .bankOfAmerica: return .red
            case .citi: return .blue
            case .capital: return .red
            }
        }
        
        switch type {
        case .cash: return .green
        case .creditCard: return .blue
        case .debitCard: return .purple
        case .check: return .orange
        case .bankTransfer: return .blue
        case .digitalWallet: return .purple
        case .other: return .gray
        }
    }
}

struct QuickAddPaymentMethodCard: View {
    let name: String
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add '\(name)'")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Quick add as new payment method")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickAddTypeButton: View {
    let type: PaymentType
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                PaymentMethodIcon(type: type, cardBrand: nil)
                    .frame(width: 32, height: 32)
                
                Text(type.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct CardBrandPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedBrand: CardBrand?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(CardBrand.allCases, id: \.rawValue) { brand in
                    Button {
                        selectedBrand = brand
                        dismiss()
                    } label: {
                        HStack {
                            PaymentMethodIcon(type: .creditCard, cardBrand: brand)
                                .frame(width: 32, height: 32)
                            
                            Text(brand.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedBrand == brand {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Card Brand")
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

// MARK: - Extensions

extension CardBrand {
    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .americanExpress: return "American Express"
        case .discover: return "Discover"
        case .chase: return "Chase"
        case .wellsFargo: return "Wells Fargo"
        case .bankOfAmerica: return "Bank of America"
        case .citi: return "Citi"
        case .capital: return "Capital One"
        }
    }
    
    static var allCases: [CardBrand] {
        return [.visa, .mastercard, .americanExpress, .discover, .chase, .wellsFargo, .bankOfAmerica, .citi, .capital]
    }
}

#Preview {
    EnhancedPaymentMethodPickerView(
        selectedPaymentMethod: .constant(nil),
        paymentMethodService: PaymentMethodManagementService(),
        onSelection: { _ in }
    )
}