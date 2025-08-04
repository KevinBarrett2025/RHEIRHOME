// ProjectViewModel+Filters.swift
// RheirMultiplatformApp

import Foundation

@MainActor
extension ProjectViewModel {
    private var currentReceipts: [Receipt] {
        selectedProject?.receipts ?? []
    }

    /// Net spent (sales minus returns) on General Conditions receipts
    private var receiptGeneralConditions: Double {
        let result = currentReceipts
            .filter { $0.category == .general }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ receiptGeneralConditions resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Net spent (sales minus returns) on Materials receipts
    private var receiptMaterials: Double {
        let result = currentReceipts
            .filter { $0.category == .material }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ receiptMaterials resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Net spent (sales minus returns) on Contingency receipts
    private var receiptContingency: Double {
        let result = currentReceipts
            .filter { $0.category == .contingency }
            .reduce(0) { acc, r in
                let amount = r.isReturn ? -r.amount : r.amount
                // Ensure each amount is valid
                guard amount.isFinite else { return acc }
                return acc + amount
            }
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ receiptContingency resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Total net receipts spending across all categories
    var totalReceiptsNet: Double {
        let result = receiptGeneralConditions + receiptMaterials + receiptContingency
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ totalReceiptsNet resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the “Labor” category
    private var hoursLabor: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "Labor" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ hoursLabor resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the “General Conditions” category
    private var hoursGeneralConditions: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "General Conditions" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ hoursGeneralConditions resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Total labor cost from logged hours in the “Contingency” category
    private var hoursContingency: Double {
        let result = selectedProject?.loggedHours
            .filter { $0.category == "Contingency" }
            .reduce(0) { acc, hour in
                let cost = hour.hours * hour.rate
                // Ensure each calculation is valid
                guard cost.isFinite else { return acc }
                return acc + cost
            } ?? 0
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ hoursContingency resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    // MARK: — Public spent properties (receipts + hours)

    /// Net spent on General Conditions (receipts + hours)
    var spentGeneralConditions: Double {
        let result = receiptGeneralConditions + hoursGeneralConditions
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ spentGeneralConditions resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Net spent on Materials (receipts only)
    var spentMaterials: Double {
        let result = receiptMaterials
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ spentMaterials resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Net spent on Labor (hours only)
    var spentLabor: Double {
        let result = hoursLabor
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ spentLabor resulted in invalid value: \(result)")
            return 0
        }
        return result
    }

    /// Net spent on Contingency (receipts + hours)
    var spentContingency: Double {
        let result = receiptContingency + hoursContingency
        
        // Ensure final result is valid
        guard result.isFinite else {
            print("⚠️ spentContingency resulted in invalid value: \(result)")
            return 0
        }
        return result
    }
    
    // MARK: - Team and Labor Calculations
    
    /// Calculate total labor cost for the current selected project based on team member rates
    func calculateTotalLaborCost() -> Double {
        guard let project = selectedProject else { return 0.0 }
        
        // Start with actual labor costs from logged hours
        let actualLaborCost = spentLabor
        
        // Add estimates for assigned team members if minimal hours logged
        let assignedMemberIDs = Set(project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) })
        let assignedMembers = teamMembers.filter { assignedMemberIDs.contains($0.id) }
        
        let estimatedCost = assignedMembers.reduce(0.0) { total, member in
            let rate = member.defaultRate?.rate ?? 25.0
            let estimatedHours = project.loggedHours.isEmpty ? 40.0 : 0.0 // Only estimate if no hours logged
            return total + (rate * estimatedHours)
        }
        
        return max(actualLaborCost, estimatedCost)
    }
    
    /// Calculate total hours logged for the current selected project
    func calculateTotalHours() -> Int {
        guard let project = selectedProject else { return 0 }
        
        let totalHours = project.loggedHours.reduce(0.0) { total, hour in
            guard hour.hours.isFinite else { return total }
            return total + hour.hours
        }
        
        return Int(totalHours)
    }
}