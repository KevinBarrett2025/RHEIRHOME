import SwiftUI
import UIKit

/// A UIViewRepresentable that shows a single image in a UIScrollView,
/// enabling pinch-to-zoom and panning with a dismiss button.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let showsDismissButton: Bool
    let allowsPageSwipeAtMinimumZoom: Bool
    let onDismiss: () -> Void
    
    init(
        image: UIImage,
        showsDismissButton: Bool = true,
        allowsPageSwipeAtMinimumZoom: Bool = false,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.image = image
        self.showsDismissButton = showsDismissButton
        self.allowsPageSwipeAtMinimumZoom = allowsPageSwipeAtMinimumZoom
        self.onDismiss = onDismiss
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        // 1. UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.panGestureRecognizer.isEnabled = !allowsPageSwipeAtMinimumZoom

        // 2. UIImageView inside
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.allowsPageSwipeAtMinimumZoom = allowsPageSwipeAtMinimumZoom
        
        containerView.addSubview(scrollView)
        
        context.coordinator.onDismiss = onDismiss

        // 4. Constrain imageView to scrollView's content
        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // ImageView constraints
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        if showsDismissButton {
            // 3. Close button
            let closeButton = UIButton(type: .system)
            closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            closeButton.backgroundColor = .black.withAlphaComponent(0.6)
            closeButton.tintColor = .white
            closeButton.layer.cornerRadius = 20
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.accessibilityIdentifier = "zoomable-image-close"
            closeButton.addTarget(context.coordinator, action: #selector(Coordinator.dismissTapped), for: .touchUpInside)

            containerView.addSubview(closeButton)

            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 16),
                closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                closeButton.widthAnchor.constraint(equalToConstant: 40),
                closeButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.allowsPageSwipeAtMinimumZoom = allowsPageSwipeAtMinimumZoom
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        var onDismiss: (() -> Void)?
        var allowsPageSwipeAtMinimumZoom = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard allowsPageSwipeAtMinimumZoom else { return }
            scrollView.panGestureRecognizer.isEnabled = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
        }
        
        @objc func dismissTapped() {
            onDismiss?()
        }
    }
}
