import SwiftUI

struct VendorManagementView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVendor: Vendor?
    @State private var showingAddVendor = false
    @State private var showingEditVendor = false
    @State private var searchText = ""
    @State private var selectedCategory: VendorCategory? = nil
    
    private var vendorService: VendorManagementService {
        projectViewModel.vendorService
    }
    
    private var filteredVendors: [Vendor] {
        let vendors = vendorService.vendors.filter { $0.isActive }
        
        var filtered = vendors
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.subcategories.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Filter by category
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        return filtered.sorted { $0.totalSpent > $1.totalSpent }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search and filter section
                searchAndFilterSection
                
                // Vendors list
                vendorsList
            }
            .navigationTitle("Vendor Directory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Vendor") {
                        showingAddVendor = true
                    }
                }
            }
            .sheet(isPresented: $showingAddVendor) {
                AddVendorServiceView(vendorService: vendorService)
            }
            .sheet(item: $selectedVendor) { vendor in
                EditVendorServiceView(vendor: vendor, vendorService: vendorService)
            }
        }
    }
    
    @ViewBuilder
    private var searchAndFilterSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search vendors...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Menu("Filter") {
                Button("All Categories") {
                    selectedCategory = nil
                }
                
                Divider()
                
                ForEach(VendorCategory.allCases) { category in
                    Button(category.rawValue) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var vendorsList: some View {
        if filteredVendors.isEmpty {
            // Empty state
            VStack(spacing: 20) {
                Image(systemName: "building.2")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("No Vendors")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(searchText.isEmpty ? 
                     "Add vendors to track your project spending and build your organization directory." :
                     "No vendors match your search criteria.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if searchText.isEmpty {
                    Button("Add First Vendor") {
                        showingAddVendor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredVendors) { vendor in
                    VendorServiceRow(vendor: vendor) {
                        selectedVendor = vendor
                        showingEditVendor = true
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search vendors...")
        }
    }
    
    // MARK: - Service-Based Vendor Row
    struct VendorServiceRow: View {
        let vendor: Vendor
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vendor.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(vendor.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !vendor.subcategories.isEmpty {
                                Text(vendor.subcategories.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if vendor.totalSpent > 0 {
                                Text(vendor.totalSpent.formatAsCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Total Spent")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !vendor.phone.isEmpty || !vendor.email.isEmpty {
                                HStack(spacing: 4) {
                                    if !vendor.phone.isEmpty {
                                        Image(systemName: "phone.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    if !vendor.email.isEmpty {
                                        Image(systemName: "envelope.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !vendor.address.isEmpty {
                        Text(vendor.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Show when it was added
                    Text("Added \(vendor.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Service-Based Add Vendor View
    struct AddVendorServiceView: View {
        @ObservedObject var vendorService: VendorManagementService
        @Environment(\.dismiss) private var dismiss
        
        @State private var name = ""
        @State private var category = VendorCategory.other
        @State private var subcategories: [String] = []
        @State private var selectedSubcategories: Set<String> = []
        @State private var customSubcategory = ""
        @State private var address = ""
        @State private var phone = ""
        @State private var email = ""
        @State private var notes = ""
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Basic Information") {
                        TextField("Vendor Name", text: $name)
                        
                        Picker("Category", selection: $category) {
                            ForEach(VendorCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: iconForCategory(cat))
                                    .tag(cat)
                            }
                        }
                        .onChange(of: category) { _, newCategory in
                            subcategories = newCategory.commonSubcategories
                            selectedSubcategories.removeAll()
                        }
                    }
                    
                    if !subcategories.isEmpty {
                        Section("Subcategories") {
                            ForEach(subcategories, id: \.self) { subcategory in
                                HStack {
                                    Text(subcategory)
                                    Spacer()
                                    if selectedSubcategories.contains(subcategory) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedSubcategories.contains(subcategory) {
                                        selectedSubcategories.remove(subcategory)
                                    } else {
                                        selectedSubcategories.insert(subcategory)
                                    }
                                }
                            }
                            
                            TextField("Custom subcategory", text: $customSubcategory)
                        }
                    }
                    
                    Section("Contact Information") {
                        TextField("Address", text: $address, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                    }
                    
                    Section("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .navigationTitle("Add Vendor")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveVendor()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .onAppear {
                    subcategories = category.commonSubcategories
                }
            }
        }
        
        private func saveVendor() {
            var finalSubcategories = Array(selectedSubcategories)
            if !customSubcategory.trimmingCharacters(in: .whitespaces).isEmpty {
                finalSubcategories.append(customSubcategory.trimmingCharacters(in: .whitespaces))
            }
            
            let vendor = Vendor(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                subcategories: finalSubcategories,
                address: address.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            
            vendorService.saveVendor(vendor)
            dismiss()
        }
        
        private func iconForCategory(_ category: VendorCategory) -> String {
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
    
    // MARK: - Service-Based Edit Vendor View
    struct EditVendorServiceView: View {
        let vendor: Vendor
        @ObservedObject var vendorService: VendorManagementService
        @Environment(\.dismiss) private var dismiss
        
        @State private var name: String
        @State private var category: VendorCategory
        @State private var subcategories: [String] = []
        @State private var selectedSubcategories: Set<String>
        @State private var customSubcategory = ""
        @State private var address: String
        @State private var phone: String
        @State private var email: String
        @State private var notes: String
        @State private var isActive: Bool
        @State private var showingDeleteAlert = false
        
        init(vendor: Vendor, vendorService: VendorManagementService) {
            self.vendor = vendor
            self.vendorService = vendorService
            
            _name = State(initialValue: vendor.name)
            _category = State(initialValue: vendor.category)
            _selectedSubcategories = State(initialValue: Set(vendor.subcategories))
            _address = State(initialValue: vendor.address)
            _phone = State(initialValue: vendor.phone)
            _email = State(initialValue: vendor.email)
            _notes = State(initialValue: vendor.notes)
            _isActive = State(initialValue: vendor.isActive)
        }
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Basic Information") {
                        TextField("Vendor Name", text: $name)
                        
                        Picker("Category", selection: $category) {
                            ForEach(VendorCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: iconForCategory(cat))
                                    .tag(cat)
                            }
                        }
                        .onChange(of: category) { _, newCategory in
                            subcategories = newCategory.commonSubcategories
                        }
                        
                        Toggle("Active", isOn: $isActive)
                    }
                    
                    if !subcategories.isEmpty {
                        Section("Subcategories") {
                            ForEach(subcategories, id: \.self) { subcategory in
                                HStack {
                                    Text(subcategory)
                                    Spacer()
                                    if selectedSubcategories.contains(subcategory) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedSubcategories.contains(subcategory) {
                                        selectedSubcategories.remove(subcategory)
                                    } else {
                                        selectedSubcategories.insert(subcategory)
                                    }
                                }
                            }
                            
                            TextField("Custom subcategory", text: $customSubcategory)
                        }
                    }
                    
                    Section("Contact Information") {
                        TextField("Address", text: $address, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                    }
                    
                    Section("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    
                    Section("Statistics") {
                        HStack {
                            Text("Total Spent")
                            Spacer()
                            Text(vendor.totalSpent.formatAsCurrency())
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Date Added")
                            Spacer()
                            Text(vendor.dateAdded, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section {
                        Button("Delete Vendor", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    }
                }
                .navigationTitle("Edit Vendor")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveVendor()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .alert("Delete Vendor", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        deleteVendor()
                    }
                } message: {
                    Text("Are you sure you want to delete '\(vendor.name)'? This action cannot be undone.")
                }
            }
        }
        
        private func saveVendor() {
            var finalSubcategories = Array(selectedSubcategories)
            if !customSubcategory.trimmingCharacters(in: .whitespaces).isEmpty {
                finalSubcategories.append(customSubcategory.trimmingCharacters(in: .whitespaces))
            }
            
            var updatedVendor = vendor
            updatedVendor.name = name.trimmingCharacters(in: .whitespaces)
            updatedVendor.category = category
            updatedVendor.subcategories = finalSubcategories
            updatedVendor.address = address.trimmingCharacters(in: .whitespaces)
            updatedVendor.phone = phone.trimmingCharacters(in: .whitespaces)
            updatedVendor.email = email.trimmingCharacters(in: .whitespaces)
            updatedVendor.notes = notes.trimmingCharacters(in: .whitespaces)
            updatedVendor.isActive = isActive
            
            vendorService.saveVendor(updatedVendor)
            dismiss()
        }
        
        private func deleteVendor() {
            vendorService.removeVendor(vendor)
            dismiss()
        }
        
        private func iconForCategory(_ category: VendorCategory) -> String {
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
}

#if DEBUG
struct VendorManagementView_Previews: PreviewProvider {
    static var previews: some View {
        VendorManagementView()
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}
#endif