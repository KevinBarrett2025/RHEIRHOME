import SwiftUI
import AVFoundation

/// Helper to request/check camera authorization and, if denied, prompt the user to open Settings.
final class CameraPermission: ObservableObject {
    @Published var showSettingsAlert = false

    /// Call before presenting a camera picker.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }

        case .denied, .restricted:
            // Trigger the “go to Settings” alert
            DispatchQueue.main.async {
                self.showSettingsAlert = true
                completion(false)
            }

        @unknown default:
            completion(false)
        }
    }

    /// Opens the app’s Settings page
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }
}
