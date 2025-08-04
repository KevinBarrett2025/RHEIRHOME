import Foundation
import CoreLocation

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
            print("❌ Failed to log hours: No project selected or project not found")
            return 
        }

        print("🕐 Creating enhanced work hour entry...")
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
            print("🍽️ Added lunch break: \(lunchDur) hours")
        }

        // Validate the work hour entry
        if !wh.isValid {
            print("⚠️ Invalid work hour entry:")
            for issue in wh.validationIssues {
                print("  - \(issue)")
            }
            // Still save it but mark for review
        }

        print("✅ Adding work hour to project: \(sel.name)")
        organizationProjects[idx].loggedHours.append(wh)
        selectedProject = organizationProjects[idx]
        
        print("📊 Project now has \(organizationProjects[idx].loggedHours.count) logged hours")
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
        
        print("💾 Successfully logged \(wh.hours) hours for \(employee)")
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
            print("❌ Failed to start live tracking: No project selected")
            return nil
        }
        
        // Check if user already has an active timer
        if organizationProjects[idx].loggedHours.contains(where: { 
            $0.employeeID == teamMember.id && $0.endTime == nil 
        }) {
            print("⚠️ Team member \(teamMember.name) already has an active timer")
            return nil
        }
        
        let workHour = WorkHour(
            teamMember: teamMember,
            rate: rate,
            category: category,
            startTime: Date(),
            location: location
        )
        
        organizationProjects[idx].loggedHours.append(workHour)
        selectedProject = organizationProjects[idx]
        
        print("⏰ Started live tracking for \(teamMember.name)")
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
            print("❌ Failed to stop live tracking: Entry not found")
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
            print("⚠️ Invalid work hour entry completed:")
            for issue in workHour.validationIssues {
                print("  - \(issue)")
            }
        }
        
        organizationProjects[idx].loggedHours[whIdx] = workHour
        selectedProject = organizationProjects[idx]
        
        // Recompute labor data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
        
        print("✅ Stopped live tracking - Total hours: \(workHour.hours)")
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
        
        selectedProject = organizationProjects[idx]
        debouncedSaveProjects()
        
        print("✅ Approved \(approvedCount) work hour entries")
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
            print("❌ Failed to update hours: project or hours entry not found")
            print("  Selected project: \(selectedProject?.name ?? "nil")")
            print("  Hours ID: \(entry.id)")
            return 
        }

        print("✅ Updating hours entry:")
        print("  Old: \(organizationProjects[idx].loggedHours[whIdx].employee) - $\(organizationProjects[idx].loggedHours[whIdx].rate)")
        print("  New: \(entry.employee) - $\(entry.rate)")

        organizationProjects[idx].loggedHours[whIdx] = entry
        selectedProject = organizationProjects[idx]
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
    }

    /// Mark an entry as paid.
    func markHoursAsPaid(_ entry: WorkHour, method: String, note: String) {
        var updated = entry
        updated.isPaid = true
        updated.paymentMethod = method
        updated.paymentNote = note
        updated.paymentTimestamp = Date()
        updateHours(updated)
    }

    /// Unmark an entry as paid.
    func unmarkHoursAsPaid(_ entry: WorkHour) {
        var updated = entry
        updated.isPaid = false
        updated.paymentMethod = nil
        updated.paymentNote = nil
        updated.paymentTimestamp = nil
        updateHours(updated)
    }

    /// Delete entries matching paid/unpaid status.
    func deleteHours(at offsets: IndexSet, paid: Bool) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let hoursToDelete = offsets.map { organizationProjects[idx].loggedHours[$0] }
            .filter { $0.isPaid == paid }
        
        organizationProjects[idx].loggedHours.removeAll { wh in
            hoursToDelete.contains { $0.id == wh.id }
        }
        
        selectedProject = organizationProjects[idx]
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
    }

    /// Delete multiple entries by their IDs.
    func deleteHours(withIDs ids: [UUID]) {
        guard let sel = selectedProject,
              let idx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { return }

        print("🗑️ Deleting hours with IDs: \(ids)")
        let beforeCount = organizationProjects[idx].loggedHours.count
        
        organizationProjects[idx].loggedHours.removeAll { ids.contains($0.id) }
        selectedProject = organizationProjects[idx]
        
        let afterCount = organizationProjects[idx].loggedHours.count
        print("  Deleted \(beforeCount - afterCount) entries")
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
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
            organizationProjects[idx].loggedHours.append(wh)
            selectedProject = organizationProjects[idx]
            
            recomputeLaborData()
            invalidateReceiptCache()
            debouncedSaveProjects()
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