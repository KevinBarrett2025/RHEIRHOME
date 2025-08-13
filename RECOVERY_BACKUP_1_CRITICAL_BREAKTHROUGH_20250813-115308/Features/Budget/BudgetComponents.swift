import SwiftUI

// MARK: - Supporting Data Structures 
struct VendorSpendingItem {
    let vendor: Vendor
    let totalSpent: Double
    let receiptCount: Int
}

struct PaymentMethodSpendingItem {
    let paymentMethod: PaymentMethod
    let totalSpent: Double
    let receiptCount: Int
}

// MARK: - Quick Stat Card Component
struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Team Stat Card Component
struct TeamStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Project Team Member Card
struct ProjectTeamMemberCard: View {
    let member: TeamMember
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Member Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if member.hasAppAccess {
                            Image(systemName: "iphone")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(member.role)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let rate = member.hourlyRate {
                            Text("• \(rate.formatAsCurrency())/hr")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Activity indicators
                    HStack(spacing: 8) {
                        ActivityIndicator(
                            icon: "receipt.fill",
                            count: getReceiptCount(),
                            color: .blue
                        )
                        
                        ActivityIndicator(
                            icon: "photo.fill",
                            count: getProgressCount(),
                            color: .green
                        )
                        
                        ActivityIndicator(
                            icon: "clock.fill",
                            count: getHoursCount(),
                            color: .orange
                        )
                        
                        Spacer()
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch member.employmentStatus {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .terminated:
            return .red
        }
    }
    
    private func getReceiptCount() -> Int {
        return project.receipts.filter { $0.teamMemberID == member.id }.count
    }
    
    private func getProgressCount() -> Int {
        return project.progressReports.filter { $0.employeeIDs.contains(member.id) }.count
    }
    
    private func getHoursCount() -> Int {
        let hours = project.loggedHours.filter { $0.employeeID == member.id }
        return Int(hours.reduce(0) { $0 + $1.hoursWorked })
    }
}

// MARK: - Activity Indicator
struct ActivityIndicator: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Detail View Components

// MARK: - Simple Detail Views
struct SimpleVendorDetailView: View {
    let vendorID: UUID
    let project: Project
    let organizationId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    private var vendor: Vendor? {
        projectVM.vendorService.getVendor(by: vendorID)
    }
    
    private var vendorReceipts: [Receipt] {
        project.receipts.filter { receipt in
            receipt.vendorID == vendorID.uuidString || 
            (vendor != nil && receipt.vendor.lowercased() == vendor!.name.lowercased())
        }
    }
    
    private var totalSpent: Double {
        vendorReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let vendor = vendor {
                        vendorHeaderSection(vendor)
                        spendingSummarySection
                        receiptsListSection
                    } else {
                        Text("Vendor not found")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Vendor Details")
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
    private func vendorHeaderSection(_ vendor: Vendor) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: vendorIcon(for: vendor.category))
                    .foregroundColor(.blue)
                Text(vendor.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
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
                    Label("Receipts", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(vendorReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
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
                Text("All Receipts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if vendorReceipts.isEmpty {
                Text("No receipts found for this vendor")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vendorReceipts.sorted { $0.date > $1.date }) { receipt in
                        VendorReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    private func vendorIcon(for category: VendorCategory) -> String {
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

struct SimplePaymentMethodDetailView: View {
    let paymentMethodID: UUID
    let project: Project
    let organizationId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    private var paymentMethod: PaymentMethod? {
        projectVM.paymentMethodService.getPaymentMethod(by: paymentMethodID)
    }
    
    private var paymentReceipts: [Receipt] {
        project.receipts.filter { receipt in
            receipt.paymentMethodID == paymentMethodID.uuidString || 
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
                    .foregroundColor(.green)
                Text(paymentMethod.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
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

// MARK: - Vendor Receipt Row Card
struct VendorReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(receipt.vendor)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(receipt.isReturn ? .red : .primary)
                    
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                // Category
                HStack(spacing: 4) {
                    Image(systemName: categoryIcon(for: receipt.category))
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(receipt.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Enhanced payment method display with card details
                if !receipt.paymentMethod.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(receipt.paymentMethod)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Show card brand and last 4 digits from paymentMethodDetails
                            if let paymentDetails = receipt.paymentMethodDetails {
                                HStack(spacing: 4) {
                                    if let cardBrand = paymentDetails.cardBrand, !cardBrand.isEmpty {
                                        Text(cardBrand)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if let lastFour = paymentDetails.lastFourDigits, !lastFour.isEmpty {
                                        Text("•••• \(lastFour)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Receipt image indicator
            if receipt.hasReceiptImage {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Has Image")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver"
        case .material: return "cube.box"
        case .contingency: return "exclamationmark.triangle"
        case .permits: return "doc.text"
        case .demolition: return "hammer"
        case .electrical: return "bolt"
        case .plumbing: return "drop"
        case .hvac: return "wind"
        case .paint: return "paintbrush"
        case .flooring: return "square.grid.4x3"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub"
        default: return "tag"
        }
    }
}

// MARK: - Payment Receipt Row Card
struct PaymentReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(receipt.vendor)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(receipt.isReturn ? .red : .primary)
                    
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                // Category
                HStack(spacing: 4) {
                    Image(systemName: categoryIcon(for: receipt.category))
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(receipt.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Enhanced payment method display with card details
                if !receipt.paymentMethod.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(receipt.paymentMethod)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Show card brand and last 4 digits from paymentMethodDetails
                            if let paymentDetails = receipt.paymentMethodDetails {
                                HStack(spacing: 4) {
                                    if let cardBrand = paymentDetails.cardBrand, !cardBrand.isEmpty {
                                        Text(cardBrand)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if let lastFour = paymentDetails.lastFourDigits, !lastFour.isEmpty {
                                        Text("•••• \(lastFour)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Receipt image indicator
            if receipt.hasReceiptImage {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Has Image")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private func categoryIcon(for category: ReceiptCategory) -> String {
        switch category {
        case .general: return "wrench.and.screwdriver"
        case .material: return "cube.box"
        case .contingency: return "exclamationmark.triangle"
        case .permits: return "doc.text"
        case .demolition: return "hammer"
        case .electrical: return "bolt"
        case .plumbing: return "drop"
        case .hvac: return "wind"
        case .paint: return "paintbrush"
        case .flooring: return "square.grid.4x3"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub"
        default: return "tag"
        }
    }
}