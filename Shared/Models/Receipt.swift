import Foundation

/// Which budget bucket a receipt applies to.
public enum ReceiptCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case material    = "Materials"
    case general     = "General Conditions"
    case contingency = "Contingency"

    public var id: Self { self }
}

/// Processing status for ChatGPT API integration
public enum ProcessingStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case needsReview = "Needs Review"
    
    public var id: Self { self }
}

/// Represents a vendor/supplier in the organization directory
public struct Vendor: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var category: VendorCategory
    public var subcategories: [String]  // Dynamic subcategories
    public var address: String
    public var phone: String
    public var email: String
    public var notes: String
    public var dateAdded: Date
    public var totalSpent: Double
    public var isActive: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: VendorCategory = .other,
        subcategories: [String] = [],
        address: String = "",
        phone: String = "",
        email: String = "",
        notes: String = "",
        dateAdded: Date = Date(),
        totalSpent: Double = 0.0,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategories = subcategories
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
        self.dateAdded = dateAdded
        self.totalSpent = totalSpent
        self.isActive = isActive
    }
}

/// Categories for different types of vendors
public enum VendorCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case hardware = "Hardware Store"
    case grocery = "Grocery Store"  
    case restaurant = "Restaurant"
    case gas = "Gas Station"
    case lumber = "Lumber Yard"
    case electrical = "Electrical Supply"
    case plumbing = "Plumbing Supply"
    case paint = "Paint Store"
    case rental = "Equipment Rental"
    case professional = "Professional Services"
    case automotive = "Automotive"
    case office = "Office Supplies"
    case other = "Other"
    
    public var id: Self { self }
    
    /// Common subcategories for each vendor type
    public var commonSubcategories: [String] {
        switch self {
        case .hardware:
            return ["Fasteners", "Tools", "Hardware", "Safety Equipment", "Adhesives"]
        case .lumber:
            return ["Framing Lumber", "Plywood", "Drywall", "Insulation", "Roofing Materials"]
        case .electrical:
            return ["Wire", "Outlets", "Switches", "Breakers", "Conduit", "Fixtures"]
        case .plumbing:
            return ["Pipes", "Fittings", "Valves", "Fixtures", "Water Heaters"]
        case .paint:
            return ["Interior Paint", "Exterior Paint", "Primer", "Brushes", "Rollers"]
        case .rental:
            return ["Heavy Equipment", "Tools", "Scaffolding", "Generators"]
        case .professional:
            return ["Legal", "Accounting", "Engineering", "Architecture", "Consulting"]
        case .automotive:
            return ["Fuel", "Vehicle Maintenance", "Parts", "Tools"]
        case .office:
            return ["Stationery", "Computers", "Software", "Furniture"]
        case .grocery, .restaurant:
            return ["Food", "Beverages", "Supplies"]
        case .gas:
            return ["Fuel", "Convenience Items"]
        case .other:
            return []
        }
    }
}

/// Represents a payment method used for receipts
public struct PaymentMethod: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String              // User-friendly nickname
    public var type: PaymentType
    public var cardBrand: CardBrand?     // For cards only
    public var lastFourDigits: String
    public var nickname: String          // Additional nickname for quick identification
    public var dateAdded: Date
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
        self.totalSpent = totalSpent
        self.isActive = isActive
        self.accountNumber = accountNumber
    }
    
    /// Display name for the payment method
    public var displayName: String {
        if !nickname.isEmpty && nickname != name {
            let cardInfo = lastFourDigits.isEmpty ? "" : " •••• \(lastFourDigits)"
            return "\(nickname)\(cardInfo)"
        }
        
        if type == .creditCard || type == .debitCard, let brand = cardBrand {
            let cardInfo = lastFourDigits.isEmpty ? "" : " •••• \(lastFourDigits)"
            return "\(brand.rawValue)\(cardInfo)"
        }
        
        let cardInfo = lastFourDigits.isEmpty ? "" : " •••• \(lastFourDigits)"
        return "\(name)\(cardInfo)"
    }
}

/// Types of payment methods
public enum PaymentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case cash = "Cash"
    case check = "Check"
    case bankTransfer = "Bank Transfer"
    case other = "Other"
    
    public var id: Self { self }
}

/// Card brands for credit/debit cards
public enum CardBrand: String, CaseIterable, Identifiable, Codable, Sendable {
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

/// Represents an individual item on a receipt
public struct ReceiptItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var quantity: Double
    public var unitPrice: Double
    public var totalPrice: Double
    public var category: ReceiptCategory
    public var subcategory: String       // Dynamic subcategory
    public var sku: String
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1.0,
        unitPrice: Double,
        totalPrice: Double,
        category: ReceiptCategory = .material,
        subcategory: String = "",
        sku: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
        self.subcategory = subcategory
        self.sku = sku
        self.notes = notes
    }
}

/// A purchase receipt (sales or returns).
public struct Receipt: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var vendor: String
    public var vendorID: UUID?           // Link to Vendor
    public var date: Date
    public var amount: Double
    public var notes: String
    public var category: ReceiptCategory
    public var photoIDs: [UUID]
    public var tags: [String]
    public var isReturn: Bool
    public var paymentMethod: String
    public var paymentMethodID: UUID?    // Link to PaymentMethod
    public var taxAmount: Double
    public var discountAmount: Double
    public var receiptNumber: String
    
    // Additional properties needed by existing code
    public var items: [ReceiptItem]
    public var processingStatus: ProcessingStatus
    public var imageData: Data?          // Legacy property for migration
    public var imageDatas: [Data]        // Legacy property for migration
    
    public init(
        id: UUID = UUID(),
        vendor: String,
        vendorID: UUID? = nil,
        date: Date,
        amount: Double,
        notes: String = "",
        category: ReceiptCategory = .material,
        photoIDs: [UUID] = [],
        tags: [String] = [],
        isReturn: Bool = false,
        paymentMethod: String = "",
        paymentMethodID: UUID? = nil,
        taxAmount: Double = 0,
        discountAmount: Double = 0,
        receiptNumber: String = "",
        items: [ReceiptItem] = [],
        processingStatus: ProcessingStatus = .completed,
        imageData: Data? = nil,
        imageDatas: [Data] = []
    ) {
        self.id = id
        self.vendor = vendor
        self.vendorID = vendorID
        self.date = date
        self.amount = amount
        self.notes = notes
        self.category = category
        self.photoIDs = photoIDs
        self.tags = tags
        self.isReturn = isReturn
        self.paymentMethod = paymentMethod
        self.paymentMethodID = paymentMethodID
        self.taxAmount = taxAmount
        self.discountAmount = discountAmount
        self.receiptNumber = receiptNumber
        self.items = items
        self.processingStatus = processingStatus
        self.imageData = imageData
        self.imageDatas = imageDatas
    }
    
    /// Whether this receipt has associated photos
    public var hasPhotos: Bool {
        return !photoIDs.isEmpty || imageData != nil || !imageDatas.isEmpty
    }
}