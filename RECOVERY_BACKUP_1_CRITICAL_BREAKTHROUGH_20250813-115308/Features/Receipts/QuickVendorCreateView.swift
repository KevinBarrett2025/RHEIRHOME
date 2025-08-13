import SwiftUI

struct QuickVendorCreateView: View {
    let onVendorCreated: (Vendor) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var category: VendorCategory = .hardware
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Vendor Name", text: $name)
                        .textContentType(.organizationName)
                    
                    Picker("Category", selection: $category) {
                        ForEach(VendorCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: vendorIcon(for: category))
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section("Contact Information") {
                    TextField("Address (optional)", text: $address)
                        .textContentType(.fullStreetAddress)
                    
                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let vendor = Vendor(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onVendorCreated(vendor)
                        dismiss()
                    }
                    .disabled(!canSave)
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

#Preview {
    QuickVendorCreateView { vendor in
        print("Created vendor: \(vendor.name)")
    }
}