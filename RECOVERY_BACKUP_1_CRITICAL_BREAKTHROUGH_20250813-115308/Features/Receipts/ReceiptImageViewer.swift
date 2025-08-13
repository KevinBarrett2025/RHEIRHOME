import SwiftUI

struct ReceiptImageViewer: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let imageData = receipt.receiptImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = max(1.0, min(scale * delta, 3.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    }
                                    .simultaneously(with:
                                        DragGesture()
                                            .onChanged { value in
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                offset = newOffset
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Receipt image not available")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .navigationTitle("Receipt Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if receipt.hasReceiptImage {
                        ShareLink(
                            item: receipt.receiptImage!,
                            preview: SharePreview("Receipt from \(receipt.vendor)", image: receipt.receiptImage!)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#if DEBUG
struct ReceiptImageViewer_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptImageViewer(receipt: Receipt(
            vendor: "Test Vendor",
            date: Date(),
            amount: 25.00,
            receiptImageData: UIImage(systemName: "photo")?.jpegData(compressionQuality: 0.8)
        ))
    }
}
#endif