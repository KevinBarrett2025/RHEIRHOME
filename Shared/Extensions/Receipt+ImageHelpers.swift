#if canImport(UIKit)
import UIKit
import Foundation

/// Convenience extensions for Receipt to handle UIImage operations
extension Receipt {
    /// Convenience initializer that accepts UIImage directly
    public init(
        id: String = UUID().uuidString,
        vendor: String,
        vendorID: String? = nil,
        date: Date,
        amount: Double,
        notes: String = "",
        category: ReceiptCategory = .material,
        subcategory: String = "",
        isReturn: Bool = false,
        paymentMethod: String = "Cash",
        paymentMethodID: String? = nil,
        taxAmount: Double = 0.0,
        discountAmount: Double = 0.0,
        tipAmount: Double? = nil,
        pricePerGallon: Double? = nil,
        receiptNumber: String = "",
        processingStatus: ReceiptProcessingStatus = .pending,
        aiAnalysis: AIAnalysisData? = nil,
        receiptImage: UIImage? = nil  // UIImage parameter
    ) {
        // Convert UIImage to Data
        let imageData = receiptImage?.jpegData(compressionQuality: 0.8)
        
        // Call the main initializer with Data
        self.init(
            id: id,
            vendor: vendor,
            vendorID: vendorID,
            date: date,
            amount: amount,
            notes: notes,
            category: category,
            subcategory: subcategory,
            isReturn: isReturn,
            paymentMethod: paymentMethod,
            paymentMethodID: paymentMethodID,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            tipAmount: tipAmount,
            pricePerGallon: pricePerGallon,
            receiptNumber: receiptNumber,
            processingStatus: processingStatus,
            aiAnalysis: aiAnalysis,
            receiptImageData: imageData
        )
    }
}
#endif
