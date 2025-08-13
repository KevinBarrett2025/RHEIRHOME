import Foundation
import UIKit
import Vision

/// Production-ready service for receipt analysis that handles the full AI integration workflow
class ReceiptAnalysisService {
    static let shared = ReceiptAnalysisService()
    
    private init() {}
    
    /// Analyzes a receipt image using OCR + AI with subscription analytics
    /// This is the main entry point for production receipt scanning
    func analyzeReceipt(
        image: UIImage,
        projectName: String?,
        organizationID: String,
        subscriptionTier: SubscriptionTier
    ) async throws -> ReceiptAnalysisResult {
        
        // Use the production OCR service which handles the full workflow
        return try await ReceiptOCRService.shared.scanAndAnalyzeReceipt(
            image: image, 
            projectName: projectName, 
            organizationID: organizationID, 
            subscriptionTier: subscriptionTier
        )
    }
    
    /// Check if organization can use AI features before attempting analysis
    func canUseAIFeatures(organizationID: String, subscriptionTier: SubscriptionTier) async -> Bool {
        return await ProductionChatGPTService.shared.canUseAIFeatures(
            organizationID: organizationID, 
            subscriptionTier: subscriptionTier
        )
    }
    
    /// Get usage statistics for organization
    func getUsageStats(for organizationID: String) async -> OrganizationUsageStats {
        return await ProductionChatGPTService.shared.getUsageStats(for: organizationID)
    }
}