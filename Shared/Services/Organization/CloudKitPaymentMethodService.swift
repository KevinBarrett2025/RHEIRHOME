import Foundation
import CloudKit
import Combine

/// CloudKit-based payment method management service for organization-wide data sharing
@MainActor
class CloudKitPaymentMethodService: ObservableObject {
    
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        self.privateDatabase = container.privateCloudDatabase
        
        Task {
            await loadPaymentMethods()
        }
    }
    
    // MARK: - CloudKit Operations
    
    func loadPaymentMethods() async {
        await MainActor.run { isLoading = true }
        
        do {
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let query = CKQuery(recordType: "PaymentMethod", predicate: predicate)
            query.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true)
            ]
            
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            let cloudKitPaymentMethods = matchResults.compactMap { (_, result) -> PaymentMethod? in
                switch result {
                case .success(let record):
                    return createPaymentMethodFromRecord(record)
                case .failure(let error):
                    print("❌ Failed to load payment method record: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.paymentMethods = cloudKitPaymentMethods
                self.isLoading = false
                self.errorMessage = nil
                print("✅ Loaded \(cloudKitPaymentMethods.count) payment methods from CloudKit for organization")
            }
            
        } catch {
            print("❌ Failed to load payment methods from CloudKit: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load payment methods: \(error.localizedDescription)"
            }
        }
    }
    
    func savePaymentMethodToCloudKit(_ paymentMethod: PaymentMethod) async throws {
        let record = createRecordFromPaymentMethod(paymentMethod)
        
        do {
            _ = try await privateDatabase.save(record)
            print("✅ Saved payment method to CloudKit: \(paymentMethod.name)")
            
            // Update local array
            await MainActor.run {
                if let index = paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
                    paymentMethods[index] = paymentMethod
                } else {
                    paymentMethods.append(paymentMethod)
                    paymentMethods.sort { $0.name.lowercased() < $1.name.lowercased() }
                }
            }
            
        } catch {
            print("❌ Failed to save payment method to CloudKit: \(error)")
            throw error
        }
    }
    
    func deletePaymentMethodFromCloudKit(_ paymentMethod: PaymentMethod) async throws {
        let recordID = CKRecord.ID(recordName: paymentMethod.id.uuidString, zoneID: organizationZoneID)
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            print("✅ Deleted payment method from CloudKit: \(paymentMethod.name)")
            
            // Update local array
            await MainActor.run {
                paymentMethods.removeAll { $0.id == paymentMethod.id }
            }
            
        } catch {
            print("❌ Failed to delete payment method from CloudKit: \(error)")
            throw error
        }
    }
    
    // MARK: - Payment Method Management (Public API)
    
    func findOrCreatePaymentMethod(name: String, type: PaymentType, cardBrand: CardBrand? = nil) async -> PaymentMethod? {
        // Check if payment method already exists (case-insensitive)
        if let existingPaymentMethod = paymentMethods.first(where: { $0.name.lowercased() == name.lowercased() }) {
            print("📍 Found existing payment method: \(existingPaymentMethod.name)")
            return existingPaymentMethod
        }
        
        // Create new payment method
        let newPaymentMethod = PaymentMethod(
            name: name,
            type: type,
            cardBrand: cardBrand,
            organizationID: organizationID
        )
        
        do {
            try await savePaymentMethodToCloudKit(newPaymentMethod)
            print("🆕 Created new payment method: \(newPaymentMethod.name) (\(type.rawValue))")
            return newPaymentMethod
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create payment method: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func updatePaymentMethodSpending(paymentMethodID: UUID, amount: Double) async {
        guard let paymentMethod = paymentMethods.first(where: { $0.id == paymentMethodID }) else { return }
        
        var updatedPaymentMethod = paymentMethod
        updatedPaymentMethod.totalSpent += amount
        updatedPaymentMethod.lastUsed = Date()
        
        do {
            try await savePaymentMethodToCloudKit(updatedPaymentMethod)
            print("💰 Updated payment method spending: \(updatedPaymentMethod.name) - Total: $\(updatedPaymentMethod.totalSpent)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update payment method spending: \(error.localizedDescription)"
            }
        }
    }
    
    func getPaymentMethod(by id: UUID) -> PaymentMethod? {
        return paymentMethods.first { $0.id == id }
    }
    
    func getPaymentMethods(by type: PaymentType) -> [PaymentMethod] {
        return paymentMethods.filter { $0.type == type && $0.isActive }
    }
    
    func getTopPaymentMethods(limit: Int = 10) -> [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive && $0.totalSpent > 0 }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }
    
    func savePaymentMethod(_ paymentMethod: PaymentMethod) async {
        do {
            try await savePaymentMethodToCloudKit(paymentMethod)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save payment method: \(error.localizedDescription)"
            }
        }
    }
    
    func removePaymentMethod(_ paymentMethod: PaymentMethod) async {
        do {
            try await deletePaymentMethodFromCloudKit(paymentMethod)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove payment method: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var paymentMethodsSortedByName: [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    var paymentMethodsSortedBySpending: [PaymentMethod] {
        return paymentMethods
            .filter { $0.isActive }
            .sorted { $0.totalSpent > $1.totalSpent }
    }
    
    // MARK: - Analytics
    
    func getPaymentMethodSpendingByDateRange(from startDate: Date, to endDate: Date) -> [(paymentMethod: PaymentMethod, amount: Double)] {
        // This would require querying receipts to get spending in date range
        // For now, return basic payment method data
        return paymentMethods
            .filter { $0.isActive && $0.totalSpent > 0 }
            .map { (paymentMethod: $0, amount: $0.totalSpent) }
            .sorted { $0.amount > $1.amount }
    }
    
    func getPaymentMethodUsageStats() -> [(paymentMethod: PaymentMethod, projectCount: Int, lastUsed: Date?)] {
        return paymentMethods
            .filter { $0.isActive }
            .map { paymentMethod in
                (
                    paymentMethod: paymentMethod,
                    projectCount: paymentMethod.projectsUsed?.count ?? 0,
                    lastUsed: paymentMethod.lastUsed
                )
            }
            .sorted { $0.paymentMethod.totalSpent > $1.paymentMethod.totalSpent }
    }
    
    // MARK: - Record Conversion
    
    private func createRecordFromPaymentMethod(_ paymentMethod: PaymentMethod) -> CKRecord {
        let recordID = CKRecord.ID(recordName: paymentMethod.id.uuidString, zoneID: organizationZoneID)
        let record = CKRecord(recordType: "PaymentMethod", recordID: recordID)
        
        record["id"] = paymentMethod.id.uuidString
        record["name"] = paymentMethod.name
        record["type"] = paymentMethod.type.rawValue
        record["cardBrand"] = paymentMethod.cardBrand?.rawValue ?? ""
        record["lastFourDigits"] = paymentMethod.lastFourDigits ?? ""
        record["nickname"] = paymentMethod.nickname ?? ""
        record["organizationID"] = organizationID
        record["totalSpent"] = paymentMethod.totalSpent
        record["isActive"] = paymentMethod.isActive ? 1 : 0
        record["dateAdded"] = paymentMethod.dateAdded
        record["lastUsed"] = paymentMethod.lastUsed
        record["accountNumber"] = paymentMethod.accountNumber ?? ""
        record["projectsUsed"] = paymentMethod.projectsUsed ?? []
        
        return record
    }
    
    private func createPaymentMethodFromRecord(_ record: CKRecord) -> PaymentMethod? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let typeString = record["type"] as? String,
              let type = PaymentType(rawValue: typeString) else {
            print("❌ Invalid payment method record format")
            return nil
        }
        
        let cardBrandString = record["cardBrand"] as? String
        let cardBrand = cardBrandString?.isEmpty == false ? CardBrand(rawValue: cardBrandString!) : nil
        
        return PaymentMethod(
            id: id,
            name: name,
            type: type,
            cardBrand: cardBrand,
            lastFourDigits: record["lastFourDigits"] as? String,
            nickname: record["nickname"] as? String,
            organizationID: record["organizationID"] as? String ?? organizationID,
            totalSpent: record["totalSpent"] as? Double ?? 0.0,
            isActive: (record["isActive"] as? Int ?? 1) == 1,
            dateAdded: record["dateAdded"] as? Date ?? Date(),
            lastUsed: record["lastUsed"] as? Date,
            accountNumber: record["accountNumber"] as? String,
            projectsUsed: record["projectsUsed"] as? [String]
        )
    }
    
    // MARK: - Migration from Local Storage
    
    func migrateLocalPaymentMethodsToCloudKit() async throws {
        print("🔄 Migrating local payment methods to CloudKit...")
        
        // Load payment methods from UserDefaults
        let key = "paymentMethods_\(organizationID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let localPaymentMethods = try? JSONDecoder().decode([PaymentMethod].self, from: data) else {
            print("📋 No local payment methods found to migrate")
            return
        }
        
        var migratedCount = 0
        
        for var paymentMethod in localPaymentMethods {
            // Ensure payment method has organization ID
            paymentMethod.organizationID = organizationID
            
            do {
                try await savePaymentMethodToCloudKit(paymentMethod)
                migratedCount += 1
            } catch {
                print("❌ Failed to migrate payment method: \(paymentMethod.name) - \(error)")
            }
        }
        
        // Clear local storage after successful migration
        if migratedCount > 0 {
            UserDefaults.standard.removeObject(forKey: key)
            print("✅ Migrated \(migratedCount) payment methods to CloudKit and cleared local storage")
        }
    }
}