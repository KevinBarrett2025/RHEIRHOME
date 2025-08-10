import Foundation
import UIKit
import Vision

/// Centralized receipt processing service that automatically detects project context
/// and manages both organization-wide and project-specific data
actor ContextAwareReceiptService {
    static let shared = ContextAwareReceiptService()
    
    private let chatGPTService = ChatGPTService.shared
    private let organizationService = OrganizationService.shared
    
    // Current context
    private var currentProjectId: String?
    private var currentOrganizationId: String?
    
    private init() {}
    
    // MARK: - Context Management
    
    /// Sets the current project context for all receipt processing
    func setProjectContext(_ projectId: String, organizationId: String) {
        self.currentProjectId = projectId
        self.currentOrganizationId = organizationId
        print("📍 Context updated: Project \(projectId) in Organization \(organizationId)")
    }
    
    /// Processes a receipt with automatic project context awareness
    func processReceiptForCurrentProject(_ image: UIImage) async -> ContextualProcessedReceipt {
        guard let projectId = currentProjectId,
              let organizationId = currentOrganizationId else {
            return ContextualProcessedReceipt(
                receipt: createFallbackReceipt(image: image),
                error: "No active project context. Please select a project first.",
                projectContext: nil,
                organizationContext: nil
            )
        }
        
        print("🔍 Processing receipt for Project: \(projectId)")
        
        do {
            // Step 1: Extract text using OCR
            let ocrText = try await extractTextFromImage(image)
            
            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return ContextualProcessedReceipt(
                    receipt: createFallbackReceipt(image: image),
                    error: "No text could be extracted from the image",
                    projectContext: ProjectContext(projectId: projectId),
                    organizationContext: OrganizationContext(organizationId: organizationId)
                )
            }
            
            // Step 2: Get organization context (master vendor/payment lists)
            let orgContext = await organizationService.getOrganizationContext(organizationId)
            
            // Step 3: Analyze with ChatGPT using organization context
            let analysis = try await chatGPTService.analyzeReceiptWithContext(
                ocrText: ocrText,
                organizationContext: orgContext
            )
            
            // Step 4: Create contextual receipt
            let receipt = await createContextualReceipt(
                from: analysis,
                ocrText: ocrText,
                image: image,
                projectId: projectId,
                organizationId: organizationId
            )
            
            // Step 5: Update both organization and project directories
            await updateDirectories(with: analysis, projectId: projectId, organizationId: organizationId)
            
            return ContextualProcessedReceipt(
                receipt: receipt,
                error: nil,
                projectContext: ProjectContext(projectId: projectId),
                organizationContext: OrganizationContext(organizationId: organizationId)
            )
            
        } catch let error as ChatGPTError {
            // Fallback to basic OCR with context
            do {
                let ocrText = try await extractTextFromImage(image)
                let basicReceipt = await createBasicContextualReceipt(
                    ocrText: ocrText,
                    image: image,
                    projectId: projectId,
                    organizationId: organizationId
                )
                
                return ContextualProcessedReceipt(
                    receipt: basicReceipt,
                    error: "AI analysis failed: \(error.localizedDescription). Using basic OCR.",
                    projectContext: ProjectContext(projectId: projectId),
                    organizationContext: OrganizationContext(organizationId: organizationId)
                )
            } catch {
                return ContextualProcessedReceipt(
                    receipt: createFallbackReceipt(image: image),
                    error: "Both AI and OCR processing failed: \(error.localizedDescription)",
                    projectContext: ProjectContext(projectId: projectId),
                    organizationContext: OrganizationContext(organizationId: organizationId)
                )
            }
        } catch {
            return ContextualProcessedReceipt(
                receipt: createFallbackReceipt(image: image),
                error: "Processing failed: \(error.localizedDescription)",
                projectContext: ProjectContext(projectId: projectId),
                organizationContext: OrganizationContext(organizationId: organizationId)
            )
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
    
    private func createContextualReceipt(
        from analysis: ContextualChatGPTAnalysis,
        ocrText: String,
        image: UIImage,
        projectId: String,
        organizationId: String
    ) async -> Receipt {
        let category = ReceiptCategory(rawValue: analysis.category) ?? .other
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        // Convert analysis items to receipt items with project context
        let items = analysis.items.map { item in
            ReceiptItem(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                category: ReceiptCategory(rawValue: item.category) ?? .other
            )
        }
        
        return Receipt(
            vendor: analysis.vendor,
            vendorID: analysis.organizationVendorId,
            date: Date(),
            amount: analysis.amount,
            notes: "Processed with AI - Project: \(projectId)",
            category: category,
            isReturn: analysis.isReturn,
            paymentMethod: analysis.paymentMethod,
            paymentMethodID: analysis.organizationPaymentMethodId,
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
    
    private func createBasicContextualReceipt(
        ocrText: String,
        image: UIImage,
        projectId: String,
        organizationId: String
    ) async -> Receipt {
        let vendor = extractVendorFromText(ocrText)
        let amount = extractAmountFromText(ocrText)
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        return Receipt(
            vendor: vendor,
            date: Date(),
            amount: amount,
            notes: "Basic OCR - Project: \(projectId)",
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
    
    private func updateDirectories(
        with analysis: ContextualChatGPTAnalysis,
        projectId: String,
        organizationId: String
    ) async {
        // Update organization master directory
        await organizationService.addVendorToMasterDirectory(
            organizationId: organizationId,
            vendorName: analysis.vendor,
            category: analysis.vendorCategory
        )
        
        await organizationService.addPaymentMethodToMasterDirectory(
            organizationId: organizationId,
            paymentMethod: analysis.paymentMethod,
            type: analysis.paymentMethodType
        )
        
        // Update project-specific tracking
        await organizationService.trackVendorForProject(
            projectId: projectId,
            vendorId: analysis.organizationVendorId,
            amount: analysis.amount
        )
        
        await organizationService.trackPaymentMethodForProject(
            projectId: projectId,
            paymentMethodId: analysis.organizationPaymentMethodId,
            amount: analysis.amount
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

// MARK: - Context Models

struct ProjectContext {
    let projectId: String
    var projectSpecificVendors: [String] = []
    var projectSpecificPaymentMethods: [String] = []
}

struct OrganizationContext {
    let organizationId: String
    var masterVendorDirectory: [OrganizationVendor] = []
    var masterPaymentMethodDirectory: [OrganizationPaymentMethod] = []
}

struct ContextualProcessedReceipt {
    let receipt: Receipt
    let error: String?
    let projectContext: ProjectContext?
    let organizationContext: OrganizationContext?
    
    var isSuccessful: Bool {
        return error == nil
    }
    
    var hasWarning: Bool {
        return error != nil && receipt.processingStatus != .failed
    }
}

// MARK: - Enhanced Models for Organization Management

struct OrganizationVendor: Identifiable, Codable {
    let id: String
    let name: String
    let category: VendorCategory
    let organizationId: String
    var totalSpentAcrossAllProjects: Double
    var projectsUsed: [String] // Project IDs where this vendor was used
    let dateFirstUsed: Date
    var lastUsed: Date
}

struct OrganizationPaymentMethod: Identifiable, Codable {
    let id: String
    let name: String
    let type: PaymentType
    let organizationId: String
    var totalSpentAcrossAllProjects: Double
    var projectsUsed: [String] // Project IDs where this payment method was used
    let dateFirstUsed: Date
    var lastUsed: Date
}

struct ProjectVendorUsage: Identifiable, Codable {
    let id: String
    let projectId: String
    let vendorId: String
    var totalSpent: Double
    var receiptCount: Int
    let firstUsed: Date
    var lastUsed: Date
}

struct ProjectPaymentMethodUsage: Identifiable, Codable {
    let id: String
    let projectId: String
    let paymentMethodId: String
    var totalSpent: Double
    var receiptCount: Int
    let firstUsed: Date
    var lastUsed: Date
}