import Foundation

// MARK: - Organization-Level Models

struct OrganizationContext: Codable {
    let organizationId: String
    let masterVendorDirectory: [OrganizationVendor]
    let masterPaymentMethodDirectory: [OrganizationPaymentMethod]
}

struct OrganizationVendor: Codable, Identifiable {
    let id: String
    let name: String
    let category: VendorCategory
    let organizationId: String
    var totalSpentAcrossAllProjects: Double
    var projectsUsed: [String] // Project IDs
    let dateFirstUsed: Date
    var lastUsed: Date
}

struct OrganizationPaymentMethod: Codable, Identifiable {
    let id: String
    let name: String
    let type: PaymentType
    let organizationId: String
    var totalSpentAcrossAllProjects: Double
    var projectsUsed: [String] // Project IDs
    let dateFirstUsed: Date
    var lastUsed: Date
}

// MARK: - Project-Specific Tracking Models

struct ProjectVendorUsage: Codable, Identifiable {
    let id: String
    let projectId: String
    let vendorId: String
    var totalSpent: Double
    var receiptCount: Int
    let firstUsed: Date
    var lastUsed: Date
}

struct ProjectPaymentMethodUsage: Codable, Identifiable {
    let id: String
    let projectId: String
    let paymentMethodId: String
    var totalSpent: Double
    var receiptCount: Int
    let firstUsed: Date
    var lastUsed: Date
}

// MARK: - Vendor Categories

enum VendorCategory: String, CaseIterable, Codable {
    case hardwareStore = "Hardware Store"
    case lumberyard = "Lumberyard"
    case electrical = "Electrical Supply"
    case plumbing = "Plumbing Supply"
    case hvac = "HVAC Supply"
    case concrete = "Concrete/Masonry"
    case roofing = "Roofing Supply"
    case flooring = "Flooring"
    case paint = "Paint Supply"
    case rental = "Equipment Rental"
    case specialty = "Specialty Contractor"
    case grocery = "Grocery/Food"
    case fuel = "Fuel/Gas"
    case office = "Office Supplies"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .hardwareStore: return "🔨"
        case .lumberyard: return "🪵"
        case .electrical: return "⚡"
        case .plumbing: return "🚰"
        case .hvac: return "❄️"
        case .concrete: return "🧱"
        case .roofing: return "🏠"
        case .flooring: return "📐"
        case .paint: return "🎨"
        case .rental: return "🚚"
        case .specialty: return "⚒️"
        case .grocery: return "🛒"
        case .fuel: return "⛽"
        case .office: return "📄"
        case .other: return "📦"
        }
    }
}

// MARK: - Payment Types

enum PaymentType: String, CaseIterable, Codable {
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case cash = "Cash"
    case check = "Check"
    case ach = "ACH/Bank Transfer"
    case paypal = "PayPal"
    case venmo = "Venmo"
    case applePay = "Apple Pay"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .creditCard: return "💳"
        case .debitCard: return "💳"
        case .cash: return "💵"
        case .check: return "📝"
        case .ach: return "🏦"
        case .paypal: return "🔵"
        case .venmo: return "💙"
        case .applePay: return "📱"
        case .other: return "💰"
        }
    }
}

// MARK: - Reporting Models

struct OrganizationReport: Codable {
    let organizationId: String
    let period: DateInterval
    let totalSpent: Double
    let topVendors: [OrganizationVendor]
    let paymentMethodBreakdown: [PaymentMethodSummary]
}

struct ProjectReport: Codable {
    let projectId: String
    let totalSpent: Double
    let vendorBreakdown: [ProjectVendorUsage]
    let paymentMethodBreakdown: [ProjectPaymentMethodUsage]
    let receiptCount: Int
}

struct PaymentMethodSummary: Codable {
    let paymentMethod: OrganizationPaymentMethod
    let totalSpent: Double
    let projectCount: Int
}