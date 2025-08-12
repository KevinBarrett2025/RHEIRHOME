// ProjectViewModel+Clocking.swift
// RheirMultiplatformApp

import Foundation

@MainActor
extension ProjectViewModel {
    /// Clock an employee in now.
    func clockIn(employee: String, rate: Double) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let wh = WorkHour(
            id: UUID(),
            date: Date(),
            startTime: Date(),
            endTime: nil,
            lunchStart: nil,
            lunchEnd: nil,
            employee: employee,
            employeeID: findTeamMemberID(for: employee), // FIXED: Link to team member ID
            rate: rate,
            category: "Labor",
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )
        organizationProjects[idx].loggedHours.append(wh)
        selectedProject = organizationProjects[idx]
        
        // CRITICAL: Recompute ALL data immediately
        recomputeLaborData()
        
        // Save to CloudKit
        Task {
            await saveAllProjectsToCloudKit()
        }
    }

    /// Clock an employee out now.
    func clockOut(_ wh: WorkHour) {
        var updated = wh
        updated.endTime = Date()
        updateHours(updated)   // `updateHours(_:)` calls recomputeLaborData()
    }

    /// Start lunch break now.
    func startLunch(_ wh: WorkHour) {
        var updated = wh
        updated.lunchStart = Date()
        updateHours(updated)
    }

    /// End lunch break now.
    func endLunch(_ wh: WorkHour) {
        var updated = wh
        updated.lunchEnd = Date()
        updateHours(updated)
    }
    
    /// 🔥 ENTERPRISE-GRADE: UNIFIED LABOR DATA COMPUTATION SYSTEM
    /// This is the SINGLE SOURCE OF TRUTH for ALL labor calculations
    func recomputeLaborData() {
        print("🔥 ENTERPRISE RECOMPUTE: Starting unified labor data calculation...")
        
        guard let project = selectedProject else { 
            print("❌ No selected project for labor calculation")
            return 
        }
        
        // Clear existing computed data
        groupedHoursByTeamMember.removeAll()
        laborTotalsByTeamMember.removeAll()
        
        // STEP 1: Group all work hours by team member (using both ID and name for compatibility)
        var memberHours: [String: [WorkHour]] = [:]
        var memberTotals: [String: (unpaid: Double, paid: Double)] = [:]
        
        print("📊 Processing \(project.loggedHours.count) work hours...")
        
        for workHour in project.loggedHours {
            let memberKey: String
            
            // ENHANCED: Use team member ID first, fallback to name for legacy support
            if let employeeID = workHour.employeeID,
               let teamMember = getTeamMember(by: employeeID) {
                memberKey = teamMember.name
                print("  ✅ Found team member by ID: \(teamMember.name)")
            } else {
                memberKey = workHour.employee
                print("  ⚠️ Using legacy name matching: \(workHour.employee)")
            }
            
            // Group hours by member
            if memberHours[memberKey] == nil {
                memberHours[memberKey] = []
                memberTotals[memberKey] = (unpaid: 0.0, paid: 0.0)
            }
            
            memberHours[memberKey]?.append(workHour)
            
            // Calculate totals
            let hourValue = workHour.hours * workHour.rate
            if workHour.isPaid {
                memberTotals[memberKey]?.paid += hourValue
            } else {
                memberTotals[memberKey]?.unpaid += hourValue
            }
            
            print("    Hour: \(workHour.hours)h @ $\(workHour.rate) = $\(hourValue) (\(workHour.isPaid ? "PAID" : "UNPAID"))")
        }
        
        // STEP 2: Update global state with calculated data
        groupedHoursByTeamMember = memberHours
        laborTotalsByTeamMember = memberTotals
        
        // STEP 3: Rebuild team member cache to ensure consistency
        updateTeamMemberCaches()
        
        // STEP 4: Log the computed results for verification
        print("🎯 ENTERPRISE CALCULATION RESULTS:")
        for (memberName, hours) in memberHours {
            let totalHours = hours.reduce(0) { $0 + $1.hours }
            let totals = memberTotals[memberName] ?? (unpaid: 0.0, paid: 0.0)
            
            print("  👤 \(memberName):")
            print("    Total Hours: \(totalHours)")
            print("    Unpaid: $\(totals.unpaid)")
            print("    Paid: $\(totals.paid)")
            print("    Total Value: $\(totals.unpaid + totals.paid)")
        }
        
        // STEP 5: Calculate project-wide totals
        let projectUnpaidTotal = memberTotals.values.reduce(0) { $0 + $1.unpaid }
        let projectPaidTotal = memberTotals.values.reduce(0) { $0 + $1.paid }
        let projectTotalHours = memberHours.values.flatMap { $0 }.reduce(0) { $0 + $1.hours }
        
        print("📈 PROJECT TOTALS:")
        print("  Total Hours: \(projectTotalHours)")
        print("  Unpaid Amount: $\(projectUnpaidTotal)")
        print("  Paid Amount: $\(projectPaidTotal)")
        print("  Total Labor Value: $\(projectUnpaidTotal + projectPaidTotal)")
        
        // STEP 6: Force UI update by notifying observers
        objectWillChange.send()
        
        print("✅ ENTERPRISE RECOMPUTE: Labor data calculation completed successfully")
    }
    
    /// 🔥 ENTERPRISE: Find team member ID by name for legacy compatibility
    private func findTeamMemberID(for employeeName: String) -> UUID? {
        return teamMembers.first { $0.name.lowercased() == employeeName.lowercased() }?.id
    }
    
    /// 🔥 ENTERPRISE: Get total hours for a specific team member
    func getTotalHours(for memberName: String) -> Double {
        return groupedHoursByTeamMember[memberName]?.reduce(0) { $0 + $1.hours } ?? 0.0
    }
    
    /// 🔥 ENTERPRISE: Get total unpaid amount for a specific team member
    func getUnpaidAmount(for memberName: String) -> Double {
        return laborTotalsByTeamMember[memberName]?.unpaid ?? 0.0
    }
    
    /// 🔥 ENTERPRISE: Get total paid amount for a specific team member
    func getPaidAmount(for memberName: String) -> Double {
        return laborTotalsByTeamMember[memberName]?.paid ?? 0.0
    }
    
    /// 🔥 ENTERPRISE: Get total amount (paid + unpaid) for a specific team member
    func getTotalAmount(for memberName: String) -> Double {
        let totals = laborTotalsByTeamMember[memberName] ?? (unpaid: 0.0, paid: 0.0)
        return totals.unpaid + totals.paid
    }
    
    /// 🔥 ENTERPRISE: Get project-wide unpaid hours total
    var projectUnpaidHours: Double {
        return groupedHoursByTeamMember.values.flatMap { $0 }.filter { !$0.isPaid }.reduce(0) { $0 + $1.hours }
    }
    
    /// 🔥 ENTERPRISE: Get project-wide unpaid amount total
    var projectUnpaidAmount: Double {
        return laborTotalsByTeamMember.values.reduce(0) { $0 + $1.unpaid }
    }
    
    /// 🔥 ENTERPRISE: Get project-wide total hours
    var projectTotalHours: Double {
        return groupedHoursByTeamMember.values.flatMap { $0 }.reduce(0) { $0 + $1.hours }
    }
    
    /// 🔥 ENTERPRISE: Get project-wide total labor cost
    var projectTotalLaborCost: Double {
        return laborTotalsByTeamMember.values.reduce(0) { $0 + $1.unpaid + $1.paid }
    }
    
    /// 🔥 ENTERPRISE: Validate data integrity
    func validateLaborDataIntegrity() -> [String] {
        var issues: [String] = []
        
        // Check for orphaned work hours (no matching team member)
        for workHour in selectedProject?.loggedHours ?? [] {
            if let employeeID = workHour.employeeID {
                if getTeamMember(by: employeeID) == nil {
                    issues.append("Work hour has invalid team member ID: \(employeeID)")
                }
            } else {
                if !teamMembers.contains(where: { $0.name.lowercased() == workHour.employee.lowercased() }) {
                    issues.append("Work hour has no matching team member: \(workHour.employee)")
                }
            }
        }
        
        // Check for calculation mismatches
        let calculatedTotal = projectUnpaidAmount
        let directTotal = selectedProject?.loggedHours.filter { !$0.isPaid }.reduce(0) { $0 + ($1.hours * $1.rate) } ?? 0
        
        if abs(calculatedTotal - directTotal) > 0.01 {
            issues.append("Calculation mismatch: Cached total $\(calculatedTotal) vs Direct total $\(directTotal)")
        }
        
        return issues
    }
}