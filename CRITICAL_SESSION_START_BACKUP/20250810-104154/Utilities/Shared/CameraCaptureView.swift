//
//  CameraCaptureView.swift
//  Rheir
//
//  Created by Kevin Barrett on 5/4/25.
//

#if canImport(UIKit)

import SwiftUI

/// A UIViewControllerRepresentable wrapper around UIImagePickerController for camera capture.
struct CameraCaptureView: UIViewControllerRepresentable {
    /// The captured image, bound back to the parent.
    @Binding var image: UIImage?
    /// Whether the picker is presented. We dismiss ourselves by toggling this.
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Fallback: if no camera (e.g. simulator), use photo library
            picker.sourceType = .photoLibrary
            return picker
        }
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {
        // nothing to update
    }

    /// Coordinator to conform to UIImagePickerControllerDelegate & UINavigationControllerDelegate
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView
        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
