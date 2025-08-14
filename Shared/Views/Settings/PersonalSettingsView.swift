import SwiftUI

/// Personal app settings view - separate from organization management
/// Accessed via gear icon in UniversalHeaderView for individual user preferences
struct PersonalSettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    // App Preferences
    @AppStorage("preferredMapProvider") private var preferredMapProvider: MapProvider = .apple
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("autoBackup") private var autoBackup: Bool = true
    @AppStorage("hideReceiptScannerIntro") private var hideReceiptScannerIntro: Bool = false
    
    // UI State
    @State private var showingSignOutAlert = false
    @State private var showingTierManagement = false
    @State private var showingAccountDetails = false
    @State private var cloudKitStatus = "Checking..."
    
    var body: some View {
        NavigationStack {
            Form {
                // Subscription Management Section
                Section {
                    Button {
                        showingTierManagement = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Subscription Management")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let org = authVM.currentOrg {
                                    Text("Current: \(org.subscriptionTier.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Manage your subscription tier and billing preferences.")
                }
                
                // App Preferences Section
                Section {
                    // Map Provider Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("Default Map App")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        
                        Picker("Map Provider", selection: $preferredMapProvider) {
                            ForEach(MapProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Notifications
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Notifications")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: $showNotifications)
                    }
                    
                    // Auto Backup
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundColor(.cyan)
                            .frame(width: 24)
                        
                        Text("Auto Backup")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoBackup)
                    }
                    
                    // Receipt Scanner Intro
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text("Show Receipt Scanner Info")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { !hideReceiptScannerIntro },
                            set: { hideReceiptScannerIntro = !$0 }
                        ))
                    }
                } footer: {
                    Text("These settings apply to your personal use of the app across all organizations.")
                }
                
                // Account Section
                Section {
                    // Organizations
                    Button {
                        showingAccountDetails = true
                    } label: {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Organizations")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Member of \(authVM.userOrganizations.count) organization\(authVM.userOrganizations.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Sign Out
                    Button {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            Text("Sign Out")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Manage your personal account across all organizations.")
                }
                
                // App Information Section
                Section {
                    HStack {
                        Text("Version")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("CloudKit Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cloudKitStatusColor)
                                .frame(width: 8, height: 8)
                            
                            Text(cloudKitStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Help & Support
                    Button {
                        if let url = URL(string: "https://rheir.com/support") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Help & Support")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("App version information and support resources.")
                }
            }
            .navigationTitle("Personal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authVM.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? Your data will remain in the cloud.")
            }
            .sheet(isPresented: $showingTierManagement) {
                NavigationStack {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 16) {
                            Text("Subscription Management")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Manage your subscription tier and billing preferences")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        
                        // Tier Switcher (now in its own space)
                        ScrollView {
                            TierSwitcherView()
                                .environmentObject(authVM)
                                .padding()
                        }
                    }
                    .navigationTitle("Tier Management")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingTierManagement = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAccountDetails) {
                AccountDetailsView()
                    .environmentObject(authVM)
            }
            .onAppear {
                checkCloudKitStatus()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var cloudKitStatusColor: Color {
        switch cloudKitStatus {
        case "Connected": return .green
        case "Checking...": return .orange
        default: return .red
        }
    }
    
    private func checkCloudKitStatus() {
        Task {
            do {
                // Simple CloudKit status check
                let status = await authVM.checkCloudKitStatus()
                await MainActor.run {
                    cloudKitStatus = status
                }
            } catch {
                await MainActor.run {
                    cloudKitStatus = "Error"
                }
            }
        }
    }
}

#Preview {
    PersonalSettingsView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}