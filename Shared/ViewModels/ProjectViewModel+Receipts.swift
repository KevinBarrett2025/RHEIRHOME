//
//  ProjectViewModel+Receipts.swift
//  RheirMultiplatformApp
//

import Foundation
import OSLog

extension Logger {
    static let receiptWorkflow = Logger(subsystem: "com.RheirHome.RHEIR", category: "receiptWorkflow")
}

enum ReceiptProjectStorage {
    case organizationProjects(index: Int)
    case allProjects(index: Int)

    var logLabel: String {
        switch self {
        case .organizationProjects:
            return "organizationProjects"
        case .allProjects:
            return "allProjects"
        }
    }
}

struct ReceiptProjectResolution {
    let project: Project
    let storage: ReceiptProjectStorage
    let synchronizedOrganizationProjects: [Project]
    let resynchronizedFromAllProjects: Bool
}

final class ReceiptProjectStore {
    func resolveProject(
        projectID: UUID,
        organizationProjects: [Project],
        allProjects: [Project],
        currentOrganizationID: String?
    ) -> ReceiptProjectResolution? {
        if let orgIndex = organizationProjects.firstIndex(where: { $0.id == projectID }) {
            return ReceiptProjectResolution(
                project: organizationProjects[orgIndex],
                storage: .organizationProjects(index: orgIndex),
                synchronizedOrganizationProjects: organizationProjects,
                resynchronizedFromAllProjects: false
            )
        }

        guard let allIndex = allProjects.firstIndex(where: { $0.id == projectID }) else {
            return nil
        }

        let project = allProjects[allIndex]
        guard currentOrganizationID == nil || project.organizationID == currentOrganizationID else {
            return nil
        }

        if let currentOrganizationID, project.organizationID == currentOrganizationID {
            var synchronizedOrganizationProjects = organizationProjects
            synchronizedOrganizationProjects.append(project)
            return ReceiptProjectResolution(
                project: project,
                storage: .organizationProjects(index: synchronizedOrganizationProjects.count - 1),
                synchronizedOrganizationProjects: synchronizedOrganizationProjects,
                resynchronizedFromAllProjects: true
            )
        }

        return ReceiptProjectResolution(
            project: project,
            storage: .allProjects(index: allIndex),
            synchronizedOrganizationProjects: organizationProjects,
            resynchronizedFromAllProjects: false
        )
    }

    func synchronize(
        _ updatedProject: Project,
        resolution: ReceiptProjectResolution,
        organizationProjects: inout [Project],
        allProjects: inout [Project]
    ) {
        organizationProjects = resolution.synchronizedOrganizationProjects

        switch resolution.storage {
        case .organizationProjects(let index):
            if organizationProjects.indices.contains(index) {
                organizationProjects[index] = updatedProject
            } else {
                organizationProjects.append(updatedProject)
            }
        case .allProjects(let index):
            if allProjects.indices.contains(index) {
                allProjects[index] = updatedProject
            } else {
                allProjects.append(updatedProject)
            }
        }

        if let allIndex = allProjects.firstIndex(where: { $0.id == updatedProject.id }) {
            allProjects[allIndex] = updatedProject
        } else {
            allProjects.append(updatedProject)
        }
    }
}

@MainActor
extension ProjectViewModel {
    
    /// Append a new receipt to the current project with Enterprise Intelligence integration.
    func addReceipt(_ receipt: Receipt) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }
        
        // Create or find vendor
        let vendor = vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: detectVendorCategory(from: receipt.vendor)
        )
        
        // Create or find payment method
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: detectPaymentType(from: receipt.paymentMethod)
        )
        
        // Update receipt with proper IDs (convert UUID to String)
        var updatedReceipt = receipt
        updatedReceipt.vendorID = vendor.id.uuidString
        updatedReceipt.paymentMethodID = paymentMethod.id.uuidString
        
        // Update spending totals
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        vendorService.updateVendorSpending(vendorID: vendor.id, amount: amount)
        paymentMethodService.updatePaymentMethodSpending(paymentMethodID: paymentMethod.id, amount: amount)
        
        // CRITICAL FIX: Auto-assign team member to project when they add a receipt
        if let teamMemberID = updatedReceipt.teamMemberID,
           !organizationProjects[idx].assignedTeamMemberIDs.contains(teamMemberID.uuidString) {
            organizationProjects[idx].assignTeamMember(teamMemberID.uuidString)
            Logger.receiptWorkflow.info("Auto-assigned team member from receipt add.")
        }
        
        // Add receipt to project
        organizationProjects[idx].receipts.append(updatedReceipt)
        selectedProject = organizationProjects[idx]
        invalidateReceiptCache() // Invalidate cache when receipts change
        
        // 🧠 ENTERPRISE INTELLIGENCE: Process receipt for organizational learning
        Task {
            await processReceiptForOrganizationIntelligence(
                vendor: receipt.vendor,
                paymentMethod: receipt.paymentMethod,
                amount: amount,
                projectID: sel.id.uuidString
            )
            
            _ = await saveAllProjectsToCloudKit()
        }
        
        Logger.receiptWorkflow.notice(
            "Added receipt to selected project [vendor=\(receipt.vendor, privacy: .private(mask: .hash)) amount=\(receipt.amount, privacy: .public) payment=\(paymentMethod.displayName, privacy: .public)]"
        )
    }

    /// Update an existing receipt in the current project with Enterprise Intelligence integration.
    func updateReceipt(_ receipt: Receipt) {
        guard let sel  = selectedProject,
              let pIdx = organizationProjects.firstIndex(where: { $0.id == sel.id }),
              let rIdx = organizationProjects[pIdx].receipts.firstIndex(where: { $0.id == receipt.id })
        else { return }
        
        // Get old receipt for spending adjustment
        let oldReceipt = organizationProjects[pIdx].receipts[rIdx]
        
        // Create or find vendor
        let vendor = vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: detectVendorCategory(from: receipt.vendor)
        )
        
        // Create or find payment method
        let paymentMethod = paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: detectPaymentType(from: receipt.paymentMethod)
        )
        
        // Update receipt with proper IDs (convert UUID to String)
        var updatedReceipt = receipt
        updatedReceipt.vendorID = vendor.id.uuidString
        updatedReceipt.paymentMethodID = paymentMethod.id.uuidString
        
        // CRITICAL FIX: Auto-assign team member to project when they update a receipt
        if let teamMemberID = updatedReceipt.teamMemberID,
           !organizationProjects[pIdx].assignedTeamMemberIDs.contains(teamMemberID.uuidString) {
            organizationProjects[pIdx].assignTeamMember(teamMemberID.uuidString)
            Logger.receiptWorkflow.info("Auto-assigned team member from receipt update.")
        }
        
        // Adjust spending totals (remove old, add new)
        if let oldVendorID = oldReceipt.vendorID, let vendorUUID = UUID(uuidString: oldVendorID) {
            let oldAmount = oldReceipt.isReturn ? -oldReceipt.amount : oldReceipt.amount
            vendorService.updateVendorSpending(vendorID: vendorUUID, amount: -oldAmount)
        }
        
        if let oldPaymentMethodID = oldReceipt.paymentMethodID, let paymentMethodUUID = UUID(uuidString: oldPaymentMethodID) {
            let oldAmount = oldReceipt.isReturn ? -oldReceipt.amount : oldReceipt.amount
            paymentMethodService.updatePaymentMethodSpending(paymentMethodID: paymentMethodUUID, amount: -oldAmount)
        }
        
        let newAmount = receipt.isReturn ? -receipt.amount : receipt.amount
        vendorService.updateVendorSpending(vendorID: vendor.id, amount: newAmount)
        paymentMethodService.updatePaymentMethodSpending(paymentMethodID: paymentMethod.id, amount: newAmount)
        
        // Update receipt in project
        organizationProjects[pIdx].receipts[rIdx] = updatedReceipt
        selectedProject = organizationProjects[pIdx]
        invalidateReceiptCache() // Invalidate cache when receipts change
        
        // 🧠 ENTERPRISE INTELLIGENCE: Process updated receipt for organizational learning
        Task {
            await processReceiptForOrganizationIntelligence(
                vendor: receipt.vendor,
                paymentMethod: receipt.paymentMethod,
                amount: newAmount,
                projectID: sel.id.uuidString
            )
            
            _ = await saveAllProjectsToCloudKit()
        }
        
        Logger.receiptWorkflow.notice(
            "Updated receipt in selected project [vendor=\(receipt.vendor, privacy: .private(mask: .hash)) amount=\(receipt.amount, privacy: .public) payment=\(paymentMethod.displayName, privacy: .public)]"
        )
    }
    
    // MARK: - Enterprise Intelligence Integration (Phase 2C - Simplified)
    
    /// Check if Enterprise Intelligence is ready for use
    var isEnterpriseIntelligenceReady: Bool {
        return currentOrganizationID != nil
    }
    
    /// Process receipt data for organizational intelligence and learning
    private func processReceiptForOrganizationIntelligence(
        vendor: String,
        paymentMethod: String,
        amount: Double,
        projectID: String
    ) async {
        guard isEnterpriseIntelligenceReady else {
            Logger.receiptIntelligence.warning("Skipped receipt intelligence processing because the organization context is not ready.")
            return
        }
        
        Logger.receiptIntelligence.info(
            "Processing receipt intelligence [vendor=\(vendor, privacy: .private(mask: .hash)) payment=\(paymentMethod, privacy: .private(mask: .hash)) amount=\(amount, privacy: .public)]"
        )
        
        // 🚀 PHASE 2C: REAL-TIME ORGANIZATIONAL LEARNING
        // Store intelligence data for this transaction
        await storeReceiptIntelligenceData(
            vendor: vendor,
            paymentMethod: paymentMethod,
            amount: amount,
            projectID: projectID
        )
        
        // Update organizational insights
        await updateOrganizationalInsights()
        
        Logger.receiptIntelligence.notice("Completed receipt intelligence processing.")
        
        // Trigger UI refresh for intelligence dashboards
        await MainActor.run {
            intelligenceSnapshotVersion = UUID()
        }
    }
    
    /// Store receipt intelligence data for organizational learning (Phase 2C)
    private func storeReceiptIntelligenceData(
        vendor: String,
        paymentMethod: String,
        amount: Double,
        projectID: String
    ) async {
        guard let organizationID = currentOrganizationID else { return }

        let intelligenceRecord = ReceiptIntelligenceRecord(
            vendor: vendor,
            paymentMethod: paymentMethod,
            amount: amount,
            projectID: projectID,
            date: Date().timeIntervalSince1970,
            organizationID: organizationID,
            category: detectVendorCategory(from: vendor).rawValue,
            paymentType: detectPaymentType(from: paymentMethod).rawValue
        )

        receiptIntelligenceStore.append(intelligenceRecord, for: organizationID)
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to detect vendor category from name
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
    
    /// Helper method to detect payment type from payment method name
    private func detectPaymentType(from paymentMethodName: String) -> PaymentType {
        let name = paymentMethodName.lowercased()
        
        if name.contains("cash") {
            return .cash
        } else if name.contains("check") {
            return .check
        } else if name.contains("debit") {
            return .debitCard
        } else if name.contains("credit") || name.contains("visa") || name.contains("mastercard") || 
                  name.contains("amex") || name.contains("discover") {
            return .creditCard
        } else if name.contains("transfer") || name.contains("wire") {
            return .bankTransfer
        }
        
        return .other
    }
    
    /// Update organizational insights with new receipt data
    private func updateOrganizationalInsights() async {
        guard let orgID = currentOrganizationID else { return }
        
        let totalVendors = vendorService.vendorsSortedByName.count
        let totalPaymentMethods = paymentMethodService.paymentMethodsSortedByName.count
        let totalSpending = organizationProjects.flatMap { $0.receipts }.reduce(0) { $0 + $1.amount }
        
        receiptIntelligenceStore.saveInsights(
            OrganizationInsightsSnapshot(
                totalVendors: totalVendors,
                totalPaymentMethods: totalPaymentMethods,
                totalSpending: totalSpending,
                lastUpdated: Date().timeIntervalSince1970,
                organizationID: orgID
            ),
            for: orgID
        )
        
        Logger.receiptIntelligence.notice(
            "Updated organizational receipt insights [vendors=\(totalVendors, privacy: .public) payments=\(totalPaymentMethods, privacy: .public) total=\(totalSpending, privacy: .public)]"
        )
    }
    
    // MARK: - Phase 2C: Historical Intelligence Population
    
    /// Scan all existing receipts and populate organizational intelligence
    func scanExistingReceiptsForIntelligence() async {
        guard currentOrganizationID != nil else {
            Logger.receiptIntelligence.error("Cannot scan receipts for intelligence without an active organization.")
            return
        }
        
        Logger.receiptIntelligence.info("Scanning existing receipts for intelligence population.")
        
        var processedCount = 0
        var totalReceiptCount = 0
        
        // Count total receipts first
        for project in organizationProjects {
            totalReceiptCount += project.receipts.count
        }
        
        // Process each project's receipts
        for project in organizationProjects {
            for receipt in project.receipts {
                let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                
                await storeReceiptIntelligenceData(
                    vendor: receipt.vendor,
                    paymentMethod: receipt.paymentMethod,
                    amount: amount,
                    projectID: project.id.uuidString
                )
                
                processedCount += 1
                
                // Update UI progress every 10 receipts
                if processedCount % 10 == 0 {
                    await MainActor.run {
                        Logger.receiptIntelligence.debug(
                            "Receipt intelligence scan progress [processed=\(processedCount, privacy: .public) total=\(totalReceiptCount, privacy: .public)]"
                        )
                    }
                }
            }
        }
        
        // Update organizational insights with all data
        await updateOrganizationalInsights()
        
        await MainActor.run {
            Logger.receiptIntelligence.notice(
                "Completed receipt intelligence population [processed=\(processedCount, privacy: .public) projects=\(self.organizationProjects.count, privacy: .public)]"
            )

            intelligenceSnapshotVersion = UUID()
        }
    }
    
    /// Get organizational intelligence data for dashboard use
    func getOrganizationalIntelligenceData() -> [String: Any]? {
        guard let orgID = currentOrganizationID else { return nil }
        
        return receiptIntelligenceStore.loadInsights(for: orgID)?.dictionary
    }
    
    /// Get receipt intelligence records for analysis
    func getReceiptIntelligenceRecords() -> [[String: Any]] {
        guard let orgID = currentOrganizationID else { return [] }
        
        return receiptIntelligenceStore.loadRecords(for: orgID).map { $0.dictionary }
    }
    
    /// Get top vendors by spending from intelligence data
    func getTopVendorsBySpending(limit: Int = 10) -> [(vendor: String, amount: Double)] {
        let records = getReceiptIntelligenceRecords()
        
        // Group by vendor and sum amounts
        var vendorSpending: [String: Double] = [:]
        for record in records {
            if let vendor = record["vendor"] as? String,
               let amount = record["amount"] as? Double {
                vendorSpending[vendor, default: 0.0] += amount
            }
        }
        
        // Sort by spending and return top results
        return vendorSpending
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (vendor: $0.key, amount: $0.value) }
    }
    
    /// Get top payment methods by usage from intelligence data
    func getTopPaymentMethodsByUsage(limit: Int = 10) -> [(paymentMethod: String, count: Int, amount: Double)] {
        let records = getReceiptIntelligenceRecords()
        
        // Group by payment method and sum amounts/counts
        var paymentMethodData: [String: (count: Int, amount: Double)] = [:]
        for record in records {
            if let paymentMethod = record["paymentMethod"] as? String,
               let amount = record["amount"] as? Double {
                let current = paymentMethodData[paymentMethod, default: (count: 0, amount: 0.0)]
                paymentMethodData[paymentMethod] = (count: current.count + 1, amount: current.amount + amount)
            }
        }
        
        // Sort by count and return top results
        return paymentMethodData
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { (paymentMethod: $0.key, count: $0.value.count, amount: $0.value.amount) }
    }

    // MARK: - Spending Calculations with Returns

    private var currentReceipts: [Receipt] {
        selectedProject?.receipts ?? []
    }

    /// Total net spending across all categories
    var totalSpent: Double {
        currentReceipts.reduce(0) { acc, r in
            acc + (r.isReturn ? -r.amount : r.amount)
        }
    }
}

struct ReceiptIntelligenceRecord: Codable, Equatable {
    let vendor: String
    let paymentMethod: String
    let amount: Double
    let projectID: String
    let date: TimeInterval
    let organizationID: String
    let category: String
    let paymentType: String

    var dictionary: [String: Any] {
        [
            "vendor": vendor,
            "paymentMethod": paymentMethod,
            "amount": amount,
            "projectID": projectID,
            "date": date,
            "organizationID": organizationID,
            "category": category,
            "paymentType": paymentType
        ]
    }
}

struct OrganizationInsightsSnapshot: Codable, Equatable {
    let totalVendors: Int
    let totalPaymentMethods: Int
    let totalSpending: Double
    let lastUpdated: TimeInterval
    let organizationID: String

    var dictionary: [String: Any] {
        [
            "totalVendors": totalVendors,
            "totalPaymentMethods": totalPaymentMethods,
            "totalSpending": totalSpending,
            "lastUpdated": lastUpdated,
            "organizationID": organizationID
        ]
    }
}

extension Logger {
    static let receiptIntelligence = Logger(subsystem: "com.RheirHome.RHEIR", category: "receiptIntelligence")
}

final class ReceiptIntelligenceStore {
    private enum Key {
        static let receiptIntelligencePrefix = "receipt_intelligence_"
        static let organizationalInsightsPrefix = "org_insights_"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func append(_ record: ReceiptIntelligenceRecord, for organizationID: String) {
        var records = loadRecords(for: organizationID)
        records.append(record)

        if records.count > 1000 {
            records = Array(records.suffix(1000))
        }

        save(records, forKey: Key.receiptIntelligencePrefix + organizationID)
        Logger.receiptIntelligence.debug(
            "Stored \(records.count, privacy: .public) receipt intelligence records for organization \(organizationID, privacy: .private(mask: .hash))"
        )
    }

    func loadRecords(for organizationID: String) -> [ReceiptIntelligenceRecord] {
        load([ReceiptIntelligenceRecord].self, forKey: Key.receiptIntelligencePrefix + organizationID, fallback: [])
    }

    func saveInsights(_ snapshot: OrganizationInsightsSnapshot, for organizationID: String) {
        save(snapshot, forKey: Key.organizationalInsightsPrefix + organizationID)
    }

    func loadInsights(for organizationID: String) -> OrganizationInsightsSnapshot? {
        loadOptional(OrganizationInsightsSnapshot.self, forKey: Key.organizationalInsightsPrefix + organizationID)
    }

    private func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            Logger.receiptIntelligence.error("Failed to encode receipt intelligence value for key \(key, privacy: .private(mask: .hash))")
            return
        }

        userDefaults.set(data, forKey: key)
    }

    private func load<Value: Decodable>(_ type: Value.Type, forKey key: String, fallback: Value) -> Value {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return fallback
        }

        return decoded
    }

    private func loadOptional<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }
}
