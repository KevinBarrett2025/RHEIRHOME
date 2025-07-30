//
//  ProjectViewModel+Receipts.swift
//  RheirMultiplatformApp
//

import Foundation

@MainActor
extension ProjectViewModel {
    /// Append a new receipt to the current project.
    func addReceipt(_ receipt: Receipt) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id })
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
        
        // Update receipt with proper IDs
        var updatedReceipt = receipt
        updatedReceipt.vendorID = vendor.id
        updatedReceipt.paymentMethodID = paymentMethod.id
        
        // Update spending totals
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        vendorService.updateVendorSpending(vendorID: vendor.id, amount: amount)
        paymentMethodService.updatePaymentMethodSpending(paymentMethodID: paymentMethod.id, amount: amount)
        
        // Add receipt to project
        projects[idx].receipts.append(updatedReceipt)
        selectedProject = projects[idx]
        invalidateReceiptCache() // Invalidate cache when receipts change
        saveAllProjects()
        
        print("📝 Added receipt: \(receipt.vendor) - \(receipt.amount.formatAsCurrency()) (\(paymentMethod.displayName))")
    }

    /// Update an existing receipt in the current project.
    func updateReceipt(_ receipt: Receipt) {
        guard let sel  = selectedProject,
              let pIdx = projects.firstIndex(where: { $0.id == sel.id }),
              let rIdx = projects[pIdx].receipts.firstIndex(where: { $0.id == receipt.id })
        else { return }
        
        // Get old receipt for spending adjustment
        let oldReceipt = projects[pIdx].receipts[rIdx]
        
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
        
        // Update receipt with proper IDs
        var updatedReceipt = receipt
        updatedReceipt.vendorID = vendor.id
        updatedReceipt.paymentMethodID = paymentMethod.id
        
        // Adjust spending totals (remove old, add new)
        if let oldVendorID = oldReceipt.vendorID {
            let oldAmount = oldReceipt.isReturn ? -oldReceipt.amount : oldReceipt.amount
            vendorService.updateVendorSpending(vendorID: oldVendorID, amount: -oldAmount)
        }
        
        if let oldPaymentMethodID = oldReceipt.paymentMethodID {
            let oldAmount = oldReceipt.isReturn ? -oldReceipt.amount : oldReceipt.amount
            paymentMethodService.updatePaymentMethodSpending(paymentMethodID: oldPaymentMethodID, amount: -oldAmount)
        }
        
        let newAmount = receipt.isReturn ? -receipt.amount : receipt.amount
        vendorService.updateVendorSpending(vendorID: vendor.id, amount: newAmount)
        paymentMethodService.updatePaymentMethodSpending(paymentMethodID: paymentMethod.id, amount: newAmount)
        
        // Update receipt in project
        projects[pIdx].receipts[rIdx] = updatedReceipt
        selectedProject = projects[pIdx]
        invalidateReceiptCache() // Invalidate cache when receipts change
        saveAllProjects()
        
        print("✏️ Updated receipt: \(receipt.vendor) - \(receipt.amount.formatAsCurrency()) (\(paymentMethod.displayName))")
    }
    
    // MARK: - Helper Methods for Detection
    
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