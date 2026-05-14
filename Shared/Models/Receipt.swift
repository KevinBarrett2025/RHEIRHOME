import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Which budget bucket a receipt applies to - Enhanced for renovation intelligence.
public enum ReceiptCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    // MARK: - Traditional Budget Categories
    case material    = "Materials"
    case general     = "General Conditions"
    case contingency = "Contingency"
    
    // MARK: - Renovation Phase Categories (Phase 2E Enhancement)
    case demolition     = "Demolition"
    case sitework       = "Site Work"
    case foundation     = "Foundation"
    case framing        = "Framing"
    case roofing        = "Roofing"
    case exterior       = "Exterior"
    case electrical     = "Electrical"
    case plumbing       = "Plumbing"
    case hvac           = "HVAC"
    case insulation     = "Insulation"
    case drywall        = "Drywall"
    case flooring       = "Flooring"
    case trim           = "Trim & Millwork"
    case paint          = "Paint & Finishes"
    case kitchen        = "Kitchen"
    case bathroom       = "Bathroom"
    case fixtures       = "Fixtures & Hardware"
    case appliances     = "Appliances"
    case landscaping    = "Landscaping"
    case permits        = "Permits & Inspections"
    case cleanup        = "Cleanup"
    
    // MARK: - Design Element Categories
    case lighting       = "Lighting"
    case cabinetry      = "Cabinetry"
    case countertops    = "Countertops"
    case tile           = "Tile & Stone"
    case windows        = "Windows & Doors"
    case specialty      = "Specialty Items"
    
    public var id: Self { self }
    
    /// Category group for organizing in UI
    public var categoryGroup: CategoryGroup {
        switch self {
        case .material, .general, .contingency:
            return .traditional
        case .demolition, .sitework, .foundation, .framing, .roofing, .exterior:
            return .structural
        case .electrical, .plumbing, .hvac:
            return .mechanical
        case .insulation, .drywall, .flooring, .trim, .paint:
            return .finishes
        case .kitchen, .bathroom, .fixtures, .appliances:
            return .specialties
        case .lighting, .cabinetry, .countertops, .tile, .windows, .specialty:
            return .design
        case .landscaping, .permits, .cleanup:
            return .other
        }
    }
    
    /// Icon for visual representation
    public var icon: String {
        switch self {
        case .material: return "cube.box.fill"
        case .general: return "building.2.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        case .demolition: return "hammer.fill"
        case .sitework: return "square.and.arrow.up.fill"
        case .foundation: return "square.stack.3d.down.right.fill"
        case .framing: return "square.grid.3x3.fill"
        case .roofing: return "house.fill"
        case .exterior: return "house.and.flag.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "fan.fill"
        case .insulation: return "snow"
        case .drywall: return "rectangle.fill"
        case .flooring: return "square.fill"
        case .trim: return "ruler.fill"
        case .paint: return "paintbrush.fill"
        case .kitchen: return "oven.fill"
        case .bathroom: return "bathtub.fill"
        case .fixtures: return "lightbulb.fill"
        case .appliances: return "washer.fill"
        case .landscaping: return "leaf.fill"
        case .permits: return "doc.text.fill"
        case .cleanup: return "trash.fill"
        case .lighting: return "lightbulb.2.fill"
        case .cabinetry: return "cabinet.fill"
        case .countertops: return "rectangle.3.group.fill"
        case .tile: return "square.grid.2x2.fill"
        case .windows: return "rectangle.portrait.and.arrow.right.fill"
        case .specialty: return "star.fill"
        }
    }
    
    /// Color for visual representation
    public var color: String {
        switch categoryGroup {
        case .traditional: return "blue"
        case .structural: return "orange"
        case .mechanical: return "yellow"
        case .finishes: return "green"
        case .specialties: return "purple"
        case .design: return "pink"
        case .other: return "gray"
        }
    }
    
    /// Whether this category typically has scheduled phases
    public var hasPhaseScheduling: Bool {
        switch self {
        case .demolition, .sitework, .foundation, .framing, .roofing, .exterior,
             .electrical, .plumbing, .hvac, .insulation, .drywall, .flooring,
             .trim, .paint, .kitchen, .bathroom, .fixtures, .appliances, .cleanup:
            return true
        default:
            return false
        }
    }
    
    /// Typical order in renovation sequence (1-20, 0 for non-sequenced)
    public var renovationSequence: Int {
        switch self {
        case .permits: return 1
        case .demolition: return 2
        case .sitework: return 3
        case .foundation: return 4
        case .framing: return 5
        case .roofing: return 6
        case .exterior: return 7
        case .electrical: return 8
        case .plumbing: return 9
        case .hvac: return 10
        case .insulation: return 11
        case .drywall: return 12
        case .flooring: return 13
        case .trim: return 14
        case .paint: return 15
        case .kitchen: return 16
        case .bathroom: return 17
        case .fixtures, .lighting: return 18
        case .appliances: return 19
        case .landscaping: return 20
        case .cleanup: return 21
        default: return 0 // Non-sequenced categories
        }
    }
}

private enum ReceiptBudgetRollup {
    case materials
    case generalConditions
    case contingency
}

private extension ReceiptCategory {
    var budgetRollup: ReceiptBudgetRollup {
        switch self {
        case .general, .permits, .cleanup:
            return .generalConditions
        case .contingency:
            return .contingency
        default:
            return .materials
        }
    }
}

/// Category groups for organizing renovation phases
public enum CategoryGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case traditional = "Traditional Budget"
    case structural = "Structural Work"
    case mechanical = "Mechanical Systems" 
    case finishes = "Interior Finishes"
    case specialties = "Room Specialties"
    case design = "Design Elements"
    case other = "Other"
    
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

// Type alias for compatibility
public typealias ReceiptProcessingStatus = ProcessingStatus

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
    public var isDefault: Bool           // Default payment method for quick selection
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
        isDefault: Bool = false,
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
        self.isDefault = isDefault
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
    public let id: String
    public var vendor: String
    public var vendorID: String?           // Link to Vendor
    public var date: Date
    public var amount: Double
    public var notes: String
    public var category: ReceiptCategory
    public var subcategory: String?
    public var photoIDs: [UUID]          // CloudKit photo references
    public var tags: [String]
    public var isReturn: Bool
    public var paymentMethod: String
    public var paymentMethodID: String?    // Link to PaymentMethod
    public var paymentMethodDetails: PaymentMethodDetails?
    public var taxAmount: Double
    public var discountAmount: Double
    public var receiptNumber: String
    public var teamMemberID: UUID?       // Link to team member who made the purchase
    
    // PHASE 2I STEP 4: Budget integration metadata
    public var teamMemberName: String?  // Cache team member name for quick display
    public var projectID: UUID?          // Link to project for analytics
    
    // Receipt details
    public var items: [ReceiptItem]
    public var processingStatus: ProcessingStatus
    
    // AI Analysis data (when using ChatGPT)
    public var aiAnalysis: AIAnalysisData?
    
    // MARK: - Receipt Image Storage
    public var receiptImageData: Data?
    public var receiptImageName: String?
    public var hasReceiptImage: Bool { receiptImageData != nil }
    
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
        paymentMethodDetails: PaymentMethodDetails? = nil,
        taxAmount: Double = 0.0,
        discountAmount: Double = 0.0,
        receiptNumber: String = "",
        processingStatus: ReceiptProcessingStatus = .pending,
        aiAnalysis: AIAnalysisData? = nil,
        receiptImageData: Data? = nil  // Accept Data directly instead of UIImage
    ) {
        self.id = id
        self.vendor = vendor
        self.vendorID = vendorID
        self.date = date
        self.amount = amount
        self.notes = notes
        self.category = category
        self.subcategory = subcategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        self.photoIDs = []
        self.tags = []
        self.isReturn = isReturn
        self.paymentMethod = paymentMethod
        self.paymentMethodID = paymentMethodID
        self.paymentMethodDetails = paymentMethodDetails
        self.taxAmount = taxAmount
        self.discountAmount = discountAmount
        self.receiptNumber = receiptNumber
        self.teamMemberID = nil
        
        // PHASE 2I STEP 4: Initialize budget integration fields
        self.teamMemberName = nil
        self.projectID = nil
        
        self.items = []
        self.processingStatus = processingStatus
        self.aiAnalysis = aiAnalysis
        
        // Set image data directly
        self.receiptImageData = receiptImageData
        self.receiptImageName = receiptImageData != nil ? "receipt_\(id).jpg" : nil
    }
    
    // MARK: - Image Access Methods
    
    /// Get the receipt image as UIImage (when UIKit is available)
    #if canImport(UIKit)
    public var receiptImage: UIImage? {
        guard let imageData = receiptImageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Update the receipt image from UIImage
    public mutating func setReceiptImage(_ image: UIImage?) {
        if let image = image {
            self.receiptImageData = image.jpegData(compressionQuality: 0.8)
            self.receiptImageName = "receipt_\(id).jpg"
        } else {
            self.receiptImageData = nil
            self.receiptImageName = nil
        }
    }
    #endif
    
    /// Update the receipt image from Data
    public mutating func setReceiptImageData(_ data: Data?) {
        self.receiptImageData = data
        self.receiptImageName = data != nil ? "receipt_\(id).jpg" : nil
    }

    /// Signed receipt total (sales positive, returns negative).
    public var signedAmount: Double {
        isReturn ? -amount : amount
    }

    /// Categories represented by this receipt.
    /// When itemization exists, item categories are authoritative.
    public var representedCategories: Set<ReceiptCategory> {
        if !items.isEmpty {
            return Set(items.map(\.category))
        }
        return [category]
    }

    /// Itemized lines that belong to a specific category.
    public func scopedItems(for category: ReceiptCategory) -> [ReceiptItem] {
        guard !items.isEmpty else { return [] }
        return items.filter { $0.category == category }
    }

    /// Whether the receipt contributes spend to a specific category.
    /// Itemized categories take precedence when present.
    public func hasScopedCategory(_ category: ReceiptCategory) -> Bool {
        if !items.isEmpty {
            return items.contains { $0.category == category }
        }
        return self.category == category
    }

    /// Category-scoped spend for UI and analytics.
    /// Itemized categories take precedence when present.
    public func scopedAmount(for category: ReceiptCategory) -> Double {
        if !items.isEmpty {
            let total = items
                .filter { $0.category == category }
                .reduce(0.0) { partialResult, item in
                    partialResult + item.totalPrice
                }
            return isReturn ? -total : total
        }

        return self.category == category ? signedAmount : 0
    }

    /// Budget-rollup spend for a category.
    /// Materials, General Conditions, and Contingency need parent-budget totals,
    /// while detailed category filters need their exact item-level spend.
    public func budgetScopedAmount(for category: ReceiptCategory) -> Double {
        guard [.material, .general, .contingency].contains(category) else {
            return scopedAmount(for: category)
        }

        let targetRollup = category.budgetRollup

        if !items.isEmpty {
            let total = items
                .filter { $0.category.budgetRollup == targetRollup }
                .reduce(0.0) { partialResult, item in
                    partialResult + item.totalPrice
                }
            return isReturn ? -total : total
        }

        return self.category.budgetRollup == targetRollup ? signedAmount : 0
    }
    
    /// Whether this receipt has associated photos
    public var hasPhotos: Bool {
        return !photoIDs.isEmpty
    }
    
    /// Whether this receipt was processed using AI
    public var wasProcessedByAI: Bool {
        return aiAnalysis != nil
    }
}

extension Receipt {
    var persistenceSafeCopy: Receipt {
        guard receiptImageData != nil || receiptImageName != nil else {
            return self
        }

        var copy = self
        copy.receiptImageData = nil
        copy.receiptImageName = nil
        return copy
    }
}

/// AI Analysis metadata for receipts processed by ChatGPT
public struct AIAnalysisData: Codable, Hashable, Sendable {
    public let confidence: Double
    public let detectedVendor: String
    public let detectedCategory: String
    public let detectedPaymentMethod: String
    public let itemCount: Int
    public let processingDate: Date
    
    public init(
        confidence: Double,
        detectedVendor: String,
        detectedCategory: String,
        detectedPaymentMethod: String,
        itemCount: Int,
        processingDate: Date = Date()
    ) {
        self.confidence = confidence
        self.detectedVendor = detectedVendor
        self.detectedCategory = detectedCategory
        self.detectedPaymentMethod = detectedPaymentMethod
        self.itemCount = itemCount
        self.processingDate = processingDate
    }
}

// MARK: - Receipt Analysis Models (for AI processing)

/// Result of AI-powered receipt analysis
public struct ReceiptAnalysisResult {
    public let vendor: String
    public let category: String
    public let amount: Double
    public let taxAmount: Double
    public let discountAmount: Double
    public let paymentMethod: String
    public let paymentMethodDetails: PaymentMethodDetails?
    public let receiptNumber: String
    public let receiptDate: Date? // Actual receipt date from OCR
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
        paymentMethodDetails: PaymentMethodDetails? = nil,
        receiptNumber: String,
        receiptDate: Date? = nil,
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
        self.paymentMethodDetails = paymentMethodDetails
        self.receiptNumber = receiptNumber
        self.receiptDate = receiptDate
        self.items = items
        self.isReturn = isReturn
        self.confidence = confidence
    }
}

/// Payment method details extracted from receipt
public struct PaymentMethodDetails: Codable, Hashable, Sendable {
    public let cardBrand: String?
    public let lastFourDigits: String?
    public let accountInfo: String?
    
    public init(cardBrand: String?, lastFourDigits: String?, accountInfo: String?) {
        self.cardBrand = cardBrand
        self.lastFourDigits = lastFourDigits
        self.accountInfo = accountInfo
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
