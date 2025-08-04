import SwiftUI
import CloudKit

struct CloudKitDebugView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel
    
    @State private var testResults: [String] = []
    @State private var isRunning = false
    @State private var selectedTest: TestType = .basicCloudKit
    
    enum TestType: String, CaseIterable {
        case basicCloudKit = "Basic CloudKit"
        case zoneSetup = "Zone Setup"
        case manualZoneCreate = "Manual Zone Creation"
        case zoneRecreation = "Zone Recreation"
        case fullDiagnostics = "Full Diagnostics"
        case schemaCheck = "Schema Check"
        case organizationTest = "Organization Test"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("CloudKit Debug Console")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Test Type Picker
                Picker("Test Type", selection: $selectedTest) {
                    ForEach(TestType.allCases, id: \.self) { test in
                        Text(test.rawValue).tag(test)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isRunning {
                    ProgressView("Running \(selectedTest.rawValue) tests...")
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        Button("Run \(selectedTest.rawValue) Test") {
                            runSelectedTest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning)
                        
                        if selectedTest == .zoneRecreation {
                            Text("⚠️ This will delete and recreate all CloudKit zones")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        } else if selectedTest == .manualZoneCreate {
                            Text("🏗️ This will create/fix zones for the current organization")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                        } else if selectedTest == .schemaCheck {
                            Text("🔍 This will check if CloudKit schema is properly set up")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                        } else if selectedTest == .organizationTest {
                            Text("🏢 This will test organization creation step by step")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                if !testResults.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(testResults, id: \.self) { result in
                                Text(result)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudKit Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runSelectedTest() {
        testResults.removeAll()
        isRunning = true
        
        Task {
            switch selectedTest {
            case .basicCloudKit:
                await performBasicCloudKitTests()
            case .zoneSetup:
                await performZoneSetupTest()
            case .manualZoneCreate:
                await performManualZoneCreation()
            case .zoneRecreation:
                await performZoneRecreationTest()
            case .fullDiagnostics:
                await performFullDiagnostics()
            case .schemaCheck:
                await performSchemaCheck()
            case .organizationTest:
                await performOrganizationTest()
            }
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    // MARK: - Schema Check Test
    
    private func performSchemaCheck() async {
        addResult("🔍 Starting CloudKit schema validation...")
        addResult("Container: iCloud.com.rheirhome.rheirhomeappV3")
        addResult("")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDB = container.privateCloudDatabase
        
        // Test 1: Account Status
        do {
            let status = try await container.accountStatus()
            addResult("✅ Account Status: \(status == .available ? "Available" : "\(status)")")
        } catch {
            addResult("❌ Account Status Error: \(error.localizedDescription)")
            return
        }
        
        addResult("")
        addResult("Testing Organization record type...")
        
        // Test 2: Try to create a test Organization record to validate schema
        let testOrgRecord = CKRecord(recordType: "Organization", recordID: CKRecord.ID(recordName: "schema-test-org"))
        testOrgRecord["id"] = "test-id" as CKRecordValue
        testOrgRecord["name"] = "Schema Test Org" as CKRecordValue
        testOrgRecord["adminUserID"] = "test-admin" as CKRecordValue
        testOrgRecord["teamMembers"] = ["test-admin"] as CKRecordValue
        testOrgRecord["createdAt"] = Date() as CKRecordValue
        testOrgRecord["isActiveV2"] = 1 as CKRecordValue
        testOrgRecord["environment"] = "development" as CKRecordValue
        
        // Fix: Encode memberRoles as BYTES instead of STRING
        let memberRoles = ["test-admin:admin"]
        if let memberRolesData = try? JSONSerialization.data(withJSONObject: memberRoles) {
            testOrgRecord["memberRoles"] = memberRolesData as CKRecordValue
        }
        
        do {
            let savedRecord = try await privateDB.save(testOrgRecord)
            addResult("✅ Organization record type exists and all fields are valid")
            addResult("   Saved test record: \(savedRecord.recordID.recordName)")
            
            // Clean up the test record
            try await privateDB.deleteRecord(withID: savedRecord.recordID)
            addResult("🗑️ Test record cleaned up")
            
        } catch let error as CKError {
            addResult("❌ Organization schema error:")
            addResult("   CKError code: \(error.code.rawValue)")
            addResult("   Description: \(error.localizedDescription)")
            
            // Fix: Access underlying error from NSError instead
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                addResult("   Underlying error: \(underlyingError.localizedDescription)")
            }
            
            switch error.code {
            case .unknownItem:
                addResult("   → The 'Organization' record type doesn't exist in CloudKit schema")
                addResult("   → You need to create the Organization record type in CloudKit Console")
            case .invalidArguments:
                addResult("   → One or more field types don't match the schema")
                addResult("   → Check field definitions in CloudKit Console")
                if let partialErrorsByItemID = error.partialErrorsByItemID {
                    for (itemID, itemError) in partialErrorsByItemID {
                        addResult("   → Field error for \(itemID): \(itemError.localizedDescription)")
                    }
                }
            default:
                addResult("   → Other CloudKit error")
            }
        } catch {
            addResult("❌ Unexpected error: \(error.localizedDescription)")
        }
        
        addResult("")
        addResult("✅ Schema check completed")
    }
    
    // MARK: - Organization Test
    
    private func performOrganizationTest() async {
        addResult("🏢 Starting organization creation test...")
        addResult("Container: iCloud.com.rheirhome.rheirhomeappV3")
        addResult("")
        
        guard let user = authViewModel.user else {
            addResult("❌ No authenticated user found")
            return
        }
        
        addResult("User: \(user.email)")
        addResult("User ID: \(user.id.prefix(8))...")
        addResult("")
        
        // Test the exact same flow as the UI
        let testOrgName = "Debug Test Org \(Int.random(in: 1000...9999))"
        
        addResult("Creating organization: \(testOrgName)")
        addResult("")
        
        do {
            let organization = try await authViewModel.createOrganization(named: testOrgName)
            addResult("✅ Organization created successfully!")
            addResult("   ID: \(organization.id.prefix(8))...")
            addResult("   Name: \(organization.name)")
            addResult("   Admin: \(organization.adminUserID.prefix(8))...")
            addResult("   Members: \(organization.members)")
            addResult("")
            addResult("Organization creation test PASSED")
            
        } catch {
            addResult("❌ Organization creation FAILED:")
            addResult("   Error: \(error.localizedDescription)")
            addResult("")
            
            if let nsError = error as NSError? {
                addResult("Error details:")
                addResult("   Domain: \(nsError.domain)")
                addResult("   Code: \(nsError.code)")
                if let userInfo = nsError.userInfo["NSLocalizedDescription"] as? String {
                    addResult("   Description: \(userInfo)")
                }
            }
        }
    }
    
    // MARK: - Basic CloudKit Tests
    
    private func performBasicCloudKitTests() async {
        addResult("🔄 Starting basic CloudKit tests...")
        
        // Test 1: Account Status
        await testAccountStatus()
        
        // Test 2: Private Database Access
        await testPrivateDatabase()
        
        // Test 3: User Record
        await testUserRecord()
        
        addResult("✅ Basic CloudKit tests completed")
    }
    
    // MARK: - Zone Setup Tests
    
    private func performZoneSetupTest() async {
        addResult("🏗️ Starting CloudKit zone setup test...")
        
        // Simple zone setup test using existing methods
        addResult("Testing current organization zone setup...")
        
        if let orgID = authViewModel.currentOrg?.id {
            addResult("Organization ID: \(orgID.prefix(8))...")
            addResult("Setting up zone...")
            
            await projectViewModel.setupCloudKitZoneForOrganization(orgID)
            
            addResult("Zone setup completed")
            addResult("CloudKit enabled: \(projectViewModel.isUsingCloudKitForOrganizationData ? "✅" : "❌")")
        } else {
            addResult("❌ No current organization found")
        }
        
        addResult("✅ Zone setup test completed")
    }
    
    // MARK: - Manual Zone Creation
    
    private func performManualZoneCreation() async {
        addResult("🏗️ Starting manual CloudKit zone creation...")
        
        if let orgID = authViewModel.currentOrg?.id {
            addResult("Organization: \(authViewModel.currentOrg?.name ?? "Unknown")")
            addResult("ID: \(orgID.prefix(8))...")
            
            // STEP 1: List existing zones BEFORE creation
            addResult("")
            addResult("STEP 1: Checking existing zones...")
            await listAllCloudKitZones()
            
            // STEP 2: Force zone setup
            addResult("")
            addResult("STEP 2: Creating organization zone...")
            await projectViewModel.setupCloudKitZoneForOrganization(orgID)
            
            addResult("Zone creation completed")
            addResult("Result: \(projectViewModel.isUsingCloudKitForOrganizationData ? "✅ Success" : "❌ Failed")")
            
            if let error = projectViewModel.zoneSetupError {
                addResult("Error: \(error)")
            }
            
            // STEP 3: List zones AFTER creation to verify
            addResult("")
            addResult("STEP 3: Verifying zones after creation...")
            await listAllCloudKitZones()
            
            // STEP 4: Try to find specific organization zone
            addResult("")
            addResult("STEP 4: Looking for organization zone...")
            await verifyOrganizationZone(orgID: orgID)
            
        } else {
            addResult("❌ No organization selected")
        }
        
        addResult("✅ Manual zone creation test completed")
    }
    
    // MARK: - Zone Recreation Tests
    
    private func performZoneRecreationTest() async {
        addResult("🔄 Starting CloudKit zone recreation...")
        addResult("⚠️ This will delete existing zones and create fresh ones")
        
        if let orgID = authViewModel.currentOrg?.id {
            let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
            let privateDB = container.privateCloudDatabase
            
            let zoneName = "org-shared-\(orgID)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            
            // Step 1: Delete existing zone
            addResult("1. Deleting existing zone...")
            do {
                try await privateDB.deleteRecordZone(withID: zoneID)
                addResult("   ✅ Zone deleted")
            } catch {
                addResult("   ⚠️ Zone deletion failed: \(error.localizedDescription)")
            }
            
            // Step 2: Wait and recreate
            addResult("2. Waiting 2 seconds...")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            addResult("3. Creating fresh zone...")
            await projectViewModel.setupCloudKitZoneForOrganization(orgID)
            
            addResult("Recreation result: \(projectViewModel.isUsingCloudKitForOrganizationData ? "✅ Success" : "❌ Failed")")
        } else {
            addResult("❌ No organization selected")
        }
        
        addResult("🏁 Zone recreation completed")
    }
    
    // MARK: - Full Diagnostics
    
    private func performFullDiagnostics() async {
        addResult("🔍 Starting full CloudKit diagnostics...")
        
        // Container and Database verification
        await verifyContainerAndDatabase()
        
        addResult("")
        addResult(String(repeating: "=", count: 50))
        addResult("")
        
        // Basic tests
        await performBasicCloudKitTests()
        
        addResult("")
        addResult(String(repeating: "=", count: 50))
        addResult("")
        
        // Zone analysis
        addResult("ZONE ANALYSIS:")
        await listAllCloudKitZones()
        
        if let orgID = authViewModel.currentOrg?.id {
            addResult("")
            await verifyOrganizationZone(orgID: orgID)
        }
        
        addResult("")
        addResult(String(repeating: "=", count: 50))
        addResult("")
        
        // Current status
        addResult("CURRENT STATUS:")
        addResult("Organization: \(authViewModel.currentOrg?.name ?? "None")")
        addResult("CloudKit enabled: \(projectViewModel.isUsingCloudKitForOrganizationData ? "✅" : "❌")")
        addResult("Projects: \(projectViewModel.organizationProjects.count)")
        addResult("Team members: \(projectViewModel.teamMembers.count)")
        
        if let error = projectViewModel.zoneSetupError {
            addResult("Zone error: \(error)")
        }
        
        addResult("🏁 Full diagnostics completed")
    }
    
    private func verifyContainerAndDatabase() async {
        addResult("🏗️ Verifying CloudKit container and database setup...")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        
        addResult("Container ID: iCloud.com.rheirhome.rheirhomeappV3")
        
        // Test container accessibility
        do {
            let accountStatus = try await container.accountStatus()
            addResult("Account status: \(accountStatus == .available ? "✅ Available" : "❌ \(accountStatus)")")
        } catch {
            addResult("❌ Container access error: \(error.localizedDescription)")
        }
        
        // Test database accessibility
        let privateDB = container.privateCloudDatabase
        addResult("Using: Private Database")
        
        // Verify we can access the database
        do {
            let zones = try await privateDB.allRecordZones()
            addResult("✅ Private database accessible")
            addResult("   Found \(zones.count) zones total")
        } catch {
            addResult("❌ Private database error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Basic CloudKit Test Methods
    
    private func testAccountStatus() async {
        addResult("📱 Testing account status...")
        
        do {
            let status = try await CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3").accountStatus()
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
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
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
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        
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
    
    // MARK: - CloudKit Zone Verification Methods
    
    private func listAllCloudKitZones() async {
        addResult("📋 Listing all CloudKit zones...")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDB = container.privateCloudDatabase
        
        do {
            let zones = try await privateDB.allRecordZones()
            addResult("Found \(zones.count) zones in private database:")
            
            for zone in zones {
                addResult("  • \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            }
            
            if zones.isEmpty {
                addResult("  (No custom zones found - only default zone exists)")
            }
            
        } catch {
            addResult("❌ Failed to list zones: \(error.localizedDescription)")
        }
    }
    
    private func verifyOrganizationZone(orgID: String) async {
        addResult("🔍 Verifying organization zone existence...")
        
        let container = CKContainer(identifier: "iCloud.com.rheirhome.rheirhomeappV3")
        let privateDB = container.privateCloudDatabase
        
        let expectedZoneName = "org-shared-\(orgID)"
        _ = CKRecordZone.ID(zoneName: expectedZoneName)
        
        do {
            // Try to fetch the specific zone
            let zones = try await privateDB.allRecordZones()
            if let orgZone = zones.first(where: { $0.zoneID.zoneName == expectedZoneName }) {
                addResult("✅ Organization zone found: \(orgZone.zoneID.zoneName)")
                
                // Check for root record
                let rootRecordID = CKRecord.ID(recordName: "org-root-\(orgID)", zoneID: orgZone.zoneID)
                do {
                    let rootRecord = try await privateDB.record(for: rootRecordID)
                    addResult("✅ Root record found: \(rootRecord.recordID.recordName)")
                    
                    // Check for share
                    if let shareReference = rootRecord.share {
                        addResult("✅ Share reference found: \(shareReference.recordID.recordName)")
                        
                        // Try to fetch the actual share
                        do {
                            let shareRecord = try await privateDB.record(for: shareReference.recordID)
                            if let share = shareRecord as? CKShare {
                                addResult("✅ Share record found and valid")
                                addResult("   Share URL: \(share.url?.absoluteString ?? "Not available yet")")
                                addResult("   Participants: \(share.participants.count)")
                            } else {
                                addResult("❌ Share record is not a CKShare")
                            }
                        } catch {
                            addResult("❌ Failed to fetch share record: \(error.localizedDescription)")
                        }
                    } else {
                        addResult("⚠️ No share reference found in root record")
                    }
                    
                } catch {
                    addResult("❌ Root record not found: \(error.localizedDescription)")
                }
                
            } else {
                addResult("❌ Organization zone NOT found in CloudKit")
                addResult("   Expected zone name: \(expectedZoneName)")
                addResult("   This indicates the zone creation failed silently")
            }
            
        } catch {
            addResult("❌ Failed to verify organization zone: \(error.localizedDescription)")
        }
    }
}

#if DEBUG
struct CloudKitDebugView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitDebugView()
            .environmentObject(AuthViewModel(service: CloudKitAuthService()))
            .environmentObject(ProjectViewModel())
    }
}
#endif