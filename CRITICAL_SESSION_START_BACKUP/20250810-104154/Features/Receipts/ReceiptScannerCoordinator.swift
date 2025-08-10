#if os(iOS)
import SwiftUI
import VisionKit
import Vision

/// Legacy coordinator - replaced by production ReceiptScannerView implementation
/// This file is kept for compatibility but is no longer used in the main receipt scanning flow
class ReceiptScannerCoordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    let parent: ReceiptScannerView
    
    init(parent: ReceiptScannerView) {
        self.parent = parent
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate
    
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        // This coordinator is no longer used - the main ReceiptScannerView handles everything
        parent.isPresented = false
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        parent.isPresented = false
    }
    
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        parent.isPresented = false
        print("❌ Document camera failed: \(error.localizedDescription)")
    }
}

// MARK: - Legacy Error Types (kept for compatibility)

private enum ReceiptScannerError: LocalizedError {
    case noAPIKey
    case invalidURL
    case apiError
    case noContent
    case invalidJSON
    case invalidImage
    case ocrFailed
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found"
        case .invalidURL:
            return "Invalid URL"
        case .apiError:
            return "API request failed"
        case .noContent:
            return "No content in response"
        case .invalidJSON:
            return "Invalid JSON response"
        case .invalidImage:
            return "Invalid image"
        case .ocrFailed:
            return "OCR failed"
        }
    }
}

#endif