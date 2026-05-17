import Foundation
import OSLog
import Vision
import UIKit

extension Logger {
    static let receiptOCR = Logger(subsystem: "com.RheirHome.RHEIR", category: "receiptOCR")
}

/// Service for extracting text from receipt images using Vision framework
public actor ReceiptOCRService {
    public static let shared = ReceiptOCRService()
    
    private init() {}
    
    /// Extracts text from a receipt image
    public func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    return try? observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: fullText)
                }
            }
            
            // Configure for better receipt text recognition
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Production-ready receipt scanning and analysis with subscription analytics
    public func scanAndAnalyzeReceipt(
        image: UIImage, 
        projectName: String?,
        organizationID: String,
        subscriptionTier: SubscriptionTier
    ) async throws -> ReceiptAnalysisResult {
        // Step 1: Extract text using OCR
        let ocrText = try await extractText(from: image)
        Logger.receiptOCR.info("Extracted OCR text for receipt analysis [characters=\(ocrText.count, privacy: .public)]")
        
        // Step 2: Analyze with Production ChatGPT (includes analytics)
        let analysis = try await ProductionChatGPTService.shared.analyzeReceipt(
            ocrText: ocrText,
            projectName: projectName,
            organizationID: organizationID,
            subscriptionTier: subscriptionTier
        )
        Logger.receiptOCR.notice(
            "Completed receipt AI analysis [items=\(analysis.items.count, privacy: .public) confidence=\(analysis.confidence, privacy: .public)]"
        )
        
        // Convert to shared type from ReceiptAnalysisTypes
        return ReceiptAnalysisResult(
            vendor: analysis.vendor,
            category: analysis.category,
            amount: analysis.amount,
            taxAmount: analysis.taxAmount,
            discountAmount: analysis.discountAmount,
            tipAmount: analysis.tipAmount,
            pricePerGallon: analysis.pricePerGallon,
            paymentMethod: analysis.paymentMethod,
            receiptNumber: analysis.receiptNumber,
            items: analysis.items.map { item in
                ReceiptItemResult(
                    name: item.name,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    totalPrice: item.totalPrice,
                    category: item.category
                )
            },
            isReturn: analysis.isReturn,
            confidence: analysis.confidence
        )
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format. Please try taking another photo."
        case .noTextFound:
            return "No readable text found in the image. Please ensure the receipt is clearly visible and well-lit."
        case .processingFailed:
            return "Failed to process the image. Please try again."
        }
    }
}
