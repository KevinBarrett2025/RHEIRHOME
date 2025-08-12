import Foundation
import SwiftUI

class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var pendingInviteToken: String?
    @Published var shouldShowAcceptInvite = false
    
    @Published var pendingOrgID: String?
    @Published var shouldShowJoinOrg = false
    
    private init() {}
    
    func handleInviteURL(_ url: URL) {
        print("🔗 DEEP LINK ▶︎ Handling invite URL: \(url)")
        
        // Parse the invite URL - expecting format: https://app.rheirhome.com/invite?token=xyz
        guard url.host == "app.rheirhome.com",
              url.path.hasPrefix("/invite"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let token = queryItems.first(where: { $0.name == "token" })?.value else {
            print("🔗 DEEP LINK ▶︎ Invalid invite URL format")
            return
        }
        
        print("🔗 DEEP LINK ▶︎ Extracted invite token: \(token)")
        
        // Store the token and trigger the accept invite flow
        DispatchQueue.main.async {
            self.pendingInviteToken = token
            self.shouldShowAcceptInvite = true
        }
    }
    
    func handleURL(_ url: URL) {
        print("🔗 DEEP LINK ▶︎ Handling URL: \(url)")
        
        // Handle organization join URLs - expecting format: rheirhome://join-org?orgID=xyz
        if url.scheme == "rheirhome" && url.host == "join-org" {
            handleOrgJoinURL(url)
            return
        }
        
        // Handle invite URLs
        if url.host == "app.rheirhome.com" {
            handleInviteURL(url)
            return
        }
        
        print("🔗 DEEP LINK ▶︎ Unrecognized URL format")
    }
    
    private func handleOrgJoinURL(_ url: URL) {
        print("🔗 DEEP LINK ▶︎ Handling organization join URL: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let orgID = queryItems.first(where: { $0.name == "orgID" })?.value else {
            print("🔗 DEEP LINK ▶︎ Invalid organization join URL format")
            return
        }
        
        print("🔗 DEEP LINK ▶︎ Extracted organization ID: \(orgID)")
        
        // Store the org ID and trigger the join flow
        DispatchQueue.main.async {
            self.pendingOrgID = orgID
            self.shouldShowJoinOrg = true
        }
    }
    
    func clearPendingInvite() {
        pendingInviteToken = nil
        shouldShowAcceptInvite = false
    }
    
    func clearPendingOrgJoin() {
        pendingOrgID = nil
        shouldShowJoinOrg = false
    }
}
