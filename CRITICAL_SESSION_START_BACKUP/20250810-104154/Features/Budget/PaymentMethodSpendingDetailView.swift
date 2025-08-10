import SwiftUI

struct PaymentMethodSpendingDetailView: View {
    let paymentMethodID: UUID
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    private var paymentMethod: PaymentMethod? {
        getLocalPaymentMethods().first { $0.id == paymentMethodID }
    }
    
    private var paymentReceipts: [Receipt] {
        project.receipts.filter { receipt in
            receipt.paymentMethodID == paymentMethodID || 
            (paymentMethod != nil && (
                receipt.paymentMethod.lowercased() == paymentMethod!.name.lowercased() ||
                receipt.paymentMethod.lowercased() == paymentMethod!.displayName.lowercased()
            ))
        }
    }
    
    private var totalSpent: Double {
        paymentReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let paymentMethod = paymentMethod {
                        paymentMethodHeaderSection(paymentMethod)
                        
                        spendingSummarySection
                        
                        receiptsListSection
                    } else {
                        Text("Payment method not found")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Payment Details")
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
    
    @ViewBuilder
    private func paymentMethodHeaderSection(_ paymentMethod: PaymentMethod) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: paymentIcon(for: paymentMethod.type))
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(paymentMethod.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(paymentMethod.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if paymentMethod.type == .creditCard || paymentMethod.type == .debitCard {
                if let cardBrand = paymentMethod.cardBrand {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.secondary)
                        Text(cardBrand.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if !paymentMethod.lastFourDigits.isEmpty {
                            Text("•••• \(paymentMethod.lastFourDigits)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            
            if !paymentMethod.nickname.isEmpty && paymentMethod.nickname != paymentMethod.name {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.secondary)
                    Text(paymentMethod.nickname)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var spendingSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Project Spending Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Total Spent", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalSpent >= 0 ? .primary : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Transactions", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(paymentReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Category breakdown
            if !paymentReceipts.isEmpty {
                let categoryBreakdown = calculateCategoryBreakdown()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending by Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(categoryBreakdown, id: \.category) { item in
                        HStack {
                            Text(item.category.rawValue)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(item.amount.formatAsCurrency())
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("(\(item.receiptCount))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Monthly breakdown (if more than 2 months of data)
            if !paymentReceipts.isEmpty {
                let monthlyBreakdown = calculateMonthlyBreakdown()
                if monthlyBreakdown.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Spending")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(monthlyBreakdown.prefix(6), id: \.month) { item in
                            HStack {
                                Text(item.month)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text(item.amount.formatAsCurrency())
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("(\(item.transactionCount))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if paymentReceipts.isEmpty {
                Text("No transactions found for this payment method")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(paymentReceipts.sorted { $0.date > $1.date }) { receipt in
                        PaymentReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateCategoryBreakdown() -> [CategorySpendingItem] {
        let grouped = Dictionary(grouping: paymentReceipts) { $0.category }
        
        return grouped.map { category, receipts in
            let amount = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            return CategorySpendingItem(
                category: category,
                amount: amount,
                receiptCount: receipts.count
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    private func calculateMonthlyBreakdown() -> [MonthlySpendingItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        let grouped = Dictionary(grouping: paymentReceipts) { receipt in
            formatter.string(from: receipt.date)
        }
        
        return grouped.map { month, receipts in
            let amount = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            return MonthlySpendingItem(
                month: month,
                amount: amount,
                transactionCount: receipts.count
            )
        }.sorted { $0.month > $1.month }
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
    
    private func getLocalPaymentMethods() -> [PaymentMethod] {
        if let data = UserDefaults.standard.data(forKey: "paymentMethods_org_primary"),
           let paymentMethods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
            return paymentMethods
        }
        return []
    }
}

struct MonthlySpendingItem {
    let month: String
    let amount: Double
    let transactionCount: Int
}

struct PaymentReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(receipt.vendor)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if receipt.isReturn {
                        Text("RETURN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !receipt.notes.isEmpty {
                    Text(receipt.notes)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                } else if !receipt.items.isEmpty {
                    Text(receipt.items.map { $0.name }.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(receipt.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !receipt.receiptNumber.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Receipt #\(receipt.receiptNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(receipt.isReturn ? .red : .primary)
                
                if receipt.taxAmount > 0 {
                    Text("Tax: \(receipt.taxAmount.formatAsCurrency())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    PaymentMethodSpendingDetailView(
        paymentMethodID: UUID(),
        project: Project(
            name: "Sample Project",
            client: "Sample Client",
            totalBudget: 10000,
            materialCost: 5000,
            laborCost: 3000,
            generalConditions: 1000,
            contingency: 1000,
            profit: 0,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30)
        )
    )
}