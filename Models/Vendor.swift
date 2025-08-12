import Foundation

/// Represents a vendor/supplier in the organization directory
public struct Vendor: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var category: VendorCategory
    public var subcategories: [String]
    public var address: String?
    public var phone: String?
    public var email: String?
    public var notes: String?
    public var organizationID: String?  // Add organization association
    public var totalSpent: Double
    public var isActive: Bool
    public var dateAdded: Date
    public var lastUsed: Date?
    public var projectsUsed: [String]?  // Array of project IDs
    public var createdBy: String?  // CloudKit user ID
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: VendorCategory,
        subcategories: [String] = [],
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        organizationID: String? = nil,
        totalSpent: Double = 0.0,
        isActive: Bool = true,
        dateAdded: Date = Date(),
        lastUsed: Date? = nil,
        projectsUsed: [String]? = nil,
        createdBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategories = subcategories.isEmpty ? category.commonSubcategories : subcategories
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
        self.organizationID = organizationID
        self.totalSpent = totalSpent
        self.isActive = isActive
        self.dateAdded = dateAdded
        self.lastUsed = lastUsed
        self.projectsUsed = projectsUsed
        self.createdBy = createdBy
    }
}

/// Categories for different types of vendors
public enum VendorCategory: String, CaseIterable, Identifiable, Codable {
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