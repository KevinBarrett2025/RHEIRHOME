import Foundation

/// Represents a payment method used for receipts
public struct PaymentMethod: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String              // User-friendly nickname
    public var type: PaymentType
    public var cardBrand: CardBrand?     // For cards only
    public var lastFourDigits: String
    public var nickname: String          // Additional nickname for quick identification
    public var dateAdded: Date
    public var lastUsed: Date?
    public var totalSpent: Double
    public var isActive: Bool
    public var accountNumber: String     // For checks/bank transfers (masked)
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: PaymentType,
        cardBrand: CardBrand? = nil,
        lastFourDigits: String = "",
        nickname: String = "",
        dateAdded: Date = Date(),
        lastUsed: Date? = nil,
        totalSpent: Double = 0.0,
        isActive: Bool = true,
        accountNumber: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.cardBrand = cardBrand
        self.lastFourDigits = lastFourDigits
        self.nickname = nickname
        self.dateAdded = dateAdded
        self.lastUsed = lastUsed
        self.totalSpent = totalSpent
        self.isActive = isActive
        self.accountNumber = accountNumber
    }
    
    /// Display name for the payment method
    public var displayName: String {
        if !nickname.isEmpty {
            return nickname
        }
        
        if type == .creditCard || type == .debitCard, let brand = cardBrand {
            let cardInfo = lastFourDigits.isEmpty ? "" : " •••• \(lastFourDigits)"
            return "\(brand.rawValue)\(cardInfo)"
        }
        
        return name
    }
}

/// Types of payment methods
public enum PaymentType: String, CaseIterable, Identifiable, Codable {
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case cash = "Cash"
    case check = "Check"
    case bankTransfer = "Bank Transfer"
    case other = "Other"
    
    public var id: Self { self }
}

/// Card brands for credit/debit cards
public enum CardBrand: String, CaseIterable, Identifiable, Codable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case americanExpress = "American Express"
    case discover = "Discover"
    case chase = "Chase"
    case wellsFargo = "Wells Fargo"
    case bankOfAmerica = "Bank of America"
    case citi = "Citi"
    case capital = "Capital One"
    case other = "Other"
    
    public var id: Self { self }
}