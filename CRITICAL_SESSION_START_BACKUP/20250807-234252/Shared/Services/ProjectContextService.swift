import Foundation

/// Service to manage project-specific vendor and payment method data
/// with organization-level sharing and fallbacks
class ProjectContextService: ObservableObject {
    static let shared = ProjectContextService()
    
    private init() {}
    
    // MARK: - Vendor Management
    
    func loadVendors(for projectId: UUID, organizationId: String) -> [Vendor] {
        // First try project-specific vendors
        if let data = UserDefaults.standard.data(forKey: "project_vendors_\(projectId)"),
           let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
            return vendors.filter { $0.isActive }
        }
        
        // Fallback to organization vendors
        if let data = UserDefaults.standard.data(forKey: "vendors_\(organizationId)"),
           let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
            return vendors.filter { $0.isActive }
        }
        
        return []
    }
    
    func saveVendors(_ vendors: [Vendor], for projectId: UUID, organizationId: String) {
        // Save to project-specific storage
        if let data = try? JSONEncoder().encode(vendors) {
            UserDefaults.standard.set(data, forKey: "project_vendors_\(projectId)")
        }
        
        // Also update organization-level storage for cross-project sharing
        var orgVendors = loadOrganizationVendors(organizationId: organizationId)
        
        // Merge new vendors into organization directory
        for vendor in vendors {
            if let existingIndex = orgVendors.firstIndex(where: { $0.id == vendor.id }) {
                orgVendors[existingIndex] = vendor
            } else {
                orgVendors.append(vendor)
            }
        }
        
        if let data = try? JSONEncoder().encode(orgVendors) {
            UserDefaults.standard.set(data, forKey: "vendors_\(organizationId)")
        }
    }
    
    func addVendor(_ vendor: Vendor, to projectId: UUID, organizationId: String) {
        var vendors = loadVendors(for: projectId, organizationId: organizationId)
        vendors.append(vendor)
        saveVendors(vendors, for: projectId, organizationId: organizationId)
    }
    
    // MARK: - Payment Method Management
    
    func loadPaymentMethods(for projectId: UUID, organizationId: String) -> [PaymentMethod] {
        // First try project-specific payment methods
        if let data = UserDefaults.standard.data(forKey: "project_payment_methods_\(projectId)"),
           let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
            return methods.filter { $0.isActive }
        }
        
        // Fallback to organization payment methods
        if let data = UserDefaults.standard.data(forKey: "paymentMethods_\(organizationId)"),
           let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
            return methods.filter { $0.isActive }
        }
        
        return []
    }
    
    func savePaymentMethods(_ methods: [PaymentMethod], for projectId: UUID, organizationId: String) {
        // Save to project-specific storage
        if let data = try? JSONEncoder().encode(methods) {
            UserDefaults.standard.set(data, forKey: "project_payment_methods_\(projectId)")
        }
        
        // Also update organization-level storage for cross-project sharing
        var orgMethods = loadOrganizationPaymentMethods(organizationId: organizationId)
        
        // Merge new methods into organization directory
        for method in methods {
            if let existingIndex = orgMethods.firstIndex(where: { $0.id == method.id }) {
                orgMethods[existingIndex] = method
            } else {
                orgMethods.append(method)
            }
        }
        
        if let data = try? JSONEncoder().encode(orgMethods) {
            UserDefaults.standard.set(data, forKey: "paymentMethods_\(organizationId)")
        }
    }
    
    func addPaymentMethod(_ method: PaymentMethod, to projectId: UUID, organizationId: String) {
        var methods = loadPaymentMethods(for: projectId, organizationId: organizationId)
        methods.append(method)
        savePaymentMethods(methods, for: projectId, organizationId: organizationId)
    }
    
    // MARK: - Organization-Level Access (for directories)
    
    func loadOrganizationVendors(organizationId: String) -> [Vendor] {
        if let data = UserDefaults.standard.data(forKey: "vendors_\(organizationId)"),
           let vendors = try? JSONDecoder().decode([Vendor].self, from: data) {
            return vendors
        }
        return []
    }
    
    func loadOrganizationPaymentMethods(organizationId: String) -> [PaymentMethod] {
        if let data = UserDefaults.standard.data(forKey: "paymentMethods_\(organizationId)"),
           let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) {
            return methods
        }
        return []
    }
    
    // MARK: - Spending Updates
    
    func updateVendorSpending(_ vendorID: UUID, amount: Double, for projectId: UUID, organizationId: String) {
        var vendors = loadVendors(for: projectId, organizationId: organizationId)
        if let index = vendors.firstIndex(where: { $0.id == vendorID }) {
            vendors[index].totalSpent += amount
            saveVendors(vendors, for: projectId, organizationId: organizationId)
        }
    }
    
    func updatePaymentMethodSpending(_ methodID: UUID, amount: Double, for projectId: UUID, organizationId: String) {
        var methods = loadPaymentMethods(for: projectId, organizationId: organizationId)
        if let index = methods.firstIndex(where: { $0.id == methodID }) {
            methods[index].totalSpent += amount
            savePaymentMethods(methods, for: projectId, organizationId: organizationId)
        }
    }
}