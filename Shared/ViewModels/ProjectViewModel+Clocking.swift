// ProjectViewModel+Clocking.swift
// RheirMultiplatformApp

import Foundation

@MainActor
extension ProjectViewModel {
    /// Clock an employee in now.
    func clockIn(employee: String, rate: Double) {
        guard let sel = selectedProject,
              let idx = projects.firstIndex(where: { $0.id == sel.id })
        else { return }

        let wh = WorkHour(startTime: Date(), employee: employee, rate: rate)
        projects[idx].loggedHours.append(wh)
        selectedProject = projects[idx]
        saveAllProjects()
        recomputeLaborData()
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
}
