import Foundation

// MARK: - Receipt Analysis Models (Consolidated)

/// Result of AI-powered receipt analysis
public struct ReceiptAnalysisResult {
    public let vendor: String
    public let category: String
    public let amount: Double
    public let taxAmount: Double
    public let discountAmount: Double
    public let paymentMethod: String
    public let receiptNumber: String
    public let items: [ReceiptItemResult]
    public let isReturn: Bool
    public let confidence: Double
    
    public init(
        vendor: String,
        category: String,
        amount: Double,
        taxAmount: Double,
        discountAmount: Double,
        paymentMethod: String,
        receiptNumber: String,
        items: [ReceiptItemResult],
        isReturn: Bool,
        confidence: Double
    ) {
        self.vendor = vendor
        self.category = category
        self.amount = amount
        self.taxAmount = taxAmount
        self.discountAmount = discountAmount
        self.paymentMethod = paymentMethod
        self.receiptNumber = receiptNumber
        self.items = items
        self.isReturn = isReturn
        self.confidence = confidence
    }
}

/// Individual item from receipt analysis
public struct ReceiptItemResult {
    public let name: String
    public let quantity: Double
    public let unitPrice: Double
    public let totalPrice: Double
    public let category: String
    
    public init(
        name: String,
        quantity: Double,
        unitPrice: Double,
        totalPrice: Double,
        category: String
    ) {
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
    }
}

/// Receipt analysis errors
public enum ReceiptAnalysisError: LocalizedError {
    case invalidImage
    case noTextFound
    case aiAnalysisFailed
    case subscriptionLimitReached
    case featureNotAllowed
    case noOrganization
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format. Please try taking another photo."
        case .noTextFound:
            return "No readable text found in the image. Please ensure the receipt is clearly visible and well-lit."
        case .aiAnalysisFailed:
            return "AI analysis failed. Please try again or use manual entry."
        case .subscriptionLimitReached:
            return "Monthly AI usage limit exceeded. Please upgrade your subscription or wait until next month."
        case .featureNotAllowed:
            return "This AI feature is not available with your current subscription plan. Please upgrade to access advanced features."
        case .noOrganization:
            return "No organization found. Please ensure you're logged in and part of an organization."
        }
    }
}