import SwiftUI

/// Account details and organization management view
struct AccountDetailsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDataExport = false
    @State private var showingOrgSwitcher = false
    @State private var showingLocalDataManagement = false
    
    var body: some View {
        NavigationStack {
            Form {
                // User Account Information
                Section {
                    // User Avatar/Initials
                    HStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(userInitials)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authVM.user?.email ?? "Unknown User")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("User ID: \(authVM.user?.id.prefix(8) ?? "Unknown")...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Apple Sign-In User")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                } footer: {
                    Text("Your personal Apple Sign-In account information across all organizations.")
                }
                
                // Organizations
                Section {
                    ForEach(authVM.userOrganizations, id: \.id) { org in
                        HStack {
                            Circle()
                                .fill(Color.green.gradient)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(org.name.prefix(2)).uppercased())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(org.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let role = authVM.organizationRoles[org.id] {
                                    Text("Role: \(role.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Tier: \(org.subscriptionTier.displayName)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            if org.id == authVM.currentOrg?.id {
                                Text("Current")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            } else {
                                Button("Switch") {
                                    authVM.switchToOrganization(org)
                                    dismiss()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    if authVM.userOrganizations.count > 1 {
                        Button {
                            showingOrgSwitcher = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                Text("Advanced Organization Switching")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Organizations you belong to. Switch between them to access different projects and teams.")
                }
                
                // Data Management
                Section {
                    Button {
                        showingDataExport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Export Personal Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingLocalDataManagement = true
                    } label: {
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            Text("Local Data Management")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Export your personal data or manage local app data and cache.")
                }
                
                // Account Security
                Section {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Authentication")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Apple Sign-In enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CloudKit Sync")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Data synced across devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } footer: {
                    Text("Your account is secured with Apple Sign-In and data is synced via CloudKit.")
                }
            }
            .navigationTitle("Account Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showingOrgSwitcher) {
                OrganizationSwitcherView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showingLocalDataManagement) {
                LocalDataManagementView()
            }
        }
    }
    
    private var userInitials: String {
        guard let email = authVM.user?.email else { return "U" }
        let components = email.components(separatedBy: "@")
        if let name = components.first, name.count >= 2 {
            return String(name.prefix(2)).uppercased()
        } else {
            return String(email.prefix(2)).uppercased()
        }
    }
}

#Preview {
    AccountDetailsView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}