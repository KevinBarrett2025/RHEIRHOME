import Foundation
import Combine
import OSLog

/// Service for managing vendors across the organization
@MainActor
class VendorManagementService: ObservableObject {
    
    @Published var vendors: [Vendor] = []
    @Published var isLoading = false
    
    private let organizationID: String
    private let userDefaults = UserDefaults.standard
    
    init(organizationID: String = "RHEIR-LLC-MAIN-ORG") {
        self.organizationID = organizationID
        loadVendors()
    }
    
    // MARK: - Vendor Management
    
    /// Find or create a vendor by name
    func findOrCreateVendor(name: String, category: VendorCategory = .other) -> Vendor {
        // Check if vendor already exists (case-insensitive)
        if let existingVendor = vendors.first(where: { $0.name.lowercased() == name.lowercased() }) {
            Logger.company.debug("Resolved existing vendor from organization directory.")
            return existingVendor
        }
        
        // Create new vendor
        let newVendor = Vendor(
            name: name,
            category: category,
            subcategories: category.commonSubcategories
        )
        
        vendors.append(newVendor)
        saveVendors()
        
        Logger.company.notice("Created vendor in organization directory [category=\(category.rawValue, privacy: .public)]")
        return newVendor
    }
    
    /// Update vendor spending total
    func updateVendorSpending(vendorID: UUID, amount: Double) {
        guard let index = vendors.firstIndex(where: { $0.id == vendorID }) else { return }
        
        vendors[index].totalSpent += amount
        saveVendors()
        
        Logger.company.info("Updated vendor spending total.")
    }
    
    /// Get vendor by ID
    func getVendor(by id: UUID) -> Vendor? {
        return vendors.first { $0.id == id }
    }
    
    /// Get vendors by category
    func getVendors(by category: VendorCategory) -> [Vendor] {
        return vendors.filter { $0.category == category && $0.isActive }
    }
    
    /// Get top vendors by spending
    func getTopVendors(limit: Int = 10) -> [Vendor] {
        return vendors
            .filter { $0.isActive && $0.totalSpent > 0 }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Add or update vendor
    func saveVendor(_ vendor: Vendor) {
        if let index = vendors.firstIndex(where: { $0.id == vendor.id }) {
            vendors[index] = vendor
        } else {
            vendors.append(vendor)
        }
        saveVendors()
    }
    
    /// Remove vendor
    func removeVendor(_ vendor: Vendor) {
        vendors.removeAll { $0.id == vendor.id }
        saveVendors()
    }
    
    /// Get vendors sorted by name
    var vendorsSortedByName: [Vendor] {
        return vendors
            .filter { $0.isActive }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    /// Get vendors sorted by spending
    var vendorsSortedBySpending: [Vendor] {
        return vendors
            .filter { $0.isActive }
            .sorted { $0.totalSpent > $1.totalSpent }
    }
    
    // MARK: - Persistence
    
    private func loadVendors() {
        let key = "vendors_\(organizationID)"
        
        guard let data = userDefaults.data(forKey: key),
              let loadedVendors = try? JSONDecoder().decode([Vendor].self, from: data) else {
            // Create default vendors if none exist
            createDefaultVendors()
            return
        }
        
        vendors = loadedVendors
        Logger.company.info("Loaded vendors for organization [count=\(self.vendors.count, privacy: .public)]")
    }
    
    private func saveVendors() {
        let key = "vendors_\(organizationID)"
        
        guard let data = try? JSONEncoder().encode(vendors) else {
            Logger.company.error("Failed to encode vendors for persistence.")
            return
        }
        
        userDefaults.set(data, forKey: key)
        Logger.company.info("Saved vendors for organization [count=\(self.vendors.count, privacy: .public)]")
    }
    
    private func createDefaultVendors() {
        let defaultVendors = [
            Vendor(name: "Home Depot", category: .hardware),
            Vendor(name: "Lowe's", category: .hardware),
            Vendor(name: "Menards", category: .hardware),
            Vendor(name: "84 Lumber", category: .lumber),
            Vendor(name: "Sherwin-Williams", category: .paint),
            Vendor(name: "Local Hardware Store", category: .hardware)
        ]
        
        vendors = defaultVendors
        saveVendors()
        Logger.company.notice("Seeded default vendors for empty organization directory.")
    }
}
