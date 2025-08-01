import Foundation
import CloudKit
import UIKit
import Combine

/// Service for managing receipt, progress, and task photos with CloudKit CKAssets
public class CloudKitPhotoService: ObservableObject {
    
    private let container: CKContainer
    private let database: CKDatabase
    
    @Published public var uploadProgress: [UUID: Double] = [:]
    @Published public var downloadProgress: [UUID: Double] = [:]
    
    public init(containerIdentifier: String = "iCloud.com.rheirhome.rheirhomeappV2") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - Receipt Photos
    
    /// Upload receipt photo to CloudKit
    public func uploadReceiptPhoto(
        imageData: Data,
        receiptID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String? = nil
    ) async throws -> ReceiptPhoto {
        
        let receiptPhoto = try await createReceiptPhotoRecord(
            imageData: imageData,
            receiptID: receiptID,
            projectID: projectID,
            organizationID: organizationID,
            fileName: fileName
        )
        
        // Upload to CloudKit
        let record = try await uploadPhotoRecord(receiptPhoto.toCKRecord(), imageData: imageData, photoID: receiptPhoto.id)
        
        // Update with CloudKit info
        var updatedPhoto = receiptPhoto
        updatedPhoto.isUploaded = true
        updatedPhoto.uploadProgress = 1.0
        
        if let asset = record["imageAsset"] as? CKAsset {
            updatedPhoto.ckAssetURL = asset.fileURL
        }
        
        return updatedPhoto
    }
    
    /// Fetch receipt photos for a specific receipt
    public func fetchReceiptPhotos(receiptID: UUID) async throws -> [ReceiptPhoto] {
        let predicate = NSPredicate(format: "receiptID == %@", receiptID.uuidString)
        let query = CKQuery(recordType: "ReceiptPhoto", predicate: predicate)
        
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return ReceiptPhoto.fromCKRecord(record)
            case .failure(let error):
                print("❌ Error fetching receipt photo: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Progress Photos
    
    /// Upload progress photo to CloudKit
    public func uploadProgressPhoto(
        imageData: Data,
        progressLogID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String? = nil,
        caption: String = ""
    ) async throws -> ProgressPhoto {
        
        let progressPhoto = try await createProgressPhotoRecord(
            imageData: imageData,
            progressLogID: progressLogID,
            projectID: projectID,
            organizationID: organizationID,
            fileName: fileName,
            caption: caption
        )
        
        // Upload to CloudKit
        let record = try await uploadPhotoRecord(progressPhoto.toCKRecord(), imageData: imageData, photoID: progressPhoto.id)
        
        // Update with CloudKit info
        var updatedPhoto = progressPhoto
        updatedPhoto.isUploaded = true
        updatedPhoto.uploadProgress = 1.0
        
        if let asset = record["imageAsset"] as? CKAsset {
            updatedPhoto.ckAssetURL = asset.fileURL
        }
        
        return updatedPhoto
    }
    
    /// Fetch progress photos for a specific progress log
    public func fetchProgressPhotos(progressLogID: UUID) async throws -> [ProgressPhoto] {
        let predicate = NSPredicate(format: "progressLogID == %@", progressLogID.uuidString)
        let query = CKQuery(recordType: "ProgressPhoto", predicate: predicate)
        
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return ProgressPhoto.fromCKRecord(record)
            case .failure(let error):
                print("❌ Error fetching progress photo: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Task Photos
    
    /// Upload task photo to CloudKit
    public func uploadTaskPhoto(
        imageData: Data,
        taskID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String? = nil,
        caption: String = ""
    ) async throws -> TaskPhoto {
        
        let taskPhoto = try await createTaskPhotoRecord(
            imageData: imageData,
            taskID: taskID,
            projectID: projectID,
            organizationID: organizationID,
            fileName: fileName,
            caption: caption
        )
        
        // Upload to CloudKit
        let record = try await uploadPhotoRecord(taskPhoto.toCKRecord(), imageData: imageData, photoID: taskPhoto.id)
        
        // Update with CloudKit info
        var updatedPhoto = taskPhoto
        updatedPhoto.isUploaded = true
        updatedPhoto.uploadProgress = 1.0
        
        if let asset = record["imageAsset"] as? CKAsset {
            updatedPhoto.ckAssetURL = asset.fileURL
        }
        
        return updatedPhoto
    }
    
    /// Fetch task photos for a specific task
    public func fetchTaskPhotos(taskID: UUID) async throws -> [TaskPhoto] {
        let predicate = NSPredicate(format: "taskID == %@", taskID.uuidString)
        let query = CKQuery(recordType: "TaskPhoto", predicate: predicate)
        
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return TaskPhoto.fromCKRecord(record)
            case .failure(let error):
                print("❌ Error fetching task photo: \(error)")
                return nil
            }
        }
    }
    
    /// Upload multiple task photos at once
    public func uploadTaskPhotos(
        imageDataList: [Data],
        taskID: UUID,
        projectID: UUID,
        organizationID: UUID,
        captions: [String] = []
    ) async throws -> [TaskPhoto] {
        
        var uploadedPhotos: [TaskPhoto] = []
        
        for (index, imageData) in imageDataList.enumerated() {
            let caption = captions.indices.contains(index) ? captions[index] : ""
            let fileName = "task_\(taskID.uuidString)_\(index)_\(Date().timeIntervalSince1970).jpg"
            
            do {
                let taskPhoto = try await uploadTaskPhoto(
                    imageData: imageData,
                    taskID: taskID,
                    projectID: projectID,
                    organizationID: organizationID,
                    fileName: fileName,
                    caption: caption
                )
                uploadedPhotos.append(taskPhoto)
                
                print("✅ TaskPhoto uploaded: \(taskPhoto.id)")
                
            } catch {
                print("❌ Failed to upload task photo \(index): \(error)")
                // Continue with other photos even if one fails
            }
        }
        
        return uploadedPhotos
    }
    
    // MARK: - Photo Download
    
    /// Download photo data from CloudKit asset
    public func downloadPhotoData(from assetURL: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: assetURL)
        return data
    }
    
    /// Download photo with progress tracking
    public func downloadPhotoWithProgress(photoID: UUID, from assetURL: URL) -> AnyPublisher<Data, Error> {
        return Future<Data, Error> { [weak self] promise in
            Task {
                do {
                    if let self = self {
                        await MainActor.run {
                            self.downloadProgress[photoID] = 0.0
                        }
                    }
                    
                    let data = try await self?.downloadPhotoData(from: assetURL)
                    
                    if let self = self {
                        await MainActor.run {
                            self.downloadProgress[photoID] = 1.0
                        }
                    }
                    
                    promise(.success(data ?? Data()))
                } catch {
                    if let self = self {
                        Task { @MainActor in
                            self.downloadProgress.removeValue(forKey: photoID)
                        }
                    }
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Download task photo with caching support
    public func downloadTaskPhoto(photoID: UUID) async throws -> UIImage? {
        // First try to get from local cache
        if let cachedImage = getCachedImage(photoID: photoID) {
            return cachedImage
        }
        
        // Fetch TaskPhoto record to get asset URL
        let taskPhotos = try await fetchTaskPhotoByID(photoID: photoID)
        guard let taskPhoto = taskPhotos.first,
              let assetURL = taskPhoto.ckAssetURL else {
            return nil
        }
        
        // Download image data
        let imageData = try await downloadPhotoData(from: assetURL)
        let image = UIImage(data: imageData)
        
        // Cache for future use
        if let image = image {
            cacheImage(image, photoID: photoID)
        }
        
        return image
    }
    
    // MARK: - Helper Methods
    
    private func createReceiptPhotoRecord(
        imageData: Data,
        receiptID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String?
    ) async throws -> ReceiptPhoto {
        
        let finalFileName = fileName ?? "receipt_\(Date().timeIntervalSince1970).jpg"
        let thumbnail = generateThumbnail(from: imageData)
        
        return ReceiptPhoto(
            receiptID: receiptID,
            projectID: projectID,
            organizationID: organizationID,
            originalFileName: finalFileName,
            fileSize: Int64(imageData.count),
            contentType: "image/jpeg",
            thumbnailData: thumbnail
        )
    }
    
    private func createProgressPhotoRecord(
        imageData: Data,
        progressLogID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String?,
        caption: String
    ) async throws -> ProgressPhoto {
        
        let finalFileName = fileName ?? "progress_\(Date().timeIntervalSince1970).jpg"
        let thumbnail = generateThumbnail(from: imageData)
        
        return ProgressPhoto(
            progressLogID: progressLogID,
            projectID: projectID,
            organizationID: organizationID,
            originalFileName: finalFileName,
            fileSize: Int64(imageData.count),
            contentType: "image/jpeg",
            thumbnailData: thumbnail,
            caption: caption
        )
    }
    
    private func createTaskPhotoRecord(
        imageData: Data,
        taskID: UUID,
        projectID: UUID,
        organizationID: UUID,
        fileName: String?,
        caption: String
    ) async throws -> TaskPhoto {
        
        let finalFileName = fileName ?? "task_\(Date().timeIntervalSince1970).jpg"
        let thumbnail = generateThumbnail(from: imageData)
        
        return TaskPhoto(
            taskID: taskID,
            projectID: projectID,
            organizationID: organizationID,
            originalFileName: finalFileName,
            fileSize: Int64(imageData.count),
            contentType: "image/jpeg",
            thumbnailData: thumbnail,
            caption: caption
        )
    }
    
    private func uploadPhotoRecord(_ record: CKRecord, imageData: Data, photoID: UUID) async throws -> CKRecord {
        // Create temporary file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(photoID.uuidString).jpg")
        
        do {
            try imageData.write(to: tempURL)
            
            // Create CKAsset
            let asset = CKAsset(fileURL: tempURL)
            record["imageAsset"] = asset
            
            // Update progress
            await MainActor.run {
                self.uploadProgress[photoID] = 0.5
            }
            
            // Save to CloudKit
            let savedRecord = try await database.save(record)
            
            // Update progress
            await MainActor.run {
                self.uploadProgress[photoID] = 1.0
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
            
            return savedRecord
            
        } catch {
            // Clean up temporary file on error
            try? FileManager.default.removeItem(at: tempURL)
            
            Task { @MainActor in
                self.uploadProgress.removeValue(forKey: photoID)
            }
            
            throw error
        }
    }
    
    private func generateThumbnail(from imageData: Data, size: CGSize = CGSize(width: 120, height: 120)) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let thumbnailImage = image.preparingThumbnail(of: size) ?? image
        return thumbnailImage.jpegData(compressionQuality: 0.7)
    }
    
    private func fetchTaskPhotoByID(photoID: UUID) async throws -> [TaskPhoto] {
        let predicate = NSPredicate(format: "___recordID == %@", photoID.uuidString)
        let query = CKQuery(recordType: "TaskPhoto", predicate: predicate)
        
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap { (_, result) in
            switch result {
            case .success(let record):
                return TaskPhoto.fromCKRecord(record)
            case .failure(let error):
                print("❌ Error fetching task photo by ID: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Image Caching
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    private func getCachedImage(photoID: UUID) -> UIImage? {
        return imageCache.object(forKey: photoID.uuidString as NSString)
    }
    
    private func cacheImage(_ image: UIImage, photoID: UUID) {
        imageCache.setObject(image, forKey: photoID.uuidString as NSString)
    }
    
    // MARK: - Cleanup
    
    /// Delete photo from CloudKit
    public func deletePhoto(recordID: CKRecord.ID) async throws {
        try await database.deleteRecord(withID: recordID)
    }
    
    /// Delete all photos for a receipt
    public func deleteReceiptPhotos(receiptID: UUID) async throws {
        let photos = try await fetchReceiptPhotos(receiptID: receiptID)
        
        for photo in photos {
            let recordID = CKRecord.ID(recordName: photo.id.uuidString)
            try await deletePhoto(recordID: recordID)
        }
    }
    
    /// Delete all photos for a progress log
    public func deleteProgressPhotos(progressLogID: UUID) async throws {
        let photos = try await fetchProgressPhotos(progressLogID: progressLogID)
        
        for photo in photos {
            let recordID = CKRecord.ID(recordName: photo.id.uuidString)
            try await deletePhoto(recordID: recordID)
        }
    }
    
    /// Delete all photos for a task
    public func deleteTaskPhotos(taskID: UUID) async throws {
        let photos = try await fetchTaskPhotos(taskID: taskID)
        
        for photo in photos {
            let recordID = CKRecord.ID(recordName: photo.id.uuidString)
            try await deletePhoto(recordID: recordID)
        }
    }
    
    /// Delete specific task photos by their IDs
    public func deleteTaskPhotos(photoIDs: [UUID]) async throws {
        for photoID in photoIDs {
            let recordID = CKRecord.ID(recordName: photoID.uuidString)
            try await deletePhoto(recordID: recordID)
        }
        
        print("✅ Deleted \(photoIDs.count) task photos from CloudKit")
    }
}