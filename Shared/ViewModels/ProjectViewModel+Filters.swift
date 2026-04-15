// ProjectViewModel+Filters.swift
// RheirMultiplatformApp

import Foundation
import OSLog

// MARK: - Budget Category Mapping (Bridge to Enhanced System)

/// High-level budget categories for enhanced analytics
public enum EnhancedBudgetCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case materials = "Materials"
    case generalConditions = "General Conditions"
    case labor = "Labor"
    case contingency = "Contingency"
    
    public var id: Self { self }
    
    public var icon: String {
        switch self {
        case .materials: return "cube.box.fill"
        case .generalConditions: return "building.2.fill"
        case .labor: return "person.2.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
extension ProjectViewModel {
    private func logInvalidBudgetValue(_ calculation: String, value: Double) {
        Logger.project.warning(
            "\(calculation, privacy: .public) resulted in invalid value: \(value, privacy: .public)"
        )
    }

    private func logEnhancedBudgetMismatch(_ category: String, enhanced: Double, legacy: Double) {
        let enhancedFormatted = enhanced.formatAsCurrency()
        let legacyFormatted = legacy.formatAsCurrency()

        Logger.project.debug(
            "\(category, privacy: .public) enhanced spending diverged from legacy. Enhanced=\(enhancedFormatted, privacy: .public) Legacy=\(legacyFormatted, privacy: .public)"
        )
    }

    private func logLegacyBudgetFallback(_ calculation: String) {
        Logger.project.notice("\(calculation, privacy: .public) used legacy fallback.")
    }

    private var currentReceipts: [Receipt] {
        selectedProject?.receipts ?? []
    }

    // MARK: - Enhanced Budget Category Mapping
    
    /// Map a receipt category to its parent budget category
    private func mapToBudgetCategory(_ receiptCategory: ReceiptCategory) -> EnhancedBudgetCategory {
        switch receiptCategory {
        // Materials mapping
        case .material, .demolition, .sitework, .foundation, .framing, .roofing, .exterior,
             .electrical, .plumbing, .hvac, .insulation, .drywall, .flooring,
             .trim, .paint, .kitchen, .bathroom, .fixtures, .appliances,
             .landscaping, .lighting, .cabinetry, .countertops, .tile, .windows, .specialty:
            return .materials
            
        // General Conditions mapping
        case .general, .permits, .cleanup:
            return .generalConditions
            
        // Contingency mapping
        case .contingency:
            return .contingency
        }
    }
    
    /// Get all receipt categories that belong to a budget category
    private func getReceiptCategories(for budgetCategory: EnhancedBudgetCategory) -> [ReceiptCategory] {
        return ReceiptCategory.allCases.filter { receiptCategory in
            mapToBudgetCategory(receiptCategory) == budgetCategory
        }
    }

    // MARK: - Legacy Budget Calculations (Maintained for Backward Compatibility)

    /// Net spent (sales minus returns) on General Conditions receipts
    private var receiptGeneralConditions: Double {
        let result = currentReceipts
            .filter { $0.category == .general }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("receiptGeneralConditions", value: result)
            return 0
        }
        return result
    }

    /// Net spent (sales minus returns) on Materials receipts
    private var receiptMaterials: Double {
        let result = currentReceipts
            .filter { $0.category == .material }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("receiptMaterials", value: result)
            return 0
        }
        return result
    }

    /// Net spent (sales minus returns) on Contingency receipts
    private var receiptContingency: Double {
        let result = currentReceipts
            .filter { $0.category == .contingency }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("receiptContingency", value: result)
            return 0
        }
        return result
    }

    /// Total net receipts spending across all categories
    var totalReceiptsNet: Double {
        let result = receiptGeneralConditions + receiptMaterials + receiptContingency
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("totalReceiptsNet", value: result)
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the "Labor" category
    private var hoursLabor: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "Labor" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("hoursLabor", value: result)
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the "General Conditions" category
    private var hoursGeneralConditions: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "General Conditions" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("hoursGeneralConditions", value: result)
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the "Contingency" category
    private var hoursContingency: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "Contingency" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("hoursContingency", value: result)
            return 0
        }
        return result
    }

    // MARK: — Enhanced Budget Calculations (New Category System)

    /// Enhanced calculation for Materials spending using detailed categories
    var enhancedSpentMaterials: Double {
        guard let project = selectedProject else { return 0 }
        
        let materialCategories = getReceiptCategories(for: .materials)
        
        let spending = project.receipts.reduce(0.0) { total, receipt in
            // Check if receipt category maps to materials
            if materialCategories.contains(receipt.category) {
                // Calculate from items if available
                if !receipt.items.isEmpty {
                    let itemsTotal = receipt.items.reduce(0.0) { itemTotal, item in
                        if materialCategories.contains(item.category) {
                            let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                            return itemTotal + amount
                        }
                        return itemTotal
                    }
                    return total + itemsTotal
                } else {
                    // Use receipt-level amount for legacy receipts
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    return total + amount
                }
            }
            return total
        }
        
        guard spending.isFinite else {
            logInvalidBudgetValue("enhancedSpentMaterials", value: spending)
            return 0
        }
        return spending
    }

    /// Enhanced calculation for General Conditions spending using detailed categories
    var enhancedSpentGeneralConditions: Double {
        guard let project = selectedProject else { return 0 }
        
        let generalCategories = getReceiptCategories(for: .generalConditions)
        
        let receiptSpending = project.receipts.reduce(0.0) { total, receipt in
            // Check if receipt category maps to general conditions
            if generalCategories.contains(receipt.category) {
                // Calculate from items if available
                if !receipt.items.isEmpty {
                    let itemsTotal = receipt.items.reduce(0.0) { itemTotal, item in
                        if generalCategories.contains(item.category) {
                            let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                            return itemTotal + amount
                        }
                        return itemTotal
                    }
                    return total + itemsTotal
                } else {
                    // Use receipt-level amount for legacy receipts
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    return total + amount
                }
            }
            return total
        }
        
        // Add labor hours for general conditions
        let totalSpending = receiptSpending + hoursGeneralConditions
        
        guard totalSpending.isFinite else {
            logInvalidBudgetValue("enhancedSpentGeneralConditions", value: totalSpending)
            return 0
        }
        return totalSpending
    }

    /// Enhanced calculation for Contingency spending using detailed categories
    var enhancedSpentContingency: Double {
        guard let project = selectedProject else { return 0 }
        
        let contingencyCategories = getReceiptCategories(for: .contingency)
        
        let receiptSpending = project.receipts.reduce(0.0) { total, receipt in
            // Check if receipt category maps to contingency
            if contingencyCategories.contains(receipt.category) {
                // Calculate from items if available
                if !receipt.items.isEmpty {
                    let itemsTotal = receipt.items.reduce(0.0) { itemTotal, item in
                        if contingencyCategories.contains(item.category) {
                            let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                            return itemTotal + amount
                        }
                        return itemTotal
                    }
                    return total + itemsTotal
                } else {
                    // Use receipt-level amount for legacy receipts
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    return total + amount
                }
            }
            return total
        }
        
        // Add labor hours for contingency
        let totalSpending = receiptSpending + hoursContingency
        
        guard totalSpending.isFinite else {
            logInvalidBudgetValue("enhancedSpentContingency", value: totalSpending)
            return 0
        }
        return totalSpending
    }

    /// Get detailed spending breakdown for a specific budget category
    func getDetailedSpendingBreakdown(for budgetCategory: EnhancedBudgetCategory) -> [ReceiptCategory: Double] {
        guard let project = selectedProject else { return [:] }
        
        let relevantCategories = Set(getReceiptCategories(for: budgetCategory))
        var breakdown: [ReceiptCategory: Double] = [:]
        
        for receipt in project.receipts {
            if !receipt.items.isEmpty {
                // Use item-level categorization
                for item in receipt.items {
                    if relevantCategories.contains(item.category) {
                        let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                        guard amount.isFinite else { continue }
                        breakdown[item.category, default: 0] += amount
                    }
                }
            } else {
                // Fall back to receipt-level category for legacy receipts
                if relevantCategories.contains(receipt.category) {
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    guard amount.isFinite else { continue }
                    breakdown[receipt.category, default: 0] += amount
                }
            }
        }
        
        // Remove zero or negative amounts for cleaner display
        return breakdown.filter { $0.value > 0 }
    }

    /// Get top spending detailed categories for a budget category, sorted by amount
    func getTopSpendingCategories(for budgetCategory: EnhancedBudgetCategory, limit: Int = 10) -> [(ReceiptCategory, Double)] {
        let breakdown = getDetailedSpendingBreakdown(for: budgetCategory)
        return breakdown
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Get spending breakdown by category group for UI organization
    func getSpendingByGroup() -> [CategoryGroup: Double] {
        guard let project = selectedProject else { return [:] }
        
        var groupSpending: [CategoryGroup: Double] = [:]
        
        for receipt in project.receipts {
            if !receipt.items.isEmpty {
                // Use item-level categorization
                for item in receipt.items {
                    let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                    guard amount.isFinite else { continue }
                    let group = item.category.categoryGroup
                    groupSpending[group, default: 0] += amount
                }
            } else {
                // Fall back to receipt-level category for legacy receipts
                let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                guard amount.isFinite else { continue }
                let group = receipt.category.categoryGroup
                groupSpending[group, default: 0] += amount
            }
        }
        
        return groupSpending.filter { $0.value > 0 }
    }

    /// Calculate percentage of budget used for a specific budget category
    func getBudgetUsagePercentage(for budgetCategory: EnhancedBudgetCategory) -> Double {
        guard let project = selectedProject else { return 0 }
        
        let spent: Double
        let budgeted: Double
        
        switch budgetCategory {
        case .materials:
            spent = enhancedSpentMaterials
            budgeted = project.materialCost
        case .generalConditions:
            spent = enhancedSpentGeneralConditions
            budgeted = project.generalConditions
        case .labor:
            spent = spentLabor
            budgeted = project.laborCost
        case .contingency:
            spent = enhancedSpentContingency
            budgeted = project.contingency
        }
        
        guard budgeted > 0, spent.isFinite, budgeted.isFinite else { return 0 }
        return (spent / budgeted) * 100
    }

    // MARK: — Public spent properties (Legacy + Enhanced - Backward Compatible)

    /// Net spent on General Conditions (enhanced calculation with fallback to legacy)
    var spentGeneralConditions: Double {
        // Use enhanced calculation, but validate against legacy for consistency
        let enhanced = enhancedSpentGeneralConditions
        let legacy = receiptGeneralConditions + hoursGeneralConditions
        
        // For debugging: log differences if significant
        if abs(enhanced - legacy) > 0.01 {
            logEnhancedBudgetMismatch("General Conditions", enhanced: enhanced, legacy: legacy)
        }
        
        // Prefer enhanced calculation
        guard enhanced.isFinite else {
            logLegacyBudgetFallback("spentGeneralConditions")
            return legacy
        }
        return enhanced
    }

    /// Net spent on Materials (enhanced calculation with fallback to legacy)
    var spentMaterials: Double {
        // Use enhanced calculation, but validate against legacy for consistency
        let enhanced = enhancedSpentMaterials
        let legacy = receiptMaterials
        
        // For debugging: log differences if significant
        if abs(enhanced - legacy) > 0.01 {
            logEnhancedBudgetMismatch("Materials", enhanced: enhanced, legacy: legacy)
        }
        
        // Prefer enhanced calculation
        guard enhanced.isFinite else {
            logLegacyBudgetFallback("spentMaterials")
            return legacy
        }
        return enhanced
    }

    /// Net spent on Labor (hours only - no change needed)
    var spentLabor: Double {
        let result = hoursLabor
        
        // Ensure final result is valid
        guard result.isFinite else {
            logInvalidBudgetValue("spentLabor", value: result)
            return 0
        }
        return result
    }

    /// Net spent on Contingency (enhanced calculation with fallback to legacy)
    var spentContingency: Double {
        // Use enhanced calculation, but validate against legacy for consistency
        let enhanced = enhancedSpentContingency
        let legacy = receiptContingency + hoursContingency
        
        // For debugging: log differences if significant
        if abs(enhanced - legacy) > 0.01 {
            logEnhancedBudgetMismatch("Contingency", enhanced: enhanced, legacy: legacy)
        }
        
        // Prefer enhanced calculation
        guard enhanced.isFinite else {
            logLegacyBudgetFallback("spentContingency")
            return legacy
        }
        return enhanced
    }
    
    // MARK: - Team and Labor Calculations
    
    /// Calculate total labor cost for the current selected project based on team member rates
    func calculateTotalLaborCost() -> Double {
        guard let project = selectedProject else { return 0.0 }
        
        // Start with actual labor costs from logged hours
        let actualLaborCost = spentLabor
        
        // Add estimates for assigned team members if minimal hours logged
        let assignedMemberIDs = Set(project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) })
        let assignedMembers = teamMembers.filter { assignedMemberIDs.contains($0.id) }
        
        let estimatedCost = assignedMembers.reduce(0.0) { total, member in
            let rate = member.defaultRate?.rate ?? 25.0
            let estimatedHours = project.loggedHours.isEmpty ? 40.0 : 0.0 // Only estimate if no hours logged
            return total + (rate * estimatedHours)
        }
        
        return max(actualLaborCost, estimatedCost)
    }
    
    /// Calculate total hours logged for the current selected project
    func calculateTotalHours() -> Int {
        guard let project = selectedProject else { return 0 }
        
        let totalHours = project.loggedHours.reduce(0.0) { total, hour in
            guard hour.hours.isFinite else { return total }
            return total + hour.hours
        }
        
        return Int(totalHours)
    }

    // MARK: - Enhanced Analytics Methods

    /// Get spending trend over time for a budget category  
    func getSpendingTrend(for budgetCategory: EnhancedBudgetCategory, days: Int = 30) -> [(Date, Double)] {
        guard let project = selectedProject else { return [] }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let relevantReceipts = project.receipts.filter { receipt in
            receipt.date >= startDate && receipt.date <= endDate
        }
        
        let relevantCategories = Set(getReceiptCategories(for: budgetCategory))
        
        // Group by day and calculate spending
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var dailySpending: [String: Double] = [:]
        
        for receipt in relevantReceipts {
            let dateKey = dateFormatter.string(from: receipt.date)
            var dailyAmount: Double = 0
            
            if !receipt.items.isEmpty {
                // Use item-level categorization
                for item in receipt.items {
                    if relevantCategories.contains(item.category) {
                        let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                        dailyAmount += amount
                    }
                }
            } else {
                // Fall back to receipt-level category for legacy receipts
                if relevantCategories.contains(receipt.category) {
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    dailyAmount += amount
                }
            }
            
            dailySpending[dateKey, default: 0] += dailyAmount
        }
        
        // Convert back to dates and sort
        return dailySpending.compactMap { (dateString, amount) -> (Date, Double)? in
            guard let date = dateFormatter.date(from: dateString) else { return nil }
            return (date, amount)
        }.sorted { $0.0 < $1.0 }
    }

    /// Calculate projected budget overrun/underrun for a category
    func getProjectedBudgetStatus(for budgetCategory: EnhancedBudgetCategory) -> (projected: Double, variance: Double, isOverBudget: Bool) {
        guard let project = selectedProject else { return (0, 0, false) }
        
        let currentSpent: Double
        let budgeted: Double
        
        switch budgetCategory {
        case .materials:
            currentSpent = enhancedSpentMaterials
            budgeted = project.materialCost
        case .generalConditions:
            currentSpent = enhancedSpentGeneralConditions
            budgeted = project.generalConditions
        case .labor:
            currentSpent = spentLabor
            budgeted = project.laborCost
        case .contingency:
            currentSpent = enhancedSpentContingency
            budgeted = project.contingency
        }
        
        // Simple projection based on timeline completion
        let totalDays = project.endDate.timeIntervalSince(project.startDate) / (24 * 60 * 60)
        let elapsedDays = Date().timeIntervalSince(project.startDate) / (24 * 60 * 60)
        let completionPercentage = max(0.1, min(1.0, elapsedDays / totalDays)) // Avoid division by zero
        
        let projectedTotal = currentSpent / completionPercentage
        let variance = projectedTotal - budgeted
        let isOverBudget = variance > 0
        
        return (projectedTotal, variance, isOverBudget)
    }

    // MARK: - Drilldown Helper Methods

    /// Get detailed breakdown text for display in UI
    func getDetailedBreakdownText(for budgetCategory: EnhancedBudgetCategory) -> String {
        let breakdown = getDetailedSpendingBreakdown(for: budgetCategory)
        let topCategories = getTopSpendingCategories(for: budgetCategory, limit: 5)
        
        if topCategories.isEmpty {
            return "No spending in this category yet."
        }
        
        var text = "\(budgetCategory.rawValue) Breakdown:\n\n"
        
        for (index, (category, amount)) in topCategories.enumerated() {
            text += "\(index + 1). \(category.rawValue): \(amount.formatAsCurrency())\n"
        }
        
        let totalSpent = breakdown.values.reduce(0, +)
        text += "\nTotal: \(totalSpent.formatAsCurrency())"
        
        return text
    }

    /// Get category spending as percentage of total project spending
    func getCategorySpendingPercentages() -> [ReceiptCategory: Double] {
        guard let project = selectedProject else { return [:] }
        
        let totalSpent = calculateTotalSpent(for: project)
        guard totalSpent > 0 else { return [:] }
        
        var categoryTotals: [ReceiptCategory: Double] = [:]
        
        for receipt in project.receipts {
            if !receipt.items.isEmpty {
                for item in receipt.items {
                    let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                    categoryTotals[item.category, default: 0] += amount
                }
            } else {
                let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                categoryTotals[receipt.category, default: 0] += amount
            }
        }
        
        // Convert to percentages
        return categoryTotals.mapValues { ($0 / totalSpent) * 100 }
    }

    /// Check if enhanced calculations differ significantly from legacy
    func validateEnhancedCalculations() -> String {
        guard selectedProject != nil else { return "No project selected" }
        
        let materialsEnhanced = enhancedSpentMaterials
        let materialsLegacy = receiptMaterials
        let materialsDiff = abs(materialsEnhanced - materialsLegacy)
        
        let generalEnhanced = enhancedSpentGeneralConditions
        let generalLegacy = receiptGeneralConditions + hoursGeneralConditions
        let generalDiff = abs(generalEnhanced - generalLegacy)
        
        let contingencyEnhanced = enhancedSpentContingency
        let contingencyLegacy = receiptContingency + hoursContingency
        let contingencyDiff = abs(contingencyEnhanced - contingencyLegacy)
        
        return """
        Enhanced Calculation Validation:
        
        Materials:
        - Enhanced: \(materialsEnhanced.formatAsCurrency())
        - Legacy: \(materialsLegacy.formatAsCurrency()) 
        - Difference: \(materialsDiff.formatAsCurrency())
        
        General Conditions:
        - Enhanced: \(generalEnhanced.formatAsCurrency())
        - Legacy: \(generalLegacy.formatAsCurrency())
        - Difference: \(generalDiff.formatAsCurrency())
        
        Contingency:
        - Enhanced: \(contingencyEnhanced.formatAsCurrency())
        - Legacy: \(contingencyLegacy.formatAsCurrency())
        - Difference: \(contingencyDiff.formatAsCurrency())
        
        Status: \(materialsDiff < 0.01 && generalDiff < 0.01 && contingencyDiff < 0.01 ? "✅ VALIDATED" : "⚠️ DIFFERENCES FOUND")
        """
    }
    
    // MARK: - Helper Methods for Project Calculations
    
    /// Calculate total spent for a given project (all categories combined)
    private func calculateTotalSpent(for project: Project) -> Double {
        let receiptTotal = project.receipts.reduce(0.0) { total, receipt in
            if !receipt.items.isEmpty {
                // Use item-level totals
                let itemsTotal = receipt.items.reduce(0.0) { itemTotal, item in
                    let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                    return itemTotal + amount
                }
                return total + itemsTotal
            } else {
                // Use receipt-level amount for legacy receipts
                let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                return total + amount
            }
        }
        
        let laborTotal = project.loggedHours.reduce(0.0) { total, hour in
            let cost = hour.hours * hour.rate
            guard cost.isFinite else { return total }
            return total + cost
        }
        
        let totalSpent = receiptTotal + laborTotal
        
        guard totalSpent.isFinite else {
            logInvalidBudgetValue("calculateTotalSpent", value: totalSpent)
            return 0
        }
        return totalSpent
    }
}
