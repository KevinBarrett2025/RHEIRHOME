import Foundation
import CloudKit
import OSLog

extension Logger {
    static let organizationDirectory = Logger(subsystem: "com.RheirHome.RHEIR", category: "organizationDirectory")
}

/// Centralized service for managing organization-wide vendor and payment method directories
/// Handles both master directories and project-specific tracking
actor OrganizationService {
    static let shared = OrganizationService()
    
    private init() {}
    
    // MARK: - Context Management
    
    func getOrganizationContext(_ organizationId: String) async -> OrganizationContext {
        let vendors = await fetchMasterVendorDirectory(organizationId: organizationId)
        let paymentMethods = await fetchMasterPaymentMethodDirectory(organizationId: organizationId)
        
        return OrganizationContext(
            organizationId: organizationId,
            masterVendorDirectory: vendors,
            masterPaymentMethodDirectory: paymentMethods
        )
    }
    
    // MARK: - Master Directory Management
    
    func addVendorToMasterDirectory(
        organizationId: String,
        vendorName: String,
        category: VendorCategory
    ) async -> String {
        // Check if vendor already exists
        let existingVendors = await fetchMasterVendorDirectory(organizationId: organizationId)
        
        if let existingVendor = existingVendors.first(where: {
            $0.name.lowercased() == vendorName.lowercased()
        }) {
            return existingVendor.id
        }
        
        // Create new vendor
        let newVendor = OrganizationVendor(
            id: UUID().uuidString,
            name: vendorName,
            category: category,
            organizationId: organizationId,
            totalSpentAcrossAllProjects: 0.0,
            projectsUsed: [],
            dateFirstUsed: Date(),
            lastUsed: Date()
        )
        
        // Save to CloudKit (implementation depends on your CloudKit setup)
        await saveMasterVendor(newVendor)
        
        Logger.organizationDirectory.notice(
            "Added vendor to master directory [vendor=\(vendorName, privacy: .private(mask: .hash))]"
        )
        return newVendor.id
    }
    
    func addPaymentMethodToMasterDirectory(
        organizationId: String,
        paymentMethod: String,
        type: PaymentType
    ) async -> String {
        // Check if payment method already exists
        let existingMethods = await fetchMasterPaymentMethodDirectory(organizationId: organizationId)
        
        if let existingMethod = existingMethods.first(where: {
            $0.name.lowercased() == paymentMethod.lowercased()
        }) {
            return existingMethod.id
        }
        
        // Create new payment method
        let newMethod = OrganizationPaymentMethod(
            id: UUID().uuidString,
            name: paymentMethod,
            type: type,
            organizationId: organizationId,
            totalSpentAcrossAllProjects: 0.0,
            projectsUsed: [],
            dateFirstUsed: Date(),
            lastUsed: Date()
        )
        
        // Save to CloudKit
        await saveMasterPaymentMethod(newMethod)
        
        Logger.organizationDirectory.notice(
            "Added payment method to master directory [paymentMethod=\(paymentMethod, privacy: .private(mask: .hash))]"
        )
        return newMethod.id
    }
    
    // MARK: - Project-Specific Tracking
    
    func trackVendorForProject(
        projectId: String,
        vendorId: String,
        amount: Double
    ) async {
        // Update project-specific vendor usage
        var usage = await fetchProjectVendorUsage(projectId: projectId, vendorId: vendorId)
        
        if usage == nil {
            usage = ProjectVendorUsage(
                id: UUID().uuidString,
                projectId: projectId,
                vendorId: vendorId,
                totalSpent: amount,
                receiptCount: 1,
                firstUsed: Date(),
                lastUsed: Date()
            )
        } else {
            usage!.totalSpent += amount
            usage!.receiptCount += 1
            usage!.lastUsed = Date()
        }
        
        await saveProjectVendorUsage(usage!)
        
        // Update master vendor totals
        await updateMasterVendorTotals(vendorId: vendorId, projectId: projectId, amount: amount)
        
        Logger.organizationDirectory.info(
            "Tracked vendor usage [project=\(projectId, privacy: .private(mask: .hash)) amount=\(amount, privacy: .public)]"
        )
    }
    
    func trackPaymentMethodForProject(
        projectId: String,
        paymentMethodId: String,
        amount: Double
    ) async {
        // Update project-specific payment method usage
        var usage = await fetchProjectPaymentMethodUsage(projectId: projectId, paymentMethodId: paymentMethodId)
        
        if usage == nil {
            usage = ProjectPaymentMethodUsage(
                id: UUID().uuidString,
                projectId: projectId,
                paymentMethodId: paymentMethodId,
                totalSpent: amount,
                receiptCount: 1,
                firstUsed: Date(),
                lastUsed: Date()
            )
        } else {
            usage!.totalSpent += amount
            usage!.receiptCount += 1
            usage!.lastUsed = Date()
        }
        
        await saveProjectPaymentMethodUsage(usage!)
        
        // Update master payment method totals
        await updateMasterPaymentMethodTotals(paymentMethodId: paymentMethodId, projectId: projectId, amount: amount)
        
        Logger.organizationDirectory.info(
            "Tracked payment method usage [project=\(projectId, privacy: .private(mask: .hash)) amount=\(amount, privacy: .public)]"
        )
    }
    
    // MARK: - Reporting
    
    func generateOrganizationReport(
        organizationId: String,
        startDate: Date,
        endDate: Date
    ) async -> OrganizationReport {
        let vendors = await fetchMasterVendorDirectory(organizationId: organizationId)
        let paymentMethods = await fetchMasterPaymentMethodDirectory(organizationId: organizationId)
        
        let totalSpent = vendors.reduce(0) { $0 + $1.totalSpentAcrossAllProjects }
        
        return OrganizationReport(
            organizationId: organizationId,
            period: DateInterval(start: startDate, end: endDate),
            totalSpent: totalSpent,
            topVendors: vendors.sorted { $0.totalSpentAcrossAllProjects > $1.totalSpentAcrossAllProjects }.prefix(10).map { $0 },
            paymentMethodBreakdown: paymentMethods.map { method in
                PaymentMethodSummary(
                    paymentMethod: method,
                    totalSpent: method.totalSpentAcrossAllProjects,
                    projectCount: method.projectsUsed.count
                )
            }
        )
    }
    
    func generateProjectReport(projectId: String) async -> ProjectReport {
        let vendorUsages = await fetchAllProjectVendorUsages(projectId: projectId)
        let paymentMethodUsages = await fetchAllProjectPaymentMethodUsages(projectId: projectId)
        
        let totalSpent = vendorUsages.reduce(0) { $0 + $1.totalSpent }
        
        return ProjectReport(
            projectId: projectId,
            totalSpent: totalSpent,
            vendorBreakdown: vendorUsages,
            paymentMethodBreakdown: paymentMethodUsages,
            receiptCount: vendorUsages.reduce(0) { $0 + $1.receiptCount }
        )
    }
    
    // MARK: - Private CloudKit Operations
    
    private func fetchMasterVendorDirectory(organizationId: String) async -> [OrganizationVendor] {
        // Implementation: Fetch from CloudKit or local storage
        // For now, return empty array as placeholder
        return []
    }
    
    private func fetchMasterPaymentMethodDirectory(organizationId: String) async -> [OrganizationPaymentMethod] {
        // Implementation: Fetch from CloudKit or local storage
        return []
    }
    
    private func saveMasterVendor(_ vendor: OrganizationVendor) async {
        // Implementation: Save to CloudKit
        Logger.organizationDirectory.debug(
            "Saving master vendor [vendor=\(vendor.name, privacy: .private(mask: .hash))]"
        )
    }
    
    private func saveMasterPaymentMethod(_ method: OrganizationPaymentMethod) async {
        // Implementation: Save to CloudKit
        Logger.organizationDirectory.debug(
            "Saving master payment method [paymentMethod=\(method.name, privacy: .private(mask: .hash))]"
        )
    }
    
    private func fetchProjectVendorUsage(projectId: String, vendorId: String) async -> ProjectVendorUsage? {
        // Implementation: Fetch project-specific vendor usage
        return nil
    }
    
    private func fetchProjectPaymentMethodUsage(projectId: String, paymentMethodId: String) async -> ProjectPaymentMethodUsage? {
        // Implementation: Fetch project-specific payment method usage
        return nil
    }
    
    private func saveProjectVendorUsage(_ usage: ProjectVendorUsage) async {
        // Implementation: Save project vendor usage
        Logger.organizationDirectory.debug(
            "Saving project vendor usage [vendor=\(usage.vendorId, privacy: .private(mask: .hash)) project=\(usage.projectId, privacy: .private(mask: .hash))]"
        )
    }
    
    private func saveProjectPaymentMethodUsage(_ usage: ProjectPaymentMethodUsage) async {
        // Implementation: Save project payment method usage
        Logger.organizationDirectory.debug(
            "Saving project payment method usage [paymentMethod=\(usage.paymentMethodId, privacy: .private(mask: .hash)) project=\(usage.projectId, privacy: .private(mask: .hash))]"
        )
    }
    
    private func updateMasterVendorTotals(vendorId: String, projectId: String, amount: Double) async {
        // Implementation: Update master vendor totals and project list
        Logger.organizationDirectory.debug(
            "Updating master vendor totals [amount=\(amount, privacy: .public)]"
        )
    }
    
    private func updateMasterPaymentMethodTotals(paymentMethodId: String, projectId: String, amount: Double) async {
        // Implementation: Update master payment method totals and project list
        Logger.organizationDirectory.debug(
            "Updating master payment method totals [amount=\(amount, privacy: .public)]"
        )
    }
    
    private func fetchAllProjectVendorUsages(projectId: String) async -> [ProjectVendorUsage] {
        // Implementation: Fetch all vendor usages for a project
        return []
    }
    
    private func fetchAllProjectPaymentMethodUsages(projectId: String) async -> [ProjectPaymentMethodUsage] {
        // Implementation: Fetch all payment method usages for a project
        return []
    }
}

// MARK: - Reporting Models

struct OrganizationReport: Codable {
    let organizationId: String
    let period: DateInterval
    let totalSpent: Double
    let topVendors: [OrganizationVendor]
    let paymentMethodBreakdown: [PaymentMethodSummary]
}

struct ProjectReport: Codable {
    let projectId: String
    let totalSpent: Double
    let vendorBreakdown: [ProjectVendorUsage]
    let paymentMethodBreakdown: [ProjectPaymentMethodUsage]
    let receiptCount: Int
}

struct PaymentMethodSummary: Codable {
    let paymentMethod: OrganizationPaymentMethod
    let totalSpent: Double
    let projectCount: Int
}
