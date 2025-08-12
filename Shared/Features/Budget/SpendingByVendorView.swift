import SwiftUI

struct SpendingByVendorView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingVendorDetails = false
    @State private var showingVendorManagement = false
    @State private var selectedVendorID: UUID? = nil
    @State private var searchText = ""
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    private var vendorSpending: [VendorSpendingItem] {
        guard let project = project else { return [] }
        return calculateVendorSpending(for: project)
    }
    
    private var filteredVendorSpending: [VendorSpendingItem] {
        if searchText.isEmpty {
            return vendorSpending
        } else {
            return vendorSpending.filter { 
                $0.vendor.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var totalSpent: Double {
        vendorSpending.reduce(0) { $0 + $1.totalSpent }
    }
    
    var body: some View {
        if let project = project {
            NavigationView {
                VStack(spacing: 0) {
                    headerSection
                    
                    if vendorSpending.isEmpty {
                        emptyStateView
                    } else {
                        vendorListSection
                    }
                }
                .searchable(text: $searchText, prompt: "Search vendors...")
                .navigationTitle("Spending by Vendor")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Manage") {
                            showingVendorManagement = true
                        }
                        .font(.subheadline)
                    }
                }
                .sheet(isPresented: $showingVendorDetails) {
                    if let vendorID = selectedVendorID,
                       let orgId = authVM.currentOrg?.id {
                        SimpleVendorDetailView(
                            vendorID: vendorID,
                            project: project,
                            organizationId: orgId
                        )
                        .environmentObject(projectVM)
                    }
                }
                .sheet(isPresented: $showingVendorManagement) {
                    VendorManagementView()
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
                    Text("Active Vendors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vendorSpending.count)")
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
    private var vendorListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredVendorSpending, id: \.vendor.id) { item in
                    VendorSpendingRowView(
                        vendor: item.vendor,
                        totalSpent: item.totalSpent,
                        receiptCount: item.receiptCount,
                        percentage: totalSpent > 0 ? item.totalSpent / totalSpent : 0
                    ) {
                        selectedVendorID = item.vendor.id
                        showingVendorDetails = true
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
            
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Vendor Spending")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Receipt spending will appear here organized by vendor.")
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
            
            Text("Select a project to view vendor spending analysis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func calculateVendorSpending(for project: Project) -> [VendorSpendingItem] {
        // Group receipts by vendor
        let receiptsByVendor = Dictionary(grouping: project.receipts) { receipt -> String in
            return receipt.vendor.lowercased()
        }
        
        var vendorSpending: [VendorSpendingItem] = []
        
        for (vendorName, receipts) in receiptsByVendor {
            let totalSpent = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            if totalSpent > 0 {
                // Use the vendor service to get or create vendor
                let vendor = projectVM.vendorService.findOrCreateVendor(
                    name: receipts.first?.vendor ?? vendorName,
                    category: detectVendorCategory(from: vendorName)
                )
                
                vendorSpending.append(VendorSpendingItem(
                    vendor: vendor,
                    totalSpent: totalSpent,
                    receiptCount: receipts.count
                ))
            }
        }
        
        return vendorSpending.sorted { $0.totalSpent > $1.totalSpent }
    }
    
    private func detectVendorCategory(from vendorName: String) -> VendorCategory {
        let name = vendorName.lowercased()
        
        if name.contains("home depot") || name.contains("lowe") || name.contains("menards") {
            return .hardware
        } else if name.contains("lumber") || name.contains("84 lumber") {
            return .lumber
        } else if name.contains("sherwin") || name.contains("paint") {
            return .paint
        } else if name.contains("electrical") {
            return .electrical
        } else if name.contains("plumbing") {
            return .plumbing
        } else if name.contains("rental") {
            return .rental
        } else if name.contains("gas") || name.contains("shell") || name.contains("bp") || name.contains("exxon") {
            return .gas
        } else if name.contains("grocery") || name.contains("walmart") || name.contains("target") {
            return .grocery
        } else if name.contains("restaurant") || name.contains("food") {
            return .restaurant
        }
        
        return .other
    }
}

// MARK: - Vendor Spending Row View
struct VendorSpendingRowView: View {
    let vendor: Vendor
    let totalSpent: Double
    let receiptCount: Int
    let percentage: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Vendor icon and info
                HStack(spacing: 12) {
                    Image(systemName: vendorIcon)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendor.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(vendor.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(categoryColor.opacity(0.2))
                                .foregroundColor(categoryColor)
                                .cornerRadius(4)
                            
                            Text("\(receiptCount) receipt\(receiptCount == 1 ? "" : "s")")
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
    
    private var vendorIcon: String {
        switch vendor.category {
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
    
    private var categoryColor: Color {
        switch vendor.category {
        case .hardware: return .orange
        case .lumber: return .brown
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .paint: return .purple
        case .rental: return .green
        case .grocery: return .red
        case .restaurant: return .pink
        case .gas: return .black
        case .automotive: return .gray
        case .professional: return .indigo
        case .office: return .cyan
        case .other: return .secondary
        }
    }
}

#Preview {
    SpendingByVendorView()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
}