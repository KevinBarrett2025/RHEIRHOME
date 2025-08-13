import Foundation
import UIKit
import Vision

/// Enhanced receipt processing service that orchestrates OCR + ChatGPT analysis
actor EnhancedReceiptService {
    static let shared = EnhancedReceiptService()
    
    private let chatGPTService = ChatGPTService.shared
    
    private init() {}
    
    /// Processes a receipt image through OCR and ChatGPT analysis
    func processReceiptImage(_ image: UIImage) async -> ProcessedReceipt {
        print("🔍 Starting enhanced receipt processing...")
        
        do {
            // Step 1: Extract text using OCR
            print("📖 Extracting text with OCR...")
            let ocrText = try await extractTextFromImage(image)
            
            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("⚠️ No text found in image")
                return ProcessedReceipt(
                    receipt: createFallbackReceipt(image: image),
                    error: "No text could be extracted from the image"
                )
            }
            
            print("✅ OCR extracted \(ocrText.count) characters")
            
            // Step 2: Analyze with ChatGPT
            print("🤖 Analyzing with ChatGPT...")
            let analysis = try await chatGPTService.analyzeReceipt(ocrText)
            
            // Step 3: Create structured receipt
            let receipt = createReceiptFromAnalysis(analysis, ocrText: ocrText, image: image)
            
            print("✅ Enhanced processing complete!")
            return ProcessedReceipt(receipt: receipt, error: nil)
            
        } catch let error as ChatGPTError {
            print("🤖 ChatGPT analysis failed: \(error.localizedDescription)")
            
            // Fallback to basic OCR processing
            do {
                let ocrText = try await extractTextFromImage(image)
                let basicReceipt = createBasicReceiptFromOCR(ocrText, image: image)
                return ProcessedReceipt(
                    receipt: basicReceipt,
                    error: "AI analysis failed: \(error.localizedDescription). Using basic OCR."
                )
            } catch {
                return ProcessedReceipt(
                    receipt: createFallbackReceipt(image: image),
                    error: "Both AI and OCR processing failed: \(error.localizedDescription)"
                )
            }
        } catch {
            print("❌ Processing error: \(error.localizedDescription)")
            
            // Fallback to basic OCR processing
            do {
                let ocrText = try await extractTextFromImage(image)
                let basicReceipt = createBasicReceiptFromOCR(ocrText, image: image)
                return ProcessedReceipt(
                    receipt: basicReceipt,
                    error: "Processing error: \(error.localizedDescription). Using basic OCR."
                )
            } catch {
                return ProcessedReceipt(
                    receipt: createFallbackReceipt(image: image),
                    error: "All processing methods failed: \(error.localizedDescription)"
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ReceiptProcessingError.invalidImage)
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptProcessingError.ocrFailed)
                    return
                }
                
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func createReceiptFromAnalysis(
        _ analysis: ChatGPTReceiptAnalysis,
        ocrText: String,
        image: UIImage
    ) -> Receipt {
        // Convert analysis to receipt category
        let category = ReceiptCategory(rawValue: analysis.category) ?? .other
        
        // Convert analysis items to receipt items
        let items = analysis.items.map { item in
            ReceiptItem(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                category: ReceiptCategory(rawValue: item.category) ?? .other
            )
        }
        
        // Convert image to data
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        return Receipt(
            vendor: analysis.vendor,
            date: Date(),
            amount: analysis.amount,
            notes: "Processed with ChatGPT AI",
            category: category,
            isReturn: analysis.isReturn,
            paymentMethod: analysis.paymentMethod,
            items: items,
            taxAmount: analysis.taxAmount,
            discountAmount: analysis.discountAmount,
            receiptNumber: analysis.receiptNumber,
            ocrText: ocrText,
            imageData: imageData,
            processingStatus: .completed,
            confidence: analysis.confidence
        )
    }
    
    private func createBasicReceiptFromOCR(_ ocrText: String, image: UIImage) -> Receipt {
        let vendor = extractVendorFromText(ocrText)
        let amount = extractAmountFromText(ocrText)
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        return Receipt(
            vendor: vendor,
            date: Date(),
            amount: amount,
            notes: "Processed with basic OCR",
            category: .other,
            ocrText: ocrText,
            imageData: imageData,
            processingStatus: .completed,
            confidence: 0.5
        )
    }
    
    private func createFallbackReceipt(image: UIImage) -> Receipt {
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        return Receipt(
            vendor: "Unknown Vendor",
            date: Date(),
            amount: 0.0,
            notes: "Manual entry required - automatic processing failed",
            category: .other,
            imageData: imageData,
            processingStatus: .failed,
            confidence: 0.0
        )
    }
    
    private func extractVendorFromText(_ text: String) -> String {
        return text
            .split(separator: "\n")
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? "Unknown Vendor"
    }
    
    private func extractAmountFromText(_ text: String) -> Double {
        let pattern = "\\$?\\d+(?:\\.\\d{2})?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return 0.0
        }
        
        let raw = text[range].replacingOccurrences(of: "$", with: "")
        return Double(raw) ?? 0.0
    }
}

// MARK: - Supporting Types

struct ProcessedReceipt {
    let receipt: Receipt
    let error: String?
    
    var isSuccessful: Bool {
        return error == nil
    }
    
    var hasWarning: Bool {
        return error != nil && receipt.processingStatus != .failed
    }
}

enum ReceiptProcessingError: LocalizedError {
    case invalidImage
    case ocrFailed
    case noTextFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .ocrFailed:
            return "OCR text extraction failed"
        case .noTextFound:
            return "No readable text found in image"
        }
    }
}
