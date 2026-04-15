import SwiftUI
import OSLog

/// Hidden debug panel accessible only via secret gesture
/// Centralizes all debug tools behind a triple-tap gesture
struct HiddenDebugPanelView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingCloudKitDebug = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Header
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                            Text("Developer Debug Panel")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            Text("🤫")
                        }
                        
                        Text("Secret developer tools for debugging and testing. Use with caution!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("These tools are hidden from production users and only accessible via secret gesture.")
                }
                
                // CloudKit Debug Section  
                Section(content: {
                    Button {
                        showingCloudKitDebug = true
                    } label: {
                        debugRow(
                            title: "Data Consistency Debug",
                            subtitle: "CloudKit sync diagnostics & repair tools",
                            icon: "icloud.and.arrow.up.fill",
                            color: .blue
                        )
                    }
                    
                    Button {
                        Task {
                            alertMessage = await authVM.bypassOrphanedICloudData()
                            showingAlert = true
                        }
                    } label: {
                        debugRow(
                            title: "🚨 BYPASS ORPHANED ICLOUD DATA",
                            subtitle: "Ignore stuck 244.5KB iCloud data - fresh start",
                            icon: "icloud.slash.fill",
                            color: .orange
                        )
                    }
                    
                    Button {
                        Task {
                            await forceCloudKitSync()
                        }
                    } label: {
                        debugRow(
                            title: "Force CloudKit Sync",
                            subtitle: "Make CloudKit the single source of truth",
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            color: .green
                        )
                    }
                    
                    Button {
                        Task {
                            statusMessage = await authVM.checkCloudKitStatus()
                            showingStatusAlert = true
                        }
                    } label: {
                        debugRow(
                            title: "Check CloudKit Status",
                            subtitle: "Verify connectivity & permissions",
                            icon: "checkmark.icloud.fill",
                            color: .cyan
                        )
                    }
                }, header: {
                    Text("CloudKit Operations")
                        .font(.headline)
                        .foregroundColor(.blue)
                })
                
                // Cache Management Section  
                Section(content: {
                    Button {
                        Task {
                            await MainActor.run {
                                authVM.clearAllLocalCache()
                                
                                // Also clear ProjectViewModel completely
                                projectVM.projects = []
                                projectVM.organizationProjects = []
                                projectVM.accessibleProjects = []
                                projectVM.teamMembers = []
                                projectVM.currentOrganization = nil
                                projectVM.currentOrganizationID = nil
                                projectVM.selectedProject = nil
                                
                                alertMessage = "✅ ALL LOCAL DATA CLEARED!\n\n" +
                                              "• UserDefaults: Cleared\n" +
                                              "• OfflineDataManager: Cleared\n" +
                                              "• ProjectViewModel: Reset\n" +
                                              "• Local JSON files: Deleted\n\n" +
                                              "App is now in fresh install state.\n" +
                                              "CloudKit data is preserved."
                                showingAlert = true
                            }
                        }
                    } label: {
                        debugRow(
                            title: "🧹 Nuclear Clear All Local Data",
                            subtitle: "Delete ALL local storage - keeps CloudKit data",
                            icon: "trash.circle.fill",
                            color: .red
                        )
                    }
                    
                    Button {
                        Logger.settingsSupport.notice("Hidden debug panel requested nuclear organization reset from memory.")
                        
                        Task {
                            await MainActor.run {
                                // CRITICAL FIX: Comprehensive nuclear reset
                                authVM.clearAllLocalCache()
                                
                                // Also clear from ProjectViewModel
                                projectVM.currentOrganization = nil
                                projectVM.currentOrganizationID = nil
                                projectVM.teamMembers = []
                                projectVM.projects = []
                                projectVM.organizationProjects = []
                                projectVM.accessibleProjects = []
                                
                                // Force UI state updates
                                authVM.needsOrganizationSetup = true
                                authVM.showOrganizationSetup = true
                                
                                alertMessage = "✅ NUCLEAR: Complete reset - app should show organization setup"
                                showingAlert = true
                            }
                        }
                    } label: {
                        debugRow(
                            title: "Nuclear Delete Organization",
                            subtitle: "Complete reset including CloudKit cache",
                            icon: "trash.fill",
                            color: .orange
                        )
                    }
                }, header: {
                    Text("Cache Management")
                        .font(.headline)
                        .foregroundColor(.red)
                })

                // Admin Flow Testing
                Section(content: {
                    Button {
                        Logger.settingsSupport.info(
                            "Hidden debug panel triggering admin onboarding [showAdminInfoUpdate=\(authVM.showAdminInfoUpdate, privacy: .public), hasCurrentOrganization=\(authVM.currentOrg != nil, privacy: .public)]"
                        )
                        
                        authVM.showAdminInfoUpdate = true
                        
                        Logger.settingsSupport.notice(
                            "Hidden debug panel updated admin onboarding flag [showAdminInfoUpdate=\(authVM.showAdminInfoUpdate, privacy: .public)]"
                        )
                        dismiss()
                    } label: {
                        debugRow(
                            title: "Trigger Admin Onboarding",
                            subtitle: "Test the professional admin setup flow",
                            icon: "crown.fill",
                            color: .purple
                        )
                    }
                }, header: {
                    Text("Admin Flow Testing")
                        .font(.headline)
                        .foregroundColor(.purple)
                })
                
                // Debug Information
                Section(content: {
                    if let currentOrg = authVM.currentOrg {
                        debugInfoRow("Organization ID", String(currentOrg.id.prefix(8)) + "...")
                    }
                    
                    if let userID = UserDefaults.standard.string(forKey: "apple_user_id") {
                        debugInfoRow("Apple ID", String(userID.prefix(8)) + "...")
                    }
                    
                    debugInfoRow("Organizations Count", "\(authVM.userOrganizations.count)")
                    debugInfoRow("Projects Count", "\(projectVM.projects.count)")
                    debugInfoRow("Team Members", "\(projectVM.teamMembers.count)")
                    debugInfoRow("Accessible Projects", "\(projectVM.accessibleProjects.count)")
                    debugInfoRow("Organization Projects", "\(projectVM.organizationProjects.count)")
                }, header: {
                    Text("Debug Information")
                        .font(.headline)
                        .foregroundColor(.gray)
                })
            }
            .navigationTitle("🔧 Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("CloudKit Status", isPresented: $showingStatusAlert) {
                Button("OK") { }
            } message: {
                Text(statusMessage)
            }
            .alert("Action Complete", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingCloudKitDebug) {
                CloudKitDebugView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func debugRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func debugInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Debug Operations
    
    @MainActor
    private func forceCloudKitSync() async {
        Logger.settingsSupport.info("Hidden debug panel started force CloudKit sync.")
        
        // Step 1: Clear all local cache using AuthViewModel's nuclear clear method
        authVM.clearAllLocalCache()
        
        Logger.settingsSupport.notice("Hidden debug panel cleared local cache before force sync.")
        
        // Step 2: Force fresh fetch from CloudKit using AuthViewModel's CloudKit sync
        let syncResult = await authVM.forceCloudKitSync()
        Logger.settingsSupport.notice("Hidden debug panel force sync completed [result=\(syncResult, privacy: .public)]")
        
        // Step 3: Reload organization data
        authVM.reloadOrganizationData()
        Logger.settingsSupport.info("Hidden debug panel reloaded organization data after force sync.")
        
        // Step 4: If current organization is set, trigger ProjectViewModel sync
        if let currentOrg = authVM.currentOrg {
            await projectVM.organizationDidChange(currentOrg.id)
            Logger.settingsSupport.notice(
                "Hidden debug panel synced project view model for organization [organization=\(currentOrg.id, privacy: .private(mask: .hash))]"
            )
            
            alertMessage = "✅ CloudKit Sync Complete!\n\nOrganizations: \(authVM.userOrganizations.count)\nCurrent: \(currentOrg.name)\nCloudKit is now the single source of truth!"
        } else {
            alertMessage = "⚠️ CloudKit sync completed but no organizations found.\n\nYou may need to create or join an organization."
        }
        
        showingAlert = true
    }
}

#Preview {
    HiddenDebugPanelView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
