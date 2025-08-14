import SwiftUI

/// Data export functionality for personal data
struct DataExportView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedExportType: ExportType = .personal
    @State private var isExporting = false
    @State private var exportProgress = ""
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    
    enum ExportType: String, CaseIterable {
        case personal = "Personal Data"
        case preferences = "App Preferences"
        case organizations = "Organization Memberships"
        
        var description: String {
            switch self {
            case .personal:
                return "Your personal profile, settings, and account information"
            case .preferences:
                return "App settings, map preferences, and notification settings"
            case .organizations:
                return "List of organizations you belong to and your roles"
            }
        }
        
        var icon: String {
            switch self {
            case .personal: return "person.fill"
            case .preferences: return "gearshape.fill"
            case .organizations: return "building.2.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Export your personal data from the RHEIR app. This includes only data associated with your personal account, not organization project data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } footer: {
                    Text("Organization project data must be exported separately by organization administrators.")
                }
                
                Section("Export Type") {
                    Picker("Export Type", selection: $selectedExportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's included:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(selectedExportType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    if isExporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Exporting Data...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if !exportProgress.isEmpty {
                                    Text(exportProgress)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button("Export Data") {
                            startExport()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    }
                } footer: {
                    Text("Data will be exported as a JSON file that you can save or share.")
                }
                
                // Export Format Info
                Section("Export Format") {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("JSON Format")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Human-readable structured data format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "calendar.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Date")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Includes timestamp of export")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ActivityViewController(activityItems: [url])
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = "Gathering data..."
        
        Task {
            do {
                let exportData = await gatherExportData()
                
                await MainActor.run {
                    exportProgress = "Formatting data..."
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                
                await MainActor.run {
                    exportProgress = "Creating file..."
                }
                
                let fileName = "RHEIR_\(selectedExportType.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(.iso8601.year().month().day())).json"
                let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
                
                try jsonData.write(to: fileURL)
                
                await MainActor.run {
                    exportedFileURL = fileURL
                    isExporting = false
                    exportProgress = ""
                    showingShareSheet = true
                }
                
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportProgress = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func gatherExportData() async -> [String: Any] {
        var data: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "export_type": selectedExportType.rawValue,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        switch selectedExportType {
        case .personal:
            data["user_data"] = [
                "email": authVM.user?.email ?? "Unknown",
                "user_id": authVM.user?.id ?? "Unknown"
            ]
            
        case .preferences:
            data["app_preferences"] = [
                "preferred_map_provider": UserDefaults.standard.string(forKey: "preferredMapProvider") ?? "apple",
                "show_notifications": UserDefaults.standard.bool(forKey: "showNotifications"),
                "auto_backup": UserDefaults.standard.bool(forKey: "autoBackup"),
                "hide_receipt_scanner_intro": UserDefaults.standard.bool(forKey: "hideReceiptScannerIntro"),
                "debug_mode": UserDefaults.standard.bool(forKey: "debugMode")
            ]
            
        case .organizations:
            data["organizations"] = authVM.userOrganizations.map { org in
                [
                    "name": org.name,
                    "id": org.id,
                    "subscription_tier": org.subscriptionTier.rawValue,
                    "role": authVM.getUserRole(for: org)?.rawValue ?? "unknown",
                    "is_current": org.id == authVM.currentOrg?.id
                ]
            }
        }
        
        return data
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// Activity View Controller for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

#Preview {
    DataExportView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}