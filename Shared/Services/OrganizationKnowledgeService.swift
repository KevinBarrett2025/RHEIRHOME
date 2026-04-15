import Foundation
import Combine
import CloudKit
import OSLog

extension Logger {
    static let organizationKnowledge = Logger(subsystem: "com.RheirHome.RHEIR", category: "organization-knowledge")
}

/// Master coordination service for enterprise organizational intelligence
/// Orchestrates vendor and payment method knowledge across the entire organization
@MainActor
class OrganizationKnowledgeService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var lastFullSync: Date?
    @Published var organizationInsights: OrganizationInsights = OrganizationInsights()
    
    // MARK: - Service Dependencies
    private let vendorKnowledgeService: VendorKnowledgeService
    private let paymentMethodKnowledgeService: PaymentMethodKnowledgeService
    private let organizationService: OrganizationService
    private let cloudKitService: CloudKitService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        organizationID: String,
        organizationService: OrganizationService,
        cloudKitService: CloudKitService
    ) {
        self.organizationService = organizationService
        self.cloudKitService = cloudKitService
        
        // Initialize knowledge services
        self.vendorKnowledgeService = VendorKnowledgeService(
            organizationID: organizationID,
            cloudKitService: cloudKitService,
            organizationService: organizationService
        )
        
        self.paymentMethodKnowledgeService = PaymentMethodKnowledgeService(
            organizationID: organizationID,
            cloudKitService: cloudKitService,
            organizationService: organizationService
        )
        
        setupKnowledgeSync()
    }
    
    // MARK: - Enterprise Intelligence Coordination
    
    /// Initialize the complete organizational knowledge system
    func initializeOrganizationKnowledge() async {
        Logger.organizationKnowledge.info("Initializing enterprise organization knowledge system.")
        
        // Start both services concurrently
        async let vendorLoad = vendorKnowledgeService.loadOrganizationVendors()
        async let paymentLoad = paymentMethodKnowledgeService.loadOrganizationPaymentMethods()
        
        // Wait for both to complete
        await vendorLoad
        await paymentLoad
        
        // Aggregate and migrate data from existing receipts if needed
        await aggregateDataFromAllProjects()
        
        // Calculate comprehensive organization insights
        await updateOrganizationInsights()
        
        // Update organization model with knowledge directories
        await updateOrganizationModel()
        
        await MainActor.run {
            self.isInitialized = true
            self.lastFullSync = Date()
        }
        
        Logger.organizationKnowledge.notice("Completed enterprise organization knowledge initialization.")
    }
    
    /// Process new receipt and update organizational knowledge
    func processNewReceipt(
        vendor: String,
        paymentMethod: String,
        amount: Double,
        projectID: String
    ) async -> (updatedVendor: Vendor, updatedPaymentMethod: PaymentMethod) {
        Logger.organizationKnowledge.info(
            "Processing receipt for organizational intelligence [project=\(projectID, privacy: .private(mask: .hash)), amount=\(amount, privacy: .public)]"
        )
        
        // Update vendor knowledge
        let updatedVendor = await vendorKnowledgeService.findOrCreateVendor(
            name: vendor,
            amount: amount,
            projectID: projectID
        )
        
        // Update payment method knowledge
        let updatedPaymentMethod = await paymentMethodKnowledgeService.findOrCreatePaymentMethod(
            name: paymentMethod,
            amount: amount,
            projectID: projectID
        )
        
        // Update organization insights
        await updateOrganizationInsights()
        
        // Sync with organization model
        await updateOrganizationModel()
        
        Logger.organizationKnowledge.notice("Updated organizational knowledge from new receipt data.")
        
        return (updatedVendor, updatedPaymentMethod)
    }
    
    /// Get pre-populated suggestions for new projects based on organization intelligence
    func getNewProjectSuggestions() -> NewProjectSuggestions {
        let topVendors = vendorKnowledgeService.getMostUsedVendorsForNewProjects(limit: 15)
        let topPaymentMethods = paymentMethodKnowledgeService.getMostUsedPaymentMethodsForNewProjects(limit: 8)
        
        return NewProjectSuggestions(
            recommendedVendors: topVendors,
            recommendedPaymentMethods: topPaymentMethods,
            organizationInsights: organizationInsights
        )
    }
    
    /// Get comprehensive organizational business intelligence report
    func getBusinessIntelligenceReport() -> BusinessIntelligenceReport {
        let vendorAnalytics = vendorKnowledgeService.vendorAnalytics
        let paymentAnalytics = paymentMethodKnowledgeService.paymentAnalytics
        let cashFlowInsights = paymentMethodKnowledgeService.getCashFlowInsights()
        let rewardsInsights = paymentMethodKnowledgeService.getRewardsOptimizationInsights()
        
        return BusinessIntelligenceReport(
            organizationInsights: organizationInsights,
            vendorAnalytics: vendorAnalytics,
            paymentAnalytics: paymentAnalytics,
            cashFlowInsights: cashFlowInsights,
            rewardsInsights: rewardsInsights,
            generatedAt: Date()
        )
    }
    
    /// Get annual business report for tax season and business planning
    func getAnnualBusinessReport(year: Int? = nil) async -> AnnualBusinessReport {
        let reportYear = year ?? Calendar.current.component(.year, from: Date())
        
        let vendorReport = vendorKnowledgeService.getAnnualSpendingReport(year: reportYear)
        let paymentReport = paymentMethodKnowledgeService.getAnnualPaymentReport(year: reportYear)
        
        return AnnualBusinessReport(
            year: reportYear,
            vendorReport: vendorReport,
            paymentReport: paymentReport,
            organizationInsights: organizationInsights,
            generatedAt: Date()
        )
    }
    
    // MARK: - Data Migration & Aggregation
    
    private func aggregateDataFromAllProjects() async {
        Logger.organizationKnowledge.info("Aggregating organizational knowledge from existing receipts.")
        
        // Run both aggregations concurrently
        async let vendorAggregation = vendorKnowledgeService.aggregateVendorDataFromAllProjects()
        async let paymentAggregation = paymentMethodKnowledgeService.aggregatePaymentMethodDataFromAllProjects()
        
        await vendorAggregation
        await paymentAggregation
        
        Logger.organizationKnowledge.notice("Completed organizational knowledge aggregation.")
    }
    
    private func updateOrganizationInsights() async {
        let vendorAnalytics = vendorKnowledgeService.vendorAnalytics
        let paymentAnalytics = paymentMethodKnowledgeService.paymentAnalytics
        
        let insights = OrganizationInsights(
            totalVendors: vendorAnalytics.totalVendors,
            totalPaymentMethods: paymentAnalytics.totalPaymentMethods,
            totalSpending: max(vendorAnalytics.totalSpending, paymentAnalytics.totalSpending),
            topVendor: vendorAnalytics.topVendor,
            topPaymentMethod: paymentAnalytics.topPaymentMethod,
            lastUpdated: Date(),
            spendingTrends: calculateSpendingTrends(),
            businessInsights: generateBusinessInsights(vendorAnalytics, paymentAnalytics)
        )
        
        await MainActor.run {
            self.organizationInsights = insights
        }
    }
    
    private func updateOrganizationModel() async {
        // Update the organization model with the latest vendor and payment method directories
        guard var organization = await organizationService.getCurrentOrganization() else { return }
        
        organization.vendors = vendorKnowledgeService.organizationVendors
        organization.paymentMethods = paymentMethodKnowledgeService.organizationPaymentMethods
        organization.lastModified = Date()
        
        await organizationService.updateOrganization(organization)

        Logger.organizationKnowledge.notice(
            "Updated organization model with knowledge directories [organization=\(organization.id, privacy: .private(mask: .hash))]"
        )
    }
    
    // MARK: - Knowledge Sync Setup
    
    private func setupKnowledgeSync() {
        // Monitor vendor knowledge changes
        vendorKnowledgeService.$organizationVendors
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateOrganizationInsights()
                    await self?.updateOrganizationModel()
                }
            }
            .store(in: &cancellables)
        
        // Monitor payment method knowledge changes
        paymentMethodKnowledgeService.$organizationPaymentMethods
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateOrganizationInsights()
                    await self?.updateOrganizationModel()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Business Intelligence Calculations
    
    private func calculateSpendingTrends() -> SpendingTrends {
        // Placeholder for spending trend calculations
        // This would analyze historical data to show spending patterns
        return SpendingTrends(
            monthlyGrowth: 0.0,
            quarterlyGrowth: 0.0,
            yearlyGrowth: 0.0
        )
    }
    
    private func generateBusinessInsights(
        _ vendorAnalytics: VendorAnalytics,
        _ paymentAnalytics: PaymentMethodAnalytics
    ) -> [BusinessInsight] {
        var insights: [BusinessInsight] = []
        
        // Top vendor insight
        if let topVendor = vendorAnalytics.topVendor {
            insights.append(BusinessInsight(
                type: .topVendor,
                title: "Top Vendor",
                message: "\(topVendor.name) is your highest spending vendor with $\(String(format: "%.0f", topVendor.totalSpent))",
                actionable: true,
                priority: .high
            ))
        }
        
        // Payment method optimization
        if let topPayment = paymentAnalytics.topPaymentMethod {
            insights.append(BusinessInsight(
                type: .paymentOptimization,
                title: "Primary Payment Method",
                message: "Most spending done with \(topPayment.displayName) - $\(String(format: "%.0f", topPayment.totalSpent))",
                actionable: true,
                priority: .medium
            ))
        }
        
        // Spending distribution
        let totalSpending = max(vendorAnalytics.totalSpending, paymentAnalytics.totalSpending)
        if totalSpending > 10000 {
            insights.append(BusinessInsight(
                type: .spendingVolume,
                title: "High Volume Spending",
                message: "Organization has $\(String(format: "%.0f", totalSpending)) in total spending - great data for business decisions",
                actionable: false,
                priority: .low
            ))
        }
        
        return insights
    }
    
    // MARK: - Public Access to Sub-services
    
    var vendors: VendorKnowledgeService {
        return vendorKnowledgeService
    }
    
    var paymentMethods: PaymentMethodKnowledgeService {
        return paymentMethodKnowledgeService
    }
}

// MARK: - Supporting Data Models

struct OrganizationInsights {
    var totalVendors: Int = 0
    var totalPaymentMethods: Int = 0
    var totalSpending: Double = 0
    var topVendor: Vendor?
    var topPaymentMethod: PaymentMethod?
    var lastUpdated: Date = Date()
    var spendingTrends: SpendingTrends = SpendingTrends()
    var businessInsights: [BusinessInsight] = []
}

struct NewProjectSuggestions {
    let recommendedVendors: [Vendor]
    let recommendedPaymentMethods: [PaymentMethod]
    let organizationInsights: OrganizationInsights
}

struct BusinessIntelligenceReport {
    let organizationInsights: OrganizationInsights
    let vendorAnalytics: VendorAnalytics
    let paymentAnalytics: PaymentMethodAnalytics
    let cashFlowInsights: CashFlowInsights
    let rewardsInsights: RewardsInsights
    let generatedAt: Date
}

struct AnnualBusinessReport {
    let year: Int
    let vendorReport: AnnualVendorReport
    let paymentReport: AnnualPaymentReport
    let organizationInsights: OrganizationInsights
    let generatedAt: Date
}

struct SpendingTrends {
    var monthlyGrowth: Double = 0.0
    var quarterlyGrowth: Double = 0.0
    var yearlyGrowth: Double = 0.0
}

struct BusinessInsight {
    let type: InsightType
    let title: String
    let message: String
    let actionable: Bool
    let priority: InsightPriority
}

enum InsightType {
    case topVendor
    case paymentOptimization
    case spendingVolume
    case cashFlowPattern
    case rewardsOpportunity
    case taxOptimization
}

enum InsightPriority {
    case high
    case medium
    case low
}
