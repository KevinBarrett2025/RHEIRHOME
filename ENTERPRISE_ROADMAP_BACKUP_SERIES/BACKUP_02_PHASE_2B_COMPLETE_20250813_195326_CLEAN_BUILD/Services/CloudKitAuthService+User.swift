import Foundation
import Combine
import CloudKit

extension CloudKitAuthService {
    /// Finds or creates the "Users" record in the *private* database
    /// under recordName == appleUser.id, and returns a `User`.
    internal func upsertUserRecord(
        appleUser: User
    ) -> AnyPublisher<User, Error> {
        let privateDB = container.privateCloudDatabase
        let recordID  = CKRecord.ID(recordName: appleUser.id)

        return Future<User, Error> { promise in
            // 1) Try to fetch existing Users record
            privateDB.fetch(withRecordID: recordID) { fetchedRec, fetchErr in
                if let err = fetchErr as? CKError, err.code == .unknownItem {
                    // → not found: create it
                    let newRec = CKRecord(recordType: "Users", recordID: recordID)
                    newRec["userID"] = appleUser.id    as CKRecordValue
                    newRec["email" ] = appleUser.email as CKRecordValue

                    privateDB.save(newRec) { savedRec, saveErr in
                        if let saveErr = saveErr {
                            print("❌ Error saving user record: \(saveErr)")
                            // If we can't create the record, still return the user
                            // This allows the app to work even if CloudKit sync fails
                            if let ckError = saveErr as? CKError,
                               ckError.code == .permissionFailure || ckError.code == .notAuthenticated {
                                print("⚠️ CloudKit permission issue, proceeding with local user")
                                promise(.success(appleUser))
                            } else {
                                promise(.failure(saveErr))
                            }
                        } else if let rec = savedRec {
                            let created = User(
                                id: rec["userID"] as? String ?? "",
                                email: rec["email"]  as? String ?? ""
                            )
                            promise(.success(created))
                        }
                    }

                } else if let err = fetchErr {
                    // some other fetch error
                    print("❌ Error fetching user record: \(err)")
                    // If fetch fails, still return the user for local operation
                    if let ckError = err as? CKError,
                       ckError.code == .permissionFailure || ckError.code == .notAuthenticated {
                        print("⚠️ CloudKit permission issue, proceeding with local user")
                        promise(.success(appleUser))
                    } else {
                        promise(.failure(err))
                    }

                } else if let rec = fetchedRec {
                    // → already exists, just return it
                    let existing = User(
                        id: rec["userID"] as? String ?? "",
                        email: rec["email"]  as? String ?? ""
                    )
                    promise(.success(existing))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
