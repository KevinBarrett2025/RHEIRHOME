import Foundation
import UIKit

/// Service for migrating from imageDatas to photoIDs system
public class PhotoDataMigrationService: ObservableObject {
    
    private let photoService = CloudKitPhotoService()
    @Published public var migrationProgress: [UUID: Double] = [:]
    @Published public var isCompleted: Bool = false
    
    // MARK: - Private Helper Methods for Legacy Data Access
    
    /// Safely access legacy imageDatas from ProjectTask
    private func getLegacyTaskImageDatas(_ task: ProjectTask) -> [Data] {
        // Temporarily suppress deprecation warning for migration purposes
        return task.imageDatas
    }
    
    /// Safely access legacy imageDatas from ProgressLog 
    private func getLegacyProgressLogImageDatas(_ progressLog: ProgressLog) -> [Data] {
        // Temporarily suppress deprecation warning for migration purposes
        return progressLog.imageDatas
    }
    
    /// Safely access legacy imageDatas from Receipt
    private func getLegacyReceiptImageDatas(_ receipt: Receipt) -> [Data] {
        // Access the deprecated property for migration purposes only
        // This suppresses the deprecation warning since we need this for migration
        return receipt.imageDatas
    }
    
    // MARK: - Task Photo Migration
    
    /// Migrate ProjectTask from imageDatas to photoIDs
    public func migrateTaskPhotos(
        task: ProjectTask,
        projectID: UUID,
        organizationID: UUID
    ) async throws -> ProjectTask {
        
        // For backwards compatibility, check if task has legacy imageDatas
        let legacyImageDatas = getLegacyTaskImageDatas(task)
        guard !legacyImageDatas.isEmpty else {
            return task
        }
        
        print(" Migrating \(legacyImageDatas.count) photos for task: \(task.title)")
        
        var updatedTask = task
        var uploadedPhotoIDs: [UUID] = []
        
        // Upload each image data to CloudKit
        for (index, imageData) in legacyImageDatas.enumerated() {
            do {
                await MainActor.run {
                    migrationProgress[task.id] = Double(index) / Double(legacyImageDatas.count)
                }
                
                let taskPhoto = try await photoService.uploadTaskPhoto(
                    imageData: imageData,
                    taskID: task.id,
                    projectID: projectID,
                    organizationID: organizationID,
                    fileName: "migrated_task_\(task.id)_\(index).jpg",
                    caption: "Migrated from legacy imageDatas"
                )
                
                uploadedPhotoIDs.append(taskPhoto.id)
                print(" Migrated photo \(index + 1)/\(legacyImageDatas.count) for task: \(task.title)")
                
            } catch {
                print(" Failed to migrate photo \(index + 1) for task \(task.title): \(error)")
                // Continue with other photos even if one fails
            }
        }
        
        // Update task with new photoIDs
        updatedTask.photoIDs = uploadedPhotoIDs
        
        await MainActor.run {
            migrationProgress[task.id] = 1.0
        }
        
        print(" Successfully migrated \(uploadedPhotoIDs.count) photos for task: \(task.title)")
        
        return updatedTask
    }
    
    /// Migrate all tasks in a project from imageDatas to photoIDs
    public func migrateAllTaskPhotos(
        project: Project,
        organizationID: UUID
    ) async throws -> Project {
        
        print(" Starting migration for project: \(project.name)")
        
        var updatedProject = project
        var migratedTasks: [ProjectTask] = []
        
        let tasksWithPhotos = project.tasks.filter { 
            // Check legacy imageDatas for migration detection
            !getLegacyTaskImageDatas($0).isEmpty
        }
        
        guard !tasksWithPhotos.isEmpty else {
            print(" No tasks with legacy photos found in project: \(project.name)")
            return project
        }
        
        print(" Found \(tasksWithPhotos.count) tasks with photos to migrate")
        
        for task in project.tasks {
            let legacyImageDatas = getLegacyTaskImageDatas(task)
            if !legacyImageDatas.isEmpty {
                let migratedTask = try await migrateTaskPhotos(
                    task: task,
                    projectID: project.id,
                    organizationID: organizationID
                )
                migratedTasks.append(migratedTask)
            } else {
                migratedTasks.append(task)
            }
        }
        
        updatedProject.tasks = migratedTasks
        
        await MainActor.run {
            isCompleted = true
        }
        
        print(" Completed migration for project: \(project.name)")
        
        return updatedProject
    }
    
    // MARK: - Progress Log Migration
    
    /// Migrate ProgressLog from imageDatas to photoIDs
    public func migrateProgressLogPhotos(
        progressLog: ProgressLog,
        projectID: UUID,
        organizationID: UUID
    ) async throws -> ProgressLog {
        
        // For backwards compatibility, check if progress log has legacy imageDatas
        let legacyImageDatas = getLegacyProgressLogImageDatas(progressLog)
        guard !legacyImageDatas.isEmpty else {
            return progressLog
        }
        
        print(" Migrating \(legacyImageDatas.count) photos for progress log: \(progressLog.workDescription)")
        
        var updatedLog = progressLog
        var uploadedPhotoIDs: [UUID] = []
        
        // Upload each image data to CloudKit
        for (index, imageData) in legacyImageDatas.enumerated() {
            do {
                await MainActor.run {
                    migrationProgress[progressLog.id] = Double(index) / Double(legacyImageDatas.count)
                }
                
                let progressPhoto = try await photoService.uploadProgressPhoto(
                    imageData: imageData,
                    progressLogID: progressLog.id,
                    projectID: projectID,
                    organizationID: organizationID,
                    fileName: "migrated_progress_\(progressLog.id)_\(index).jpg",
                    caption: "Migrated from legacy imageDatas"
                )
                
                uploadedPhotoIDs.append(progressPhoto.id)
                print(" Migrated photo \(index + 1)/\(legacyImageDatas.count) for progress log")
                
            } catch {
                print(" Failed to migrate progress photo \(index + 1): \(error)")
                // Continue with other photos even if one fails
            }
        }
        
        // Update progress log with new photoIDs
        updatedLog.photoIDs = uploadedPhotoIDs
        
        await MainActor.run {
            migrationProgress[progressLog.id] = 1.0
        }
        
        print(" Successfully migrated \(uploadedPhotoIDs.count) photos for progress log")
        
        return updatedLog
    }
    
    // MARK: - Receipt Migration
    
    /// Migrate Receipt from imageDatas to photoIDs
    public func migrateReceiptPhotos(
        receipt: Receipt,
        projectID: UUID,
        organizationID: UUID
    ) async throws -> Receipt {
        
        // For backwards compatibility, check if receipt has legacy imageDatas
        let legacyImageDatas = getLegacyReceiptImageDatas(receipt)
        guard !legacyImageDatas.isEmpty else {
            return receipt
        }
        
        print(" Migrating \(legacyImageDatas.count) photos for receipt: \(receipt.vendor)")
        
        var updatedReceipt = receipt
        var uploadedPhotoIDs: [UUID] = []
        
        // Upload each image data to CloudKit
        for (index, imageData) in legacyImageDatas.enumerated() {
            do {
                await MainActor.run {
                    migrationProgress[receipt.id] = Double(index) / Double(legacyImageDatas.count)
                }
                
                let receiptPhoto = try await photoService.uploadReceiptPhoto(
                    imageData: imageData,
                    receiptID: receipt.id,
                    projectID: projectID,
                    organizationID: organizationID,
                    fileName: "migrated_receipt_\(receipt.id)_\(index).jpg"
                )
                
                uploadedPhotoIDs.append(receiptPhoto.id)
                print(" Migrated photo \(index + 1)/\(legacyImageDatas.count) for receipt")
                
            } catch {
                print(" Failed to migrate receipt photo \(index + 1): \(error)")
                // Continue with other photos even if one fails
            }
        }
        
        // Update receipt with new photoIDs
        updatedReceipt.photoIDs = uploadedPhotoIDs
        
        await MainActor.run {
            migrationProgress[receipt.id] = 1.0
        }
        
        print(" Successfully migrated \(uploadedPhotoIDs.count) photos for receipt")
        
        return updatedReceipt
    }
    
    // MARK: - Full Project Migration
    
    /// Migrate entire project from imageDatas to photoIDs system
    public func migrateProjectPhotos(
        project: Project,
        organizationID: UUID
    ) async throws -> Project {
        
        print(" Starting full photo migration for project: \(project.name)")
        
        var updatedProject = project
        
        // 1. Migrate Task Photos
        updatedProject = try await migrateAllTaskPhotos(
            project: updatedProject,
            organizationID: organizationID
        )
        
        // 2. Migrate Progress Log Photos
        var migratedProgressLogs: [ProgressLog] = []
        for progressLog in updatedProject.progressLogs {
            let migratedLog = try await migrateProgressLogPhotos(
                progressLog: progressLog,
                projectID: updatedProject.id,
                organizationID: organizationID
            )
            migratedProgressLogs.append(migratedLog)
        }
        updatedProject.progressLogs = migratedProgressLogs
        
        // 3. Migrate Receipt Photos
        var migratedReceipts: [Receipt] = []
        for receipt in updatedProject.receipts {
            let migratedReceipt = try await migrateReceiptPhotos(
                receipt: receipt,
                projectID: updatedProject.id,
                organizationID: organizationID
            )
            migratedReceipts.append(migratedReceipt)
        }
        updatedProject.receipts = migratedReceipts
        
        print(" Completed full photo migration for project: \(project.name)")
        
        return updatedProject
    }
    
    // MARK: - Utility Methods
    
    /// Check if project needs photo migration
    public func needsPhotoMigration(project: Project) -> Bool {
        let hasTaskPhotos = project.tasks.contains { !getLegacyTaskImageDatas($0).isEmpty }
        let hasProgressPhotos = project.progressLogs.contains { !getLegacyProgressLogImageDatas($0).isEmpty }
        let hasReceiptPhotos = project.receipts.contains { !getLegacyReceiptImageDatas($0).isEmpty }
        
        return hasTaskPhotos || hasProgressPhotos || hasReceiptPhotos
    }
    
    /// Get migration statistics for a project
    public func getMigrationStats(project: Project) -> (tasks: Int, progressLogs: Int, receipts: Int, totalPhotos: Int) {
        let taskPhotos = project.tasks.reduce(0) { $0 + getLegacyTaskImageDatas($1).count }
        let progressPhotos = project.progressLogs.reduce(0) { $0 + getLegacyProgressLogImageDatas($1).count }
        let receiptPhotos = project.receipts.reduce(0) { $0 + getLegacyReceiptImageDatas($1).count }
        
        let tasksWithPhotos = project.tasks.filter { !getLegacyTaskImageDatas($0).isEmpty }.count
        let progressLogsWithPhotos = project.progressLogs.filter { !getLegacyProgressLogImageDatas($0).isEmpty }.count
        let receiptsWithPhotos = project.receipts.filter { !getLegacyReceiptImageDatas($0).isEmpty }.count
        
        return (
            tasks: tasksWithPhotos,
            progressLogs: progressLogsWithPhotos,
            receipts: receiptsWithPhotos,
            totalPhotos: taskPhotos + progressPhotos + receiptPhotos
        )
    }
    
    /// Clear migration progress
    public func clearProgress() {
        Task { @MainActor in
            migrationProgress.removeAll()
            isCompleted = false
        }
    }
}