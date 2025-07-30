import Foundation
import CloudKit
import SwiftUI

/// Simple CloudKit sharing service for organization data
class CloudKitSharingService: ObservableObject {
    private let container: CKContainer
    private let privateDB: CKDatabase
    
    init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeapp") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDB = container.privateCloudDatabase
    }
    
    /// Create a shareable link for an organization
    func createOrganizationShare(for organizationID: String, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🔗 Creating shareable link for organization: \(organizationID)")
        
        // Fetch the organization record first
        let recordID = CKRecord.ID(recordName: organizationID)
        
        privateDB.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to fetch organization record: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let orgRecord = record else {
                let error = NSError(domain: "CloudKitSharingService", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Organization record not found"])
                completion(.failure(error))
                return
            }
            
            // Create a share for this record
            let share = CKShare(rootRecord: orgRecord)
            share.publicPermission = .none // Private sharing only
            share[CKShare.SystemFieldKey.title] = "RHEIR Organization Invitation" as CKRecordValue
            
            // Save both the updated record and the share
            let operation = CKModifyRecordsOperation(recordsToSave: [orgRecord, share], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            
            operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                if let error = error {
                    print("❌ Failed to create share: \(error)")
                    completion(.failure(error))
                    return
                }
                
                // Generate the share URL
                if let shareURL = share.url {
                    print("✅ Successfully created share URL: \(shareURL)")
                    completion(.success(shareURL))
                } else {
                    let error = NSError(domain: "CloudKitSharingService", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to generate share URL"])
                    completion(.failure(error))
                }
            }
            
            self.privateDB.add(operation)
        }
    }
    
    /// Accept a shared organization (when someone clicks a shared link)
    func acceptSharedOrganization(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔗 Accepting shared organization from URL: \(url)")
        
        let operation = CKAcceptSharesOperation(shareURLs: [url])
        
        operation.acceptSharesCompletionBlock = { error in
            if let error = error {
                print("❌ Failed to accept shared organization: \(error)")
                completion(.failure(error))
                return
            }
            
            print("✅ Successfully accepted shared organization")
            // Extract organization ID from the accepted share
            // This is simplified - in production you'd want to fetch the actual organization details
            let organizationID = url.lastPathComponent
            completion(.success(organizationID))
        }
        
        container.add(operation)
    }
}

/// SwiftUI wrapper for sharing organization
struct OrganizationShareView: UIViewControllerRepresentable {
    let organizationID: String
    let sharingService = CloudKitSharingService()
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        // This is a placeholder - we'll implement proper CloudKit sharing
        let controller = UICloudSharingController { _, completion in
            // Create the share
            sharingService.createOrganizationShare(for: organizationID) { result in
                switch result {
                case .success(let shareURL):
                    // In a real implementation, you'd create a proper CKShare object here
                    completion(nil, CKContainer.default(), nil)
                case .failure(let error):
                    completion(nil, nil, error)
                }
            }
        }
        
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: OrganizationShareView
        
        init(_ parent: OrganizationShareView) {
            self.parent = parent
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ Failed to save share: \(error)")
            parent.dismiss()
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "RHEIR Organization"
        }
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("✅ Successfully saved organization share")
            parent.dismiss()
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("🛑 Stopped sharing organization")
            parent.dismiss()
        }
    }
}