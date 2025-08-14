//
//  ProjectViewModel+Receipts.swift
//  RheirMultiplatformApp
//

import Foundation

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
            print("✅ Auto-assigned team member \(teamMemberID) to project from receipt")
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
        
        print("📝 Added receipt: \(receipt.vendor) - \(receipt.amount.formatAsCurrency()) (\(paymentMethod.displayName))")
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
            print("✅ Auto-assigned team member \(teamMemberID) to project from receipt update")
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
        
        print("✏️ Updated receipt: \(receipt.vendor) - \(receipt.amount.formatAsCurrency()) (\(paymentMethod.displayName))")
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
            print("⚠️ Enterprise Intelligence not ready - skipping intelligence processing")
            return
        }
        
        print("🧠 ENTERPRISE INTELLIGENCE: Processing receipt for organizational learning...")
        print("  📊 Vendor: \(vendor), Payment: \(paymentMethod), Amount: \(amount.formatAsCurrency())")
        
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
        
        print("✅ ORGANIZATIONAL LEARNING: Receipt processed and intelligence updated!")
        
        // Trigger UI refresh for intelligence dashboards
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    /// Store receipt intelligence data for organizational learning (Phase 2C)
    private func storeReceiptIntelligenceData(
        vendor: String,
        paymentMethod: String,
        amount: Double,
        projectID: String
    ) async {
        guard let _ = currentOrganizationID else { return }
        
        // Create intelligence record with detailed categorization
        let intelligenceRecord = [
            "vendor": vendor,
            "paymentMethod": paymentMethod,
            "amount": amount,
            "projectID": projectID,
            "date": Date().timeIntervalSince1970,
            "organizationID": currentOrganizationID ?? "",
            "category": detectVendorCategory(from: vendor).rawValue,
            "paymentType": detectPaymentType(from: paymentMethod).rawValue
        ] as [String : Any]
        
        // Store in UserDefaults with organization-specific key
        let key = "receipt_intelligence_\(currentOrganizationID ?? "")"
        var existingRecords = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        existingRecords.append(intelligenceRecord)
        
        // Keep only the last 1000 records for performance
        if existingRecords.count > 1000 {
            existingRecords = Array(existingRecords.suffix(1000))
        }
        
        UserDefaults.standard.set(existingRecords, forKey: key)
        
        print("💾 Stored receipt intelligence: \(existingRecords.count) total records")
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
        
        print("🏢 ORGANIZATIONAL INSIGHTS: Updating enterprise intelligence metrics...")
        
        let totalVendors = vendorService.vendorsSortedByName.count
        let totalPaymentMethods = paymentMethodService.paymentMethodsSortedByName.count
        let totalSpending = organizationProjects.flatMap { $0.receipts }.reduce(0) { $0 + $1.amount }
        
        // Store updated insights in simple format
        let insights = [
            "totalVendors": totalVendors,
            "totalPaymentMethods": totalPaymentMethods,
            "totalSpending": totalSpending,
            "lastUpdated": Date().timeIntervalSince1970,
            "organizationID": orgID
        ] as [String : Any]
        
        UserDefaults.standard.set(insights, forKey: "org_insights_\(orgID)")
        
        print("  🎯 Organizational insights updated: \(totalVendors) vendors, \(totalPaymentMethods) payment methods, \(totalSpending.formatAsCurrency()) total spending")
    }
    
    // MARK: - Phase 2C: Historical Intelligence Population
    
    /// Scan all existing receipts and populate organizational intelligence
    func scanExistingReceiptsForIntelligence() async {
        guard let orgID = currentOrganizationID else {
            print("❌ Cannot scan receipts - no organization selected")
            return
        }
        
        print("🔍 PHASE 2C: Scanning existing receipts for organizational intelligence...")
        
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
                        print("  📊 Progress: \(processedCount)/\(totalReceiptCount) receipts processed")
                    }
                }
            }
        }
        
        // Update organizational insights with all data
        await updateOrganizationalInsights()
        
        await MainActor.run {
            print("✅ INTELLIGENCE POPULATION COMPLETE!")
            print("  📈 Processed \(processedCount) receipts across \(organizationProjects.count) projects")
            print("  🧠 Organizational intelligence is now fully populated!")
            
            // Trigger UI refresh for intelligence dashboards
            objectWillChange.send()
        }
    }
    
    /// Get organizational intelligence data for dashboard use
    func getOrganizationalIntelligenceData() -> [String: Any]? {
        guard let orgID = currentOrganizationID else { return nil }
        
        let insightsKey = "org_insights_\(orgID)"
        return UserDefaults.standard.dictionary(forKey: insightsKey)
    }
    
    /// Get receipt intelligence records for analysis
    func getReceiptIntelligenceRecords() -> [[String: Any]] {
        guard let orgID = currentOrganizationID else { return [] }
        
        let key = "receipt_intelligence_\(orgID)"
        return UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
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