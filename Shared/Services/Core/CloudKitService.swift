import Foundation
import Combine
import CloudKit

/// Core CloudKit service providing infrastructure and account management
protocol CloudKitServiceProtocol {
    var container: CKContainer { get }
    var privateDatabase: CKDatabase { get }
    var publicDatabase: CKDatabase { get }
    
    func checkAccountStatus() -> AnyPublisher<Void, Error>
    func fetchUserRecordID() -> AnyPublisher<CKRecord.ID, Error>
}

final class CloudKitService: ObservableObject, CloudKitServiceProtocol {
    // MARK: - Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    let publicDatabase: CKDatabase
    
    @Published var isSignedIn: Bool = false
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV3") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Public Methods
    
    func checkAccountStatus() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CloudKitError.serviceUnavailable))
                return
            }
            
            self.container.accountStatus { status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [CloudKit] Account status check failed: \(error)")
                        promise(.failure(error))
                        return
                    }
                    
                    switch status {
                    case .available:
                        print("✅ [CloudKit] Account available")
                        self.isSignedIn = true
                        self.accountStatus = status
                        promise(.success(()))
                    case .noAccount:
                        let error = CloudKitError.noAccount
                        print("❌ [CloudKit] \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .couldNotDetermine:
                        let error = CloudKitError.couldNotDetermineStatus
                        print("❌ [CloudKit] \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .restricted:
                        let error = CloudKitError.accountRestricted
                        print("❌ [CloudKit] \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .temporarilyUnavailable:
                        let error = CloudKitError.temporarilyUnavailable
                        print("⚠️ [CloudKit] \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    @unknown default:
                        let error = CloudKitError.unknownStatus
                        print("❌ [CloudKit] \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchUserRecordID() -> AnyPublisher<CKRecord.ID, Error> {
        return Future<CKRecord.ID, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(CloudKitError.serviceUnavailable))
                return
            }
            
            self.container.fetchUserRecordID { recordID, error in
                if let error = error {
                    print("❌ [CloudKit] Failed to fetch user record ID: \(error)")
                    promise(.failure(error))
                } else if let recordID = recordID {
                    print("✅ [CloudKit] User record ID: \(recordID.recordName)")
                    promise(.success(recordID))
                } else {
                    print("❌ [CloudKit] No user record ID returned")
                    promise(.failure(CloudKitError.noUserRecord))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case serviceUnavailable
    case noAccount
    case couldNotDetermineStatus
    case accountRestricted
    case temporarilyUnavailable
    case unknownStatus
    case noUserRecord
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "CloudKit service is unavailable"
        case .noAccount:
            return "No iCloud account found. Please sign in to iCloud in Settings."
        case .couldNotDetermineStatus:
            return "Could not determine iCloud account status."
        case .accountRestricted:
            return "iCloud account is restricted."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable."
        case .unknownStatus:
            return "Unknown iCloud account status."
        case .noUserRecord:
            return "No user record found in CloudKit."
        }
    }
}