import Foundation
import CloudKit
import Combine

/// CloudKit-based vendor management service for organization-wide data sharing
@MainActor
class CloudKitVendorService: ObservableObject {
    
    @Published var vendors: [Vendor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let organizationID: String
    private let container: CKContainer
    private let database: CKDatabase
    private var organizationZoneID: CKRecordZone.ID
    
    private var cancellables = Set<AnyCancellable>()
    
    init(organizationID: String) {
        self.organizationID = organizationID
        self.container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2")
        self.database = container.privateCloudDatabase
        self.organizationZoneID = CKRecordZone.ID(zoneName: "org-\(organizationID)")
        
        Task {
            await setupOrganizationZone()
            await loadVendorsFromCloudKit()
        }
    }
    
    // MARK: - Zone Setup
    
    private func setupOrganizationZone() async {
        do {
            let zone = CKRecordZone(zoneID: organizationZoneID)
            _ = try await database.save(zone)
            print("✅ Organization zone setup complete for vendors: \(organizationZoneID.zoneName)")
        } catch let error as CKError where error.code == .zoneNotEmpty {
            // Zone already exists, which is fine
            print("📋 Organization zone already exists for vendors: \(organizationZoneID.zoneName)")
        } catch {
            print("❌ Failed to setup organization zone for vendors: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to setup organization zone: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - CloudKit Operations
    
    func loadVendorsFromCloudKit() async {
        await MainActor.run { isLoading = true }
        
        do {
            let predicate = NSPredicate(format: "organizationID == %@", organizationID)
            let query = CKQuery(recordType: "Vendor", predicate: predicate)
            query.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true)
            ]
            
            let (matchResults, _) = try await database.records(matching: query, inZoneWith: organizationZoneID)
            
            let cloudKitVendors = matchResults.compactMap { (_, result) -> Vendor? in
                switch result {
                case .success(let record):
                    return createVendorFromRecord(record)
                case .failure(let error):
                    print("❌ Failed to load vendor record: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.vendors = cloudKitVendors
                self.isLoading = false
                self.errorMessage = nil
                print("✅ Loaded \(cloudKitVendors.count) vendors from CloudKit for organization")
            }
            
        } catch {
            print("❌ Failed to load vendors from CloudKit: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load vendors: \(error.localizedDescription)"
            }
        }
    }
    
    func saveVendorToCloudKit(_ vendor: Vendor) async throws {
        let record = createRecordFromVendor(vendor)
        
        do {
            _ = try await database.save(record)
            print("✅ Saved vendor to CloudKit: \(vendor.name)")
            
            // Update local array
            await MainActor.run {
                if let index = vendors.firstIndex(where: { $0.id == vendor.id }) {
                    vendors[index] = vendor
                } else {
                    vendors.append(vendor)
                    vendors.sort { $0.name.lowercased() < $1.name.lowercased() }
                }
            }
            
        } catch {
            print("❌ Failed to save vendor to CloudKit: \(error)")
            throw error
        }
    }
    
    func deleteVendorFromCloudKit(_ vendor: Vendor) async throws {
        let recordID = CKRecord.ID(recordName: vendor.id.uuidString, zoneID: organizationZoneID)
        
        do {
            _ = try await database.deleteRecord(withID: recordID)
            print("✅ Deleted vendor from CloudKit: \(vendor.name)")
            
            // Update local array
            await MainActor.run {
                vendors.removeAll { $0.id == vendor.id }
            }
            
        } catch {
            print("❌ Failed to delete vendor from CloudKit: \(error)")
            throw error
        }
    }
    
    // MARK: - Vendor Management (Public API)
    
    func findOrCreateVendor(name: String, category: VendorCategory = .other) async -> Vendor? {
        // Check if vendor already exists (case-insensitive)
        if let existingVendor = vendors.first(where: { $0.name.lowercased() == name.lowercased() }) {
            print("📍 Found existing vendor: \(existingVendor.name)")
            return existingVendor
        }
        
        // Create new vendor
        let newVendor = Vendor(
            name: name,
            category: category,
            subcategories: category.commonSubcategories,
            organizationID: organizationID
        )
        
        do {
            try await saveVendorToCloudKit(newVendor)
            print("🆕 Created new vendor: \(newVendor.name) (\(category.rawValue))")
            return newVendor
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create vendor: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func updateVendorSpending(vendorID: UUID, amount: Double) async {
        guard let vendor = vendors.first(where: { $0.id == vendorID }) else { return }
        
        var updatedVendor = vendor
        updatedVendor.totalSpent += amount
        updatedVendor.lastUsed = Date()
        
        do {
            try await saveVendorToCloudKit(updatedVendor)
            print("💰 Updated vendor spending: \(updatedVendor.name) - Total: $\(updatedVendor.totalSpent)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update vendor spending: \(error.localizedDescription)"
            }
        }
    }
    
    func getVendor(by id: UUID) -> Vendor? {
        return vendors.first { $0.id == id }
    }
    
    func getVendors(by category: VendorCategory) -> [Vendor] {
        return vendors.filter { $0.category == category && $0.isActive }
    }
    
    func getTopVendors(limit: Int = 10) -> [Vendor] {
        return vendors
            .filter { $0.isActive && $0.totalSpent > 0 }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }
    
    func saveVendor(_ vendor: Vendor) async {
        do {
            try await saveVendorToCloudKit(vendor)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save vendor: \(error.localizedDescription)"
            }
        }
    }
    
    func removeVendor(_ vendor: Vendor) async {
        do {
            try await deleteVendorFromCloudKit(vendor)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove vendor: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var vendorsSortedByName: [Vendor] {
        return vendors
            .filter { $0.isActive }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    var vendorsSortedBySpending: [Vendor] {
        return vendors
            .filter { $0.isActive }
            .sorted { $0.totalSpent > $1.totalSpent }
    }
    
    // MARK: - Analytics
    
    func getVendorSpendingByDateRange(from startDate: Date, to endDate: Date) -> [(vendor: Vendor, amount: Double)] {
        // This would require querying receipts to get spending in date range
        // For now, return basic vendor data
        return vendors
            .filter { $0.isActive && $0.totalSpent > 0 }
            .map { (vendor: $0, amount: $0.totalSpent) }
            .sorted { $0.amount > $1.amount }
    }
    
    func getVendorUsageStats() -> [(vendor: Vendor, projectCount: Int, lastUsed: Date?)] {
        return vendors
            .filter { $0.isActive }
            .map { vendor in
                (
                    vendor: vendor,
                    projectCount: vendor.projectsUsed?.count ?? 0,
                    lastUsed: vendor.lastUsed
                )
            }
            .sorted { $0.vendor.totalSpent > $1.vendor.totalSpent }
    }
    
    // MARK: - Record Conversion
    
    private func createRecordFromVendor(_ vendor: Vendor) -> CKRecord {
        let recordID = CKRecord.ID(recordName: vendor.id.uuidString, zoneID: organizationZoneID)
        let record = CKRecord(recordType: "Vendor", recordID: recordID)
        
        record["id"] = vendor.id.uuidString
        record["name"] = vendor.name
        record["category"] = vendor.category.rawValue
        record["subcategories"] = vendor.subcategories
        record["address"] = vendor.address ?? ""
        record["phone"] = vendor.phone ?? ""
        record["email"] = vendor.email ?? ""
        record["notes"] = vendor.notes ?? ""
        record["organizationID"] = organizationID
        record["totalSpent"] = vendor.totalSpent
        record["isActive"] = vendor.isActive ? 1 : 0
        record["dateAdded"] = vendor.dateAdded
        record["lastUsed"] = vendor.lastUsed
        record["projectsUsed"] = vendor.projectsUsed ?? []
        
        return record
    }
    
    private func createVendorFromRecord(_ record: CKRecord) -> Vendor? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let categoryString = record["category"] as? String,
              let category = VendorCategory(rawValue: categoryString) else {
            print("❌ Invalid vendor record format")
            return nil
        }
        
        return Vendor(
            id: id,
            name: name,
            category: category,
            subcategories: record["subcategories"] as? [String] ?? [],
            address: record["address"] as? String,
            phone: record["phone"] as? String,
            email: record["email"] as? String,
            notes: record["notes"] as? String,
            organizationID: record["organizationID"] as? String ?? organizationID,
            totalSpent: record["totalSpent"] as? Double ?? 0.0,
            isActive: (record["isActive"] as? Int ?? 1) == 1,
            dateAdded: record["dateAdded"] as? Date ?? Date(),
            lastUsed: record["lastUsed"] as? Date,
            projectsUsed: record["projectsUsed"] as? [String]
        )
    }
    
    // MARK: - Migration from Local Storage
    
    func migrateLocalVendorsToCloudKit() async throws {
        print("🔄 Migrating local vendors to CloudKit...")
        
        // Load vendors from UserDefaults
        let key = "vendors_\(organizationID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let localVendors = try? JSONDecoder().decode([Vendor].self, from: data) else {
            print("📋 No local vendors found to migrate")
            return
        }
        
        var migratedCount = 0
        
        for var vendor in localVendors {
            // Ensure vendor has organization ID
            vendor.organizationID = organizationID
            
            do {
                try await saveVendorToCloudKit(vendor)
                migratedCount += 1
            } catch {
                print("❌ Failed to migrate vendor: \(vendor.name) - \(error)")
            }
        }
        
        // Clear local storage after successful migration
        if migratedCount > 0 {
            UserDefaults.standard.removeObject(forKey: key)
            print("✅ Migrated \(migratedCount) vendors to CloudKit and cleared local storage")
        }
    }
    
    // MARK: - Offline-First Sync Methods
    
    /// Sync local changes to CloudKit when coming back online
    func syncLocalChangesToCloudKit() async {
        print("🔄 Syncing local vendor changes to CloudKit...")
        
        // Load any pending local changes
        let localChanges = loadPendingLocalChanges()
        
        var syncedCount = 0
        
        for vendorChange in localChanges {
            do {
                switch vendorChange.operation {
                case .create, .update:
                    try await saveVendorToCloudKit(vendorChange.vendor)
                    syncedCount += 1
                case .delete:
                    try await deleteVendorFromCloudKit(vendorChange.vendor)
                    syncedCount += 1
                }
                
                // Remove from pending changes after successful sync
                removePendingLocalChange(vendorChange)
                
            } catch {
                print("❌ Failed to sync vendor change: \(vendorChange.vendor.name) - \(error)")
                // Keep in pending changes for retry later
            }
        }
        
        print("✅ Synced \(syncedCount) vendor changes to CloudKit")
    }
    
    /// Save vendor locally when offline, queue for sync when online
    func saveVendorOffline(_ vendor: Vendor, operation: VendorSyncOperation = .update) {
        // Save to local UserDefaults immediately
        if let index = vendors.firstIndex(where: { $0.id == vendor.id }) {
            vendors[index] = vendor
        } else {
            vendors.append(vendor)
            vendors.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        // Save to persistent local storage
        saveVendorsToLocalStorage()
        
        // Queue for CloudKit sync when online
        queuePendingLocalChange(VendorSyncChange(vendor: vendor, operation: operation))
        
        print("📱 Saved vendor offline: \(vendor.name) (queued for sync)")
    }
    
    /// Merge CloudKit data with local data, handling conflicts
    func mergeWithCloudKitData(_ cloudKitVendors: [Vendor]) async {
        var mergedVendors: [Vendor] = []
        
        // Start with CloudKit data as source of truth
        for cloudKitVendor in cloudKitVendors {
            // Check if we have local changes for this vendor
            if let localVendor = vendors.first(where: { $0.id == cloudKitVendor.id }) {
                // Use newer modification date to resolve conflicts
                let useCloudKit = cloudKitVendor.lastUsed ?? Date.distantPast
                let useLocal = localVendor.lastUsed ?? Date.distantPast
                
                if useCloudKit >= useLocal {
                    mergedVendors.append(cloudKitVendor)
                    print("🔄 Using CloudKit version of vendor: \(cloudKitVendor.name)")
                } else {
                    mergedVendors.append(localVendor)
                    print("🔄 Using local version of vendor: \(localVendor.name)")
                    
                    // Queue local version for sync to CloudKit
                    queuePendingLocalChange(VendorSyncChange(vendor: localVendor, operation: .update))
                }
            } else {
                // Vendor only exists in CloudKit
                mergedVendors.append(cloudKitVendor)
            }
        }
        
        // Add any local-only vendors (created while offline)
        for localVendor in vendors {
            if !cloudKitVendors.contains(where: { $0.id == localVendor.id }) {
                mergedVendors.append(localVendor)
                print("📱 Found local-only vendor: \(localVendor.name) (queued for sync)")
                
                // Queue for sync to CloudKit
                queuePendingLocalChange(VendorSyncChange(vendor: localVendor, operation: .create))
            }
        }
        
        await MainActor.run {
            self.vendors = mergedVendors.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        // Save merged data locally
        saveVendorsToLocalStorage()
        
        print("🔄 Merged vendor data: \(mergedVendors.count) total vendors")
    }
    
    // MARK: - Local Storage for Offline-First
    
    private func saveVendorsToLocalStorage() {
        let key = "vendors_\(organizationID)"
        
        guard let data = try? JSONEncoder().encode(vendors) else {
            print("❌ Failed to encode vendors for local storage")
            return
        }
        
        UserDefaults.standard.set(data, forKey: key)
        print("💾 Saved \(vendors.count) vendors to local storage")
    }
    
    private func loadVendorsFromLocalStorage() -> [Vendor] {
        let key = "vendors_\(organizationID)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let loadedVendors = try? JSONDecoder().decode([Vendor].self, from: data) else {
            return []
        }
        
        return loadedVendors
    }
    
    private func queuePendingLocalChange(_ change: VendorSyncChange) {
        let key = "pending_vendor_changes_\(organizationID)"
        
        var pendingChanges = loadPendingLocalChanges()
        
        // Remove any existing changes for this vendor
        pendingChanges.removeAll { $0.vendor.id == change.vendor.id }
        
        // Add new change
        pendingChanges.append(change)
        
        // Save back to UserDefaults
        if let data = try? JSONEncoder().encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func loadPendingLocalChanges() -> [VendorSyncChange] {
        let key = "pending_vendor_changes_\(organizationID)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let changes = try? JSONDecoder().decode([VendorSyncChange].self, from: data) else {
            return []
        }
        
        return changes
    }
    
    private func removePendingLocalChange(_ change: VendorSyncChange) {
        let key = "pending_vendor_changes_\(organizationID)"
        
        var pendingChanges = loadPendingLocalChanges()
        pendingChanges.removeAll { $0.vendor.id == change.vendor.id }
        
        if let data = try? JSONEncoder().encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Supporting Types for Offline Sync

enum VendorSyncOperation: String, Codable {
    case create
    case update
    case delete
}

struct VendorSyncChange: Codable {
    let vendor: Vendor
    let operation: VendorSyncOperation
    let timestamp: Date
    
    init(vendor: Vendor, operation: VendorSyncOperation) {
        self.vendor = vendor
        self.operation = operation
        self.timestamp = Date()
    }
}