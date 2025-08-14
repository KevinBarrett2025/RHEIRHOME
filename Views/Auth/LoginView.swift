import SwiftUI
import AuthenticationServices

/// LoginView contains exactly one Sign-in-with-Apple button.
/// When the coordinator publishes a non-nil credential, we call `vm.signInWithApple(using:)`.
/// Any error from either the coordinator or the AuthViewModel appears in a SwiftUI Alert.
struct LoginView: View {
    @ObservedObject var vm: AuthViewModel
    @StateObject private var appleCoordinator = SignInWithAppleCoordinator()

    @State private var showErrorAlert = false
    @State private var lastErrorMessage = ""

    var body: some View {
        VStack(spacing: 40) {
            // ──────────────────────────────────────────────────────────
            // Only the Apple-sign-in button here. No extra "Welcome" text.
            // ──────────────────────────────────────────────────────────
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: appleCoordinator.handle(result:)
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 45)
            .padding(.horizontal, 32)
            .onReceive(appleCoordinator.$credential) { credential in
                // Once the coordinator publishes a non-nil credential, call VM:
                guard let appleID = credential else { return }
                vm.signInWithApple(using: appleID)
            }

            // ──────────────────────────────────────────────────────────
            // Show any AuthViewModel error message (red text) as well
            // ──────────────────────────────────────────────────────────
            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .onReceive(appleCoordinator.$coordinatorError) { newErr in
            // If the Apple coordinator reports a problem (e.g. canceled, network issue),
            // show an alert immediately:
            guard let txt = newErr else { return }
            lastErrorMessage = txt
            showErrorAlert = true
        }
        .onReceive(vm.$errorMessage) { newValue in
            // If the ViewModel posts an error, show it in the same alert:
            guard let txt = newValue else { return }
            lastErrorMessage = txt
            showErrorAlert = true
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Login Problem"),
                message: Text(lastErrorMessage),
                dismissButton: .default(Text("OK")) {
                    // Clear both coordinator and VM errors on dismiss:
                    vm.errorMessage = nil
                    appleCoordinator.coordinatorError = nil
                }
            )
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(vm: AuthViewModel(service: CloudKitAuthService()))
    }
}
