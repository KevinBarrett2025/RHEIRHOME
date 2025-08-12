import Foundation
import Combine
import CloudKit

/// Enterprise-wide vendor intelligence service that aggregates vendor data from all organization projects
/// This transforms RHEIR from project management into enterprise construction intelligence platform
@MainActor
class VendorKnowledgeService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var organizationVendors: [Vendor] = []
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
    @Published var vendorAnalytics: VendorAnalytics = VendorAnalytics()
    
    // MARK: - Initialization
    
    init(organizationID: String, cloudKitService: CloudKitService, organizationService: OrganizationService) {
        self.organizationID = organizationID
        self.cloudKitService = cloudKitService
        self.organizationService = organizationService
        
        setupRealtimeSync()
        loadOrganizationVendors()
    }
    
    // MARK: - Enterprise Vendor Intelligence
    
    /// Load all vendors across the entire organization from CloudKit
    func loadOrganizationVendors() async {
        isLoading = true
        syncStatus = .syncing
        
        do {
            print("🏢 Loading organization-wide vendor intelligence...")
            
            // Query all vendors in the organization zone
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let query = CKQuery(recordType: "OrgVendor", predicate: predicate)
            
            let (matchResults, _) = try await database.records(matching: query)
            
            var vendors: [Vendor] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let vendor = createVendorFromRecord(record) {
                        vendors.append(vendor)
                    }
                case .failure(let error):
                    print("❌ Failed to load vendor record: \(error)")
                }
            }
            
            // Calculate analytics
            let analytics = calculateVendorAnalytics(from: vendors)
            
            await MainActor.run {
                self.organizationVendors = vendors.sorted { $0.totalSpent > $1.totalSpent }
                self.vendorAnalytics = analytics
                self.isLoading = false
                self.syncStatus = .completed
                self.lastSyncDate = Date()
            }
            
            print("📊 Loaded \(vendors.count) organization vendors with $\(analytics.totalSpending) in spending")
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.syncStatus = .failed(error)
            }
            print("❌ Failed to load organization vendors: \(error)")
        }
    }
    
    /// Aggregate vendor data from all projects in the organization
    func aggregateVendorDataFromAllProjects() async {
        print("🔄 Aggregating vendor data from all organization projects...")
        
        do {
            // Get all projects in the organization
            let projects = try await getOrganizationProjects()
            var vendorSpendingMap: [String: VendorSpendingData] = [:]
            
            // Aggregate spending from all receipts across all projects
            for project in projects {
                let receipts = try await getProjectReceipts(projectID: project.id)
                
                for receipt in receipts {
                    let vendorKey = receipt.vendor.lowercased().trimmingCharacters(in: .whitespaces)
                    
                    if vendorSpendingMap[vendorKey] == nil {
                        vendorSpendingMap[vendorKey] = VendorSpendingData(
                            name: receipt.vendor,
                            category: determineVendorCategory(receipt.vendor),
                            totalSpent: 0,
                            projectsUsed: [],
                            receiptCount: 0,
                            lastUsed: receipt.date
                        )
                    }
                    
                    vendorSpendingMap[vendorKey]?.totalSpent += receipt.amount
                    vendorSpendingMap[vendorKey]?.receiptCount += 1
                    
                    if !vendorSpendingMap[vendorKey]!.projectsUsed.contains(project.id) {
                        vendorSpendingMap[vendorKey]?.projectsUsed.append(project.id)
                    }
                    
                    if receipt.date > vendorSpendingMap[vendorKey]!.lastUsed {
                        vendorSpendingMap[vendorKey]?.lastUsed = receipt.date
                    }
                }
            }
            
            // Convert to Vendor objects and save to CloudKit
            let vendors = vendorSpendingMap.values.map { data in
                Vendor(
                    name: data.name,
                    category: data.category,
                    organizationID: organizationID,
                    totalSpent: data.totalSpent,
                    lastUsed: data.lastUsed,
                    projectsUsed: data.projectsUsed
                )
            }
            
            // Save to CloudKit organization zone
            await saveVendorsToCloudKit(vendors)
            
            print("💼 Aggregated \(vendors.count) vendors with $\(vendors.reduce(0) { $0 + $1.totalSpent }) total spending")
            
        } catch {
            print("❌ Failed to aggregate vendor data: \(error)")
        }
    }
    
    /// Find or create vendor with organization-wide intelligence
    func findOrCreateVendor(name: String, amount: Double, projectID: String) async -> Vendor {
        let vendorName = name.trimmingCharacters(in: .whitespaces)
        
        // Check if vendor already exists in organization
        if let existingVendor = await findExistingVendor(name: vendorName) {
            print("📍 Found existing organization vendor: \(existingVendor.name)")
            
            // Update spending and usage
            await updateVendorUsage(
                vendorID: existingVendor.id, 
                additionalSpending: amount, 
                projectID: projectID
            )
            
            return existingVendor
        }
        
        // Create new vendor with organization intelligence
        let category = determineVendorCategory(vendorName)
        let newVendor = Vendor(
            name: vendorName,
            category: category,
            organizationID: organizationID,
            totalSpent: amount,
            lastUsed: Date(),
            projectsUsed: [projectID]
        )
        
        // Save to CloudKit and update local cache
        await saveVendorToCloudKit(newVendor)
        
        await MainActor.run {
            self.organizationVendors.append(newVendor)
            self.organizationVendors.sort { $0.totalSpent > $1.totalSpent }
        }
        
        print("🆕 Created new organization vendor: \(newVendor.name) (\(category.rawValue))")
        return newVendor
    }
    
    /// Update vendor usage when new receipts are added
    func updateVendorUsage(vendorID: UUID, additionalSpending: Double, projectID: String) async {
        guard let index = organizationVendors.firstIndex(where: { $0.id == vendorID }) else { return }
        
        await MainActor.run {
            organizationVendors[index].totalSpent += additionalSpending
            organizationVendors[index].lastUsed = Date()
            
            if let projectsUsed = organizationVendors[index].projectsUsed,
               !projectsUsed.contains(projectID) {
                organizationVendors[index].projectsUsed?.append(projectID)
            }
            
            // Re-sort by spending
            organizationVendors.sort { $0.totalSpent > $1.totalSpent }
        }
        
        // Update in CloudKit
        let updatedVendor = organizationVendors[index]
        await updateVendorInCloudKit(updatedVendor)
        
        // Recalculate analytics
        await MainActor.run {
            self.vendorAnalytics = calculateVendorAnalytics(from: organizationVendors)
        }
        
        print("💰 Updated organization vendor: \(updatedVendor.name) - New total: $\(updatedVendor.totalSpent)")
    }
    
    // MARK: - Enterprise Analytics
    
    /// Get top vendors by spending across the organization
    func getTopVendors(limit: Int = 10) -> [Vendor] {
        return Array(organizationVendors
            .filter { $0.isActive && $0.totalSpent > 0 }
            .prefix(limit))
    }
    
    /// Get vendors by category with organization-wide data
    func getVendors(by category: VendorCategory) -> [Vendor] {
        return organizationVendors.filter { $0.category == category && $0.isActive }
    }
    
    /// Get most frequently used vendors for new project pre-population
    func getMostUsedVendorsForNewProjects(limit: Int = 20) -> [Vendor] {
        return organizationVendors
            .filter { $0.isActive }
            .sorted { ($0.projectsUsed?.count ?? 0) > ($1.projectsUsed?.count ?? 0) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get spending trends by vendor over time
    func getVendorSpendingTrends(vendorID: UUID, timeframe: AnalyticsTimeframe = .year) -> VendorSpendingTrend {
        // Implementation would query CloudKit for historical spending data
        // This is a placeholder for future enhancement
        return VendorSpendingTrend(vendorID: vendorID, timeframe: timeframe, dataPoints: [])
    }
    
    /// Get annual spending report for tax season
    func getAnnualSpendingReport(year: Int = Calendar.current.component(.year, from: Date())) -> AnnualVendorReport {
        let currentYear = Calendar.current.component(.year, from: Date())
        let isCurrentYear = year == currentYear
        
        let vendorsThisYear = organizationVendors.filter { vendor in
            guard let lastUsed = vendor.lastUsed else { return false }
            return Calendar.current.component(.year, from: lastUsed) == year
        }
        
        return AnnualVendorReport(
            year: year,
            totalVendors: vendorsThisYear.count,
            totalSpending: vendorsThisYear.reduce(0) { $0 + $1.totalSpent },
            topVendors: Array(vendorsThisYear.prefix(20)),
            spendingByCategory: Dictionary(grouping: vendorsThisYear) { $0.category }
                .mapValues { vendors in vendors.reduce(0) { $0 + $1.totalSpent } }
        )
    }
    
    // MARK: - CloudKit Integration
    
    private func saveVendorToCloudKit(_ vendor: Vendor) async {
        do {
            let record = createRecordFromVendor(vendor)
            _ = try await database.save(record)
            print("☁️ Saved vendor to CloudKit: \(vendor.name)")
        } catch {
            print("❌ Failed to save vendor to CloudKit: \(error)")
        }
    }
    
    private func saveVendorsToCloudKit(_ vendors: [Vendor]) async {
        do {
            let records = vendors.map { createRecordFromVendor($0) }
            
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
                        print("❌ Failed to save vendor batch: \(error)")
                    }
                }
            }
            
            print("☁️ Saved \(vendors.count) vendors to CloudKit")
        } catch {
            print("❌ Failed to save vendors batch to CloudKit: \(error)")
        }
    }
    
    private func updateVendorInCloudKit(_ vendor: Vendor) async {
        await saveVendorToCloudKit(vendor) // CloudKit handles updates automatically
    }
    
    private func createRecordFromVendor(_ vendor: Vendor) -> CKRecord {
        let recordID = CKRecord.ID(recordName: vendor.id.uuidString)
        let record = CKRecord(recordType: "OrgVendor", recordID: recordID)
        
        record["organizationID"] = organizationID
        record["name"] = vendor.name
        record["category"] = vendor.category.rawValue
        record["totalSpent"] = vendor.totalSpent
        record["isActive"] = vendor.isActive
        record["dateAdded"] = vendor.dateAdded
        record["lastUsed"] = vendor.lastUsed
        record["projectsUsed"] = vendor.projectsUsed
        record["address"] = vendor.address
        record["phone"] = vendor.phone
        record["email"] = vendor.email
        record["notes"] = vendor.notes
        
        return record
    }
    
    private func createVendorFromRecord(_ record: CKRecord) -> Vendor? {
        guard let name = record["name"] as? String,
              let categoryString = record["category"] as? String,
              let category = VendorCategory(rawValue: categoryString),
              let totalSpent = record["totalSpent"] as? Double,
              let isActive = record["isActive"] as? Bool,
              let dateAdded = record["dateAdded"] as? Date else {
            return nil
        }
        
        return Vendor(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            category: category,
            address: record["address"] as? String,
            phone: record["phone"] as? String,
            email: record["email"] as? String,
            notes: record["notes"] as? String,
            organizationID: organizationID,
            totalSpent: totalSpent,
            isActive: isActive,
            dateAdded: dateAdded,
            lastUsed: record["lastUsed"] as? Date,
            projectsUsed: record["projectsUsed"] as? [String]
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
                recordType: "OrgVendor",
                predicate: predicate,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            _ = try await database.save(subscription)
            print("🔔 Set up real-time sync for organization vendors")
        } catch {
            print("❌ Failed to set up vendor sync subscription: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findExistingVendor(name: String) async -> Vendor? {
        return organizationVendors.first { vendor in
            vendor.name.lowercased().trimmingCharacters(in: .whitespaces) == 
            name.lowercased().trimmingCharacters(in: .whitespaces)
        }
    }
    
    private func determineVendorCategory(_ vendorName: String) -> VendorCategory {
        let name = vendorName.lowercased()
        
        if name.contains("home depot") || name.contains("lowe") || name.contains("menards") {
            return .hardware
        } else if name.contains("lumber") || name.contains("84 lumber") {
            return .lumber
        } else if name.contains("sherwin") || name.contains("paint") {
            return .paint
        } else if name.contains("electrical") || name.contains("electric") {
            return .electrical
        } else if name.contains("plumbing") || name.contains("plumber") {
            return .plumbing
        } else if name.contains("rental") || name.contains("rent") {
            return .rental
        } else if name.contains("gas") || name.contains("fuel") || name.contains("shell") || name.contains("bp") {
            return .gas
        } else if name.contains("restaurant") || name.contains("food") || name.contains("cafe") {
            return .restaurant
        } else if name.contains("grocery") || name.contains("market") {
            return .grocery
        } else if name.contains("office") || name.contains("staples") {
            return .office
        } else if name.contains("auto") || name.contains("car") {
            return .automotive
        } else {
            return .other
        }
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
    
    private func calculateVendorAnalytics(from vendors: [Vendor]) -> VendorAnalytics {
        let totalSpending = vendors.reduce(0) { $0 + $1.totalSpent }
        let averageSpending = vendors.isEmpty ? 0 : totalSpending / Double(vendors.count)
        
        let topVendor = vendors.max(by: { $0.totalSpent < $1.totalSpent })
        
        let spendingByCategory = Dictionary(grouping: vendors) { $0.category }
            .mapValues { categoryVendors in categoryVendors.reduce(0) { $0 + $1.totalSpent } }
        
        return VendorAnalytics(
            totalVendors: vendors.count,
            totalSpending: totalSpending,
            averageSpending: averageSpending,
            topVendor: topVendor,
            spendingByCategory: spendingByCategory
        )
    }
}

// MARK: - Supporting Data Models

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

struct VendorSpendingData {
    var name: String
    var category: VendorCategory
    var totalSpent: Double
    var projectsUsed: [String]
    var receiptCount: Int
    var lastUsed: Date
}

struct VendorAnalytics {
    var totalVendors: Int = 0
    var totalSpending: Double = 0
    var averageSpending: Double = 0
    var topVendor: Vendor?
    var spendingByCategory: [VendorCategory: Double] = [:]
}

struct VendorSpendingTrend {
    let vendorID: UUID
    let timeframe: AnalyticsTimeframe
    let dataPoints: [SpendingDataPoint]
}

struct SpendingDataPoint {
    let date: Date
    let amount: Double
}

enum AnalyticsTimeframe {
    case month
    case quarter
    case year
    case allTime
}

struct AnnualVendorReport {
    let year: Int
    let totalVendors: Int
    let totalSpending: Double
    let topVendors: [Vendor]
    let spendingByCategory: [VendorCategory: Double]
}