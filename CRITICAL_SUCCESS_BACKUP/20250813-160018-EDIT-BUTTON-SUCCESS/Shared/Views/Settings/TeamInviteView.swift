import SwiftUI

struct TeamInviteView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteLink: String = ""
    @State private var showingCopiedAlert = false
    @State private var isGeneratingLink = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection
                organizationInfoSection
                inviteLinkSection
                instructionsSection
                Spacer()
                actionButtons
            }
            .padding()
            .navigationTitle("Invite Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Link Copied!", isPresented: $showingCopiedAlert) {
                Button("OK") {}
            } message: {
                Text("The team invitation link has been copied to your clipboard. Share it with your team members!")
            }
            .onAppear {
                generateInviteLink()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Invite Team Members")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Share your RHEIR organization with team members so they can access and edit the same projects")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var organizationInfoSection: some View {
        Group {
            if let org = authVM.currentOrg {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.blue)
                        Text("Organization: \(org.name)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(projectVM.projects.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Projects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(projectVM.teamMembers.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(authVM.pendingInvites.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Pending")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var inviteLinkSection: some View {
        VStack(spacing: 16) {
            if isGeneratingLink {
                ProgressView("Generating invite link...")
                    .padding()
            } else if !inviteLink.isEmpty {
                VStack(spacing: 12) {
                    Text("Team Invitation Link:")
                        .font(.headline)
                    
                    Text(inviteLink)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            copyToClipboard()
                        }
                    
                    Button("Copy Invite Link") {
                        copyToClipboard()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Team Invitation Works:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("1.")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Copy the invitation link above")
                }
                
                HStack(alignment: .top) {
                    Text("2.")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Send it to team members via text, email, or messaging app")
                }
                
                HStack(alignment: .top) {
                    Text("3.")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("When they tap the link, it opens the RHEIR app")
                }
                
                HStack(alignment: .top) {
                    Text("4.")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("They'll automatically join your organization and see all shared projects")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if !inviteLink.isEmpty {
                Button("Share via Messages") {
                    shareViaMessages()
                }
                .buttonStyle(.bordered)
                
                Button("Share via Email") {
                    shareViaEmail()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Refresh Link") {
                generateInviteLink()
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - Private Methods
    
    private func generateInviteLink() {
        isGeneratingLink = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            inviteLink = authVM.getTeamMemberInviteLink() ?? "Failed to generate invite link"
            isGeneratingLink = false
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = inviteLink
        showingCopiedAlert = true
    }
    
    private func shareViaMessages() {
        let message = """
        Join our RHEIR organization to access shared construction projects!
        
        Tap this link to get started: \(inviteLink)
        
        The RHEIR app helps us manage projects, track expenses, and coordinate work together.
        """
        
        if let url = URL(string: "sms:?body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareViaEmail() {
        let subject = "Join Our RHEIR Organization"
        let body = """
        Hi there!
        
        You've been invited to join our RHEIR construction management organization. This will give you access to our shared projects, where you can:
        
        • View and edit project details
        • Track expenses and receipts  
        • Log work hours
        • Monitor project progress
        • Coordinate with the team
        
        To get started:
        1. Tap this link: \(inviteLink)
        2. It will open the RHEIR app
        3. You'll automatically join our organization
        
        If you don't have the RHEIR app yet, you can download it from the App Store first.
        
        Welcome to the team!
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    TeamInviteView()
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}