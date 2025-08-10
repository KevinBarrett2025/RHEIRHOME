import SwiftUI

struct VendorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedVendor: Vendor?
    @ObservedObject var vendorService: VendorManagementService
    let onSelection: (Vendor) -> Void
    
    @State private var searchText = ""
    @State private var showingAddVendor = false
    @State private var newVendorName = ""
    @State private var newVendorCategory: VendorCategory = .hardware
    
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
    
    var body: some View {
        NavigationStack {
            List {
                // Search/Add section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search or enter new vendor", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    
                    if !searchText.isEmpty && !vendorExists(searchText) {
                        Button("Add '\(searchText)' as new vendor") {
                            addNewVendor(name: searchText)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Existing vendors
                if !filteredVendors.isEmpty {
                    Section("Select Vendor") {
                        ForEach(filteredVendors) { vendor in
                            VendorRowView(vendor: vendor, isSelected: selectedVendor?.id == vendor.id) {
                                selectedVendor = vendor
                                onSelection(vendor)
                                dismiss()
                            }
                        }
                    }
                }
                
                // Category shortcuts
                Section("Add by Category") {
                    ForEach(VendorCategory.allCases) { category in
                        Button(category.rawValue) {
                            newVendorCategory = category
                            showingAddVendor = true
                        }
                        .foregroundColor(.primary)
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
            .searchable(text: $searchText, prompt: "Search vendors")
        }
        .alert("Add New Vendor", isPresented: $showingAddVendor) {
            TextField("Vendor Name", text: $newVendorName)
            Button("Add") {
                if !newVendorName.isEmpty {
                    addNewVendor(name: newVendorName, category: newVendorCategory)
                    newVendorName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newVendorName = ""
            }
        } message: {
            Text("Enter the name for the new \(newVendorCategory.rawValue.lowercased()) vendor")
        }
    }
    
    private func vendorExists(_ name: String) -> Bool {
        return vendorService.vendors.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    private func addNewVendor(name: String, category: VendorCategory = .other) {
        let vendor = vendorService.findOrCreateVendor(name: name, category: category)
        selectedVendor = vendor
        onSelection(vendor)
        dismiss()
    }
}

struct VendorRowView: View {
    let vendor: Vendor
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(vendor.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if vendor.totalSpent > 0 {
                        Text("Total spent: \(vendor.totalSpent.formatAsCurrency())")
                            .font(.caption2)
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
    VendorPickerView(
        selectedVendor: .constant(nil),
        vendorService: VendorManagementService(),
        onSelection: { _ in }
    )
}