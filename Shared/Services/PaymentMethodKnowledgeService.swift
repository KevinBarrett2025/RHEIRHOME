import Foundation
import Combine
import CloudKit
import OSLog

extension Logger {
    static let paymentMethodKnowledge = Logger(subsystem: "com.RheirHome.RHEIR", category: "paymentMethodKnowledge")
}

/// Enterprise-wide payment method intelligence service that tracks payment patterns across the organization
/// Provides business insights for cash flow, rewards optimization, and financial planning
@MainActor
class PaymentMethodKnowledgeService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var organizationPaymentMethods: [PaymentMethod] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    private let organizationID: String
    private let cloudKitService: CloudKitService
    private let organizationService: OrganizationService
    private var cancellables = Set<AnyCancellable>()
    private let database = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3").sharedCloudDatabase
    
    // MARK: - Analytics Properties
    @Published var paymentAnalytics: PaymentMethodAnalytics = PaymentMethodAnalytics()
    
    // MARK: - Initialization
    
    init(organizationID: String, cloudKitService: CloudKitService, organizationService: OrganizationService) {
        self.organizationID = organizationID
        self.cloudKitService = cloudKitService
        self.organizationService = organizationService
        
        setupRealtimeSync()
        loadOrganizationPaymentMethods()
    }
    
    // MARK: - Enterprise Payment Intelligence
    
    /// Load all payment methods across the entire organization from CloudKit
    func loadOrganizationPaymentMethods() async {
        isLoading = true
        syncStatus = .syncing
        
        do {
            Logger.paymentMethodKnowledge.info(
                "Loading organization payment intelligence [organization=\(organizationID, privacy: .private(mask: .hash))]"
            )
            
            // Query all payment methods in the organization zone
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let query = CKQuery(recordType: "OrgPaymentMethod", predicate: predicate)
            
            let (matchResults, _) = try await database.records(matching: query)
            
            var paymentMethods: [PaymentMethod] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let paymentMethod = createPaymentMethodFromRecord(record) {
                        paymentMethods.append(paymentMethod)
                    }
                case .failure(let error):
                    Logger.paymentMethodKnowledge.error(
                        "Failed to load payment method record: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            
            // Calculate analytics
            let analytics = calculatePaymentMethodAnalytics(from: paymentMethods)
            
            await MainActor.run {
                self.organizationPaymentMethods = paymentMethods.sorted { $0.totalSpent > $1.totalSpent }
                self.paymentAnalytics = analytics
                self.isLoading = false
                self.syncStatus = .completed
                self.lastSyncDate = Date()
            }
            
            Logger.paymentMethodKnowledge.notice(
                "Loaded organization payment intelligence [count=\(paymentMethods.count, privacy: .public) totalSpending=\(analytics.totalSpending, privacy: .public)]"
            )
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.syncStatus = .failed(error)
            }
            Logger.paymentMethodKnowledge.error(
                "Failed to load organization payment methods: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Aggregate payment method data from all projects in the organization
    func aggregatePaymentMethodDataFromAllProjects() async {
        Logger.paymentMethodKnowledge.info("Aggregating payment method data from all organization projects.")
        
        do {
            // Get all projects in the organization
            let projects = try await getOrganizationProjects()
            var paymentMethodSpendingMap: [String: PaymentMethodSpendingData] = [:]
            
            // Aggregate spending from all receipts across all projects
            for project in projects {
                let receipts = try await getProjectReceipts(projectID: project.id)
                
                for receipt in receipts {
                    let paymentKey = receipt.paymentMethod.lowercased().trimmingCharacters(in: .whitespaces)
                    
                    if paymentMethodSpendingMap[paymentKey] == nil {
                        let detectedType = detectPaymentType(receipt.paymentMethod)
                        let detectedBrand = detectCardBrand(receipt.paymentMethod)
                        
                        paymentMethodSpendingMap[paymentKey] = PaymentMethodSpendingData(
                            name: receipt.paymentMethod,
                            type: detectedType,
                            cardBrand: detectedBrand,
                            totalSpent: 0,
                            transactionCount: 0,
                            projectsUsed: [],
                            lastUsed: receipt.date,
                            averageTransactionAmount: 0
                        )
                    }
                    
                    paymentMethodSpendingMap[paymentKey]?.totalSpent += receipt.amount
                    paymentMethodSpendingMap[paymentKey]?.transactionCount += 1
                    
                    if !paymentMethodSpendingMap[paymentKey]!.projectsUsed.contains(project.id) {
                        paymentMethodSpendingMap[paymentKey]?.projectsUsed.append(project.id)
                    }
                    
                    if receipt.date > paymentMethodSpendingMap[paymentKey]!.lastUsed {
                        paymentMethodSpendingMap[paymentKey]?.lastUsed = receipt.date
                    }
                }
            }
            
            // Calculate average transaction amounts and convert to PaymentMethod objects
            let paymentMethods = paymentMethodSpendingMap.values.map { data in
                let avgAmount = data.transactionCount > 0 ? data.totalSpent / Double(data.transactionCount) : 0
                
                return PaymentMethod(
                    name: data.name,
                    type: data.type,
                    cardBrand: data.cardBrand,
                    nickname: data.name,
                    lastUsed: data.lastUsed,
                    totalSpent: data.totalSpent
                )
            }
            
            // Save to CloudKit organization zone
            await savePaymentMethodsToCloudKit(paymentMethods)
            
            Logger.paymentMethodKnowledge.notice(
                "Aggregated payment methods from organization projects [count=\(paymentMethods.count, privacy: .public) totalSpending=\(paymentMethods.reduce(0) { $0 + $1.totalSpent }, privacy: .public)]"
            )
            
        } catch {
            Logger.paymentMethodKnowledge.error(
                "Failed to aggregate payment method data: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Find or create payment method with organization-wide intelligence
    func findOrCreatePaymentMethod(name: String, amount: Double, projectID: String) async -> PaymentMethod {
        let paymentName = name.trimmingCharacters(in: .whitespaces)
        
        // Check if payment method already exists in organization
        if let existingMethod = await findExistingPaymentMethod(name: paymentName) {
            Logger.paymentMethodKnowledge.debug(
                "Matched existing organization payment method [paymentMethod=\(existingMethod.displayName, privacy: .private(mask: .hash))]"
            )
            
            // Update spending and usage
            await updatePaymentMethodUsage(
                paymentMethodID: existingMethod.id,
                additionalSpending: amount,
                projectID: projectID
            )
            
            return existingMethod
        }
        
        // Create new payment method with organization intelligence
        let type = detectPaymentType(paymentName)
        let cardBrand = detectCardBrand(paymentName)
        
        let newPaymentMethod = PaymentMethod(
            name: paymentName,
            type: type,
            cardBrand: cardBrand,
            nickname: paymentName,
            lastUsed: Date(),
            totalSpent: amount
        )
        
        // Save to CloudKit and update local cache
        await savePaymentMethodToCloudKit(newPaymentMethod)
        
        await MainActor.run {
            self.organizationPaymentMethods.append(newPaymentMethod)
            self.organizationPaymentMethods.sort { $0.totalSpent > $1.totalSpent }
        }
        
        Logger.paymentMethodKnowledge.notice(
            "Created organization payment method [paymentMethod=\(newPaymentMethod.displayName, privacy: .private(mask: .hash)) type=\(type.rawValue, privacy: .public)]"
        )
        return newPaymentMethod
    }
    
    /// Update payment method usage when new receipts are added
    func updatePaymentMethodUsage(paymentMethodID: UUID, additionalSpending: Double, projectID: String) async {
        guard let index = organizationPaymentMethods.firstIndex(where: { $0.id == paymentMethodID }) else { return }
        
        await MainActor.run {
            organizationPaymentMethods[index].totalSpent += additionalSpending
            organizationPaymentMethods[index].lastUsed = Date()
            
            // Re-sort by spending
            organizationPaymentMethods.sort { $0.totalSpent > $1.totalSpent }
        }
        
        // Update in CloudKit
        let updatedMethod = organizationPaymentMethods[index]
        await updatePaymentMethodInCloudKit(updatedMethod)
        
        // Recalculate analytics
        await MainActor.run {
            self.paymentAnalytics = calculatePaymentMethodAnalytics(from: organizationPaymentMethods)
        }
        
        Logger.paymentMethodKnowledge.info(
            "Updated organization payment method usage [paymentMethod=\(updatedMethod.displayName, privacy: .private(mask: .hash)) total=\(updatedMethod.totalSpent, privacy: .public)]"
        )
    }
    
    // MARK: - Enterprise Analytics & Insights
    
    /// Get top payment methods by spending across the organization
    func getTopPaymentMethods(limit: Int = 10) -> [PaymentMethod] {
        return Array(organizationPaymentMethods
            .filter { $0.isActive && $0.totalSpent > 0 }
            .prefix(limit))
    }
    
    /// Get payment methods by type with organization-wide data
    func getPaymentMethods(by type: PaymentType) -> [PaymentMethod] {
        return organizationPaymentMethods.filter { $0.type == type && $0.isActive }
    }
    
    /// Get most frequently used payment methods for new project pre-population
    func getMostUsedPaymentMethodsForNewProjects(limit: Int = 10) -> [PaymentMethod] {
        return organizationPaymentMethods
            .filter { $0.isActive }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get cash flow insights for better financial planning
    func getCashFlowInsights() -> CashFlowInsights {
        let creditCardSpending = organizationPaymentMethods
            .filter { $0.type == .creditCard }
            .reduce(0) { $0 + $1.totalSpent }
        
        let debitCardSpending = organizationPaymentMethods
            .filter { $0.type == .debitCard }
            .reduce(0) { $0 + $1.totalSpent }
        
        let cashSpending = organizationPaymentMethods
            .filter { $0.type == .cash }
            .reduce(0) { $0 + $1.totalSpent }
        
        let checkSpending = organizationPaymentMethods
            .filter { $0.type == .check }
            .reduce(0) { $0 + $1.totalSpent }
        
        let totalSpending = paymentAnalytics.totalSpending
        
        return CashFlowInsights(
            creditCardPercentage: totalSpending > 0 ? (creditCardSpending / totalSpending) * 100 : 0,
            debitCardPercentage: totalSpending > 0 ? (debitCardSpending / totalSpending) * 100 : 0,
            cashPercentage: totalSpending > 0 ? (cashSpending / totalSpending) * 100 : 0,
            checkPercentage: totalSpending > 0 ? (checkSpending / totalSpending) * 100 : 0,
            creditCardTotal: creditCardSpending,
            debitCardTotal: debitCardSpending,
            cashTotal: cashSpending,
            checkTotal: checkSpending,
            totalSpending: totalSpending
        )
    }
    
    /// Get rewards optimization insights
    func getRewardsOptimizationInsights() -> RewardsInsights {
        let creditCards = organizationPaymentMethods.filter { $0.type == .creditCard }
        
        // Calculate potential rewards based on common card reward rates
        var potentialRewards: [PaymentMethodRewards] = []
        
        for card in creditCards {
            let estimatedRewardRate = getEstimatedRewardRate(for: card.cardBrand)
            let potentialEarnings = card.totalSpent * estimatedRewardRate
            
            potentialRewards.append(PaymentMethodRewards(
                paymentMethod: card,
                estimatedRewardRate: estimatedRewardRate,
                potentialEarnings: potentialEarnings
            ))
        }
        
        let totalPotentialRewards = potentialRewards.reduce(0) { $0 + $1.potentialEarnings }
        
        return RewardsInsights(
            totalPotentialRewards: totalPotentialRewards,
            paymentMethodRewards: potentialRewards,
            recommendations: generateRewardsRecommendations(potentialRewards)
        )
    }
    
    /// Get annual payment report for tax season
    func getAnnualPaymentReport(year: Int = Calendar.current.component(.year, from: Date())) -> AnnualPaymentReport {
        let currentYear = Calendar.current.component(.year, from: Date())
        let isCurrentYear = year == currentYear
        
        let paymentMethodsThisYear = organizationPaymentMethods.filter { method in
            guard let lastUsed = method.lastUsed else { return false }
            return Calendar.current.component(.year, from: lastUsed) == year
        }
        
        return AnnualPaymentReport(
            year: year,
            totalPaymentMethods: paymentMethodsThisYear.count,
            totalSpending: paymentMethodsThisYear.reduce(0) { $0 + $1.totalSpent },
            topPaymentMethods: Array(paymentMethodsThisYear.prefix(10)),
            spendingByType: Dictionary(grouping: paymentMethodsThisYear) { $0.type }
                .mapValues { methods in methods.reduce(0) { $0 + $1.totalSpent } },
            cashFlowInsights: getCashFlowInsights(),
            rewardsInsights: getRewardsOptimizationInsights()
        )
    }
    
    // MARK: - CloudKit Integration
    
    private func savePaymentMethodToCloudKit(_ paymentMethod: PaymentMethod) async {
        do {
            let record = createRecordFromPaymentMethod(paymentMethod)
            _ = try await database.save(record)
            Logger.paymentMethodKnowledge.debug(
                "Saved payment method to CloudKit [paymentMethod=\(paymentMethod.displayName, privacy: .private(mask: .hash))]"
            )
        } catch {
            Logger.paymentMethodKnowledge.error(
                "Failed to save payment method to CloudKit: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    private func savePaymentMethodsToCloudKit(_ paymentMethods: [PaymentMethod]) async {
        do {
            let records = paymentMethods.map { createRecordFromPaymentMethod($0) }
            
            // Save in batches of 400 (CloudKit limit)
            let batchSize = 400
            for i in stride(from: 0, to: records.count, by: batchSize) {
                let endIndex = min(i + batchSize, records.count)
                let batch = Array(records[i..<endIndex])
                
                let (saveResults, _) = try await database.modifyRecords(saving: batch, deleting: [])
                
                for (_, result) in saveResults {
                    switch result {
                    case .success:
                        break // Success
                    case .failure(let error):
                        Logger.paymentMethodKnowledge.error(
                            "Failed payment method batch save: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
            }
            
            Logger.paymentMethodKnowledge.notice(
                "Saved payment methods to CloudKit [count=\(paymentMethods.count, privacy: .public)]"
            )
        } catch {
            Logger.paymentMethodKnowledge.error(
                "Failed to save payment methods batch to CloudKit: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    private func updatePaymentMethodInCloudKit(_ paymentMethod: PaymentMethod) async {
        await savePaymentMethodToCloudKit(paymentMethod) // CloudKit handles updates automatically
    }
    
    private func createRecordFromPaymentMethod(_ paymentMethod: PaymentMethod) -> CKRecord {
        let recordID = CKRecord.ID(recordName: paymentMethod.id.uuidString)
        let record = CKRecord(recordType: "OrgPaymentMethod", recordID: recordID)
        
        record["organizationID"] = organizationID
        record["name"] = paymentMethod.name
        record["type"] = paymentMethod.type.rawValue
        record["cardBrand"] = paymentMethod.cardBrand?.rawValue
        record["lastFourDigits"] = paymentMethod.lastFourDigits
        record["nickname"] = paymentMethod.nickname
        record["totalSpent"] = paymentMethod.totalSpent
        record["isActive"] = paymentMethod.isActive
        record["dateAdded"] = paymentMethod.dateAdded
        record["lastUsed"] = paymentMethod.lastUsed
        record["accountNumber"] = paymentMethod.accountNumber
        
        return record
    }
    
    private func createPaymentMethodFromRecord(_ record: CKRecord) -> PaymentMethod? {
        guard let name = record["name"] as? String,
              let typeString = record["type"] as? String,
              let type = PaymentType(rawValue: typeString),
              let totalSpent = record["totalSpent"] as? Double,
              let isActive = record["isActive"] as? Bool,
              let dateAdded = record["dateAdded"] as? Date else {
            return nil
        }
        
        let cardBrand: CardBrand? = {
            if let brandString = record["cardBrand"] as? String {
                return CardBrand(rawValue: brandString)
            }
            return nil
        }()
        
        return PaymentMethod(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            type: type,
            cardBrand: cardBrand,
            lastFourDigits: record["lastFourDigits"] as? String ?? "",
            nickname: record["nickname"] as? String ?? "",
            dateAdded: dateAdded,
            lastUsed: record["lastUsed"] as? Date,
            totalSpent: totalSpent,
            isActive: isActive,
            accountNumber: record["accountNumber"] as? String ?? ""
        )
    }
    
    // MARK: - Real-time Sync
    
    private func setupRealtimeSync() {
        // Set up CloudKit subscription for real-time updates
        Task {
            await createCloudKitSubscription()
        }
    }
    
    private func createCloudKitSubscription() async {
        do {
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let subscription = CKQuerySubscription(
                recordType: "OrgPaymentMethod",
                predicate: predicate,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            _ = try await database.save(subscription)
            Logger.paymentMethodKnowledge.info("Configured payment method CloudKit subscription.")
        } catch {
            Logger.paymentMethodKnowledge.error(
                "Failed to configure payment method sync subscription: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func findExistingPaymentMethod(name: String) async -> PaymentMethod? {
        return organizationPaymentMethods.first { method in
            method.name.lowercased().trimmingCharacters(in: .whitespaces) == 
            name.lowercased().trimmingCharacters(in: .whitespaces) ||
            method.nickname.lowercased().trimmingCharacters(in: .whitespaces) == 
            name.lowercased().trimmingCharacters(in: .whitespaces)
        }
    }
    
    private func detectPaymentType(_ paymentName: String) -> PaymentType {
        let name = paymentName.lowercased()
        
        if name.contains("cash") {
            return .cash
        } else if name.contains("check") {
            return .check
        } else if name.contains("debit") {
            return .debitCard
        } else if name.contains("credit") || name.contains("card") || 
                  name.contains("visa") || name.contains("mastercard") ||
                  name.contains("amex") || name.contains("discover") ||
                  name.contains("chase") || name.contains("wells fargo") ||
                  name.contains("bank of america") || name.contains("citi") {
            return .creditCard
        } else if name.contains("transfer") || name.contains("ach") {
            return .bankTransfer
        } else {
            return .other
        }
    }
    
    private func detectCardBrand(_ paymentName: String) -> CardBrand? {
        let name = paymentName.lowercased()
        
        if name.contains("visa") {
            return .visa
        } else if name.contains("mastercard") || name.contains("master card") {
            return .mastercard
        } else if name.contains("american express") || name.contains("amex") {
            return .americanExpress
        } else if name.contains("discover") {
            return .discover
        } else if name.contains("chase") {
            return .chase
        } else if name.contains("wells fargo") {
            return .wellsFargo
        } else if name.contains("bank of america") || name.contains("boa") {
            return .bankOfAmerica
        } else if name.contains("citi") {
            return .citi
        } else if name.contains("capital one") {
            return .capital
        }
        
        return nil
    }
    
    private func getEstimatedRewardRate(for cardBrand: CardBrand?) -> Double {
        // Estimated reward rates based on common card programs
        switch cardBrand {
        case .chase:
            return 0.015 // 1.5% average
        case .americanExpress:
            return 0.018 // 1.8% average
        case .citi:
            return 0.014 // 1.4% average
        case .discover:
            return 0.015 // 1.5% average
        case .bankOfAmerica:
            return 0.013 // 1.3% average
        case .capital:
            return 0.015 // 1.5% average
        default:
            return 0.012 // 1.2% conservative estimate
        }
    }
    
    private func generateRewardsRecommendations(_ rewards: [PaymentMethodRewards]) -> [String] {
        var recommendations: [String] = []
        
        if let topCard = rewards.max(by: { $0.potentialEarnings < $1.potentialEarnings }) {
            recommendations.append("Your \(topCard.paymentMethod.displayName) earned approximately $\(String(format: "%.0f", topCard.potentialEarnings)) in rewards this year")
        }
        
        let totalRewards = rewards.reduce(0) { $0 + $1.potentialEarnings }
        if totalRewards > 500 {
            recommendations.append("Great job! You've potentially earned over $\(String(format: "%.0f", totalRewards)) in credit card rewards")
        }
        
        return recommendations
    }
    
    private func getOrganizationProjects() async throws -> [Project] {
        // This would integrate with your existing project loading logic
        // Placeholder for now
        return []
    }
    
    private func getProjectReceipts(projectID: String) async throws -> [Receipt] {
        // This would integrate with your existing receipt loading logic
        // Placeholder for now
        return []
    }
    
    private func calculatePaymentMethodAnalytics(from paymentMethods: [PaymentMethod]) -> PaymentMethodAnalytics {
        let totalSpending = paymentMethods.reduce(0) { $0 + $1.totalSpent }
        let averageSpending = paymentMethods.isEmpty ? 0 : totalSpending / Double(paymentMethods.count)
        
        let topPaymentMethod = paymentMethods.max(by: { $0.totalSpent < $1.totalSpent })
        
        let spendingByType = Dictionary(grouping: paymentMethods) { $0.type }
            .mapValues { typeMethods in typeMethods.reduce(0) { $0 + $1.totalSpent } }
        
        return PaymentMethodAnalytics(
            totalPaymentMethods: paymentMethods.count,
            totalSpending: totalSpending,
            averageSpending: averageSpending,
            topPaymentMethod: topPaymentMethod,
            spendingByType: spendingByType
        )
    }
}

// MARK: - Supporting Data Models

struct PaymentMethodSpendingData {
    var name: String
    var type: PaymentType
    var cardBrand: CardBrand?
    var totalSpent: Double
    var transactionCount: Int
    var projectsUsed: [String]
    var lastUsed: Date
    var averageTransactionAmount: Double
}

struct PaymentMethodAnalytics {
    var totalPaymentMethods: Int = 0
    var totalSpending: Double = 0
    var averageSpending: Double = 0
    var topPaymentMethod: PaymentMethod?
    var spendingByType: [PaymentType: Double] = [:]
}

struct CashFlowInsights {
    let creditCardPercentage: Double
    let debitCardPercentage: Double
    let cashPercentage: Double
    let checkPercentage: Double
    let creditCardTotal: Double
    let debitCardTotal: Double
    let cashTotal: Double
    let checkTotal: Double
    let totalSpending: Double
}

struct RewardsInsights {
    let totalPotentialRewards: Double
    let paymentMethodRewards: [PaymentMethodRewards]
    let recommendations: [String]
}

struct PaymentMethodRewards {
    let paymentMethod: PaymentMethod
    let estimatedRewardRate: Double
    let potentialEarnings: Double
}

struct AnnualPaymentReport {
    let year: Int
    let totalPaymentMethods: Int
    let totalSpending: Double
    let topPaymentMethods: [PaymentMethod]
    let spendingByType: [PaymentType: Double]
    let cashFlowInsights: CashFlowInsights
    let rewardsInsights: RewardsInsights
}
