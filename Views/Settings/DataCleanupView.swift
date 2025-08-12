import SwiftUI

struct DataCleanupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var vendorKeys: [String] = []
    @State private var paymentMethodKeys: [String] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Vendor Storage") {
                    ForEach(vendorKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                            Spacer()
                            if let data = UserDefaults.standard.data(forKey: key),
                               let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
                                Text("\(vendors.count) vendors")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Payment Method Storage") {
                    ForEach(paymentMethodKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                            Spacer()
                            if let data = UserDefaults.standard.data(forKey: key),
                               let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
                                Text("\(methods.count) methods")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Consolidate Data") {
                        consolidateData()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clean Up Duplicates") {
                        cleanupDuplicates()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset All Vendor/Payment Data") {
                        resetAllData()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Data Cleanup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Data Cleanup", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                scanForStorageKeys()
            }
        }
    }
    
    private func scanForStorageKeys() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        
        vendorKeys = defaults.keys.filter { $0.hasPrefix("vendors_") }.sorted()
        paymentMethodKeys = defaults.keys.filter { $0.hasPrefix("paymentMethods_") }.sorted()
    }
    
    private func consolidateData() {
        guard let orgId = authViewModel.currentOrg?.id else {
            alertMessage = "No organization found"
            showingAlert = true
            return
        }
        
        let correctVendorKey = "vendors_\(orgId)"
        let correctPaymentKey = "paymentMethods_\(orgId)"
        
        // Consolidate vendors
        var allVendors: [Vendor] = []
        for key in vendorKeys {
            if let data = UserDefaults.standard.data(forKey: key),
               let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
                allVendors.append(contentsOf: vendors)
            }
        }
        
        // Remove duplicates by name
        let uniqueVendors = Array(Set(allVendors.map { $0.name })).compactMap { name in
            allVendors.first { $0.name == name }
        }
        
        // Consolidate payment methods
        var allPaymentMethods: [PaymentMethod] = []
        for key in paymentMethodKeys {
            if let data = UserDefaults.standard.data(forKey: key),
               let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
                allPaymentMethods.append(contentsOf: methods)
            }
        }
        
        // Remove duplicates by name
        let uniquePaymentMethods = Array(Set(allPaymentMethods.map { $0.name })).compactMap { name in
            allPaymentMethods.first { $0.name == name }
        }
        
        // Save consolidated data
        if let vendorData = try? JSONEncoder().encode(uniqueVendors) {
            UserDefaults.standard.set(vendorData, forKey: correctVendorKey)
        }
        
        if let paymentData = try? JSONEncoder().encode(uniquePaymentMethods) {
            UserDefaults.standard.set(paymentData, forKey: correctPaymentKey)
        }
        
        alertMessage = "Consolidated \(uniqueVendors.count) vendors and \(uniquePaymentMethods.count) payment methods to correct keys"
        showingAlert = true
        
        scanForStorageKeys()
    }
    
    private func cleanupDuplicates() {
        guard let orgId = authViewModel.currentOrg?.id else {
            alertMessage = "No organization found"
            showingAlert = true
            return
        }
        
        // Remove all keys except the correct ones
        let correctVendorKey = "vendors_\(orgId)"
        let correctPaymentKey = "paymentMethods_\(orgId)"
        
        for key in vendorKeys {
            if key != correctVendorKey {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        for key in paymentMethodKeys {
            if key != correctPaymentKey {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        alertMessage = "Cleaned up duplicate storage keys"
        showingAlert = true
        
        scanForStorageKeys()
    }
    
    private func resetAllData() {
        // Remove all vendor and payment method keys
        for key in vendorKeys + paymentMethodKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        alertMessage = "Reset all vendor and payment method data"
        showingAlert = true
        
        scanForStorageKeys()
    }
}

#Preview {
    DataCleanupView()
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
}