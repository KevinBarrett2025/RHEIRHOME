import Foundation
import CoreLocation
import OSLog

extension Logger {
    static let labor = Logger(subsystem: "com.RheirHome.RHEIR", category: "labor")
}

@MainActor
extension ProjectViewModel {
    /// Enhanced log hours method with team member integration
    func logHours(
        startTime: Date,
        endTime: Date,
        employee: String,
        rate: Double,
        category: String,
        lunchBreakDuration: Double?,
        employeeID: UUID? = nil,
        location: CLLocation? = nil
    ) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { 
            Logger.labor.error("Failed to log hours because no active project is selected.")
            return 
        }

        Logger.labor.info("Creating work-hour entry for selected project.")
        var wh = WorkHour(
            id: UUID(),
            date: startTime,
            startTime: startTime,
            endTime: endTime,
            lunchStart: nil,
            lunchEnd: nil,
            employee: employee,
            employeeID: employeeID,
            rate: rate,
            category: category,
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil,
            clockInLocation: location,
            clockOutLocation: nil
        )

        if let lunchDur = lunchBreakDuration, lunchDur > 0 {
            let totalShift = endTime.timeIntervalSince(startTime)
            let beforeLunch = (totalShift - lunchDur * 3600) / 2
            wh.lunchStart = startTime.addingTimeInterval(beforeLunch)
            wh.lunchEnd   = wh.lunchStart?.addingTimeInterval(lunchDur * 3600)
            Logger.labor.debug("Added lunch break [hours=\(lunchDur, privacy: .public)]")
        }

        // Validate the work hour entry
        if !wh.isValid {
            for issue in wh.validationIssues {
                Logger.labor.warning("Work-hour validation issue: \(issue, privacy: .public)")
            }
            // Still save it but mark for review
        }

        // CRITICAL FIX: Auto-assign team member to project when they log hours
        if let employeeID = wh.employeeID,
           !organizationProjects[idx].assignedTeamMemberIDs.contains(employeeID.uuidString) {
            organizationProjects[idx].assignTeamMember(employeeID.uuidString)
            Logger.labor.info("Auto-assigned team member from logged hours [teamMember=\(employeeID.uuidString, privacy: .private(mask: .hash))]")
        } else if let employeeID = wh.employeeID, 
                  organizationProjects[idx].assignedTeamMemberIDs.contains(employeeID.uuidString) {
            Logger.labor.debug("Team member already assigned to project [teamMember=\(employeeID.uuidString, privacy: .private(mask: .hash))]")
        }

        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours.append(wh)
        applyProjectMutationLocally(
            updatedProject,
            reason: "log labor hours",
            selectProject: true,
            scheduleCloudSync: true
        )

        Logger.labor.notice(
            "Logged hours for project [project=\(sel.id.uuidString, privacy: .private(mask: .hash)) totalEntries=\(updatedProject.loggedHours.count, privacy: .public)]"
        )

        Logger.labor.info("Saved work-hour entry [hours=\(wh.hours, privacy: .public)]")
    }
    
    /// Start live tracking for a team member
    func startLiveTracking(
        teamMember: TeamMember,
        rate: Double,
        category: String,
        location: CLLocation? = nil
    ) -> UUID? {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { 
            Logger.labor.error("Failed to start live tracking because no active project is selected.")
            return nil
        }
        
        // Check if user already has an active timer
        if organizationProjects[idx].loggedHours.contains(where: { 
            $0.employeeID == teamMember.id && $0.endTime == nil 
        }) {
            Logger.labor.warning("Attempted to start duplicate live timer for a team member.")
            return nil
        }
        
        let workHour = WorkHour(
            teamMember: teamMember,
            rate: rate,
            category: category,
            startTime: Date(),
            location: location
        )
        
        // CRITICAL FIX: Auto-assign team member to project when they start tracking time
        if !organizationProjects[idx].assignedTeamMemberIDs.contains(teamMember.id.uuidString) {
            organizationProjects[idx].assignTeamMember(teamMember.id.uuidString)
            Logger.labor.info("Auto-assigned team member from live tracking [teamMember=\(teamMember.id.uuidString, privacy: .private(mask: .hash))]")
        }
        
        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours.append(workHour)
        applyProjectMutationLocally(
            updatedProject,
            reason: "start live labor tracking",
            selectProject: true,
            scheduleCloudSync: true
        )
        
        Logger.labor.notice("Started live tracking [teamMember=\(teamMember.id.uuidString, privacy: .private(mask: .hash))]")
        return workHour.id
    }
    
    /// Stop live tracking and finalize the work hour
    func stopLiveTracking(
        workHourID: UUID,
        endLocation: CLLocation? = nil,
        notes: String? = nil
    ) -> Bool {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id }),
              let whIdx = organizationProjects[idx].loggedHours.firstIndex(where: { $0.id == workHourID })
        else { 
            Logger.labor.error("Failed to stop live tracking because the work-hour entry was not found.")
            return false
        }
        
        var workHour = organizationProjects[idx].loggedHours[whIdx]
        workHour.endTime = Date()
        workHour.clockOutLocation = endLocation
        
        if let notes = notes, !notes.isEmpty {
            workHour.validationNotes = notes
        }
        
        // Validate the completed entry
        if !workHour.isValid {
            for issue in workHour.validationIssues {
                Logger.labor.warning("Completed work-hour validation issue: \(issue, privacy: .public)")
            }
        }
        
        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours[whIdx] = workHour
        applyProjectMutationLocally(
            updatedProject,
            reason: "stop live labor tracking",
            selectProject: true,
            scheduleCloudSync: true
        )
        
        Logger.labor.notice("Stopped live tracking [hours=\(workHour.hours, privacy: .public)]")
        return true
    }
    
    /// Get active timers for the current project
    var activeTimers: [WorkHour] {
        guard let project = selectedProject else { return [] }
        return project.loggedHours.filter { $0.endTime == nil }
    }
    
    /// Get pending approval hours
    var pendingApprovalHours: [WorkHour] {
        guard let project = selectedProject else { return [] }
        return project.loggedHours.filter { !$0.isApproved && $0.endTime != nil }
    }
    
    /// Approve work hours (for managers)
    func approveWorkHours(_ workHourIDs: [UUID], managerID: UUID, notes: String? = nil) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }
        
        var approvedCount = 0
        
        for i in 0..<organizationProjects[idx].loggedHours.count {
            if workHourIDs.contains(organizationProjects[idx].loggedHours[i].id) {
                organizationProjects[idx].loggedHours[i].approve(by: managerID, notes: notes)
                approvedCount += 1
            }
        }
        
        applyProjectMutationLocally(
            organizationProjects[idx],
            reason: "approve labor hours",
            selectProject: true,
            scheduleCloudSync: true
        )
        
        Logger.labor.notice("Approved work-hour entries [count=\(approvedCount, privacy: .public)]")
    }
    
    /// Detect overlapping time entries for validation
    func findOverlappingEntries(for employeeID: UUID) -> [(WorkHour, WorkHour)] {
        guard let project = selectedProject else { return [] }
        
        let employeeHours = project.loggedHours
            .filter { $0.employeeID == employeeID && $0.endTime != nil }
            .sorted { $0.startTime < $1.startTime }
        
        var overlaps: [(WorkHour, WorkHour)] = []
        
        for i in 0..<employeeHours.count - 1 {
            let current = employeeHours[i]
            let next = employeeHours[i + 1]
            
            if let currentEnd = current.endTime,
               currentEnd > next.startTime {
                overlaps.append((current, next))
            }
        }
        
        return overlaps
    }
    
    /// Calculate weekly hours for overtime detection
    func getWeeklyHours(for employeeID: UUID, week: Date) -> Double {
        guard let project = selectedProject else { return 0 }
        
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: week)?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: week)?.end
        else { return 0 }
        
        return project.loggedHours
            .filter { 
                $0.employeeID == employeeID &&
                $0.startTime >= weekStart &&
                $0.startTime < weekEnd &&
                $0.endTime != nil
            }
            .reduce(0) { $0 + $1.hours }
    }
    
    /// Get time tracking analytics for a team member
    func getTimeTrackingAnalytics(for employeeID: UUID, period: TimeInterval = 30 * 24 * 60 * 60) -> TimeTrackingAnalytics {
        guard let project = selectedProject else { 
            return TimeTrackingAnalytics(totalHours: 0, totalEarnings: 0, averageHoursPerDay: 0, overtimeHours: 0, daysWorked: 0)
        }
        
        let startDate = Date().addingTimeInterval(-period)
        
        let periodHours = project.loggedHours.filter { 
            $0.employeeID == employeeID &&
            $0.startTime >= startDate &&
            $0.endTime != nil
        }
        
        let totalHours = periodHours.reduce(0) { $0 + $1.hours }
        let totalEarnings = periodHours.reduce(0) { $0 + $1.totalPay }
        let overtimeHours = periodHours.reduce(0) { $0 + $1.overtimeHours }
        
        let uniqueDays = Set(periodHours.map { 
            Calendar.current.startOfDay(for: $0.date) 
        }).count
        
        let averageHoursPerDay = uniqueDays > 0 ? totalHours / Double(uniqueDays) : 0
        
        return TimeTrackingAnalytics(
            totalHours: totalHours,
            totalEarnings: totalEarnings,
            averageHoursPerDay: averageHoursPerDay,
            overtimeHours: overtimeHours,
            daysWorked: uniqueDays
        )
    }

    /// Update an existing work‐hour entry.
    func updateHours(_ entry: WorkHour) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id }),
              let whIdx = organizationProjects[idx].loggedHours.firstIndex(where: { $0.id == entry.id })
        else { 
            Logger.labor.error("Failed to update hours because the project or work-hour entry was not found.")
            return 
        }

        Logger.labor.info("Updating work-hour entry.")

        // CRITICAL FIX: Auto-assign team member to project when hours are updated with employeeID
        if let employeeID = entry.employeeID,
           !organizationProjects[idx].assignedTeamMemberIDs.contains(employeeID.uuidString) {
            organizationProjects[idx].assignTeamMember(employeeID.uuidString)
            Logger.labor.info("Auto-assigned team member from updated hours [teamMember=\(employeeID.uuidString, privacy: .private(mask: .hash))]")
        }

        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours[whIdx] = entry
        applyProjectMutationLocally(
            updatedProject,
            reason: "update labor hours",
            selectProject: true,
            scheduleCloudSync: true
        )
    }

    /// Mark an entry as paid.
    func markHoursAsPaid(_ entry: WorkHour, method: String, note: String) {
        var updated = entry
        updated.recordPayment(
            amount: updated.effectiveUnpaidAmount,
            method: method,
            note: note
        )
        updateHours(updated)
    }

    /// Unmark an entry as paid.
    func unmarkHoursAsPaid(_ entry: WorkHour) {
        var updated = entry
        updated.reversePayments(note: "Payment reversed")
        updateHours(updated)
    }

    func recordLaborPayment(
        for entries: [WorkHour],
        amount: Double,
        method: String,
        reference: String,
        note: String
    ) {
        guard amount > 0,
              let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else {
            Logger.labor.error("Failed to record labor payment because the request was invalid.")
            return
        }

        var remainingAmount = amount
        var updatedProject = organizationProjects[idx]
        var paidEntryCount = 0
        let entryIDs = entries
            .sorted { $0.date < $1.date }
            .map(\.id)

        for workHourID in entryIDs {
            guard remainingAmount > 0,
                  let hourIndex = updatedProject.loggedHours.firstIndex(where: { $0.id == workHourID })
            else { continue }

            var workHour = updatedProject.loggedHours[hourIndex]
            let appliedAmount = min(workHour.effectiveUnpaidAmount, remainingAmount)
            guard appliedAmount > 0 else { continue }

            workHour.recordPayment(
                amount: appliedAmount,
                method: method,
                reference: reference,
                note: note
            )
            updatedProject.loggedHours[hourIndex] = workHour
            remainingAmount -= appliedAmount
            paidEntryCount += 1
        }

        guard paidEntryCount > 0 else {
            Logger.labor.warning("Ignored labor payment because no unpaid amount could be applied.")
            return
        }

        applyProjectMutationLocally(
            updatedProject,
            reason: "record labor payment",
            selectProject: true,
            scheduleCloudSync: true
        )

        Logger.labor.notice(
            "Recorded labor payment [entries=\(paidEntryCount, privacy: .public) requestedAmount=\(amount, privacy: .public) unapplied=\(remainingAmount, privacy: .public) method=\(method, privacy: .public)]"
        )
    }

    func reverseLaborPayments(for entry: WorkHour, note: String = "Payment reversed for correction or reissue") {
        var updated = entry
        updated.reversePayments(note: note)
        updateHours(updated)
    }

    /// Delete entries matching paid/unpaid status.
    func deleteHours(at offsets: IndexSet, paid: Bool) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let hoursToDelete = offsets.map { organizationProjects[idx].loggedHours[$0] }
            .filter { $0.isPaid == paid }
        
        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours.removeAll { wh in
            hoursToDelete.contains { $0.id == wh.id }
        }

        applyProjectMutationLocally(
            updatedProject,
            reason: "delete labor hours by offset",
            selectProject: true,
            scheduleCloudSync: true
        )
    }

    /// Delete multiple entries by their IDs.
    func deleteHours(withIDs ids: [UUID]) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let beforeCount = organizationProjects[idx].loggedHours.count
        
        var updatedProject = organizationProjects[idx]
        updatedProject.loggedHours.removeAll { ids.contains($0.id) }
        
        let afterCount = updatedProject.loggedHours.count
        Logger.labor.notice("Deleted work-hour entries [count=\(beforeCount - afterCount, privacy: .public)]")

        applyProjectMutationLocally(
            updatedProject,
            reason: "delete labor hours by id",
            selectProject: true,
            scheduleCloudSync: true
        )
    }

    /// Total earnings for an employee filtered by paid status.
    func total(for employee: String, paid: Bool) -> Double {
        guard let p = selectedProject else { return 0 }
        return p.loggedHours
            .filter { $0.employee == employee && $0.isPaid == paid }
            .reduce(0) { $0 + $1.hours * $1.rate }
    }

    /// All active clock-ins (no end time yet).
    var activeClockIns: [WorkHour] {
        guard let p = selectedProject else { return [] }
        return p.loggedHours.filter { $0.endTime == nil }
    }
    
    /// Quick clock toggle: clock out if open, else clock in now.
    func quickToggleClock(employee: String, rate: Double) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        // Try to find by employee name (legacy support)
        if let openHour = organizationProjects[idx].loggedHours.first(where: { 
            $0.employee == employee && $0.endTime == nil 
        }) {
            // Clock out
            var updated = openHour
            updated.endTime = Date()
            updateHours(updated)
        } else {
            // Clock in
            let now = Date()
            let wh = WorkHour(
                id: UUID(),
                date: now,
                startTime: now,
                endTime: nil,
                lunchStart: nil,
                lunchEnd: nil,
                employee: employee,
                employeeID: nil, // Legacy mode - no team member ID
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
                reason: "quick clock in",
                selectProject: true,
                scheduleCloudSync: true
            )
        }
    }
}

// MARK: - Time Tracking Analytics Model
struct TimeTrackingAnalytics {
    let totalHours: Double
    let totalEarnings: Double
    let averageHoursPerDay: Double
    let overtimeHours: Double
    let daysWorked: Int
}
