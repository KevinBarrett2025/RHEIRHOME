import Foundation
import Combine
import CloudKit
import OSLog

/// Service responsible for user management operations
protocol UserServiceProtocol {
    func upsertUser(_ user: User) -> AnyPublisher<User, Error>
    func fetchUser(by id: String) -> AnyPublisher<User?, Error>
    func updateUser(_ user: User) -> AnyPublisher<User, Error>
    func deleteUser(id: String) -> AnyPublisher<Void, Error>
}

final class CloudKitUserService: UserServiceProtocol {
    // MARK: - Dependencies
    private let cloudKitService: CloudKitServiceProtocol
    
    // MARK: - Initialization
    init(cloudKitService: CloudKitServiceProtocol) {
        self.cloudKitService = cloudKitService
    }
    
    // MARK: - Public Methods
    
    func upsertUser(_ user: User) -> AnyPublisher<User, Error> {
        Logger.auth.info("Upserting CloudKit user record [user=\(user.id, privacy: .private(mask: .hash))]")
        
        let recordID = CKRecord.ID(recordName: user.id)
        
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(UserServiceError.serviceUnavailable))
                return
            }
            
            let privateDB = self.cloudKitService.privateDatabase
            
            // Try to fetch existing user record
            privateDB.fetch(withRecordID: recordID) { fetchedRecord, fetchError in
                if let error = fetchError as? CKError, error.code == .unknownItem {
                    // User doesn't exist, create new record
                    self.createUserRecord(user, promise: promise)
                } else if let error = fetchError {
                    // Other fetch error
                    self.handleCloudKitError(error, fallbackUser: user, promise: promise)
                } else if let record = fetchedRecord {
                    // User exists, update if needed
                    self.updateUserRecord(record, with: user, promise: promise)
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchUser(by id: String) -> AnyPublisher<User?, Error> {
        Logger.auth.info("Fetching CloudKit user record [user=\(id, privacy: .private(mask: .hash))]")
        
        let recordID = CKRecord.ID(recordName: id)
        
        return Future<User?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(UserServiceError.serviceUnavailable))
                return
            }
            
            let privateDB = self.cloudKitService.privateDatabase
            
            privateDB.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        promise(.success(nil)) // User not found
                    } else {
                        promise(.failure(error))
                    }
                } else if let record = record {
                    let user = self.mapRecordToUser(record)
                    promise(.success(user))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateUser(_ user: User) -> AnyPublisher<User, Error> {
        Logger.auth.info("Updating CloudKit user record [user=\(user.id, privacy: .private(mask: .hash))]")
        
        let recordID = CKRecord.ID(recordName: user.id)
        
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(UserServiceError.serviceUnavailable))
                return
            }
            
            let privateDB = self.cloudKitService.privateDatabase
            
            privateDB.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    promise(.failure(error))
                } else if let record = record {
                    self.updateUserRecord(record, with: user, promise: promise)
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteUser(id: String) -> AnyPublisher<Void, Error> {
        Logger.auth.notice("Deleting CloudKit user record [user=\(id, privacy: .private(mask: .hash))]")
        
        let recordID = CKRecord.ID(recordName: id)
        
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(UserServiceError.serviceUnavailable))
                return
            }
            
            let privateDB = self.cloudKitService.privateDatabase
            
            privateDB.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func createUserRecord(_ user: User, promise: @escaping (Result<User, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: user.id)
        let record = CKRecord(recordType: "Users", recordID: recordID)
        
        record["userID"] = user.id as CKRecordValue
        record["email"] = user.email as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        
        let privateDB = cloudKitService.privateDatabase
        
        privateDB.save(record) { savedRecord, error in
            if let error = error {
                Logger.auth.error("Failed to create CloudKit user record: \(error.localizedDescription, privacy: .public)")
                self.handleCloudKitError(error, fallbackUser: user, promise: promise)
            } else if let savedRecord = savedRecord {
                let createdUser = self.mapRecordToUser(savedRecord)
                Logger.auth.notice("Created CloudKit user record successfully.")
                promise(.success(createdUser))
            }
        }
    }
    
    private func updateUserRecord(_ record: CKRecord, with user: User, promise: @escaping (Result<User, Error>) -> Void) {
        record["userID"] = user.id as CKRecordValue
        record["email"] = user.email as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        
        let privateDB = cloudKitService.privateDatabase
        
        privateDB.save(record) { savedRecord, error in
            if let error = error {
                Logger.auth.error("Failed to update CloudKit user record: \(error.localizedDescription, privacy: .public)")
                self.handleCloudKitError(error, fallbackUser: user, promise: promise)
            } else if let savedRecord = savedRecord {
                let updatedUser = self.mapRecordToUser(savedRecord)
                Logger.auth.notice("Updated CloudKit user record successfully.")
                promise(.success(updatedUser))
            }
        }
    }
    
    private func mapRecordToUser(_ record: CKRecord) -> User {
        return User(
            id: record["userID"] as? String ?? record.recordID.recordName,
            email: record["email"] as? String ?? ""
        )
    }
    
    private func handleCloudKitError(_ error: Error, fallbackUser: User, promise: @escaping (Result<User, Error>) -> Void) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .permissionFailure, .notAuthenticated:
                Logger.auth.warning("Using fallback user because CloudKit permissions are unavailable.")
                promise(.success(fallbackUser))
            case .networkFailure, .networkUnavailable:
                Logger.auth.warning("Using fallback user because CloudKit networking is unavailable.")
                promise(.success(fallbackUser))
            default:
                promise(.failure(error))
            }
        } else {
            promise(.failure(error))
        }
    }
}

// MARK: - User Service Errors
enum UserServiceError: LocalizedError {
    case serviceUnavailable
    case userNotFound
    case invalidUserData
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "User service is unavailable"
        case .userNotFound:
            return "User not found"
        case .invalidUserData:
            return "Invalid user data provided"
        }
    }
}
