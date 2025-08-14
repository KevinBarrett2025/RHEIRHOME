import SwiftUI

struct VendorSpendingDetailView: View {
    let vendorID: UUID
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    private var vendor: Vendor? {
        getLocalVendors().first { $0.id == vendorID }
    }
    
    private var vendorReceipts: [Receipt] {
        project.receipts.filter { receipt in
            receipt.vendorID == vendorID || 
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
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(vendor.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !vendor.address.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                    Text(vendor.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if !vendor.phone.isEmpty {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                    Text(vendor.phone)
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
                    Label("Receipts", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(vendorReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Category breakdown
            if !vendorReceipts.isEmpty {
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
                        ReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateCategoryBreakdown() -> [CategorySpendingItem] {
        let grouped = Dictionary(grouping: vendorReceipts) { $0.category }
        
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
    
    private func getLocalVendors() -> [Vendor] {
        if let data = UserDefaults.standard.data(forKey: "vendors_org_primary"),
           let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
            return vendors
        }
        return []
    }
}

struct CategorySpendingItem {
    let category: ReceiptCategory
    let amount: Double
    let receiptCount: Int
}

struct ReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
                    
                    Text(receipt.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !receipt.notes.isEmpty {
                    Text(receipt.notes)
                        .font(.subheadline)
                        .lineLimit(2)
                } else if !receipt.items.isEmpty {
                    Text(receipt.items.map { $0.name }.joined(separator: ", "))
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                if !receipt.paymentMethod.isEmpty {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(receipt.paymentMethod)
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
    VendorSpendingDetailView(
        vendorID: UUID(),
        project: Project(
            name: "Sample Project",
            client: "Sample Client",
            totalBudget: 10000,
            materialCost: 5000,
            laborCost: 3000,
            generalConditions: 1000,
            contingency: 1000,
            
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id".addingTimeInterval(86400 * 30)
        )
    )
}