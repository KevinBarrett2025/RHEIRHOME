import Foundation
import CloudKit

/// Represents a progress photo stored in CloudKit using CKAsset
public struct ProgressPhoto: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var progressLogID: UUID
    public var projectID: UUID
    public var organizationID: UUID
    public var originalFileName: String
    public var fileSize: Int64
    public var contentType: String
    public var dateAdded: Date
    public var thumbnailData: Data?  // Small thumbnail stored locally
    public var ckAssetURL: URL?      // CloudKit asset URL
    public var isUploaded: Bool
    public var uploadProgress: Double
    public var caption: String       // Optional caption for the photo
    
    public init(
        id: UUID = UUID(),
        progressLogID: UUID,
        projectID: UUID,
        organizationID: UUID,
        originalFileName: String,
        fileSize: Int64 = 0,
        contentType: String = "image/jpeg",
        dateAdded: Date = Date(),
        thumbnailData: Data? = nil,
        ckAssetURL: URL? = nil,
        isUploaded: Bool = false,
        uploadProgress: Double = 0.0,
        caption: String = ""
    ) {
        self.id = id
        self.progressLogID = progressLogID
        self.projectID = projectID
        self.organizationID = organizationID
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentType = contentType
        self.dateAdded = dateAdded
        self.thumbnailData = thumbnailData
        self.ckAssetURL = ckAssetURL
        self.isUploaded = isUploaded
        self.uploadProgress = uploadProgress
        self.caption = caption
    }
}

// MARK: - CloudKit Conversion
extension ProgressPhoto {
    /// Convert to CloudKit record
    public func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ProgressPhoto", recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["progressLogID"] = progressLogID.uuidString
        record["projectID"] = projectID.uuidString
        record["organizationID"] = organizationID.uuidString
        record["originalFileName"] = originalFileName
        record["fileSize"] = fileSize
        record["contentType"] = contentType
        record["dateAdded"] = dateAdded
        record["isUploaded"] = isUploaded ? 1 : 0
        record["uploadProgress"] = uploadProgress
        record["caption"] = caption
        
        if let thumbnailData = thumbnailData {
            record["thumbnailData"] = thumbnailData
        }
        
        return record
    }
    
    /// Create from CloudKit record
    public static func fromCKRecord(_ record: CKRecord) -> ProgressPhoto? {
        guard let progressLogIDString = record["progressLogID"] as? String,
              let progressLogID = UUID(uuidString: progressLogIDString),
              let projectIDString = record["projectID"] as? String,
              let projectID = UUID(uuidString: projectIDString),
              let organizationIDString = record["organizationID"] as? String,
              let organizationID = UUID(uuidString: organizationIDString),
              let originalFileName = record["originalFileName"] as? String,
              let dateAdded = record["dateAdded"] as? Date else {
            return nil
        }
        
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let fileSize = record["fileSize"] as? Int64 ?? 0
        let contentType = record["contentType"] as? String ?? "image/jpeg"
        let isUploaded = (record["isUploaded"] as? Int64 ?? 0) == 1
        let uploadProgress = record["uploadProgress"] as? Double ?? 0.0
        let caption = record["caption"] as? String ?? ""
        let thumbnailData = record["thumbnailData"] as? Data
        
        // Extract CKAsset URL if available
        var ckAssetURL: URL?
        if let asset = record["imageAsset"] as? CKAsset {
            ckAssetURL = asset.fileURL
        }
        
        return ProgressPhoto(
            id: id,
            progressLogID: progressLogID,
            projectID: projectID,
            organizationID: organizationID,
            originalFileName: originalFileName,
            fileSize: fileSize,
            contentType: contentType,
            dateAdded: dateAdded,
            thumbnailData: thumbnailData,
            ckAssetURL: ckAssetURL,
            isUploaded: isUploaded,
            uploadProgress: uploadProgress,
            caption: caption
        )
    }
}