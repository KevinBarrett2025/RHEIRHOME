import Foundation

// MARK: - Intelligence Scan Results

struct IntelligenceScanResult {
    let success: Bool
    let message: String
    let scannedReceipts: Int
    
    var isSuccessful: Bool {
        return success && scannedReceipts > 0
    }
}

// MARK: - Vendor Intelligence Models

struct VendorUsageData: Codable {
    let vendorName: String
    let amount: Double
    let projectID: String
    let date: Date
    let category: VendorCategory
    let id = UUID()
}

// MARK: - Payment Method Intelligence Models

struct PaymentMethodUsageData: Codable {
    let paymentMethodName: String
    let amount: Double
    let projectID: String
    let date: Date
    let type: PaymentType
    let id = UUID()
}

// MARK: - Organizational Insights Models

struct OrganizationalInsights: Codable {
    let totalVendors: Int
    let totalPaymentMethods: Int
    let totalSpending: Double
    let lastUpdated: Date
    let id = UUID()
    
    /// Get formatted spending amount
    var formattedTotalSpending: String {
        return totalSpending.formatAsCurrency()
    }
    
    /// Get spending summary
    var spendingSummary: String {
        return """
        Organization Analytics:
        • Vendors: \(totalVendors)
        • Payment Methods: \(totalPaymentMethods)  
        • Total Spending: \(formattedTotalSpending)
        • Last Updated: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))
        """
    }
}

// MARK: - Intelligence Analytics Extensions

extension ProjectViewModel {
    
    /// Get vendor intelligence analytics for the current organization
    func getVendorIntelligenceAnalytics() -> VendorIntelligenceAnalytics? {
        guard let orgID = currentOrganizationID else { return nil }
        
        let vendorData = loadVendorIntelligenceData(orgID: orgID)
        
        // Calculate top vendors by spending
        let vendorSpending = Dictionary(grouping: vendorData) { $0.vendorName }
            .mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        
        let topVendors = vendorSpending.sorted { $0.value > $1.value }
            .prefix(10)
            .map { VendorSpendingSummary(name: $0.key, totalSpent: $0.value) }
        
        // Calculate most frequent vendors
        let vendorFrequency = Dictionary(grouping: vendorData) { $0.vendorName }
            .mapValues { $0.count }
        
        let mostFrequentVendors = vendorFrequency.sorted { $0.value > $1.value }
            .prefix(10)
            .map { VendorFrequencySummary(name: $0.key, transactionCount: $0.value) }
        
        return VendorIntelligenceAnalytics(
            topVendorsBySpending: topVendors,
            mostFrequentVendors: mostFrequentVendors,
            totalTransactions: vendorData.count,
            totalSpending: vendorSpending.values.reduce(0, +)
        )
    }
    
    /// Get payment method intelligence analytics for the current organization
    func getPaymentMethodIntelligenceAnalytics() -> PaymentMethodIntelligenceAnalytics? {
        guard let orgID = currentOrganizationID else { return nil }
        
        let paymentData = loadPaymentMethodIntelligenceData(orgID: orgID)
        
        // Calculate payment method spending
        let paymentSpending = Dictionary(grouping: paymentData) { $0.paymentMethodName }
            .mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        
        let topPaymentMethods = paymentSpending.sorted { $0.value > $1.value }
            .prefix(10)
            .map { PaymentMethodSpendingSummary(name: $0.key, totalSpent: $0.value) }
        
        // Calculate payment method frequency
        let paymentFrequency = Dictionary(grouping: paymentData) { $0.paymentMethodName }
            .mapValues { $0.count }
        
        let mostUsedPaymentMethods = paymentFrequency.sorted { $0.value > $1.value }
            .prefix(10)
            .map { PaymentMethodFrequencySummary(name: $0.key, transactionCount: $0.value) }
        
        return PaymentMethodIntelligenceAnalytics(
            topPaymentMethodsBySpending: topPaymentMethods,
            mostUsedPaymentMethods: mostUsedPaymentMethods,
            totalTransactions: paymentData.count,
            totalSpending: paymentSpending.values.reduce(0, +)
        )
    }
}

// MARK: - Analytics Result Models

struct VendorIntelligenceAnalytics {
    let topVendorsBySpending: [VendorSpendingSummary]
    let mostFrequentVendors: [VendorFrequencySummary]
    let totalTransactions: Int
    let totalSpending: Double
}

struct VendorSpendingSummary {
    let name: String
    let totalSpent: Double
}

struct VendorFrequencySummary {
    let name: String
    let transactionCount: Int
}

struct PaymentMethodIntelligenceAnalytics {
    let topPaymentMethodsBySpending: [PaymentMethodSpendingSummary]
    let mostUsedPaymentMethods: [PaymentMethodFrequencySummary]
    let totalTransactions: Int
    let totalSpending: Double
}

struct PaymentMethodSpendingSummary {
    let name: String
    let totalSpent: Double
}

struct PaymentMethodFrequencySummary {
    let name: String
    let transactionCount: Int
}