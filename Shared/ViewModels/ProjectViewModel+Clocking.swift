// ProjectViewModel+Clocking.swift
// RheirMultiplatformApp

import Foundation
import OSLog

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
        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours.append(wh)
        applyProjectMutationLocally(
            updatedProject,
            reason: "clock in labor",
            selectProject: true,
            scheduleCloudSync: true
        )
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
        guard let project = selectedProject else { 
            groupedHoursByTeamMember = [:]
            laborTotalsByTeamMember = [:]
            Logger.labor.error("No selected project available for labor recomputation.")
            return 
        }

        let computation = laborStore.recompute(project: project, teamMembers: teamMembers)
        groupedHoursByTeamMember = computation.groupedHoursByMember
        laborTotalsByTeamMember = computation.totalsByMember.mapValues { totals in
            (unpaid: totals.unpaid, paid: totals.paid)
        }

        updateTeamMemberCaches()

        Logger.labor.notice(
            "Recomputed labor snapshot [project=\(project.id.uuidString, privacy: .private(mask: .hash)) teamMembers=\(computation.groupedHoursByMember.count, privacy: .public) totalHours=\(computation.totalHours, privacy: .public)]"
        )
    }
    
    /// 🔥 ENTERPRISE: Find team member ID by name for legacy compatibility
    private func findTeamMemberID(for employeeName: String) -> UUID? {
        return teamMembers.first { $0.name.lowercased() == employeeName.lowercased() }?.id
    }
    
    /// 🔥 ENTERPRISE: Get total hours for a specific team member
    func getTotalHours(for memberName: String) -> Double {
        laborStore.totalHours(for: memberName, groupedHoursByMember: groupedHoursByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Get total unpaid amount for a specific team member
    func getUnpaidAmount(for memberName: String) -> Double {
        laborTotalsByTeamMember[memberName]?.unpaid ?? 0.0
    }
    
    /// 🔥 ENTERPRISE: Get total paid amount for a specific team member
    func getPaidAmount(for memberName: String) -> Double {
        laborTotalsByTeamMember[memberName]?.paid ?? 0.0
    }
    
    /// 🔥 ENTERPRISE: Get total amount (paid + unpaid) for a specific team member
    func getTotalAmount(for memberName: String) -> Double {
        laborStore.totalAmount(for: memberName, totalsByMember: laborTotalsByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Get project-wide unpaid hours total
    var projectUnpaidHours: Double {
        laborStore.projectUnpaidHours(groupedHoursByMember: groupedHoursByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Get project-wide unpaid amount total
    var projectUnpaidAmount: Double {
        laborStore.projectUnpaidAmount(totalsByMember: laborTotalsByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Get project-wide total hours
    var projectTotalHours: Double {
        laborStore.projectTotalHours(groupedHoursByMember: groupedHoursByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Get project-wide total labor cost
    var projectTotalLaborCost: Double {
        laborStore.projectTotalLaborCost(totalsByMember: laborTotalsByTeamMember)
    }
    
    /// 🔥 ENTERPRISE: Validate data integrity
    func validateLaborDataIntegrity() -> [String] {
        laborStore.validate(
            project: selectedProject,
            teamMembers: teamMembers,
            calculatedUnpaidAmount: projectUnpaidAmount
        )
    }
}

struct LaborMemberTotals: Codable, Equatable {
    var unpaid: Double
    var paid: Double
}

struct LaborComputation: Equatable {
    let groupedHoursByMember: [String: [WorkHour]]
    let totalsByMember: [String: LaborMemberTotals]

    var totalHours: Double {
        groupedHoursByMember.values.flatMap { $0 }.reduce(0) { $0 + $1.hours }
    }
}

final class LaborStore {
    func recompute(project: Project, teamMembers: [TeamMember]) -> LaborComputation {
        var memberHours: [String: [WorkHour]] = [:]
        var memberTotals: [String: LaborMemberTotals] = [:]

        for workHour in project.loggedHours {
            let memberKey = resolvedMemberName(for: workHour, teamMembers: teamMembers)

            if memberHours[memberKey] == nil {
                memberHours[memberKey] = []
                memberTotals[memberKey] = LaborMemberTotals(unpaid: 0.0, paid: 0.0)
            }

            memberHours[memberKey, default: []].append(workHour)

            memberTotals[memberKey, default: LaborMemberTotals(unpaid: 0.0, paid: 0.0)].paid += workHour.effectivePaidAmount
            memberTotals[memberKey, default: LaborMemberTotals(unpaid: 0.0, paid: 0.0)].unpaid += workHour.effectiveUnpaidAmount
        }

        return LaborComputation(groupedHoursByMember: memberHours, totalsByMember: memberTotals)
    }

    func totalHours(for memberName: String, groupedHoursByMember: [String: [WorkHour]]) -> Double {
        groupedHoursByMember[memberName]?.reduce(0) { $0 + $1.hours } ?? 0.0
    }

    func totalAmount(for memberName: String, totalsByMember: [String: (unpaid: Double, paid: Double)]) -> Double {
        let totals = totalsByMember[memberName] ?? (unpaid: 0.0, paid: 0.0)
        return totals.unpaid + totals.paid
    }

    func projectUnpaidHours(groupedHoursByMember: [String: [WorkHour]]) -> Double {
        groupedHoursByMember.values
            .flatMap { $0 }
            .filter { $0.effectiveUnpaidAmount > 0 }
            .reduce(0) { $0 + $1.hours }
    }

    func projectUnpaidAmount(totalsByMember: [String: (unpaid: Double, paid: Double)]) -> Double {
        totalsByMember.values.reduce(0) { $0 + $1.unpaid }
    }

    func projectTotalHours(groupedHoursByMember: [String: [WorkHour]]) -> Double {
        groupedHoursByMember.values.flatMap { $0 }.reduce(0) { $0 + $1.hours }
    }

    func projectTotalLaborCost(totalsByMember: [String: (unpaid: Double, paid: Double)]) -> Double {
        totalsByMember.values.reduce(0) { $0 + $1.unpaid + $1.paid }
    }

    func validate(
        project: Project?,
        teamMembers: [TeamMember],
        calculatedUnpaidAmount: Double
    ) -> [String] {
        guard let project else {
            return []
        }

        var issues: [String] = []

        for workHour in project.loggedHours {
            if let employeeID = workHour.employeeID {
                if !teamMembers.contains(where: { $0.id == employeeID }) {
                    issues.append("Work hour has invalid team member ID: \(employeeID)")
                }
            } else if !teamMembers.contains(where: { $0.name.lowercased() == workHour.employee.lowercased() }) {
                issues.append("Work hour has no matching team member: \(workHour.employee)")
            }
        }

        let directTotal = project.loggedHours.reduce(0) { $0 + $1.effectiveUnpaidAmount }
        if abs(calculatedUnpaidAmount - directTotal) > 0.01 {
            issues.append("Calculation mismatch: Cached total $\(calculatedUnpaidAmount) vs Direct total $\(directTotal)")
        }

        return issues
    }

    private func resolvedMemberName(for workHour: WorkHour, teamMembers: [TeamMember]) -> String {
        if let employeeID = workHour.employeeID,
           let teamMember = teamMembers.first(where: { $0.id == employeeID }) {
            return teamMember.name
        }

        return workHour.employee
    }
}
