import Foundation
import SwiftUI

// MARK: - Budget Categories (Roll-up Only)

/// High-level budget categories for project budget allocation and tracking.
/// These are NOT selectable during receipt entry - only used for budget calculations.
public enum BudgetCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case materials = "Materials"
    case generalConditions = "General Conditions"
    case labor = "Labor"
    case contingency = "Contingency"
    
    public var id: Self { self }
    
    public var icon: String {
        switch self {
        case .materials: return "cube.box.fill"
        case .generalConditions: return "building.2.fill"
        case .labor: return "person.2.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .materials: return .green
        case .generalConditions: return .blue
        case .labor: return .orange
        case .contingency: return .red
        }
    }
    
    public var description: String {
        switch self {
        case .materials:
            return "All physical materials, supplies, and equipment purchases"
        case .generalConditions:
            return "Project management, supervision, and administrative costs"
        case .labor:
            return "All labor costs including wages, benefits, and contractor fees"
        case .contingency:
            return "Unexpected costs and budget overruns"
        }
    }
}

// MARK: - Detailed Receipt Categories (For Receipt Entry)

/// Granular categories for receipt entry. Users MUST select from these when entering receipts.
/// These automatically map to BudgetCategory for budget calculations.
public enum DetailedReceiptCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    // Materials subcategories
    case demolition = "Demolition"
    case sitework = "Site Work"
    case foundation = "Foundation"
    case framing = "Framing"
    case roofing = "Roofing"
    case exterior = "Exterior"
    case electrical = "Electrical"
    case plumbing = "Plumbing"
    case hvac = "HVAC"
    case insulation = "Insulation"
    case drywall = "Drywall"
    case flooring = "Flooring"
    case trim = "Trim & Millwork"
    case paint = "Paint & Finishes"
    case kitchen = "Kitchen"
    case bathroom = "Bathroom"
    case fixtures = "Fixtures & Hardware"
    case appliances = "Appliances"
    case landscaping = "Landscaping"
    case lighting = "Lighting"
    case cabinetry = "Cabinetry"
    case countertops = "Countertops"
    case tile = "Tile & Stone"
    case windows = "Windows & Doors"
    case specialty = "Specialty Items"
    
    // General Conditions subcategories
    case permits = "Permits & Inspections"
    case cleanup = "Cleanup"
    case projectManagement = "Project Management"
    case supervision = "Supervision"
    case utilities = "Utilities"
    case insurance = "Insurance"
    case equipment = "Equipment Rental"
    case transportation = "Transportation"
    case administrative = "Administrative"
    
    // Contingency subcategories
    case unforeseen = "Unforeseen Costs"
    case changeOrders = "Change Orders"
    case emergencyRepairs = "Emergency Repairs"
    case overruns = "Budget Overruns"
    
    public var id: Self { self }
    
    /// Maps this detailed category to its parent budget category
    public var budgetCategory: BudgetCategory {
        switch self {
        // Materials
        case .demolition, .sitework, .foundation, .framing, .roofing, .exterior,
             .electrical, .plumbing, .hvac, .insulation, .drywall, .flooring,
             .trim, .paint, .kitchen, .bathroom, .fixtures, .appliances,
             .landscaping, .lighting, .cabinetry, .countertops, .tile,
             .windows, .specialty:
            return .materials
            
        // General Conditions
        case .permits, .cleanup, .projectManagement, .supervision, .utilities,
             .insurance, .equipment, .transportation, .administrative:
            return .generalConditions
            
        // Contingency
        case .unforeseen, .changeOrders, .emergencyRepairs, .overruns:
            return .contingency
        }
    }
    
    /// Category group for UI organization
    public var categoryGroup: DetailedCategoryGroup {
        switch self {
        case .demolition, .sitework, .foundation, .framing, .roofing, .exterior:
            return .structural
        case .electrical, .plumbing, .hvac:
            return .mechanical
        case .insulation, .drywall, .flooring, .trim, .paint:
            return .finishes
        case .kitchen, .bathroom, .appliances:
            return .specialRooms
        case .fixtures, .lighting, .cabinetry, .countertops, .tile, .windows:
            return .design
        case .landscaping, .specialty:
            return .exterior
        case .permits, .cleanup, .projectManagement, .supervision, .utilities,
             .insurance, .equipment, .transportation, .administrative:
            return .management
        case .unforeseen, .changeOrders, .emergencyRepairs, .overruns:
            return .contingency
        }
    }
    
    /// Icon for visual representation
    public var icon: String {
        switch self {
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
        case .projectManagement: return "person.badge.key.fill"
        case .supervision: return "person.2.badge.gearshape.fill"
        case .utilities: return "power.plug.fill"
        case .insurance: return "shield.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .transportation: return "truck.box.fill"
        case .administrative: return "folder.fill"
        case .unforeseen: return "questionmark.circle.fill"
        case .changeOrders: return "arrow.triangle.swap"
        case .emergencyRepairs: return "exclamationmark.triangle.fill"
        case .overruns: return "chart.line.uptrend.xyaxis"
        }
    }
    
    /// Color for visual representation
    public var color: Color {
        return budgetCategory.color
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
    
    /// Typical order in renovation sequence (1-25, 0 for non-sequenced)
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
        case .cabinetry: return 20
        case .countertops: return 21
        case .tile: return 22
        case .windows: return 23
        case .landscaping: return 24
        case .cleanup: return 25
        default: return 0 // Non-sequenced categories
        }
    }
}

// MARK: - Category Groups for UI Organization

/// Groups of detailed categories for better UI organization
public enum DetailedCategoryGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case structural = "Structural Work"
    case mechanical = "Mechanical Systems"
    case finishes = "Interior Finishes"
    case specialRooms = "Special Rooms"
    case design = "Design Elements"
    case exterior = "Exterior & Landscaping"
    case management = "Project Management"
    case contingency = "Contingency"
    
    public var id: Self { self }
    
    public var icon: String {
        switch self {
        case .structural: return "building.2.fill"
        case .mechanical: return "gearshape.2.fill"
        case .finishes: return "paintbrush.fill"
        case .specialRooms: return "house.rooms.fill"
        case .design: return "sparkles"
        case .exterior: return "leaf.fill"
        case .management: return "person.badge.key.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .structural: return .orange
        case .mechanical: return .yellow
        case .finishes: return .green
        case .specialRooms: return .purple
        case .design: return .pink
        case .exterior: return .mint
        case .management: return .blue
        case .contingency: return .red
        }
    }
    
    /// Categories that belong to this group
    public var categories: [DetailedReceiptCategory] {
        return DetailedReceiptCategory.allCases.filter { $0.categoryGroup == self }
    }
}

// MARK: - Category Mapping Extensions

public extension BudgetCategory {
    /// Get all detailed categories that roll up to this budget category
    var detailedCategories: [DetailedReceiptCategory] {
        return DetailedReceiptCategory.allCases.filter { $0.budgetCategory == self }
    }
    
    /// Calculate spending for this budget category from detailed receipt items
    func calculateSpending(from receipts: [Receipt]) -> Double {
        let relevantCategories = Set(detailedCategories)
        
        return receipts.reduce(0.0) { totalSpent, receipt in
            let receiptTotal = receipt.items.reduce(0.0) { itemTotal, item in
                // Check if this item's category maps to our budget category
                if relevantCategories.contains(item.detailedCategory) {
                    let amount = receipt.isReturn ? -item.totalPrice : item.totalPrice
                    return itemTotal + amount
                } else {
                    return itemTotal
                }
            }
            
            // If receipt has no items, fall back to receipt-level category (for backward compatibility)
            if receipt.items.isEmpty {
                // Convert legacy ReceiptCategory to DetailedReceiptCategory
                if let legacyCategory = receipt.category.toDetailedCategory(),
                   relevantCategories.contains(legacyCategory) {
                    let amount = receipt.isReturn ? -receipt.amount : receipt.amount
                    return totalSpent + amount
                }
            }
            
            return totalSpent + receiptTotal
        }
    }
}

// MARK: - Backward Compatibility Extensions

public extension ReceiptCategory {
    /// Convert legacy ReceiptCategory to new DetailedReceiptCategory
    func toDetailedCategory() -> DetailedReceiptCategory? {
        switch self {
        // Direct mappings where names match
        case .demolition: return .demolition
        case .sitework: return .sitework
        case .foundation: return .foundation
        case .framing: return .framing
        case .roofing: return .roofing
        case .exterior: return .exterior
        case .electrical: return .electrical
        case .plumbing: return .plumbing
        case .hvac: return .hvac
        case .insulation: return .insulation
        case .drywall: return .drywall
        case .flooring: return .flooring
        case .trim: return .trim
        case .paint: return .paint
        case .kitchen: return .kitchen
        case .bathroom: return .bathroom
        case .fixtures: return .fixtures
        case .appliances: return .appliances
        case .landscaping: return .landscaping
        case .permits: return .permits
        case .cleanup: return .cleanup
        case .lighting: return .lighting
        case .cabinetry: return .cabinetry
        case .countertops: return .countertops
        case .tile: return .tile
        case .windows: return .windows
        case .specialty: return .specialty
        
        // Legacy categories that need special handling
        case .material:
            // Default material category maps to framing (most common)
            return .framing
        case .general:
            // Default general conditions maps to project management
            return .projectManagement
        case .contingency:
            // Default contingency maps to unforeseen costs
            return .unforeseen
        }
    }
    
    /// Get all DetailedReceiptCategories that would map to this budget category
    var detailedCategoryMappings: [DetailedReceiptCategory] {
        switch self {
        case .material:
            return DetailedReceiptCategory.allCases.filter { $0.budgetCategory == .materials }
        case .general:
            return DetailedReceiptCategory.allCases.filter { $0.budgetCategory == .generalConditions }
        case .contingency:
            return DetailedReceiptCategory.allCases.filter { $0.budgetCategory == .contingency }
        default:
            // For specific categories, return the direct mapping
            if let detailedCategory = self.toDetailedCategory() {
                return [detailedCategory]
            } else {
                return []
            }
        }
    }
}

public extension DetailedReceiptCategory {
    /// Convert DetailedReceiptCategory back to legacy ReceiptCategory (for storage compatibility)
    func toLegacyCategory() -> ReceiptCategory {
        switch self {
        // Direct mappings
        case .demolition: return .demolition
        case .sitework: return .sitework
        case .foundation: return .foundation
        case .framing: return .framing
        case .roofing: return .roofing
        case .exterior: return .exterior
        case .electrical: return .electrical
        case .plumbing: return .plumbing
        case .hvac: return .hvac
        case .insulation: return .insulation
        case .drywall: return .drywall
        case .flooring: return .flooring
        case .trim: return .trim
        case .paint: return .paint
        case .kitchen: return .kitchen
        case .bathroom: return .bathroom
        case .fixtures: return .fixtures
        case .appliances: return .appliances
        case .landscaping: return .landscaping
        case .permits: return .permits
        case .cleanup: return .cleanup
        case .lighting: return .lighting
        case .cabinetry: return .cabinetry
        case .countertops: return .countertops
        case .tile: return .tile
        case .windows: return .windows
        case .specialty: return .specialty
        
        // New categories that don't have direct legacy equivalents
        case .projectManagement, .supervision, .utilities, .insurance,
             .equipment, .transportation, .administrative:
            return .general
        case .unforeseen, .changeOrders, .emergencyRepairs, .overruns:
            return .contingency
        }
    }
}

// MARK: - Receipt Enhancement Extensions

public extension Receipt {
    /// The primary detailed category for this receipt (derived from items or fallback to legacy)
    var primaryDetailedCategory: DetailedReceiptCategory {
        // If we have items, use the most common category from items
        if !items.isEmpty {
            let categoryCount = Dictionary(grouping: items, by: { $0.category.toDetailedCategory() ?? .specialty })
                .mapValues { $0.count }
            let mostCommon = categoryCount.max { $0.value < $1.value }
            return mostCommon?.key ?? .specialty
        } else {
            // Fallback to converting legacy category
            return category.toDetailedCategory() ?? .specialty
        }
    }
    
    /// Calculate total spending by detailed category for this receipt
    var spendingByDetailedCategory: [DetailedReceiptCategory: Double] {
        var categorySpending: [DetailedReceiptCategory: Double] = [:]
        
        if !items.isEmpty {
            // Use item-level categorization
            for item in items {
                let amount = isReturn ? -item.totalPrice : item.totalPrice
                let detailedCategory = item.category.toDetailedCategory() ?? .specialty
                categorySpending[detailedCategory, default: 0] += amount
            }
        } else {
            // Fallback to receipt-level category for legacy receipts
            if let detailedCategory = category.toDetailedCategory() {
                let amount = isReturn ? -self.amount : self.amount
                categorySpending[detailedCategory] = amount
            }
        }
        
        return categorySpending
    }
    
    /// Calculate total spending by budget category for this receipt
    var spendingByBudgetCategory: [BudgetCategory: Double] {
        let detailedSpending = spendingByDetailedCategory
        var budgetSpending: [BudgetCategory: Double] = [:]
        
        for (detailedCategory, amount) in detailedSpending {
            let budgetCategory = detailedCategory.budgetCategory
            budgetSpending[budgetCategory, default: 0] += amount
        }
        
        return budgetSpending
    }
}

// MARK: - ReceiptItem Enhancement Extensions

public extension ReceiptItem {
    /// The detailed category for this receipt item (new categorization system)
    var detailedCategory: DetailedReceiptCategory {
        get {
            return category.toDetailedCategory() ?? .specialty
        }
        set {
            category = newValue.toLegacyCategory()
        }
    }
    
    /// The budget category this item contributes to
    var budgetCategory: BudgetCategory {
        return detailedCategory.budgetCategory
    }
}