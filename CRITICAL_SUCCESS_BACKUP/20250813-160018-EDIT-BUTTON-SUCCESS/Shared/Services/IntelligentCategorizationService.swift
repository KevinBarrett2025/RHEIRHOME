import Foundation
import SwiftUI

/// Service for intelligently categorizing receipts into renovation phases and design elements
@MainActor
public class IntelligentCategorizationService: ObservableObject {
    
    // MARK: - Vendor-Based Categorization
    
    /// Predict receipt category based on vendor name and receipt content
    public func predictCategory(vendorName: String, receiptAmount: Double, items: [ReceiptItem] = []) -> ReceiptCategory {
        let vendor = vendorName.lowercased()
        
        // First check if we have specific items to analyze
        if !items.isEmpty {
            if let categoryFromItems = predictCategoryFromItems(items) {
                return categoryFromItems
            }
        }
        
        // Use vendor name intelligence
        return predictCategoryFromVendor(vendor, amount: receiptAmount)
    }
    
    private func predictCategoryFromVendor(_ vendor: String, amount: Double) -> ReceiptCategory {
        // Electrical suppliers
        if vendor.contains("electric") || vendor.contains("grainger") || 
           vendor.contains("graybar") || vendor.contains("rexel") {
            return .electrical
        }
        
        // Plumbing suppliers
        if vendor.contains("plumb") || vendor.contains("ferguson") || 
           vendor.contains("supply house") || vendor.contains("pipe") {
            return .plumbing
        }
        
        // Paint stores
        if vendor.contains("sherwin") || vendor.contains("benjamin moore") || 
           vendor.contains("paint") || vendor.contains("behr") {
            return .paint
        }
        
        // Lumber yards
        if vendor.contains("lumber") || vendor.contains("84 lumber") || 
           vendor.contains("harvey") || vendor.contains("weyerhaeuser") {
            return .framing
        }
        
        // Roofing suppliers
        if vendor.contains("roof") || vendor.contains("abc supply") || 
           vendor.contains("beacon") || vendor.contains("gaf") {
            return .roofing
        }
        
        // Flooring specialists
        if vendor.contains("floor") || vendor.contains("carpet") || 
           vendor.contains("tile") || vendor.contains("hardwood") {
            return .flooring
        }
        
        // Kitchen/Bath specialists
        if vendor.contains("kitchen") || vendor.contains("bath") || 
           vendor.contains("cabinet") || vendor.contains("granite") {
            // Use amount to distinguish
            if amount > 5000 {
                return vendor.contains("kitchen") ? .kitchen : .bathroom
            } else if vendor.contains("granite") || vendor.contains("quartz") {
                return .countertops
            } else {
                return .cabinetry
            }
        }
        
        // HVAC suppliers
        if vendor.contains("hvac") || vendor.contains("heating") || 
           vendor.contains("cooling") || vendor.contains("lennox") || 
           vendor.contains("carrier") || vendor.contains("trane") {
            return .hvac
        }
        
        // Hardware stores (context-sensitive)
        if vendor.contains("home depot") || vendor.contains("lowe") || 
           vendor.contains("menards") || vendor.contains("ace hardware") {
            // Use amount and context to predict
            if amount > 1000 {
                return .material // Large purchases likely materials
            } else if amount < 50 {
                return .fixtures // Small purchases likely hardware/fixtures
            } else {
                return .material // Medium purchases default to materials
            }
        }
        
        // Appliance stores
        if vendor.contains("appliance") || vendor.contains("best buy") || 
           vendor.contains("sears") || vendor.contains("whirlpool") {
            return .appliances
        }
        
        // Lighting specialists
        if vendor.contains("light") || vendor.contains("electric supply") || 
           vendor.contains("lamp") || vendor.contains("chandelier") {
            return .lighting
        }
        
        // Landscaping
        if vendor.contains("nursery") || vendor.contains("landscape") || 
           vendor.contains("garden") || vendor.contains("mulch") {
            return .landscaping
        }
        
        // Government/Permits
        if vendor.contains("city of") || vendor.contains("county") || 
           vendor.contains("permit") || vendor.contains("inspection") {
            return .permits
        }
        
        // Waste management
        if vendor.contains("waste") || vendor.contains("dumpster") || 
           vendor.contains("disposal") || vendor.contains("trash") {
            return .cleanup
        }
        
        // Default fallback
        return .material
    }
    
    private func predictCategoryFromItems(_ items: [ReceiptItem]) -> ReceiptCategory? {
        // Analyze item names for category hints
        let itemNames = items.map { $0.name.lowercased() }.joined(separator: " ")
        
        // Electrical items
        if itemNames.contains("wire") || itemNames.contains("outlet") || 
           itemNames.contains("switch") || itemNames.contains("breaker") {
            return .electrical
        }
        
        // Plumbing items
        if itemNames.contains("pipe") || itemNames.contains("fitting") || 
           itemNames.contains("valve") || itemNames.contains("faucet") {
            return .plumbing
        }
        
        // Paint items
        if itemNames.contains("paint") || itemNames.contains("primer") || 
           itemNames.contains("brush") || itemNames.contains("roller") {
            return .paint
        }
        
        // Lumber items
        if itemNames.contains("lumber") || itemNames.contains("board") || 
           itemNames.contains("stud") || itemNames.contains("plywood") {
            return .framing
        }
        
        // Flooring items
        if itemNames.contains("vinyl") || itemNames.contains("laminate") || 
           itemNames.contains("hardwood") || itemNames.contains("carpet") {
            return .flooring
        }
        
        // Tile items
        if itemNames.contains("tile") || itemNames.contains("grout") || 
           itemNames.contains("mortar") || itemNames.contains("backsplash") {
            return .tile
        }
        
        return nil
    }
    
    // MARK: - Category Intelligence
    
    /// Get smart suggestions for similar purchases
    public func getCategoryRecommendations(for category: ReceiptCategory) -> [String] {
        switch category {
        case .electrical:
            return ["Wire", "Outlets", "Switches", "Breakers", "Conduit", "Junction boxes"]
        case .plumbing:
            return ["PVC pipe", "Copper fittings", "Valves", "Faucets", "Toilet", "Shower"]
        case .paint:
            return ["Interior paint", "Exterior paint", "Primer", "Brushes", "Drop cloths"]
        case .framing:
            return ["2x4 studs", "Plywood", "OSB", "Screws", "Nails", "Brackets"]
        case .kitchen:
            return ["Cabinets", "Countertops", "Appliances", "Backsplash", "Sink", "Faucet"]
        case .bathroom:
            return ["Vanity", "Toilet", "Shower", "Tile", "Mirror", "Lighting"]
        case .flooring:
            return ["Hardwood", "Laminate", "Vinyl", "Carpet", "Underlayment", "Trim"]
        case .roofing:
            return ["Shingles", "Underlayment", "Flashing", "Gutters", "Ridge cap"]
        case .hvac:
            return ["Furnace", "AC unit", "Ductwork", "Vents", "Thermostat", "Filters"]
        case .fixtures:
            return ["Light fixtures", "Cabinet hardware", "Door handles", "Hinges"]
        case .appliances:
            return ["Refrigerator", "Stove", "Dishwasher", "Washer", "Dryer", "Microwave"]
        case .landscaping:
            return ["Plants", "Mulch", "Fertilizer", "Seeds", "Garden tools", "Irrigation"]
        default:
            return []
        }
    }
    
    /// Predict renovation phase completion percentage based on spending
    public func estimatePhaseCompletion(_ category: ReceiptCategory, spent: Double, budgeted: Double) -> Double {
        guard budgeted > 0 else { return 0 }
        
        let basicProgress = min(spent / budgeted, 1.0)
        
        // Adjust based on category type
        switch category {
        case .permits:
            // Permits are usually all-or-nothing
            return spent > 0 ? 1.0 : 0.0
        case .demolition, .cleanup:
            // These tend to be front-loaded
            return min(basicProgress * 1.2, 1.0)
        case .paint, .trim:
            // These tend to be back-loaded (materials bought at end)
            return min(basicProgress * 0.8, 1.0)
        default:
            return basicProgress
        }
    }
    
    /// Get next recommended renovation phases based on current progress
    public func getNextRecommendedPhases(completedCategories: Set<ReceiptCategory>) -> [ReceiptCategory] {
        let allPhases = ReceiptCategory.allCases.filter { $0.hasPhaseScheduling }
        let sortedPhases = allPhases.sorted { $0.renovationSequence < $1.renovationSequence }
        
        var recommendations: [ReceiptCategory] = []
        
        for phase in sortedPhases {
            if !completedCategories.contains(phase) {
                // Check if prerequisites are met
                let prerequisites = getPrerequisites(for: phase)
                let prerequisitesMet = prerequisites.allSatisfy { completedCategories.contains($0) }
                
                if prerequisitesMet {
                    recommendations.append(phase)
                    if recommendations.count >= 5 { break } // Limit to 5 recommendations
                }
            }
        }
        
        return recommendations
    }
    
    private func getPrerequisites(for category: ReceiptCategory) -> [ReceiptCategory] {
        switch category {
        case .foundation:
            return [.permits, .demolition, .sitework]
        case .framing:
            return [.foundation]
        case .roofing:
            return [.framing]
        case .electrical, .plumbing, .hvac:
            return [.framing]
        case .insulation:
            return [.electrical, .plumbing, .hvac]
        case .drywall:
            return [.insulation]
        case .paint:
            return [.drywall]
        case .flooring:
            return [.drywall]
        case .trim:
            return [.paint, .flooring]
        case .fixtures:
            return [.paint]
        case .appliances:
            return [.electrical, .plumbing]
        case .cleanup:
            return [.paint, .trim, .fixtures]
        default:
            return []
        }
    }
    
    // MARK: - Budget Intelligence
    
    /// Predict typical budget allocation for a category based on total project budget
    public func predictBudgetAllocation(for category: ReceiptCategory, totalBudget: Double) -> Double {
        let percentage: Double
        
        switch category {
        case .framing:
            percentage = 0.15 // 15% of budget
        case .electrical:
            percentage = 0.08 // 8% of budget
        case .plumbing:
            percentage = 0.07 // 7% of budget
        case .kitchen:
            percentage = 0.20 // 20% of budget
        case .bathroom:
            percentage = 0.12 // 12% of budget
        case .flooring:
            percentage = 0.10 // 10% of budget
        case .paint:
            percentage = 0.05 // 5% of budget
        case .roofing:
            percentage = 0.12 // 12% of budget
        case .hvac:
            percentage = 0.08 // 8% of budget
        case .appliances:
            percentage = 0.08 // 8% of budget
        case .fixtures:
            percentage = 0.04 // 4% of budget
        case .permits:
            percentage = 0.02 // 2% of budget
        default:
            percentage = 0.03 // 3% default
        }
        
        return totalBudget * percentage
    }
}

// MARK: - Intelligence Insight Models

public struct IntelligenceInsight: Identifiable {
    public let id: String
    public let type: InsightType
    public let title: String
    public let description: String
    public let actionTitle: String
    public let category: ReceiptCategory?
    
    public enum InsightType {
        case warning, info, suggestion
        
        public var color: Color {
            switch self {
            case .warning: return .red
            case .info: return .blue
            case .suggestion: return .green
            }
        }
        
        public var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .suggestion: return "lightbulb.fill"
            }
        }
    }
    
    public init(id: String, type: InsightType, title: String, description: String, actionTitle: String, category: ReceiptCategory? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.category = category
    }
}