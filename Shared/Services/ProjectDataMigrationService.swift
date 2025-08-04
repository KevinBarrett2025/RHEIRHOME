import SwiftUI
import CloudKit

// MARK: - Project Data Migration Service
class ProjectDataMigrationService {
    private let cloudKitContainer = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
    
    private var privateDatabase: CKDatabase {
        return cloudKitContainer.privateCloudDatabase
    }
    
    private var currentEnvironment: String {
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }
    
    func migrateLocalProjectsToCloudKit(projects: [Project], completion: @escaping (Bool) -> Void) {
        let privateDB = privateDatabase
        let group = DispatchGroup()
        var allSucceeded = true
        
        print("🔄 Starting migration of \(projects.count) projects to CloudKit (\(currentEnvironment))...")
        
        for project in projects {
            group.enter()
            
            let projectRecord = CKRecord(recordType: "Project", recordID: CKRecord.ID(recordName: project.id.uuidString))
            
            // Basic project fields
            projectRecord["name"] = project.name as CKRecordValue
            projectRecord["client"] = project.client as CKRecordValue
            projectRecord["totalBudget"] = project.totalBudget as CKRecordValue
            projectRecord["startDate"] = project.startDate as CKRecordValue
            projectRecord["endDate"] = project.endDate as CKRecordValue
            projectRecord["status"] = project.status.rawValue as CKRecordValue
            
            // Store complete project as JSON backup
            if let projectData = try? JSONEncoder().encode(project) {
                projectRecord["fullProjectData"] = projectData as CKRecordValue
            }
            
            privateDB.save(projectRecord) { savedRecord, error in
                if let error = error {
                    print("❌ Failed to migrate project '\(project.name)': \(error.localizedDescription)")
                    allSucceeded = false
                } else {
                    print("✅ Successfully migrated project '\(project.name)'")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("🔄 Migration completed. Success: \(allSucceeded)")
            completion(allSucceeded)
        }
    }
    
    func cleanupOrganizations(keepOnlyOrganizationWithName: String, completion: @escaping (Bool) -> Void) {
        let privateDB = privateDatabase
        
        let query = CKQuery(recordType: "Organization", predicate: NSPredicate(value: true))
        
        print("🔍 Searching for Organization records in CloudKit...")
        
        // Use modern CloudKit API and avoid recordName queries completely
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name"], resultsLimit: 50) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure(let error):
                            print("❌ Failed to fetch record: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    if records.isEmpty {
                        print("✅ No organizations found to clean up")
                        completion(true)
                        return
                    }
                    
                    print("📋 Total organizations found: \(records.count)")
                    
                    // Filter records to delete based on name field (not recordName)
                    let recordsToDelete = records.filter { record in
                        let name = record["name"] as? String ?? ""
                        let shouldDelete = name != keepOnlyOrganizationWithName
                        if shouldDelete {
                            print("🗑️ Will delete organization: \(name)")
                        } else {
                            print("✅ Keeping organization: \(name)")
                        }
                        return shouldDelete
                    }
                    
                    if recordsToDelete.isEmpty {
                        print("✅ No organizations to delete")
                        completion(true)
                        return
                    }
                    
                    self.deleteRecords(recordsToDelete, completion: completion)
                    
                case .failure(let error):
                    print("❌ Failed to query organizations: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    private func deleteRecords(_ records: [CKRecord], completion: @escaping (Bool) -> Void) {
        let privateDB = privateDatabase
        let recordIDs = records.map { $0.recordID }
        
        print("🗑️ Deleting \(recordIDs.count) organization records...")
        
        let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        deleteOperation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully deleted \(recordIDs.count) organizations")
                    completion(true)
                case .failure(let error):
                    print("❌ Failed to delete organizations: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
        
        privateDB.add(deleteOperation)
    }
    
    func testCloudKitEnvironment(completion: @escaping (String) -> Void) {
        let privateDB = privateDatabase
        let query = CKQuery(recordType: "Organization", predicate: NSPredicate(value: true))
        
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name"], resultsLimit: 10) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    let recordCount = records.count
                    var message = """
                    Environment: \(self.currentEnvironment)
                    Organizations found: \(recordCount)
                    Status: ✅ Connected
                    """
                    
                    if let firstOrg = records.first {
                        if let name = firstOrg["name"] as? String {
                            message += "\nFirst org: \(name)"
                        }
                    }
                    completion(message)
                    
                case .failure(let error):
                    let message = """
                    Environment: \(self.currentEnvironment)
                    Error: \(error.localizedDescription)
                    Status: ❌ Failed
                    """
                    completion(message)
                }
            }
        }
    }
    
    func exploreCloudKitData(completion: @escaping (String) -> Void) {
        var results = "🔍 CLOUDKIT DATA EXPLORER:\n\n"
        let privateDB = privateDatabase
        
        let recordTypes = ["Organization", "Project", "Receipt", "ProgressLog", "Employee", "ProjectTask"]
        let group = DispatchGroup()
        
        results += "Environment: \(currentEnvironment)\n\n"
        
        for recordType in recordTypes {
            group.enter()
            
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 10) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    results += "✅ \(recordType): \(records.count) records found\n"
                    
                    if !records.isEmpty {
                        for (index, record) in records.prefix(2).enumerated() {
                            results += "  Record \(index + 1):\n"
                            results += "    Created: \(record.creationDate?.formatted() ?? "Unknown")\n"
                            results += "    Modified: \(record.modificationDate?.formatted() ?? "Unknown")\n"
                            
                            // Show key fields safely
                            let allKeys = record.allKeys()
                            for key in allKeys.sorted().prefix(5) {
                                if let fieldValue = record[key] {
                                    let preview = String(describing: fieldValue).prefix(30)
                                    results += "    \(key): \(preview)...\n"
                                }
                            }
                            results += "\n"
                        }
                    }
                    results += "\n"
                    
                case .failure(let error):
                    results += "❌ \(recordType): Error - \(error.localizedDescription)\n\n"
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    func exploreCloudKitDataSafely(completion: @escaping (String) -> Void) {
        var results = "🔍 CLOUDKIT DATA EXPLORER (Safe Mode):\n\n"
        let privateDB = privateDatabase
        
        let recordTypes = ["Organization", "Project", "Receipt", "ProgressLog", "Employee", "ProjectTask"]
        let group = DispatchGroup()
        
        results += "Environment: \(currentEnvironment)\n"
        results += "Note: Using safe queries (no recordName dependencies)\n\n"
        
        for recordType in recordTypes {
            group.enter()
            
            // Use NSPredicate(value: true) to fetch all records safely
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 10) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    results += "✅ \(recordType): \(records.count) records found\n"
                    
                    if !records.isEmpty {
                        for (index, record) in records.prefix(2).enumerated() {
                            results += "  Record \(index + 1):\n"
                            results += "    ID: \(record.recordID.recordName.prefix(8))...\n"
                            results += "    Created: \(record.creationDate?.formatted() ?? "Unknown")\n"
                            results += "    Modified: \(record.modificationDate?.formatted() ?? "Unknown")\n"
                            
                            // Show key fields safely (avoid any field-specific queries)
                            if let name = record["name"] as? String {
                                results += "    Name: \(name)\n"
                            }
                            if let client = record["client"] as? String {
                                results += "    Client: \(client)\n"
                            }
                            if let orgID = record["organizationID"] as? String {
                                results += "    OrgID: \(orgID.prefix(8))...\n"
                            }
                            results += "\n"
                        }
                    }
                    results += "\n"
                    
                case .failure(let error):
                    results += "❌ \(recordType): Error - \(error.localizedDescription)\n\n"
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    func findRecentActivity(completion: @escaping (String) -> Void) {
        var results = "📅 RECENT ACTIVITY (Last 2 Weeks):\n\n"
        let privateDB = privateDatabase
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        
        let recordTypes = ["Project", "Receipt", "ProgressLog"]
        let group = DispatchGroup()
        
        for recordType in recordTypes {
            group.enter()
            
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            
            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["name", "client"], resultsLimit: 20) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { (_, recordResult) -> CKRecord? in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    let recentRecords = records.filter { record in
                        record.modificationDate ?? Date.distantPast > twoWeeksAgo
                    }
                    
                    if !recentRecords.isEmpty {
                        results += "🔥 \(recordType): \(recentRecords.count) recent records\n"
                        for record in recentRecords.prefix(3) {
                            results += "  Modified: \(record.modificationDate?.formatted() ?? "Unknown")\n"
                            if let name = record["name"] as? String {
                                results += "    Name: \(name)\n"
                            }
                            if let client = record["client"] as? String {
                                results += "    Client: \(client)\n"
                            }
                        }
                        results += "\n"
                    }
                    
                case .failure(let error):
                    results += "❌ \(recordType): Error - \(error.localizedDescription)\n"
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    func debugLocalData(completion: @escaping (String) -> Void) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var debugInfo = "📱 LOCAL DATA DEBUG:\n\n"
        
        let projectsFile = documentsPath.appendingPathComponent("projects.json")
        if FileManager.default.fileExists(atPath: projectsFile.path) {
            do {
                let data = try Data(contentsOf: projectsFile)
                let projects = try JSONDecoder().decode([Project].self, from: data)
                debugInfo += "📂 projects.json: \(projects.count) projects found\n"
                
                for (index, project) in projects.enumerated() {
                    debugInfo += "  Project \(index + 1): \(project.name)\n"
                    debugInfo += "    Client: \(project.client)\n"
                    debugInfo += "    Receipts: \(project.receipts.count)\n"
                    debugInfo += "    Progress Logs: \(project.progressLogs.count)\n"
                    debugInfo += "    Last Modified: \(project.startDate.formatted())\n\n"
                }
            } catch {
                debugInfo += "❌ Error reading projects.json: \(error)\n"
            }
        } else {
            debugInfo += "❌ projects.json not found\n"
        }
        
        completion(debugInfo)
    }
}