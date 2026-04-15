import Foundation
import Combine
import CloudKit
import OSLog

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
                        Logger.auth.error("CloudKit account status check failed: \(error.localizedDescription, privacy: .public)")
                        promise(.failure(error))
                        return
                    }
                    
                    switch status {
                    case .available:
                        Logger.auth.notice("CloudKit account is available.")
                        self.isSignedIn = true
                        self.accountStatus = status
                        promise(.success(()))
                    case .noAccount:
                        let error = CloudKitError.noAccount
                        Logger.auth.warning("\(error.localizedDescription ?? "No iCloud account found.", privacy: .public)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .couldNotDetermine:
                        let error = CloudKitError.couldNotDetermineStatus
                        Logger.auth.warning("\(error.localizedDescription ?? "Could not determine iCloud account status.", privacy: .public)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .restricted:
                        let error = CloudKitError.accountRestricted
                        Logger.auth.warning("\(error.localizedDescription ?? "iCloud account is restricted.", privacy: .public)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    case .temporarilyUnavailable:
                        let error = CloudKitError.temporarilyUnavailable
                        Logger.auth.warning("\(error.localizedDescription ?? "iCloud is temporarily unavailable.", privacy: .public)")
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    @unknown default:
                        let error = CloudKitError.unknownStatus
                        Logger.auth.error("\(error.localizedDescription ?? "Unknown iCloud account status.", privacy: .public)")
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
                    Logger.auth.error("Failed to fetch CloudKit user record ID: \(error.localizedDescription, privacy: .public)")
                    promise(.failure(error))
                } else if let recordID = recordID {
                    Logger.auth.notice("Fetched CloudKit user record ID [record=\(recordID.recordName, privacy: .private(mask: .hash))]")
                    promise(.success(recordID))
                } else {
                    Logger.auth.error("CloudKit did not return a user record ID.")
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
