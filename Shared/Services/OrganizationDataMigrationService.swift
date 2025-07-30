import Foundation
import Combine
import CloudKit

/// Enhanced data migration service for organization-based zones
class OrganizationDataMigrationService: ObservableObject {
    
    // MARK: - Properties
    private let cloudKitContainer = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeapp")
    private let organizationSharingService = CloudKitOrganizationSharingService()
    
    @Published var migrationProgress = ""
    @Published var isBackingUp = false
    @Published var isRestoring = false
    
    private var currentEnvironment: String {
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }
    
    // MARK: - Local Data Backup (Safety First!)
    
    /// Creates a complete local backup before any migration
    func createLocalBackup(completion: @escaping (Bool, String?) -> Void) {
        isBackingUp = true
        migrationProgress = "Creating local backup..."
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupDate = DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd_HH-mm-ss" }.string(from: Date())
        let backupPath = documentsPath.appendingPathComponent("RHEIR_Backup_\(backupDate)")
        
        do {
            try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)
            
            // Backup projects.json if it exists
            let projectsFile = documentsPath.appendingPathComponent("projects.json")
            if FileManager.default.fileExists(atPath: projectsFile.path) {
                let backupProjectsFile = backupPath.appendingPathComponent("projects.json")
                try FileManager.default.copyItem(at: projectsFile, to: backupProjectsFile)
                
                // Also create a human-readable summary
                if let data = try? Data(contentsOf: projectsFile),
                   let projects = try? JSONDecoder().decode([Project].self, from: data) {
                    
                    var summary = "RHEIR Project Backup Summary\n"
                    summary += "Created: \(Date())\n"
                    summary += "Environment: \(currentEnvironment)\n"
                    summary += "Total Projects: \(projects.count)\n\n"
                    
                    for (index, project) in projects.enumerated() {
                        summary += "Project \(index + 1): \(project.name)\n"
                        summary += "  Client: \(project.client)\n"
                        summary += "  Budget: $\(project.totalBudget)\n"
                        summary += "  Status: \(project.status.rawValue)\n"
                        summary += "  Receipts: \(project.receipts.count)\n"
                        summary += "  Progress Logs: \(project.progressLogs.count)\n"
                        summary += "  Tasks: \(project.tasks.count)\n\n"
                    }
                    
                    let summaryFile = backupPath.appendingPathComponent("backup_summary.txt")
                    try summary.write(to: summaryFile, atomically: true, encoding: .utf8)
                }
            }
            
            // Backup any other important files
            let userDefaults = UserDefaults.standard.dictionaryRepresentation()
            let userDefaultsData = try JSONSerialization.data(withJSONObject: userDefaults, options: .prettyPrinted)
            let userDefaultsFile = backupPath.appendingPathComponent("user_defaults.json")
            try userDefaultsData.write(to: userDefaultsFile)
            
            isBackingUp = false
            migrationProgress = "✅ Local backup created at: \(backupPath.lastPathComponent)"
            
            print("✅ Local backup created: \(backupPath.path)")
            completion(true, backupPath.path)
            
        } catch {
            isBackingUp = false
            migrationProgress = "❌ Backup failed: \(error.localizedDescription)"
            print("❌ Backup failed: \(error)")
            completion(false, error.localizedDescription)
        }
    }
    
    // MARK: - Organization Zone Migration
    
    /// Migrates local projects to organization-specific CloudKit zone
    func migrateProjectsToOrganizationZone(
        organizationID: String,
        organizationName: String,
        adminUserID: String,
        projects: [Project],
        completion: @escaping (Bool, String) -> Void
    ) {
        
        migrationProgress = "Starting organization zone migration..."
        
        // Step 1: Create local backup first
        createLocalBackup { [weak self] backupSuccess, backupPath in
            guard let self = self else { return }
            
            if !backupSuccess {
                completion(false, "❌ Failed to create backup: \(backupPath ?? "unknown error")")
                return
            }
            
            self.migrationProgress = "✅ Backup created. Setting up organization zone..."
            
            // Step 2: Set up complete organization with zone and sharing
            self.organizationSharingService.setupCompleteOrganization(
                organizationID: organizationID,
                name: organizationName,
                adminUserID: adminUserID
            )
            .flatMap { result -> AnyPublisher<[CKRecord], Error> in
                self.migrationProgress = "✅ Organization zone created. Migrating \(projects.count) projects..."
                
                // Step 3: Migrate all projects to the organization zone
                let projectPublishers = projects.map { project in
                    self.organizationSharingService.saveProjectToOrganizationZone(
                        project: project,
                        organizationID: organizationID
                    )
                }
                
                return Publishers.MergeMany(projectPublishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion_result in
                    switch completion_result {
                    case .success:
                        self.migrationProgress = "✅ Migration completed successfully!"
                        completion(true, """
                        ✅ Migration Successful!
                        
                        • Local backup: \(backupPath ?? "created")
                        • Organization zone: Created
                        • Projects migrated: \(projects.count)
                        • Sharing: Enabled
                        
                        Your data is now safely stored in CloudKit and ready for sharing!
                        """)
                    case .failure(let error):
                        self.migrationProgress = "❌ Migration failed: \(error.localizedDescription)"
                        completion(false, """
                        ❌ Migration Failed
                        
                        Error: \(error.localizedDescription)
                        
                        Your local backup is safe at: \(backupPath ?? "unknown location")
                        Your original data is unchanged.
                        """)
                    }
                },
                receiveValue: { savedRecords in
                    self.migrationProgress = "✅ Migrated \(savedRecords.count) projects to organization zone"
                    print("✅ Successfully migrated \(savedRecords.count) projects")
                }
            )
        }
    }
    
    // MARK: - Recovery & Restore
    
    /// Lists available local backups
    func listAvailableBackups() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            )
            
            return contents
                .filter { $0.lastPathComponent.hasPrefix("RHEIR_Backup_") }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("❌ Failed to list backups: \(error)")
            return []
        }
    }
    
    /// Restores projects from a local backup
    func restoreFromBackup(backupURL: URL, completion: @escaping (Bool, String) -> Void) {
        isRestoring = true
        migrationProgress = "Restoring from backup..."
        
        let projectsFile = backupURL.appendingPathComponent("projects.json")
        
        guard FileManager.default.fileExists(atPath: projectsFile.path) else {
            isRestoring = false
            migrationProgress = "❌ No projects.json found in backup"
            completion(false, "No projects.json found in backup")
            return
        }
        
        do {
            let data = try Data(contentsOf: projectsFile)
            let projects = try JSONDecoder().decode([Project].self, from: data)
            
            // Restore to current location
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let currentProjectsFile = documentsPath.appendingPathComponent("projects.json")
            
            try data.write(to: currentProjectsFile)
            
            isRestoring = false
            migrationProgress = "✅ Restored \(projects.count) projects from backup"
            
            completion(true, "✅ Successfully restored \(projects.count) projects from backup")
            
        } catch {
            isRestoring = false
            migrationProgress = "❌ Restore failed: \(error.localizedDescription)"
            completion(false, "Restore failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Verification
    
    /// Verifies that projects exist in both local and CloudKit
    func verifyDataConsistency(
        organizationID: String,
        localProjects: [Project],
        completion: @escaping (Bool, String) -> Void
    ) {
        
        migrationProgress = "Verifying data consistency..."
        
        // Fetch projects from organization zone
        let privateDB = cloudKitContainer.privateCloudDatabase
        let zoneName = "zone_org_\(organizationID)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        
        privateDB.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: ["name", "fullProjectData"], resultsLimit: 100) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    let cloudKitProjects = matchResults.compactMap { (_, recordResult) -> Project? in
                        switch recordResult {
                        case .success(let record):
                            if let fullProjectData = record["fullProjectData"] as? Data,
                               let project = try? JSONDecoder().decode(Project.self, from: fullProjectData) {
                                return project
                            }
                            return nil
                        case .failure:
                            return nil
                        }
                    }
                    
                    let localCount = localProjects.count
                    let cloudCount = cloudKitProjects.count
                    
                    if localCount == cloudCount {
                        self.migrationProgress = "✅ Data verification passed"
                        completion(true, """
                        ✅ Data Verification Passed
                        
                        Local projects: \(localCount)
                        CloudKit projects: \(cloudCount)
                        
                        Your data is safely synchronized!
                        """)
                    } else {
                        self.migrationProgress = "⚠️ Data count mismatch detected"
                        completion(false, """
                        ⚠️ Data Count Mismatch
                        
                        Local projects: \(localCount)
                        CloudKit projects: \(cloudCount)
                        
                        Some projects may not have migrated successfully.
                        """)
                    }
                    
                case .failure(let error):
                    self.migrationProgress = "❌ Verification failed"
                    completion(false, "Verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}