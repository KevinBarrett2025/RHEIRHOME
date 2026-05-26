import Foundation
import OSLog

extension Logger {
    static let productionChatGPT = Logger(subsystem: "com.RheirHome.RHEIR", category: "productionChatGPT")
}

/// Production ChatGPT service with subscription analytics.
actor ProductionChatGPTService {
    static let shared = ProductionChatGPTService()

    private init() {}
    
    /// Analyzes receipt text with project context - Production version with analytics
    func analyzeReceipt(
        ocrText: String, 
        projectName: String?,
        organizationID: String,
        subscriptionTier: SubscriptionTier
    ) async throws -> ReceiptAnalysisResult {
        
        // Check subscription limits
        let limitStatus = await AIUsageAnalyticsService.shared.checkUsageLimits(
            organizationID: organizationID,
            subscriptionTier: subscriptionTier
        )
        
        if limitStatus == .exceeded {
            throw ProductionChatGPTError.usageLimitExceeded
        }
        
        // Check if feature is allowed for subscription tier
        guard subscriptionTier.aiUsageLimits.isFeatureAllowed(.receiptAnalysis) else {
            throw ProductionChatGPTError.featureNotAllowed
        }
        
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProductionChatGPTError.emptyText
        }
        
        throw ProductionChatGPTError.secureBackendUnavailable
    }
    
    /// Check if organization can use AI features
    func canUseAIFeatures(organizationID: String, subscriptionTier: SubscriptionTier) async -> Bool {
        let limitStatus = await AIUsageAnalyticsService.shared.checkUsageLimits(
            organizationID: organizationID,
            subscriptionTier: subscriptionTier
        )
        
        return limitStatus != .exceeded
    }
    
    /// Get usage statistics for organization
    func getUsageStats(for organizationID: String) async -> OrganizationUsageStats {
        return await AIUsageAnalyticsService.shared.getUsageStats(for: organizationID)
    }
    
    // MARK: - Private Methods
    
    private func makeAPIRequest(prompt: String) async throws -> GlobalChatGPTResponse {
        throw ProductionChatGPTError.secureBackendUnavailable
    }
    
    private func createReceiptAnalysisPrompt(ocrText: String, projectName: String?) -> String {
        let contextInfo = projectName.map { "Project: \($0)" } ?? "No specific project context"
        
        let commonStores = """
        Common store names to recognize:
        - Home Depot (not "How doers", "How Depot", "Home Dopot")
        - Lowe's (not "Lowes", "Low's") 
        - Menards
        - Ace Hardware
        - Harbor Freight Tools
        - Sherwin-Williams
        - Benjamin Moore
        - Walmart
        - Target
        - Costco
        - Sam's Club
        - Amazon
        - Best Buy
        - Office Depot
        - Staples
        - AutoZone
        - O'Reilly Auto Parts
        - NAPA Auto Parts
        - Tractor Supply Co.
        - Northern Tool
        - Grainger
        - Ferguson
        - Supply House
        - Plumbing Plus
        - Electrical Supply
        """
        
        return """
        Analyze this receipt OCR text and return ONLY a valid JSON object with the following structure:
        {
            "vendor": "string - business name",
            "category": "Materials|General Conditions|Contingency|Other",
            "amount": number - total amount,
            "taxAmount": number - tax amount (0 if not found),
            "discountAmount": number - discount amount (0 if not found),
            "tipAmount": number - restaurant gratuity amount (null if not found),
            "pricePerGallon": number - gas/fuel price per gallon (null if not found),
            "paymentMethod": "Credit Card|Debit Card|Cash|Check|Bank Transfer|Other",
            "paymentMethodDetails": {
                "cardBrand": "string - Visa, Mastercard, American Express, Discover, etc. (if card payment)",
                "lastFourDigits": "string - last 4 digits of card (if visible on receipt)",
                "accountInfo": "string - any additional payment account info"
            },
            "receiptNumber": "string - receipt/transaction number",
            "receiptDate": "string - actual transaction date from receipt (format: YYYY-MM-DD)",
            "items": [
                {
                    "name": "string - item name",
                    "quantity": number,
                    "unitPrice": number,
                    "totalPrice": number,
                    "category": "Materials|General Conditions|Contingency|Other"
                }
            ],
            "isReturn": boolean,
            "confidence": number - confidence score 0.0 to 1.0
        }

        Context: \(contextInfo)

        \(commonStores)

        CRITICAL INSTRUCTIONS:
        1. RECEIPT DATE: Look for the actual transaction date on the receipt. Common patterns:
           - Date stamps at top or bottom of receipt
           - Format like: MM/DD/YY, MM/DD/YYYY, DD/MM/YY, YYYY-MM-DD
           - Look for words like "Date:", "Transaction Date:", or standalone dates
           - The receipt date is NOT today's date - find the actual date from the receipt text
        
        2. PAYMENT METHOD DETAILS: Look for card information:
           - Card brand: Visa, Mastercard, American Express, Discover, Chase, etc.
           - Last 4 digits: Often shown as "****1234" or "XXXX-XXXX-XXXX-1234"
           - Account ending in: Look for "Account ending in" or similar phrases
           - For cash payments, set cardBrand and lastFourDigits to null
        
        3. VENDOR RECOGNITION: Use the correct store names from the common stores list above
           - Look for partial matches or OCR errors in store names and correct them

        4. CONTRACTOR-SPECIFIC FIELDS:
           - For restaurants, extract tip/gratuity separately when visible.
           - For gas/fuel receipts, extract the posted price per gallon when visible.
        
        Guidelines:
        - Materials: lumber, nails, screws, paint, tools, hardware, building supplies
        - General Conditions: permits, insurance, utilities, office supplies, fuel
        - Contingency: unexpected items, misc supplies
        - Other: food, personal items, non-construction related
        - Extract as many individual items as possible
        - Be conservative with confidence scores
        - ALWAYS try to find the actual receipt date from the text, not today's date

        Receipt text:
        \(ocrText)
        """
    }
    
    private func parseReceiptAnalysis(_ content: String) throws -> ReceiptAnalysisResult {
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8) else {
            throw ProductionChatGPTError.invalidJSON
        }
        
        do {
            // Decode as GlobalReceiptAnalysis first, then convert to shared type
            let globalAnalysis = try JSONDecoder().decode(GlobalReceiptAnalysis.self, from: data)
            
            // Convert payment method details
            var paymentMethodDetails: PaymentMethodDetails?
            if let globalDetails = globalAnalysis.paymentMethodDetails {
                paymentMethodDetails = PaymentMethodDetails(
                    cardBrand: globalDetails.cardBrand,
                    lastFourDigits: globalDetails.lastFourDigits,
                    accountInfo: globalDetails.accountInfo
                )
            }
            
            // Parse receipt date from string
            var receiptDate: Date?
            if let dateString = globalAnalysis.receiptDate, !dateString.isEmpty {
                receiptDate = parseReceiptDate(dateString)
            }
            
            return ReceiptAnalysisResult(
                vendor: globalAnalysis.vendor,
                category: globalAnalysis.category,
                amount: globalAnalysis.amount,
                taxAmount: globalAnalysis.taxAmount,
                discountAmount: globalAnalysis.discountAmount,
                tipAmount: globalAnalysis.tipAmount,
                pricePerGallon: globalAnalysis.pricePerGallon,
                paymentMethod: globalAnalysis.paymentMethod,
                paymentMethodDetails: paymentMethodDetails,
                receiptNumber: globalAnalysis.receiptNumber,
                receiptDate: receiptDate,
                items: globalAnalysis.items.map { item in
                    ReceiptItemResult(
                        name: item.name,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        totalPrice: item.totalPrice,
                        category: item.category
                    )
                },
                isReturn: globalAnalysis.isReturn,
                confidence: globalAnalysis.confidence
            )
        } catch {
            Logger.productionChatGPT.error(
                "Failed to parse receipt analysis JSON [error=\(error.localizedDescription, privacy: .public) characters=\(cleanContent.count, privacy: .public)]"
            )
            throw ProductionChatGPTError.invalidJSON
        }
    }
    
    /// Parse receipt date from various formats
    private func parseReceiptDate(_ dateString: String) -> Date? {
        let dateFormatters = [
            // Standard formats
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "dd/MM/yyyy",
            "dd/MM/yy",
            "M/d/yyyy",
            "M/d/yy",
            // With time
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yy HH:mm:ss",
            // Other common formats
            "MMM dd, yyyy",
            "MMM d, yyyy",
            "dd MMM yyyy",
            "d MMM yyyy"
        ]
        
        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: dateString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        
        Logger.productionChatGPT.warning(
            "Could not parse receipt date [value=\(dateString, privacy: .private(mask: .hash))]"
        )
        return nil
    }
    
    // MARK: - Cost Calculation
    
    private func estimateTokenUsage(prompt: String, response: String) -> Int {
        // Rough estimation: 1 token ≈ 0.75 words
        let promptWords = prompt.split(separator: " ").count
        let responseWords = response.split(separator: " ").count
        let totalWords = promptWords + responseWords
        
        return Int(Double(totalWords) / 0.75)
    }
    
    private func calculateCost(tokens: Int) -> Double {
        // GPT-3.5-turbo pricing (as of 2024)
        // Input: $0.0015 per 1K tokens
        // Output: $0.002 per 1K tokens  
        // We'll use blended rate of $0.00175 per 1K tokens
        
        let costPer1KTokens = 0.00175
        return Double(tokens) * costPer1KTokens / 1000.0
    }
}

// MARK: - Production Errors

enum ProductionChatGPTError: LocalizedError {
    case emptyText
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case noContent
    case invalidJSON
    case usageLimitExceeded
    case featureNotAllowed
    case secureBackendUnavailable
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Receipt text is empty. Please scan a receipt with readable text."
        case .invalidURL:
            return "Invalid ChatGPT API URL."
        case .invalidResponse:
            return "Invalid response from ChatGPT API."
        case .httpError(let statusCode, let message):
            return "ChatGPT API error (\(statusCode)): \(message)"
        case .noContent:
            return "No content received from ChatGPT API."
        case .invalidJSON:
            return "Invalid JSON response from ChatGPT API."
        case .usageLimitExceeded:
            return "Monthly AI usage limit exceeded. Please upgrade your subscription or wait until next month."
        case .featureNotAllowed:
            return "This AI feature is not available with your current subscription plan. Please upgrade to access advanced features."
        case .secureBackendUnavailable:
            return "Secure receipt analysis is not currently available. Please review the OCR result manually."
        }
    }
}
