import Foundation
import SwiftUI
import OSLog

class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var pendingInviteToken: String?
    @Published var shouldShowAcceptInvite = false
    
    @Published var pendingOrgID: String?
    @Published var shouldShowJoinOrg = false
    
    private init() {}
    
    func handleInviteURL(_ url: URL) {
        Logger.session.info("Handling invite URL.")
        
        // Parse the invite URL - expecting format: https://app.rheirhome.com/invite?token=xyz
        guard url.host == "app.rheirhome.com",
              url.path.hasPrefix("/invite"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let token = queryItems.first(where: { $0.name == "token" })?.value else {
            Logger.session.warning("Rejected invite URL because it did not match the expected format.")
            return
        }
        
        Logger.session.notice(
            "Stored pending invite token [token=\(token, privacy: .private(mask: .hash))]"
        )
        
        // Store the token and trigger the accept invite flow
        DispatchQueue.main.async {
            self.pendingInviteToken = token
            self.shouldShowAcceptInvite = true
        }
    }
    
    func handleURL(_ url: URL) {
        Logger.session.info("Handling incoming URL.")
        
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
        
        Logger.session.warning("Ignored unrecognized incoming URL.")
    }
    
    private func handleOrgJoinURL(_ url: URL) {
        Logger.session.info("Handling organization join URL.")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let orgID = queryItems.first(where: { $0.name == "orgID" })?.value else {
            Logger.session.warning("Rejected organization join URL because it did not match the expected format.")
            return
        }
        
        Logger.session.notice(
            "Stored pending organization join [organization=\(orgID, privacy: .private(mask: .hash))]"
        )
        
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
