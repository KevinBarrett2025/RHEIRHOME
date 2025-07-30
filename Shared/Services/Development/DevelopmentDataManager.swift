import Foundation
import CloudKit

/// DEVELOPMENT ONLY: One-time data reset utility
/// ⚠️ This should NEVER be included in production builds
#if DEBUG

@MainActor
public class DevelopmentDataManager: ObservableObject {
    
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase
    
    @Published public var isResetting = false
    @Published public var resetProgress = ""
    
    // Safety flags to prevent accidental execution
    private let RESET_CONFIRMATION_CODE = "RESET_RHEIR_DEV_DATA_2025"
    private var hasBeenReset = UserDefaults.standard.bool(forKey: "DevelopmentDataHasBeenReset")
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2")
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
    }
    
    /// Perform one-time development data reset
    /// This requires explicit confirmation and can only be run once
    public func performOneTimeDataReset(confirmationCode: String) async throws {
        
        // Safety checks
        guard confirmationCode == RESET_CONFIRMATION_CODE else {
            throw DevelopmentError.invalidConfirmationCode
        }
        
        guard !hasBeenReset else {
            throw DevelopmentError.alreadyReset
        }
        
        // Additional safety: Only run in debug mode
        #if !DEBUG
        throw DevelopmentError.productionEnvironment
        #endif
        
        isResetting = true
        resetProgress = "Starting development data reset..."
        
        do {
            // Reset organization data
            resetProgress = "Deleting organizations..."
            try await deleteAllRecords(recordType: "Organization", database: privateDB)
            
            // Reset organization registry (public)
            resetProgress = "Deleting organization registry..."
            try await deleteAllRecords(recordType: "OrganizationRegistry", database: publicDB)
            
            // Reset projects
            resetProgress = "Deleting projects..."
            try await deleteAllRecords(recordType: "Project", database: privateDB)
            
            // Reset users
            resetProgress = "Deleting users..."
            try await deleteAllRecords(recordType: "User", database: privateDB)
            
            // Reset team members
            resetProgress = "Deleting team members..."
            try await deleteAllRecords(recordType: "TeamMember", database: privateDB)
            
            // Reset receipts
            resetProgress = "Deleting receipts..."
            try await deleteAllRecords(recordType: "Receipt", database: privateDB)
            
            // Reset vendors
            resetProgress = "Deleting vendors..."
            try await deleteAllRecords(recordType: "Vendor", database: privateDB)
            
            // Reset payment methods
            resetProgress = "Deleting payment methods..."
            try await deleteAllRecords(recordType: "PaymentMethod", database: privateDB)
            
            // Reset photos
            resetProgress = "Deleting photos..."
            try await deleteAllRecords(recordType: "ReceiptPhoto", database: privateDB)
            try await deleteAllRecords(recordType: "ProgressPhoto", database: privateDB)
            try await deleteAllRecords(recordType: "TaskPhoto", database: privateDB)
            
            // Clear local caches
            resetProgress = "Clearing local data..."
            clearLocalData()
            
            // Mark as reset to prevent future executions
            UserDefaults.standard.set(true, forKey: "DevelopmentDataHasBeenReset")
            hasBeenReset = true
            
            resetProgress = "✅ Development data reset complete!"
            
            print("🔄 DEVELOPMENT DATA RESET COMPLETED")
            print("   This operation has been permanently disabled.")
            print("   All CloudKit data has been deleted for fresh start.")
            
        } catch {
            resetProgress = "❌ Reset failed: \(error.localizedDescription)"
            isResetting = false
            throw error
        }
        
        isResetting = false
    }
    
    private func deleteAllRecords(recordType: String, database: CKDatabase) async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        let result = try await database.records(matching: query)
        let recordIDs = result.matchResults.compactMap { (recordID, _) in recordID }
        
        if !recordIDs.isEmpty {
            let deleteResult = try await database.modifyRecords(saving: [], deleting: recordIDs)
            print("🗑️ Deleted \(deleteResult.deleteResults.count) \(recordType) records")
        }
    }
    
    private func clearLocalData() {
        // Clear UserDefaults related to app data
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedProjectID")
        defaults.removeObject(forKey: "currentOrganizationID")
        defaults.removeObject(forKey: "lastSyncTimestamp")
        defaults.removeObject(forKey: "cachedUserData")
        
        // Clear any cached files
        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("AppCache"))
        }
    }
    
    /// Check if reset is available (development only)
    public var canPerformReset: Bool {
        #if DEBUG
        return !hasBeenReset
        #else
        return false
        #endif
    }
    
    /// Get reset status information
    public var resetStatusInfo: String {
        if hasBeenReset {
            return "Development data has already been reset. This operation is no longer available."
        } else {
            return "One-time development data reset is available. This will delete ALL CloudKit data."
        }
    }
}

public enum DevelopmentError: LocalizedError {
    case invalidConfirmationCode
    case alreadyReset
    case productionEnvironment
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfirmationCode:
            return "Invalid confirmation code provided"
        case .alreadyReset:
            return "Development data has already been reset"
        case .productionEnvironment:
            return "Data reset is not available in production environment"
        }
    }
}

#endif