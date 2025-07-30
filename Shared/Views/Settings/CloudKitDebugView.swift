import SwiftUI
import CloudKit

struct CloudKitDebugView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("CloudKit Connection Test")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if isRunning {
                    ProgressView("Running tests...")
                        .padding()
                } else {
                    Button("Start Test") {
                        runCloudKitTests()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                }
                
                if !testResults.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(testResults, id: \.self) { result in
                                Text(result)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudKit Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runCloudKitTests() {
        testResults.removeAll()
        isRunning = true
        
        Task {
            await performCloudKitTests()
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func performCloudKitTests() async {
        addResult("🔄 Starting CloudKit tests...")
        
        // Test 1: Account Status
        await testAccountStatus()
        
        // Test 2: Private Database Access
        await testPrivateDatabase()
        
        // Test 3: User Record
        await testUserRecord()
        
        addResult("✅ CloudKit tests completed")
    }
    
    private func testAccountStatus() async {
        addResult("📱 Testing account status...")
        
        do {
            let status = try await CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2").accountStatus()
            switch status {
            case .available:
                addResult("✅ iCloud account is available")
            case .noAccount:
                addResult("❌ No iCloud account configured")
            case .restricted:
                addResult("⚠️ iCloud account is restricted")
            case .couldNotDetermine:
                addResult("❓ Could not determine iCloud account status")
            case .temporarilyUnavailable:
                addResult("⏳ iCloud account temporarily unavailable")
            @unknown default:
                addResult("❓ Unknown iCloud account status")
            }
        } catch {
            addResult("❌ Account status error: \(error.localizedDescription)")
        }
    }
    
    private func testPrivateDatabase() async {
        addResult("🔒 Testing private database access...")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2")
        let database = container.privateCloudDatabase
        
        // Try to save a test record
        let testRecord = CKRecord(recordType: "TestRecord")
        testRecord["testField"] = "test value" as CKRecordValue
        
        do {
            let savedRecord = try await database.save(testRecord)
            addResult("✅ Successfully saved test record: \(savedRecord.recordID)")
            
            // Clean up by deleting the test record
            try await database.deleteRecord(withID: savedRecord.recordID)
            addResult("🗑️ Test record cleaned up")
        } catch {
            addResult("❌ Private database error: \(error.localizedDescription)")
        }
    }
    
    private func testUserRecord() async {
        addResult("👤 Testing user record access...")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV2")
        
        do {
            let userRecord = try await container.userRecordID()
            addResult("✅ User record ID: \(userRecord.recordName)")
        } catch {
            addResult("❌ User record error: \(error.localizedDescription)")
        }
    }
    
    private func addResult(_ result: String) {
        Task { @MainActor in
            testResults.append(result)
        }
    }
}

#if DEBUG
struct CloudKitDebugView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitDebugView()
    }
}
#endif
