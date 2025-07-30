import SwiftUI

@main
struct RheirApp: App {
    @StateObject private var authViewModel = AuthViewModel(service: CloudKitAuthService())
    @StateObject private var projectViewModel = ProjectViewModel(cloudKitService: CloudKitAuthService())
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(projectViewModel)
                .onAppear {
                    // Connect AuthViewModel and ProjectViewModel for organization sync
                    authViewModel.setProjectViewModel(projectViewModel)
                }
                .onOpenURL { url in
                    print("📱 App opened with URL: \(url)")
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        print("📱 App opened with Universal Link: \(url)")
                        handleIncomingURL(url)
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 Processing URL: \(url)")
        
        // Handle RHEIR invite links (both custom scheme and universal links)
        if isRHEIRInviteLink(url) {
            print("📧 Detected RHEIR invite link")
            handleRHEIRInviteLink(url)
            return
        }
        
        // Handle CloudKit sharing URLs
        if url.absoluteString.contains("cloudkit") || url.absoluteString.contains("icloud") {
            print("☁️ CloudKit share URL detected")
            if authViewModel.user != nil {
                print("✅ User authenticated - CloudKit sharing available")
            } else {
                print("⚠️ User not authenticated - will authenticate then process share")
            }
            return
        }
        
        print("⚠️ Unrecognized URL format: \(url)")
    }
    
    private func isRHEIRInviteLink(_ url: URL) -> Bool {
        // Custom scheme: rheirhome://invite
        if url.scheme == "rheirhome" && url.host == "invite" {
            return true
        }
        
        // Universal link: https://app.rheirhome.com/invite
        if url.host == "app.rheirhome.com" && url.path.hasPrefix("/invite") {
            return true
        }
        
        return false
    }
    
    private func handleRHEIRInviteLink(_ url: URL) {
        print("📧 Processing RHEIR invite: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Invalid URL components")
            return
        }
        
        let orgID = queryItems.first(where: { $0.name == "orgID" })?.value
        let token = queryItems.first(where: { $0.name == "token" })?.value
        let orgName = queryItems.first(where: { $0.name == "name" })?.value
        
        print("📧 Extracted - orgID: \(orgID ?? "nil"), token: \(token ?? "nil"), name: \(orgName ?? "nil")")
        
        // Validate required parameters
        guard let validOrgID = orgID, !validOrgID.isEmpty else {
            print("❌ Invalid or missing organization ID")
            return
        }
        
        print("✅ Valid invite detected - processing...")
        
        // Store the invite details for processing after authentication
        UserDefaults.standard.set(validOrgID, forKey: "pending_invite_orgID")
        UserDefaults.standard.set(orgName ?? "Organization", forKey: "pending_invite_orgName")
        UserDefaults.standard.set(token ?? "", forKey: "pending_invite_token")
        print("📧 Stored pending invite details")
        
        // If user is already authenticated, process the invite immediately
        if authViewModel.user != nil {
            processPendingInvite()
        } else {
            print("📧 User not authenticated - invite will be processed after sign-in")
        }
    }
    
    private func processPendingInvite() {
        guard let orgID = UserDefaults.standard.string(forKey: "pending_invite_orgID"),
              let orgName = UserDefaults.standard.string(forKey: "pending_invite_orgName") else {
            print("📧 No pending invite found")
            return
        }
        
        print("📧 Processing pending invite for: \(orgName)")
        
        // Join the organization
        authViewModel.joinOrganization(with: orgID) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully joined organization: \(orgName)")
                    
                    // Clear the pending invite
                    UserDefaults.standard.removeObject(forKey: "pending_invite_orgID")
                    UserDefaults.standard.removeObject(forKey: "pending_invite_orgName")
                    UserDefaults.standard.removeObject(forKey: "pending_invite_token")
                    
                    // Show success message
                    self.authViewModel.inviteStatus = "✅ Successfully joined \(orgName)!"
                    
                } else {
                    print("❌ Failed to join organization: \(error ?? "Unknown error")")
                    self.authViewModel.errorMessage = error ?? "Failed to join organization"
                }
            }
        }
    }
}

extension RheirApp {
    /// Call this after successful authentication to process any pending invites
    func checkForPendingInvites() {
        if UserDefaults.standard.string(forKey: "pending_invite_orgID") != nil {
            print("📧 Processing pending invite after authentication")
            processPendingInvite()
        }
    }
}