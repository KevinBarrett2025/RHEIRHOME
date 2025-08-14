import Foundation
import SwiftUI

// MARK: - ProjectViewModel Budget Integration Extension for Phase 2I Step 4

extension ProjectViewModel {
    
    // MARK: - Real-Time Budget Analysis Methods
    
    /// Calculate comprehensive budget impact for receipt entry
    func calculateBudgetImpact(
        project: Project,
        category: ReceiptCategory,
        amount: Double,
        isReturn: Bool = false
    ) -> BudgetImpactAnalysis {
        
        let effectiveAmount = isReturn ? -amount : amount
        
        // Calculate current totals
        let currentTotalSpent = calculateTotalSpent(for: project)
        let currentCategorySpent = calculateCategorySpent(for: project, category: category)
        
        // Calculate budgets
        let totalBudget = project.totalBudget
        let categoryBudget = getCategoryBudget(for: project, category: category)
        
        // Calculate after amounts
        let afterTotalSpent = currentTotalSpent + effectiveAmount
        let afterCategorySpent = currentCategorySpent + effectiveAmount
        
        // Calculate remaining budgets
        let categoryRemaining = categoryBudget - currentCategorySpent
        
        return BudgetImpactAnalysis(
            beforeAmount: currentTotalSpent,
            afterAmount: afterTotalSpent,
            impactAmount: effectiveAmount,
            totalBudget: totalBudget,
            categoryBudgetRemaining: categoryRemaining,
            willExceedBudget: afterTotalSpent > totalBudget,
            willExceedCategoryBudget: afterCategorySpent > categoryBudget
        )
    }
    
    /// Generate smart category suggestions based on budget status and context
    func generateSmartCategorySuggestions(
        for project: Project,
        amount: Double,
        vendor: Vendor? = nil,
        teamMember: TeamMember? = nil
    ) -> [SmartCategorySuggestion] {
        
        var suggestions: [SmartCategorySuggestion] = []
        let categories: [ReceiptCategory] = [.material, .general, .contingency]
        
        for category in categories {
            let categoryBudget = getCategoryBudget(for: project, category: category)
            let categorySpent = calculateCategorySpent(for: project, category: category)
            let remaining = categoryBudget - categorySpent
            
            var confidence: Double = 0.4 // Base confidence
            var reasons: [String] = []
            
            // Budget availability factor
            if remaining >= amount {
                confidence += 0.3
                reasons.append("Sufficient budget (\(remaining.formatAsCurrency()) remaining)")
            } else if remaining > 0 {
                confidence += 0.1
                reasons.append("Limited budget (\(remaining.formatAsCurrency()) remaining)")
            } else {
                confidence -= 0.2
                reasons.append("Over budget by \((amount - remaining).formatAsCurrency()))")
            }
            
            // Vendor type matching
            if let vendor = vendor {
                if vendorCategoryMatches(vendor: vendor, category: category) {
                    confidence += 0.4
                    reasons.append("Vendor type matches category")
                }
            }
            
            // Amount pattern matching
            if amountMatchesCategoryPattern(amount: amount, category: category, project: project) {
                confidence += 0.2
                reasons.append("Amount typical for category")
            }
            
            // Team member spending patterns
            if let teamMember = teamMember {
                if teamMemberFavorsCategory(teamMember: teamMember, category: category, project: project) {
                    confidence += 0.15
                    reasons.append("Team member commonly uses this category")
                }
            }
            
            // Historical frequency
            let categoryReceipts = project.receipts.filter { $0.category == category }
            if !categoryReceipts.isEmpty {
                let frequency = Double(categoryReceipts.count) / Double(project.receipts.count)
                confidence += frequency * 0.2
                if frequency > 0.3 {
                    reasons.append("Frequently used category")
                }
            }
            
            if confidence > 0.3 {
                suggestions.append(SmartCategorySuggestion(
                    category: category,
                    confidence: min(confidence, 1.0),
                    reason: reasons.joined(separator: " • "),
                    budgetRemaining: remaining,
                    willExceedBudget: amount > remaining
                ))
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    /// Generate budget warnings based on impact analysis
    func generateBudgetWarnings(
        for project: Project,
        impact: BudgetImpactAnalysis,
        category: ReceiptCategory,
        amount: Double
    ) -> [BudgetWarning] {
        
        var warnings: [BudgetWarning] = []
        
        // Critical: Total project budget exceeded
        if impact.willExceedBudget {
            let overage = impact.afterAmount - impact.totalBudget
            warnings.append(BudgetWarning(
                id: UUID(),
                severity: .critical,
                title: "Project Budget Exceeded",
                message: "This receipt will exceed the total project budget by \(overage.formatAsCurrency()). Consider reallocating funds or adjusting the budget.",
                category: nil,
                suggestedAction: .adjustBudget
            ))
        }
        
        // High: Category budget exceeded
        if impact.willExceedCategoryBudget {
            let overage = amount - impact.categoryBudgetRemaining
            warnings.append(BudgetWarning(
                id: UUID(),
                severity: .high,
                title: "\(category.rawValue.capitalized) Budget Exceeded",
                message: "This receipt will exceed the \(category.rawValue) budget by \(overage.formatAsCurrency()). The overage will be allocated from contingency funds.",
                category: category,
                suggestedAction: .useContingency
            ))
        } else if impact.categoryBudgetRemaining < amount * 2 && impact.categoryBudgetRemaining > amount {
            // Medium: Approaching category budget limit
            warnings.append(BudgetWarning(
                id: UUID(),
                severity: .medium,
                title: "Approaching \(category.rawValue.capitalized) Budget Limit",
                message: "Only \(impact.categoryBudgetRemaining.formatAsCurrency()) remaining in \(category.rawValue) budget. Consider monitoring future expenses.",
                category: category,
                suggestedAction: .monitor
            ))
        }
        
        // Medium: High project budget utilization
        let budgetUtilization = impact.afterAmount / impact.totalBudget
        if budgetUtilization > 0.85 && !impact.willExceedBudget {
            warnings.append(BudgetWarning(
                id: UUID(),
                severity: .medium,
                title: "High Budget Utilization",
                message: "This receipt will bring the project to \(Int(budgetUtilization * 100))% of total budget. Consider reviewing remaining project needs.",
                category: nil,
                suggestedAction: .monitor
            ))
        }
        
        // Low: Large single expense warning
        if amount > (impact.totalBudget * 0.1) {
            warnings.append(BudgetWarning(
                id: UUID(),
                severity: .low,
                title: "Large Expense",
                message: "This is a significant expense (\(Int((amount / impact.totalBudget) * 100))% of total budget). Verify all details are correct.",
                category: category,
                suggestedAction: .monitor
            ))
        }
        
        return warnings
    }
    
    /// Generate team member spending context for receipt entry
    func generateTeamMemberSpendingContext(
        teamMember: TeamMember,
        project: Project
    ) -> TeamMemberSpendingContext {
        
        let memberReceipts = project.receipts.filter { $0.teamMemberID == teamMember.id }
        let totalSpent = memberReceipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
        let averageAmount = memberReceipts.isEmpty ? 0 : totalSpent / Double(memberReceipts.count)
        let lastReceiptDate = memberReceipts.map { $0.date }.max()
        
        // Calculate top categories
        let categoryTotals = Dictionary(grouping: memberReceipts) { $0.category }
            .mapValues { receipts in receipts.reduce(0) { $0 + $1.amount } }
        let topCategories = categoryTotals.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        
        return TeamMemberSpendingContext(
            teamMember: teamMember,
            totalSpentOnProject: totalSpent,
            receiptCount: memberReceipts.count,
            lastReceiptDate: lastReceiptDate,
            averageReceiptAmount: averageAmount,
            topCategories: Array(topCategories)
        )
    }
    
    // MARK: - Budget Calculation Helper Methods
    
    /// Calculate total spent for a specific category in a project
    func calculateCategorySpent(for project: Project, category: ReceiptCategory) -> Double {
        return project.receipts
            .filter { $0.category == category }
            .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    }
    
    /// Get budget amount for a specific category
    func getCategoryBudget(for project: Project, category: ReceiptCategory) -> Double {
        switch category {
        case .general: return project.generalConditions
        case .material: return project.materialCost
        case .contingency: return project.contingency
        default: return project.materialCost
        }
    }
    
    /// Get spending breakdown by category for budget analysis
    func getDetailedSpendingBreakdown(for category: EnhancedBudgetCategory) -> [(ReceiptCategory, Double)] {
        guard let project = selectedProject else { return [] }
        
        let relevantReceipts = project.receipts.filter { receipt in
            switch category {
            case .generalConditions:
                return receipt.category == .general
            case .materials:
                return receipt.category == .material
            case .labor:
                return false // Labor is calculated from work hours, not receipts
            case .contingency:
                return receipt.category == .contingency
            }
        }
        
        let breakdown = Dictionary(grouping: relevantReceipts) { $0.category }
            .mapValues { receipts in
                receipts.reduce(0) { acc, receipt in
                    acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
                }
            }
        
        return breakdown.sorted { $0.value > $1.value }
    }
    
    // MARK: - Smart Suggestion Helper Methods
    
    /// Check if vendor category matches receipt category
    private func vendorCategoryMatches(vendor: Vendor, category: ReceiptCategory) -> Bool {
        switch (vendor.category, category) {
        case (.hardware, .material), (.lumber, .material), (.electrical, .material),
             (.plumbing, .material), (.paint, .material):
            return true
        case (.office, .general), (.professional, .general):
            return true
        case (.rental, .general):
            return true
        default:
            return false
        }
    }
    
    /// Check if amount matches typical spending pattern for category
    private func amountMatchesCategoryPattern(amount: Double, category: ReceiptCategory, project: Project) -> Bool {
        let categoryReceipts = project.receipts.filter { $0.category == category }
        guard !categoryReceipts.isEmpty else { return false }
        
        let amounts = categoryReceipts.map { $0.amount }
        let averageAmount = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - averageAmount, 2) }.reduce(0, +) / Double(amounts.count)
        let standardDeviation = sqrt(variance)
        
        // Check if amount is within 1 standard deviation of average
        return abs(amount - averageAmount) <= standardDeviation
    }
    
    /// Check if team member commonly uses a specific category
    private func teamMemberFavorsCategory(teamMember: TeamMember, category: ReceiptCategory, project: Project) -> Bool {
        let memberReceipts = project.receipts.filter { $0.teamMemberID == teamMember.id }
        guard !memberReceipts.isEmpty else { return false }
        
        let categoryCount = memberReceipts.filter { $0.category == category }.count
        let percentage = Double(categoryCount) / Double(memberReceipts.count)
        
        return percentage > 0.3 // Team member uses this category more than 30% of the time
    }
    
    // MARK: - Enhanced Analytics Methods
    
    /// Get vendor spending analytics for organization intelligence
    func getTopVendorsBySpending(limit: Int = 10) -> [(vendor: String, amount: Double)] {
        let allReceipts = organizationProjects.flatMap { $0.receipts }
        let vendorTotals = Dictionary(grouping: allReceipts) { $0.vendor.lowercased() }
            .mapValues { receipts in
                receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            }
        
        return vendorTotals.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (vendor: $0.key.capitalized, amount: $0.value) }
    }
    
    /// Get payment method usage analytics for organization intelligence
    func getTopPaymentMethodsByUsage(limit: Int = 5) -> [(paymentMethod: String, count: Int, amount: Double)] {
        let allReceipts = organizationProjects.flatMap { $0.receipts }
        let paymentMethodGroups = Dictionary(grouping: allReceipts) { $0.paymentMethod.lowercased() }
        
        return paymentMethodGroups.map { (method, receipts) in
            let totalAmount = receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            return (paymentMethod: method.capitalized, count: receipts.count, amount: totalAmount)
        }
        .sorted { $0.count > $1.count }
        .prefix(limit)
        .map { $0 }
    }
    
    /// Get organizational intelligence data for dashboard
    func getOrganizationalIntelligenceData() -> [String: Any]? {
        guard let orgID = currentOrganizationID else { return nil }
        
        let allReceipts = organizationProjects.flatMap { $0.receipts }
        let totalSpending = allReceipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
        let receiptCount = allReceipts.count
        let averageReceiptAmount = receiptCount > 0 ? totalSpending / Double(receiptCount) : 0
        
        return [
            "organizationID": orgID,
            "totalSpending": totalSpending,
            "receiptCount": receiptCount,
            "averageReceiptAmount": averageReceiptAmount,
            "activeProjects": organizationProjects.filter { $0.status == .active }.count,
            "completedProjects": organizationProjects.filter { $0.status == .completed }.count,
            "teamMemberCount": teamMembers.count,
            "vendorCount": vendorService.vendorsSortedByName.count,
            "paymentMethodCount": paymentMethodService.paymentMethodsSortedByName.count,
            "lastUpdated": Date().timeIntervalSince1970
        ]
    }
    
    /// Get receipt intelligence records for analytics
    func getReceiptIntelligenceRecords() -> [[String: Any]] {
        let allReceipts = organizationProjects.flatMap { $0.receipts }
        
        return allReceipts.map { receipt in
            [
                "id": receipt.id.uuidString,
                "vendor": receipt.vendor,
                "amount": receipt.amount,
                "category": receipt.category.rawValue,
                "paymentMethod": receipt.paymentMethod,
                "date": receipt.date.timeIntervalSince1970,
                "projectID": receipt.projectID?.uuidString ?? "",
                "teamMemberID": receipt.teamMemberID?.uuidString ?? ""
            ]
        }
    }
    
    /// Scan existing receipts to populate organizational intelligence
    func scanExistingReceiptsForIntelligence() async {
        print("🧠 INTELLIGENCE: Scanning \(organizationProjects.flatMap { $0.receipts }.count) receipts for organizational intelligence...")
        
        let allReceipts = organizationProjects.flatMap { $0.receipts }
        var intelligenceRecords: [[String: Any]] = []
        
        for receipt in allReceipts {
            let record: [String: Any] = [
                "id": receipt.id.uuidString,
                "vendor": receipt.vendor,
                "amount": receipt.amount,
                "category": receipt.category.rawValue,
                "paymentMethod": receipt.paymentMethod,
                "date": receipt.date.timeIntervalSince1970,
                "projectID": receipt.projectID?.uuidString ?? "",
                "teamMemberID": receipt.teamMemberID?.uuidString ?? "",
                "isReturn": receipt.isReturn,
                "notes": receipt.notes
            ]
            intelligenceRecords.append(record)
        }
        
        // Store intelligence data (in a real implementation, this would go to CloudKit)
        if let orgID = currentOrganizationID {
            let intelligenceData: [String: Any] = [
                "records": intelligenceRecords,
                "totalSpending": allReceipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) },
                "lastUpdated": Date().timeIntervalSince1970,
                "recordCount": intelligenceRecords.count
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: intelligenceData) {
                UserDefaults.standard.set(data, forKey: "intelligence_\(orgID)")
            }
        }
        
        print("✅ INTELLIGENCE: Scanned and stored intelligence for \(allReceipts.count) receipts")
    }
    
    // MARK: - CloudKit Team Member Integration Methods
    
    /// Get team members working on current project with receipt activity
    func getActiveProjectTeamMembers() -> [TeamMember] {
        guard let project = selectedProject else { return [] }
        
        // Get team members who have submitted receipts for this project
        let receiptMemberIDs = project.receipts.compactMap { $0.teamMemberID }
        let activeReceiptMembers = teamMembers.filter { member in
            receiptMemberIDs.contains(member.id)
        }
        
        // Get explicitly assigned team members
        let assignedMemberIDs = project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) }
        let assignedMembers = teamMembers.filter { member in
            assignedMemberIDs.contains(member.id)
        }
        
        // Combine and deduplicate
        let allActiveMembers = Set(activeReceiptMembers + assignedMembers)
        
        return Array(allActiveMembers).sorted { $0.name < $1.name }
    }
    
    /// Update team member activity based on receipt submission
    func updateTeamMemberActivityFromReceipt(_ receipt: Receipt) {
        guard let teamMemberID = receipt.teamMemberID,
              let member = teamMembers.first(where: { $0.id == teamMemberID }) else {
            return
        }
        
        var updatedMember = member
        updatedMember.lastReceiptDate = receipt.date
        updatedMember.totalReceiptSpending += receipt.amount
        
        // Update employment status to active if they were between projects
        if updatedMember.employmentStatus == .betweenProjects {
            updatedMember.employmentStatus = .active
        }
        
        updateTeamMemberInOrganization(updatedMember)
        
        print("👥 Updated team member activity: \(member.name) - \(receipt.amount.formatAsCurrency())")
    }
}

// MARK: - Enhanced Budget Category Enum
enum EnhancedBudgetCategory: String, CaseIterable {
    case generalConditions = "General Conditions"
    case materials = "Materials"
    case labor = "Labor"
    case contingency = "Contingency"
    
    var color: Color {
        switch self {
        case .generalConditions: return .blue
        case .materials: return .orange
        case .labor: return .green
        case .contingency: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .generalConditions: return "building.fill"
        case .materials: return "hammer.fill"
        case .labor: return "person.2.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
}