import Foundation
import Combine
import OSLog

/// Service for managing payment methods across the organization
@MainActor
class PaymentMethodManagementService: ObservableObject {
    
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var isLoading = false
    
    private let organizationID: String
    private let userDefaults = UserDefaults.standard
    
    init(organizationID: String = "RHEIR-LLC-MAIN-ORG") {
        self.organizationID = organizationID
        loadPaymentMethods()
    }
    
    // MARK: - Payment Method Management
    
    /// Find or create a payment method by name or nickname
    func findOrCreatePaymentMethod(name: String, type: PaymentType = .other) -> PaymentMethod {
        // First check if payment method already exists by name (case-insensitive)
        if let existingMethod = paymentMethods.first(where: { 
            $0.name.lowercased() == name.lowercased() || 
            $0.nickname.lowercased() == name.lowercased() ||
            $0.displayName.lowercased() == name.lowercased()
        }) {
            Logger.company.debug("Resolved existing payment method from receipt payment source.")
            return existingMethod
        }
        
        // Try to detect card brand from name
        let cardBrand = detectCardBrand(from: name)
        
        // Create new payment method
        let newMethod = PaymentMethod(
            name: name,
            type: type,
            cardBrand: cardBrand,
            nickname: name
        )
        
        paymentMethods.append(newMethod)
        savePaymentMethods()
        
        Logger.company.notice("Created payment method from receipt payment source [type=\(type.rawValue, privacy: .public)]")
        return newMethod
    }
    
    /// Find payment method by receipt payment method string (handles nicknames)
    func findPaymentMethodByReceiptName(_ receiptPaymentMethod: String) -> PaymentMethod? {
        return paymentMethods.first { method in
            method.name.lowercased() == receiptPaymentMethod.lowercased() ||
            method.nickname.lowercased() == receiptPaymentMethod.lowercased() ||
            method.displayName.lowercased() == receiptPaymentMethod.lowercased()
        }
    }
    
    /// Update payment method spending total
    func updatePaymentMethodSpending(paymentMethodID: UUID, amount: Double) {
        guard let index = paymentMethods.firstIndex(where: { $0.id == paymentMethodID }) else { return }
        
        paymentMethods[index].totalSpent += amount
        savePaymentMethods()
        
        Logger.company.info("Updated payment method spending total.")
    }
    
    /// Get payment method by ID
    func getPaymentMethod(by id: UUID) -> PaymentMethod? {
        return paymentMethods.first { $0.id == id }
    }
    
    /// Get payment methods by type
    func getPaymentMethods(by type: PaymentType) -> [PaymentMethod] {
        return paymentMethods.filter { $0.type == type && $0.isActive }
    }
    
    /// Get top payment methods by spending
    func getTopPaymentMethods(limit: Int = 10) -> [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive && $0.totalSpent > 0 }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Add or update payment method
    func savePaymentMethod(_ paymentMethod: PaymentMethod) {
        if let index = paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
            paymentMethods[index] = paymentMethod
        } else {
            paymentMethods.append(paymentMethod)
        }
        savePaymentMethods()
    }
    
    /// Remove payment method
    func removePaymentMethod(_ paymentMethod: PaymentMethod) {
        paymentMethods.removeAll { $0.id == paymentMethod.id }
        savePaymentMethods()
    }
    
    /// Get payment methods sorted by name
    var paymentMethodsSortedByName: [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive }
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }
    
    /// Get payment methods sorted by spending
    var paymentMethodsSortedBySpending: [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive }
            .sorted { $0.totalSpent > $1.totalSpent }
    }
    
    /// Clean up duplicate payment methods (merge duplicates by name/nickname)
    func cleanupDuplicatePaymentMethods() {
        Logger.company.info("Cleaning duplicate payment methods.")
        
        var seenNames: Set<String> = []
        var cleanedMethods: [PaymentMethod] = []
        var duplicatesFound = 0
        
        for method in paymentMethods {
            let normalizedName = method.name.lowercased().trimmingCharacters(in: .whitespaces)
            let normalizedNickname = method.nickname.lowercased().trimmingCharacters(in: .whitespaces)
            let normalizedDisplayName = method.displayName.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Check if we've already seen this payment method (by any of its names)
            let hasSeenName = seenNames.contains(normalizedName) || 
                             seenNames.contains(normalizedNickname) ||
                             seenNames.contains(normalizedDisplayName)
            
            if !hasSeenName {
                // This is a unique payment method
                cleanedMethods.append(method)
                seenNames.insert(normalizedName)
                if !normalizedNickname.isEmpty {
                    seenNames.insert(normalizedNickname)
                }
                seenNames.insert(normalizedDisplayName)
            } else {
                // This is a duplicate - find the existing one and merge spending
                if let existingIndex = cleanedMethods.firstIndex(where: { existing in
                    let existingNormalizedName = existing.name.lowercased().trimmingCharacters(in: .whitespaces)
                    let existingNormalizedNickname = existing.nickname.lowercased().trimmingCharacters(in: .whitespaces)
                    let existingNormalizedDisplayName = existing.displayName.lowercased().trimmingCharacters(in: .whitespaces)
                    
                    return existingNormalizedName == normalizedName ||
                           existingNormalizedName == normalizedNickname ||
                           existingNormalizedNickname == normalizedName ||
                           existingNormalizedDisplayName == normalizedName ||
                           existingNormalizedDisplayName == normalizedNickname
                }) {
                    // Merge the spending from the duplicate into the existing one
                    cleanedMethods[existingIndex].totalSpent += method.totalSpent
                    duplicatesFound += 1
                    Logger.company.debug("Merged duplicate payment method into canonical company payment entry.")
                }
            }
        }
        
        if duplicatesFound > 0 {
            paymentMethods = cleanedMethods
            savePaymentMethods()
            Logger.company.notice(
                "Cleaned duplicate payment methods [duplicates=\(duplicatesFound, privacy: .public) remaining=\(self.paymentMethods.count, privacy: .public)]"
            )
        } else {
            Logger.company.debug("No duplicate payment methods found during cleanup.")
        }
    }
    
    // MARK: - Card Brand Detection
    
    private func detectCardBrand(from name: String) -> CardBrand? {
        let lowercased = name.lowercased()
        
        if lowercased.contains("visa") {
            return .visa
        } else if lowercased.contains("mastercard") || lowercased.contains("master card") {
            return .mastercard
        } else if lowercased.contains("american express") || lowercased.contains("amex") {
            return .americanExpress
        } else if lowercased.contains("discover") {
            return .discover
        } else if lowercased.contains("chase") {
            return .chase
        } else if lowercased.contains("wells fargo") {
            return .wellsFargo
        } else if lowercased.contains("bank of america") || lowercased.contains("boa") {
            return .bankOfAmerica
        } else if lowercased.contains("citi") {
            return .citi
        } else if lowercased.contains("capital one") {
            return .capital
        }
        
        return nil
    }
    
    // MARK: - Persistence
    
    private func loadPaymentMethods() {
        let key = "paymentMethods_\(organizationID)"
        
        guard let data = userDefaults.data(forKey: key),
              let loadedMethods = try? JSONDecoder().decode([PaymentMethod].self, from: data) else {
            // Create default payment methods if none exist
            createDefaultPaymentMethods()
            return
        }
        
        paymentMethods = loadedMethods
        Logger.company.info("Loaded company payment methods [count=\(self.paymentMethods.count, privacy: .public)]")
    }
    
    private func savePaymentMethods() {
        let key = "paymentMethods_\(organizationID)"
        
        guard let data = try? JSONEncoder().encode(paymentMethods) else {
            Logger.company.error("Failed to encode company payment methods for persistence.")
            return
        }
        
        userDefaults.set(data, forKey: key)
        Logger.company.info("Saved company payment methods [count=\(self.paymentMethods.count, privacy: .public)]")
    }
    
    private func createDefaultPaymentMethods() {
        let defaultMethods = [
            PaymentMethod(name: "Cash", type: .cash),
            PaymentMethod(name: "Business Credit Card", type: .creditCard, cardBrand: .visa, nickname: "Business Card"),
            PaymentMethod(name: "Personal Credit Card", type: .creditCard, cardBrand: .mastercard, nickname: "Personal Card"),
            PaymentMethod(name: "Debit Card", type: .debitCard),
            PaymentMethod(name: "Company Check", type: .check)
        ]
        
        paymentMethods = defaultMethods
        savePaymentMethods()
        Logger.company.notice("Created default company payment methods [count=\(defaultMethods.count, privacy: .public)]")
    }
}
