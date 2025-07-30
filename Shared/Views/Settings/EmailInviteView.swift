import SwiftUI

struct EmailInviteView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: String = ""
    @State private var showingCopiedAlert = false
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Invite Team Members")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Share this link to invite team members to your organization. When they tap it, it will open the RHEIR app directly.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Organization Info
                if let orgName = authViewModel.currentOrg?.name {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.blue)
                            Text("Organization: \(orgName)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        Text("Current Members: \(authViewModel.currentOrg?.members.count ?? 0)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !authViewModel.pendingInvites.isEmpty {
                            Text("Pending Invites: \(authViewModel.pendingInvites.count)")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Share URL Display
                if !shareURL.isEmpty {
                    VStack(spacing: 16) {
                        Text("Invite Link:")
                            .font(.headline)
                        
                        Text(shareURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onTapGesture {
                                copyToClipboard()
                            }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button("Copy Link") {
                                copyToClipboard()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Share") {
                                showingShareSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        VStack(spacing: 8) {
                            Text("📱 How to invite someone:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("1. Tap 'Share' or 'Copy Link' above\n2. Send via Messages, Email, or any app\n3. When they tap the link, it opens RHEIR app\n4. They'll automatically join your organization")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(8)
                    }
                }
                
                // Status
                if !authViewModel.inviteStatus.isEmpty {
                    Text(authViewModel.inviteStatus)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if shareURL.isEmpty {
                        Button("Generate Invite Link") {
                            createShareLink()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Invite Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Link Copied!", isPresented: $showingCopiedAlert) {
                Button("OK") {}
            } message: {
                Text("The invite link has been copied to your clipboard. Send it to team members via Messages, Email, or any messaging app!")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareURL])
            }
            .onAppear {
                if shareURL.isEmpty {
                    createShareLink()
                }
            }
        }
    }
    
    private func createShareLink() {
        shareURL = authViewModel.getShareURLForCopying()
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = shareURL
        showingCopiedAlert = true
    }
}

// MARK: - ShareSheet for native iOS sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
struct EmailInviteView_Previews: PreviewProvider {
    static var previews: some View {
        EmailInviteView()
            .environmentObject(AuthViewModel(service: CloudKitAuthService()))
    }
}
#endif