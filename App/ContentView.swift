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
        
        var orgID: String?
        var orgName: String?
        var token: String?
        var roleString: String?
        
        for item in queryItems {
            switch item.name {
            case "orgID": orgID = item.value
            case "name": orgName = item.value?.removingPercentEncoding
            case "token": token = item.value
            case "role": roleString = item.value
            default: break
            }
        }
        
        guard let orgID = orgID, let orgName = orgName, let token = token else {
            print("❌ Invalid invite URL - missing required parameters")
            return
        }
        
        // Parse role, default to member if not specified
        let role = OrganizationRole(rawValue: roleString ?? "member") ?? .member
        
        print("📧 INVITE URL ▶︎ Received invite for: \(orgName) (\(orgID)) as \(role.displayName)")
        
        if authVM.user != nil {
            // User is logged in - join immediately with the specified role
            authVM.joinOrganization(with: orgID, role: role) { success, error in
                if success {
                    print("📧 INVITE URL ▶︎ ✅ Successfully joined organization as \(role.displayName)")
                } else {
                    print("📧 INVITE URL ▶︎ ❌ Failed to join: \(error ?? "Unknown error")")
                }
            }
        } else {
            // User not logged in - store invite for after authentication
            UserDefaults.standard.set(orgID, forKey: "pending_invite_orgID")
            UserDefaults.standard.set(orgName, forKey: "pending_invite_orgName")
            UserDefaults.standard.set(token, forKey: "pending_invite_token")
            UserDefaults.standard.set(role.rawValue, forKey: "pending_invite_role")
            
            print("📧 INVITE URL ▶︎ Stored pending invite - will process after login as \(role.displayName)")
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