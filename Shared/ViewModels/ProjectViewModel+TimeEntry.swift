import Foundation

@MainActor
extension ProjectViewModel {
    /// Log a new block of work hours, distributing lunch if provided.
    /// Now includes a `category` parameter.
    func logHours(
        startTime: Date,
        endTime: Date,
        employee: String,
        rate: Double,
        category: String,
        lunchBreakDuration: Double?
    ) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id })
        else { 
            print("❌ Failed to log hours: No project selected or project not found")
            print("  Selected project: \(selectedProject?.name ?? "none")")
            print("  Available projects: \(projects.map(\.name))")
            return 
        }

        print("🕐 Creating work hour entry...")
        var wh = WorkHour(
            id: UUID(),
            date: startTime,
            startTime: startTime,
            endTime: endTime,
            lunchStart: nil,
            lunchEnd: nil,
            employee: employee,
            rate: rate,
            category: category,
            isPaid: false,
            paymentMethod: nil,
            paymentNote: nil,
            paymentTimestamp: nil
        )

        if let lunchDur = lunchBreakDuration, lunchDur > 0 {
            let totalShift = endTime.timeIntervalSince(startTime)
            let beforeLunch = (totalShift - lunchDur * 3600) / 2
            wh.lunchStart = startTime.addingTimeInterval(beforeLunch)
            wh.lunchEnd   = wh.lunchStart?.addingTimeInterval(lunchDur * 3600)
            print("🍽️ Added lunch break: \(lunchDur) hours")
        }

        print("✅ Adding work hour to project: \(sel.name)")
        projects[idx].loggedHours.append(wh)
        selectedProject = projects[idx]
        
        print("📊 Project now has \(projects[idx].loggedHours.count) logged hours")
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
        
        print("💾 Successfully logged \(wh.hours) hours for \(employee)")
    }

    /// Quick clock toggle: clock out if open, else clock in now.
    /// Uses default category "Labor".
    func quickToggleClock(employee: String, rate: Double) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id })
        else { return }

        if let openHour = projects[idx].loggedHours.first(where: { $0.employee == employee && $0.endTime == nil }) {
            var updated = openHour
            updated.endTime = Date()
            updateHours(updated)
        } else {
            let now = Date()
            let wh = WorkHour(
                id: UUID(),
                date: now,
                startTime: now,
                endTime: nil,
                lunchStart: nil,
                lunchEnd: nil,
                employee: employee,
                rate: rate,
                category: "Labor",
                isPaid: false,
                paymentMethod: nil,
                paymentNote: nil,
                paymentTimestamp: nil
            )
            projects[idx].loggedHours.append(wh)
            selectedProject = projects[idx]
            
            // Invalidate caches and recompute data
            recomputeLaborData()
            invalidateReceiptCache()
            debouncedSaveProjects()
        }
    }

    /// Update an existing work‐hour entry.
    func updateHours(_ entry: WorkHour) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id }),
              let whIdx = projects[idx].loggedHours.firstIndex(where: { $0.id == entry.id })
        else { 
            print("❌ Failed to update hours: project or hours entry not found")
            print("  Selected project: \(selectedProject?.name ?? "nil")")
            print("  Hours ID: \(entry.id)")
            return 
        }

        print("✅ Updating hours entry:")
        print("  Old: \(projects[idx].loggedHours[whIdx].employee) - $\(projects[idx].loggedHours[whIdx].rate)")
        print("  New: \(entry.employee) - $\(entry.rate)")

        projects[idx].loggedHours[whIdx] = entry
        selectedProject = projects[idx]
        
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
              let idx = projects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let hoursToDelete = offsets.map { projects[idx].loggedHours[$0] }
            .filter { $0.isPaid == paid }
        
        projects[idx].loggedHours.removeAll { wh in
            hoursToDelete.contains { $0.id == wh.id }
        }
        
        selectedProject = projects[idx]
        
        // Invalidate caches and recompute data
        recomputeLaborData()
        invalidateReceiptCache()
        debouncedSaveProjects()
    }

    /// Delete multiple entries by their IDs.
    func deleteHours(withIDs ids: [UUID]) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id })
        else { return }

        print("🗑️ Deleting hours with IDs: \(ids)")
        let beforeCount = projects[idx].loggedHours.count
        
        projects[idx].loggedHours.removeAll { ids.contains($0.id) }
        selectedProject = projects[idx]
        
        let afterCount = projects[idx].loggedHours.count
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
}