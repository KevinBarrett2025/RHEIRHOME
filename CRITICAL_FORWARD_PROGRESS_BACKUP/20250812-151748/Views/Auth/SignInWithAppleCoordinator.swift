import Foundation
import AuthenticationServices
import UIKit

/// A more verbose SignInWithAppleCoordinator that logs every step.
/// It publishes:
///   - `credential` when Apple gives us a valid ASAuthorizationAppleIDCredential
///   - `coordinatorError` if anything goes wrong (e.g. user cancels → error code 1001)
final class SignInWithAppleCoordinator: NSObject,
    ObservableObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    /// When AppleID succeeds, we’ll publish the raw credential here.
    @Published var credential: ASAuthorizationAppleIDCredential? = nil

    /// If the coordinator encounters an error (e.g. user canceled, network failure, etc.),
    /// we publish a human-readable string here so the UI can show an Alert.
    @Published var coordinatorError: String? = nil

    private func log(_ msg: String) {
        #if DEBUG
        print("🔑 [SignInCoordinator] \(msg)")
        #endif
    }

    /// Called by SwiftUI’s SignInWithAppleButton(onCompletion:).
    func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            log("🟢 handle(result:) got .success, credential type = \(type(of: auth.credential))")
            if let appleID = auth.credential as? ASAuthorizationAppleIDCredential {
                log("   → Got AppleID credential - userID=\(appleID.user), email=\(appleID.email ?? "nil")")
                DispatchQueue.main.async {
                    self.credential = appleID
                }
            } else {
                log("   → credential was not ASAuthorizationAppleIDCredential, it was \(auth.credential)")
            }

        case .failure(let error):
            let errMsg: String
            if let authError = error as? ASAuthorizationError {
                errMsg = "Authorization failed (code=\(authError.errorCode)): \(authError.localizedDescription)"
            } else {
                errMsg = "Authorization failed: \(error.localizedDescription)"
            }
            DispatchQueue.main.async {
                self.coordinatorError = errMsg
            }
            log("❌ handle(result:) \(errMsg)")
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        log("🟢 didCompleteWithAuthorization called, credential = \(authorization.credential)")
        if let appleID = authorization.credential as? ASAuthorizationAppleIDCredential {
            log("   → DID get AppleID credential - userID=\(appleID.user), email=\(appleID.email ?? "nil")")
            DispatchQueue.main.async {
                self.credential = appleID
            }
        } else {
            log("   → credentials were not AppleID, they were \(type(of: authorization.credential))")
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let errMsg: String
        if let authError = error as? ASAuthorizationError {
            errMsg = "ASAuthorizationController error (code=\(authError.errorCode)): \(authError.localizedDescription)"
        } else {
            errMsg = "ASAuthorizationController unknown error: \(error.localizedDescription)"
        }
        DispatchQueue.main.async {
            self.coordinatorError = errMsg
        }
        log("❌ didCompleteWithError \(errMsg)")
    }

    // MARK: - Presentation Context

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // Find the key window to present the AppleID sheet
        let anchor = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIWindow()
        log("🖼 presentationAnchor returning \(anchor) for ASAuthorizationController")
        return anchor
    }
}

