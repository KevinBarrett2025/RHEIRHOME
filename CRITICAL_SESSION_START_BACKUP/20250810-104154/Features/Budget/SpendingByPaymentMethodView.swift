import SwiftUI

struct SpendingByPaymentMethodView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingPaymentDetails = false
    @State private var showingPaymentMethodManagement = false
    @State private var selectedPaymentMethodID: UUID? = nil
    @State private var searchText = ""
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    private var paymentSpending: [PaymentMethodSpendingItem] {
        guard let project = project else { return [] }
        return calculatePaymentMethodSpending(for: project)
    }
    
    private var filteredPaymentSpending: [PaymentMethodSpendingItem] {
        if searchText.isEmpty {
            return paymentSpending
        } else {
            return paymentSpending.filter {
                $0.paymentMethod.name.localizedCaseInsensitiveContains(searchText) ||
                $0.paymentMethod.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var totalSpent: Double {
        paymentSpending.reduce(0) { $0 + $1.totalSpent }
    }
    
    var body: some View {
        if let project = project {
            NavigationView {
                VStack(spacing: 0) {
                    headerSection
                    
                    if paymentSpending.isEmpty {
                        emptyStateView
                    } else {
                        paymentMethodListSection
                    }
                }
                .searchable(text: $searchText, prompt: "Search payment methods...")
                .navigationTitle("Spending by Payment Method")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Manage") {
                            showingPaymentMethodManagement = true
                        }
                        .font(.subheadline)
                    }
                }
                .sheet(isPresented: $showingPaymentDetails) {
                    if let paymentMethodID = selectedPaymentMethodID,
                       let orgId = authVM.currentOrg?.id {
                        SimplePaymentMethodDetailView(
                            paymentMethodID: paymentMethodID,
                            project: project,
                            organizationId: orgId
                        )
                        .environmentObject(projectVM)
                    }
                }
                .sheet(isPresented: $showingPaymentMethodManagement) {
                    PaymentMethodManagementView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                }
            }
        } else {
            emptyProjectView
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Project info
            if let project = project {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Client: \(project.client)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Summary stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Payment Methods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(paymentSpending.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
    
    @ViewBuilder
    private var paymentMethodListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPaymentSpending, id: \.paymentMethod.id) { item in
                    PaymentMethodSpendingRowView(
                        paymentMethod: item.paymentMethod,
                        totalSpent: item.totalSpent,
                        receiptCount: item.receiptCount,
                        percentage: totalSpent > 0 ? item.totalSpent / totalSpent : 0
                    ) {
                        selectedPaymentMethodID = item.paymentMethod.id
                        showingPaymentDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Payment Method Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Receipt spending will appear here organized by payment method.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view payment method spending analysis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func calculatePaymentMethodSpending(for project: Project) -> [PaymentMethodSpendingItem] {
        // Group receipts by payment method name to calculate totals
        let receiptsByPaymentMethod = Dictionary(grouping: project.receipts) { receipt in
            receipt.paymentMethod.lowercased().trimmingCharacters(in: .whitespaces)
        }
        
        var paymentSpending: [PaymentMethodSpendingItem] = []
        
        for (paymentMethodName, receipts) in receiptsByPaymentMethod {
            guard !paymentMethodName.isEmpty else { continue }
            
            let totalSpent = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            if totalSpent > 0 {
                // Use the payment method service to get or create payment method
                let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
                    name: receipts.first?.paymentMethod ?? paymentMethodName,
                    type: determinePaymentType(from: paymentMethodName)
                )
                
                // Always use the actual calculated total from receipts, not the stored total
                paymentSpending.append(PaymentMethodSpendingItem(
                    paymentMethod: paymentMethod,
                    totalSpent: totalSpent,  // Use calculated total, not paymentMethod.totalSpent
                    receiptCount: receipts.count
                ))
            }
        }
        
        return paymentSpending.sorted { $0.totalSpent > $1.totalSpent }
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

// MARK: - Payment Method Spending Row View
struct PaymentMethodSpendingRowView: View {
    let paymentMethod: PaymentMethod
    let totalSpent: Double
    let receiptCount: Int
    let percentage: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Payment method icon and info
                HStack(spacing: 12) {
                    Image(systemName: paymentIcon)
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(paymentMethod.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(paymentMethod.type.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(typeColor.opacity(0.2))
                                .foregroundColor(typeColor)
                                .cornerRadius(4)
                            
                            if !paymentMethod.lastFourDigits.isEmpty {
                                Text("•••• \(paymentMethod.lastFourDigits)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(receiptCount) transaction\(receiptCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Amount and percentage
                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalSpent.formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var paymentIcon: String {
        switch paymentMethod.type {
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    private var typeColor: Color {
        switch paymentMethod.type {
        case .creditCard: return .blue
        case .debitCard: return .green
        case .cash: return .orange
        case .check: return .purple
        case .bankTransfer: return .indigo
        case .other: return .secondary
        }
    }
}

#Preview {
    SpendingByPaymentMethodView()
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
}