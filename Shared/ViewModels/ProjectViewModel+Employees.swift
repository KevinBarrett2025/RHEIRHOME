//
//  ProjectViewModel+TeamMembers.swift
//  RheirMultiplatformApp
//
//  Created by Kevin Barrett on 5/14/25.
//

import Foundation
import CloudKit

@MainActor
extension ProjectViewModel {
    // MARK: – Team Members

    /// Add a new team member to the directory.
    func addTeamMember(_ teamMember: TeamMember) {
        // Check for duplicates by name
        if teamMembers.contains(where: { $0.name.lowercased() == teamMember.name.lowercased() }) {
            print("⚠️ Team member with name '\(teamMember.name)' already exists, not adding duplicate")
            return
        }
        
        print("✅ Adding new team member: \(teamMember.name) with \(teamMember.rates.count) rates")
        teamMembers.append(teamMember)
        rebuildTeamMemberCache() // Rebuild cache immediately
        debouncedSaveTeamMembers()
        
        // PHASE 5: Save to directory zone
        Task {
            do {
                try await self.saveTeamMemberToZone(teamMember)
                print("✅ PHASE 5: Team member '\(teamMember.name)' saved to directory zone")
            } catch {
                print("⚠️ PHASE 5: Failed to save team member to zone: \(error)")
            }
        }
    }

    /// Update an existing team member's details.
    func updateTeamMember(_ updated: TeamMember) {
        guard let idx = teamMembers.firstIndex(where: { $0.id == updated.id }) else {
            print("❌ Could not find team member with ID \(updated.id) to update")
            return
        }
        
        print("✅ Updating team member: \(teamMembers[idx].name) → \(updated.name)")
        print("  Rates: \(teamMembers[idx].rates.count) → \(updated.rates.count)")
        
        let oldName = teamMembers[idx].name
        teamMembers[idx] = updated
        
        // If name changed, update all WorkHour entries
        if oldName != updated.name {
            updateWorkHourTeamMemberNames(from: oldName, to: updated.name)
        }
        
        rebuildTeamMemberCache() // Rebuild cache immediately
        debouncedSaveTeamMembers()
        
        // PHASE 5: Update in directory zone
        Task {
            do {
                try await self.saveTeamMemberToZone(updated)
                print("✅ PHASE 5: Team member '\(updated.name)' updated in directory zone")
            } catch {
                print("⚠️ PHASE 5: Failed to update team member in zone: \(error)")
            }
        }
    }

    /// Remove a team member (and their rates) from the directory.
    func removeTeamMember(_ teamMember: TeamMember) {
        print("🗑️ Removing team member: \(teamMember.name)")
        teamMembers.removeAll { $0.id == teamMember.id }
        rebuildTeamMemberCache() // Rebuild cache immediately
        debouncedSaveTeamMembers()
        
        // PHASE 5: Remove from directory zone
        Task {
            do {
                try await self.removeTeamMemberFromZone(teamMember)
                print("✅ PHASE 5: Team member '\(teamMember.name)' removed from directory zone")
            } catch {
                print("⚠️ PHASE 5: Failed to remove team member from zone: \(error)")
            }
        }
    }

    /// Delete a team member entirely: removes from directory,
    /// and also clears any logged hours for them on the current project.
    func deleteTeamMember(_ toDelete: TeamMember) {
        print("🗑️ Deleting team member entirely: \(toDelete.name)")
        
        // 1) remove from team member directory
        teamMembers.removeAll { $0.id == toDelete.id }
        
        // 2) strip out any logged hours under that name in the selected project
        guard let sel = selectedProject,
              let projIdx = projects.firstIndex(where: { $0.id == sel.id })
        else { 
            rebuildTeamMemberCache()
            debouncedSaveTeamMembers()
            return 
        }

        let beforeCount = projects[projIdx].loggedHours.count
        projects[projIdx].loggedHours.removeAll { $0.employee == toDelete.name }
        let afterCount = projects[projIdx].loggedHours.count
        
        print("  Removed \(beforeCount - afterCount) logged hours for \(toDelete.name)")
        
        // re-assign to force view update
        selectedProject = projects[projIdx]
        
        rebuildTeamMemberCache()
        recomputeLaborData()
        debouncedSaveTeamMembers()
        debouncedSaveProjects()
    }
    
    /// Update team member names in all WorkHour entries when a team member's name changes
    private func updateWorkHourTeamMemberNames(from oldName: String, to newName: String) {
        guard let sel = selectedProject,
              let projIdx = projects.firstIndex(where: { $0.id == sel.id }) else {
            return
        }
        
        var updatedCount = 0
        for i in 0..<projects[projIdx].loggedHours.count {
            if projects[projIdx].loggedHours[i].employee == oldName {
                projects[projIdx].loggedHours[i].employee = newName
                updatedCount += 1
            }
        }
        
        if updatedCount > 0 {
            print("  Updated \(updatedCount) work hour entries from '\(oldName)' to '\(newName)'")
            selectedProject = projects[projIdx]
            recomputeLaborData()
            debouncedSaveProjects()
        }
    }
    
    /// Debug method to print current team member state
    func debugTeamMemberState() {
        print("🔍 Current Team Member State:")
        print("  Total team members: \(teamMembers.count)")
        for (index, teamMember) in teamMembers.enumerated() {
            print("  [\(index)] \(teamMember.name) - \(teamMember.rates.count) rates - Role: \(teamMember.role.displayName)")
            for rate in teamMember.rates {
                print("    - \(rate.taskType): $\(rate.rate)")
            }
        }
        print("  Cache size: \(teamMemberCache.count)")
    }
    
    // MARK: - Backward Compatibility Methods
    
    /// Backward compatibility for existing code
    var employees: [TeamMember] {
        get { teamMembers }
        set { teamMembers = newValue }
    }
    
    func addEmployee(_ employee: TeamMember) {
        addTeamMember(employee)
    }
    
    func updateEmployee(_ employee: TeamMember) {
        updateTeamMember(employee)
    }
    
    func removeEmployee(_ employee: TeamMember) {
        removeTeamMember(employee)
    }
    
    func deleteEmployee(_ employee: TeamMember) {
        deleteTeamMember(employee)
    }
    
    var employeeCache: [String: TeamMember] {
        get { teamMemberCache }
        set { teamMemberCache = newValue }
    }
    
    func rebuildEmployeeCache() {
        rebuildTeamMemberCache()
    }
    
    func debouncedSaveEmployees() {
        debouncedSaveTeamMembers()
    }
    
    var groupedHoursByEmployee: [String: [WorkHour]] {
        get { groupedHoursByTeamMember }
    }
    
    var laborTotalsByEmployee: [String: (unpaid: Double, paid: Double)] {
        get { laborTotalsByTeamMember }
    }
}
