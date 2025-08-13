import SwiftUI

struct CloudKitConsistencyDebugView: View {
    let authVM: AuthViewModel  // Changed from @ObservedObject
    @State private var consistencyReport = "Tap 'Check Consistency' to start..."
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                debugActionsSection
                consistencyReportSection
            }
            .padding()
        }
        .navigationTitle("CloudKit Debug")
        .navigationBarTitleDisplayMode(.large)
        .alert("Debug Action Complete", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔍 CloudKit Data Consistency Crisis")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This tool helps diagnose why the app shows different organization counts than CloudKit Console.")
                .font(.body)
                .foregroundColor(.secondary)
            
            if let currentOrg = authVM.currentOrg {
                Text("Current Org: \(currentOrg.name)")
                    .font(.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
    
    private var debugActionsSection: some View {
        VStack(spacing: 12) {
            Text("Debug Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: checkConsistency) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Check Data Consistency")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
            
            Button(action: forceCloudKitSync) {
                HStack {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("Force CloudKit Sync")
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
            
            Button(action: nuclearReset) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Nuclear Reset")
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
        }
    }
    
    private var consistencyReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consistency Report")
                .font(.headline)
            
            ScrollView {
                Text(consistencyReport)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(minHeight: 200)
        }
    }
    
    private func checkConsistency() {
        isLoading = true
        Task {
            let report = await authVM.validateDataConsistency()
            await MainActor.run {
                consistencyReport = report
                isLoading = false
            }
        }
    }
    
    private func forceCloudKitSync() {
        isLoading = true
        Task {
            let result = await authVM.forceCloudKitSync()
            await MainActor.run {
                alertMessage = result
                showingAlert = true
                isLoading = false
                
                // Refresh the consistency report
                checkConsistency()
            }
        }
    }
    
    private func nuclearReset() {
        isLoading = true
        Task {
            await MainActor.run {
                authVM.clearAllLocalCache()
                alertMessage = "✅ Nuclear reset complete! The app will refresh with fresh CloudKit data."
                showingAlert = true
                isLoading = false
                consistencyReport = "Nuclear reset performed. Tap 'Check Consistency' to see fresh data."
            }
        }
    }
}