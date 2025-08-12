import SwiftUI

/// Simple vendor picker for quick selection
struct SimpleVendorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedVendor: Vendor?
    @ObservedObject var vendorService: VendorManagementService
    let onSelection: (Vendor) -> Void
    
    @State private var searchText = ""
    
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
    
    private var favoriteVendors: [Vendor] {
        vendorService.vendorsSortedBySpending.prefix(3).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search vendors...", text: $searchText)
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
                
                List {
                    // Quick add from search
                    if !searchText.isEmpty && !vendorExists(searchText) {
                        Section {
                            Button("Add '\(searchText)' as new vendor") {
                                addNewVendor(name: searchText)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Favorites
                    if !favoriteVendors.isEmpty && searchText.isEmpty {
                        Section("Favorites") {
                            ForEach(favoriteVendors, id: \.id) { vendor in
                                VendorRow(
                                    vendor: vendor,
                                    isSelected: selectedVendor?.id == vendor.id,
                                    showStats: true,
                                    onTap: {
                                        selectVendor(vendor)
                                    }
                                )
                            }
                        }
                    }
                    
                    // All vendors
                    Section(searchText.isEmpty ? "All Vendors" : "Search Results") {
                        ForEach(filteredVendors, id: \.id) { vendor in
                            VendorRow(
                                vendor: vendor,
                                isSelected: selectedVendor?.id == vendor.id,
                                showStats: false,
                                onTap: {
                                    selectVendor(vendor)
                                }
                            )
                        }
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
        }
    }
    
    private func selectVendor(_ vendor: Vendor) {
        selectedVendor = vendor
        onSelection(vendor)
        dismiss()
    }
    
    private func vendorExists(_ name: String) -> Bool {
        return vendorService.vendors.contains { 
            $0.name.lowercased() == name.lowercased()
        }
    }
    
    private func addNewVendor(name: String) {
        let vendor = vendorService.findOrCreateVendor(name: name)
        selectVendor(vendor)
    }
}

struct VendorRow: View {
    let vendor: Vendor
    let isSelected: Bool
    let showStats: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(vendor.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if showStats && vendor.totalSpent > 0 {
                        Text("Total spent: \(vendor.totalSpent.formatAsCurrency())")
                            .font(.caption)
                            .foregroundColor(.green)
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

#Preview {
    SimpleVendorPickerView(
        selectedVendor: .constant(nil),
        vendorService: VendorManagementService(),
        onSelection: { _ in }
    )
}