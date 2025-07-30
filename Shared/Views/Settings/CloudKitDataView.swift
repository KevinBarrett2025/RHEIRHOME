import SwiftUI
import CloudKit

struct CloudKitDataView: View {
    @State private var organizations: [CKRecord] = []
    @State private var projects: [CKRecord] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    private let cloudKitContainer = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2")
    
    var body: some View {
        NavigationStack {
            List {
                Section("Organizations (\(organizations.count))") {
                    if organizations.isEmpty {
                        Text("No organizations found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(organizations, id: \.recordID) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record["name"] as? String ?? "Unknown")
                                    .font(.headline)
                                
                                Text("ID: \(record.recordID.recordName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontDesign(.monospaced)
                                
                                if let createdAt = record.creationDate {
                                    Text("Created: \(createdAt, formatter: dateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Delete") {
                                    deleteOrganization(record)
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                
                Section("Projects (\(projects.count))") {
                    if projects.isEmpty {
                        Text("No projects found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(projects, id: \.recordID) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record["name"] as? String ?? "Unknown Project")
                                    .font(.headline)
                                
                                if let client = record["client"] as? String {
                                    Text("Client: \(client)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("ID: \(record.recordID.recordName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontDesign(.monospaced)
                            }
                            .swipeActions {
                                Button("Delete") {
                                    deleteProject(record)
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Create Test Organization") {
                        createTestOrganization()
                    }
                    .disabled(isLoading)
                    
                    Button("Refresh Data") {
                        loadAllData()
                    }
                    .disabled(isLoading)
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                        }
                    }
                }
            }
            .navigationTitle("CloudKit Data")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAllData()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func loadAllData() {
        isLoading = true
        loadOrganizations()
        loadProjects()
    }
    
    private func loadOrganizations() {
        let privateDB = cloudKitContainer.privateCloudDatabase
        let query = CKQuery(recordType: "Organization", predicate: NSPredicate(value: true))
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.desiredKeys = ["name"]
        queryOperation.resultsLimit = 50
        
        var fetchedRecords: [CKRecord] = []
        
        queryOperation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                fetchedRecords.append(record)
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    organizations = fetchedRecords
                    print("📋 Loaded \(fetchedRecords.count) organizations")
                case .failure(let error):
                    errorMessage = "Failed to load organizations: \(error.localizedDescription)"
                    showingError = true
                    print("❌ Organization query failed: \(error)")
                }
                checkLoadingComplete()
            }
        }
        
        privateDB.add(queryOperation)
    }
    
    private func loadProjects() {
        let privateDB = cloudKitContainer.privateCloudDatabase
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.desiredKeys = ["name", "client"]
        queryOperation.resultsLimit = 50
        
        var fetchedRecords: [CKRecord] = []
        
        queryOperation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                fetchedRecords.append(record)
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    projects = fetchedRecords
                    print("📋 Loaded \(fetchedRecords.count) projects")
                case .failure(let error):
                    errorMessage = "Failed to load projects: \(error.localizedDescription)"
                    showingError = true
                    print("❌ Project query failed: \(error)")
                }
                checkLoadingComplete()
            }
        }
        
        privateDB.add(queryOperation)
    }
    
    private func checkLoadingComplete() {
        // Simple check - in a real app you'd want to track both operations
        isLoading = false
    }
    
    private func createTestOrganization() {
        isLoading = true
        let privateDB = cloudKitContainer.privateCloudDatabase
        
        let orgRecord = CKRecord(recordType: "Organization")
        orgRecord["name"] = "RHEIR LLC" as CKRecordValue
        
        privateDB.save(orgRecord) { savedRecord, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to create organization: \(error.localizedDescription)"
                    showingError = true
                } else {
                    print("✅ Created test organization")
                    loadOrganizations()
                }
            }
        }
    }
    
    private func deleteOrganization(_ record: CKRecord) {
        isLoading = true
        let privateDB = cloudKitContainer.privateCloudDatabase
        
        privateDB.delete(withRecordID: record.recordID) { _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to delete organization: \(error.localizedDescription)"
                    showingError = true
                } else {
                    print("✅ Deleted organization")
                    loadOrganizations()
                }
            }
        }
    }
    
    private func deleteProject(_ record: CKRecord) {
        isLoading = true
        let privateDB = cloudKitContainer.privateCloudDatabase
        
        privateDB.delete(withRecordID: record.recordID) { _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to delete project: \(error.localizedDescription)"
                    showingError = true
                } else {
                    print("✅ Deleted project")
                    loadProjects()
                }
            }
        }
    }
}
