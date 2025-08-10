// ... existing code ...

struct ContentView: View {
    @StateObject private var projectVM = ProjectViewModel(cloudKitService: CloudKitAuthService())
    @StateObject private var authVM = AuthViewModel(service: CloudKitAuthService())
    @State private var selectedTab: Tab = .projects

    var body: some View {
        Group {
            // Use RootView for proper authentication routing
            RootView()
                .environmentObject(projectVM)
                .environmentObject(authVM)
        }
        .onAppear {
            // Connect AuthViewModel to ProjectViewModel for organization sync
            authVM.setProjectViewModel(projectVM)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "rheirhome" else { return }
        
        if url.host == "invite" {
            handleInviteURL(url)
        }
    }
    
    private func handleInviteURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }
        
        var token: String?
        var isSecure = false
        
        // Check for new secure token-based invites first
        for item in queryItems {
            switch item.name {
            case "token": token = item.value
            case "secure": isSecure = item.value == "true"
            default: break
            }
        }
        
        if let inviteToken = token, isSecure {
            // Handle secure token-based invite
            handleSecureInviteToken(inviteToken)
            return
        }
        
        // Fallback to legacy invite handling for backward compatibility
        handleLegacyInviteURL(queryItems)
    }
    
    private func handleSecureInviteToken(_ token: String) {
        print("🔐 SECURE INVITE ▶︎ Processing token: \(token.prefix(8))...")
        
        if authVM.user != nil {
            // User is logged in - process invite immediately
            Task {
                let result = await authVM.processInviteToken(token)
                
                await MainActor.run {
                    switch result {
                    case .success(let message):
                        print("🔐 SECURE INVITE ▶︎ ✅ \(message)")
                    case .failure(let error):
                        print("🔐 SECURE INVITE ▶︎ ❌ \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // User not logged in - store secure token for after authentication
            UserDefaults.standard.set(token, forKey: "pending_secure_invite_token")
            print("🔐 SECURE INVITE ▶︎ Stored secure token for after login")
        }
    }
    
    private func handleLegacyInviteURL(_ queryItems: [URLQueryItem]) {
        // Legacy invite handling (keep for backward compatibility)
        var orgID: String?
        var orgName: String?
        var roleString: String?
        
        for item in queryItems {
            switch item.name {
            case "orgID": orgID = item.value
            case "name": orgName = item.value?.removingPercentEncoding
            case "role": roleString = item.value
            default: break
            }
        }
        
        guard let orgID = orgID, let orgName = orgName else {
            print("❌ Legacy invite URL - missing required parameters")
            return
        }
        
        let role = OrganizationRole(rawValue: roleString ?? "member") ?? .member
        
        print("📧 LEGACY INVITE ▶︎ Received invite for: \(orgName) (\(orgID)) as \(role.displayName)")
        
        if authVM.user != nil {
            authVM.joinOrganization(with: orgID, role: role) { success, error in
                if success {
                    print("📧 LEGACY INVITE ▶︎ ✅ Successfully joined organization as \(role.displayName)")
                } else {
                    print("📧 LEGACY INVITE ▶︎ ❌ Failed to join: \(error ?? "Unknown error")")
                }
            }
        } else {
            // Store legacy invite
            UserDefaults.standard.set(orgID, forKey: "pending_invite_orgID")
            UserDefaults.standard.set(orgName, forKey: "pending_invite_orgName")
            UserDefaults.standard.set(role.rawValue, forKey: "pending_invite_role")
            
            print("📧 LEGACY INVITE ▶︎ Stored pending invite - will process after login as \(role.displayName)")
        }
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// ... existing code ...