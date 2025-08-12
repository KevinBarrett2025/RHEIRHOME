import SwiftUI

struct OrganizationDataMigrationView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @State private var migrationStatus = ""
    @State private var isLoading = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection
                    migrationActionsSection
                    analyticsPreviewSection
                }
                .padding()
            }
            .navigationTitle("Organization Data Migration")
            .alert("Migrate to CloudKit", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Migrate", role: .destructive) {
                    performMigration()
                }
            } message: {
                Text("This will migrate all vendor and payment method data to CloudKit for team sharing. This cannot be undone.")
            }
        }
    }
    
    private var statusSection: some View {
        Section("📊 Current Status") {
            Button("Check Migration Status") {
                migrationStatus = projectViewModel.getOrganizationDataMigrationStatus()
            }
            .buttonStyle(.bordered)
            
            if !migrationStatus.isEmpty {
                ScrollView {
                    Text(migrationStatus)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private var migrationActionsSection: some View {
        Section("🔄 Migration Actions") {
            VStack(alignment: .leading, spacing: 15) {
                
                Text("CloudKit Services Status:")
                    .font(.headline)
                
                cloudKitStatusView
                
                Button("🚀 Migrate to CloudKit") {
                    showingConfirmation = true
                }
                .foregroundColor(.blue)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || projectViewModel.isUsingCloudKitForOrganizationData)
                
                if isLoading {
                    ProgressView("Migrating data...")
                        .padding()
                }
                
                if let error = errorMessage {
                    Text("❌ \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var cloudKitStatusView: some View {
        HStack {
            Image(systemName: projectViewModel.isUsingCloudKitForOrganizationData ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(projectViewModel.isUsingCloudKitForOrganizationData ? .green : .red)
            Text(projectViewModel.isUsingCloudKitForOrganizationData ? "CloudKit Active" : "Using Local Storage")
        }
    }
    
    private var analyticsPreviewSection: some View {
        Section("📈 Organization Analytics Preview") {
            VStack(alignment: .leading, spacing: 10) {
                vendorAnalyticsView
                paymentAnalyticsView
            }
        }
    }
    
    private var vendorAnalyticsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vendor Analytics:")
                .font(.headline)
            
            let vendorAnalytics = Array(projectViewModel.getOrganizationVendorSpendingAnalytics().prefix(5))
            ForEach(vendorAnalytics, id: \.vendor.id) { analytics in
                HStack {
                    Text(analytics.vendor.name)
                        .font(.caption)
                    Spacer()
                    Text("$\(analytics.amount, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var paymentAnalyticsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payment Method Analytics:")
                .font(.headline)
                .padding(.top)
            
            let paymentAnalytics = Array(projectViewModel.getOrganizationPaymentMethodSpendingAnalytics().prefix(5))
            ForEach(paymentAnalytics, id: \.paymentMethod.id) { analytics in
                HStack {
                    Text(analytics.paymentMethod.name)
                        .font(.caption)
                    Spacer()
                    Text("$\(analytics.amount, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func performMigration() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await projectViewModel.forceMigrateOrganizationDataToCloudKit()
                
                await MainActor.run {
                    isLoading = false
                    migrationStatus = projectViewModel.getOrganizationDataMigrationStatus()
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    OrganizationDataMigrationView(projectViewModel: ProjectViewModel(offlineDataManager: OfflineDataManager()))
}