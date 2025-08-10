#if os(iOS)
import SwiftUI
import VisionKit
import Vision

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
        parent.isPresented = false
        
        // Process the first scanned page
        guard scan.pageCount > 0 else { return }
        
        let image = scan.imageOfPage(at: 0)
        
        Task {
            await processScannedImage(image)
        }
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
    
    // MARK: - Image Processing
    
    @MainActor
    private func processScannedImage(_ image: UIImage) async {
        do {
            // Extract text using OCR
            let ocrText = try await extractTextFromImage(image)
            
            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                // Create manual receipt with just the image
                createManualReceipt(image: image, ocrText: "")
                return
            }
            
            // Try AI analysis if available
            if hasAICapability {
                do {
                    let projectName = parent.project.name
                    let analysis = try await analyzeReceiptWithChatGPT(ocrText: ocrText, projectName: projectName)
                    createReceiptFromAnalysis(analysis, image: image, ocrText: ocrText)
                } catch {
                    print("🤖 AI analysis failed: \(error.localizedDescription)")
                    // Fall back to manual entry with OCR text
                    createManualReceipt(image: image, ocrText: ocrText)
                }
            } else {
                // No AI capability, create manual receipt
                createManualReceipt(image: image, ocrText: ocrText)
            }
            
        } catch {
            print("❌ OCR failed: \(error.localizedDescription)")
            // Create receipt with just the image
            createManualReceipt(image: image, ocrText: "")
        }
    }
    
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ReceiptScannerError.invalidImage)
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptScannerError.ocrFailed)
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
    
    private func analyzeReceiptWithChatGPT(ocrText: String, projectName: String?) async throws -> ReceiptAnalysis {
        guard let apiKey = UserDefaults.standard.string(forKey: "global_chatgpt_api_key"), !apiKey.isEmpty else {
            throw ReceiptScannerError.noAPIKey
        }
        
        let prompt = createReceiptAnalysisPrompt(ocrText: ocrText, projectName: projectName)
        
        let requestBody = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1500,
            "temperature": 0.1
        ] as [String: Any]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ReceiptScannerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("RHEIR-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ReceiptScannerError.apiError
        }
        
        let chatResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw ReceiptScannerError.noContent
        }
        
        return try parseReceiptAnalysis(content)
    }
    
    private func createReceiptAnalysisPrompt(ocrText: String, projectName: String?) -> String {
        let contextInfo = projectName.map { "Project: \($0)" } ?? "No specific project context"
        
        return """
        Analyze this receipt OCR text and return ONLY a valid JSON object with the following structure:
        {
            "vendor": "string - business name",
            "category": "Materials|General Conditions|Contingency",
            "subcategory": "string - specific subcategory",
            "amount": number - total amount,
            "paymentMethod": "string - payment method name",
            "isReturn": boolean,
            "notes": "string - any additional notes"
        }

        Context: \(contextInfo)

        Category Guidelines:
        - Materials: lumber, nails, screws, paint, tools, hardware, building supplies
        - General Conditions: permits, insurance, utilities, office supplies, fuel, food
        - Contingency: unexpected items, misc supplies

        Instructions:
        - Be conservative and accurate
        - Default to "Materials" if uncertain about category
        - Extract payment method if visible (card name, cash, etc.)
        - Provide helpful subcategory that matches the items

        Receipt text:
        \(ocrText)
        """
    }
    
    private func parseReceiptAnalysis(_ content: String) throws -> ReceiptAnalysis {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8) else {
            throw ReceiptScannerError.invalidJSON
        }
        
        do {
            return try JSONDecoder().decode(ReceiptAnalysis.self, from: data)
        } catch {
            print("📝 JSON Parsing Error: \(error)")
            print("📝 Raw Content: \(cleanContent)")
            throw ReceiptScannerError.invalidJSON
        }
    }
    
    @MainActor
    private func createReceiptFromAnalysis(_ analysis: ReceiptAnalysis, image: UIImage, ocrText: String) {
        let receipt = Receipt(
            vendor: analysis.vendor,
            vendorID: nil, // Will be linked later if vendor exists
            date: Date(),
            amount: analysis.amount,
            notes: analysis.notes,
            category: ReceiptCategory(rawValue: analysis.category) ?? .material,
            
            isReturn: analysis.isReturn,
            paymentMethod: analysis.paymentMethod,
            paymentMethodID: nil // Will be linked later if payment method exists
        )
        
        // Add to current project - we'll need to get the ProjectViewModel from environment
        // For now, this is a placeholder - the actual implementation would require accessing
        // the environment object which isn't directly available in this coordinator
        print("✅ Receipt created: \(receipt.vendor) - $\(receipt.amount)")
        
        // Show success feedback
        showSuccessMessage(for: receipt)
    }
    
    @MainActor
    private func createManualReceipt(image: UIImage, ocrText: String) {
        let receipt = Receipt(
            vendor: "Unknown Vendor",
            vendorID: nil,
            date: Date(),
            amount: 0.0,
            notes: "Please edit this receipt to add details",
            category: .material,
            isReturn: false,
            paymentMethod: "Unknown",
            paymentMethodID: nil,
            processingStatus: .needsReview
        )
        
        // Add to current project - placeholder implementation
        print("📝 Manual receipt created - needs editing")
        
        // Show feedback that manual editing is needed
        showManualEditMessage(for: receipt)
    }
    
    private func showSuccessMessage(for receipt: Receipt) {
        let amountText = String(format: "%.2f", receipt.amount)
        print("✅ Receipt scanned: \(receipt.vendor) - $\(amountText)")
        
        // TODO: Show success toast or alert
        // This could be improved with a toast notification system
    }
    
    private func showManualEditMessage(for receipt: Receipt) {
        print("📝 Receipt needs manual editing - OCR text available")
        
        // TODO: Show message that receipt needs editing
        // This could navigate to the receipt edit view
    }
    
    private var hasAICapability: Bool {
        UserDefaults.standard.string(forKey: "global_chatgpt_api_key") != nil
    }
}

// MARK: - Supporting Types

private struct ReceiptAnalysis: Codable {
    let vendor: String
    let category: String
    let subcategory: String
    let amount: Double
    let paymentMethod: String
    let isReturn: Bool
    let notes: String
}

private struct ChatGPTResponse: Codable {
    let choices: [ChatGPTChoice]
}

private struct ChatGPTChoice: Codable {
    let message: ChatGPTMessage
}

private struct ChatGPTMessage: Codable {
    let content: String
}

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