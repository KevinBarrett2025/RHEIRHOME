import Foundation
import AuthenticationServices
import UIKit
import OSLog

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
        Logger.auth.debug("\(msg, privacy: .public)")
        #endif
    }

    /// Called by SwiftUI’s SignInWithAppleButton(onCompletion:).
    func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            log("Received Sign in with Apple success callback [credentialType=\(String(describing: type(of: auth.credential)))]")
            if let appleID = auth.credential as? ASAuthorizationAppleIDCredential {
                Logger.auth.info(
                    "Received Apple credential [user=\(appleID.user, privacy: .private(mask: .hash)) email=\((appleID.email ?? "nil"), privacy: .private(mask: .hash))]"
                )
                DispatchQueue.main.async {
                    self.credential = appleID
                }
            } else {
                log("Received non-AppleID credential in success callback.")
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
            Logger.auth.error("Sign in with Apple callback failed: \(errMsg, privacy: .public)")
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        log("Authorization controller completed successfully.")
        if let appleID = authorization.credential as? ASAuthorizationAppleIDCredential {
            Logger.auth.info(
                "Authorization controller produced Apple credential [user=\(appleID.user, privacy: .private(mask: .hash)) email=\((appleID.email ?? "nil"), privacy: .private(mask: .hash))]"
            )
            DispatchQueue.main.async {
                self.credential = appleID
            }
        } else {
            log("Authorization controller produced a non-AppleID credential.")
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
        Logger.auth.error("Authorization controller failed: \(errMsg, privacy: .public)")
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
        log("Resolved presentation anchor for Sign in with Apple.")
        return anchor
    }
}
