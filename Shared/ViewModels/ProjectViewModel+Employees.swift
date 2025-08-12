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
    // MARK: – Team Members (Enterprise Single Source of Truth)

    /// Add a new team member to the organization directory.
    func addTeamMember(_ teamMember: TeamMember) {
        // Check for duplicates by name in organization
        if teamMembers.contains(where: { $0.name.lowercased() == teamMember.name.lowercased() }) {
            print("⚠️ Team member with name '\(teamMember.name)' already exists, not adding duplicate")
            return
        }
        
        print("✅ Adding new team member to organization: \(teamMember.name) with \(teamMember.rates.count) rates")
        addTeamMemberToOrganization(teamMember)
        
        updateTeamMemberCaches() // Rebuild cache immediately
    }

    /// Update an existing team member's details in the organization.
    func updateTeamMember(_ updated: TeamMember) {
        guard teamMembers.contains(where: { $0.id == updated.id }) else {
            print("❌ Could not find team member with ID \(updated.id) in organization")
            return
        }
        
        let oldTeamMember = teamMembers.first { $0.id == updated.id }
        let oldName = oldTeamMember?.name ?? ""
        
        print("✅ Updating team member in organization: \(oldName) → \(updated.name)")
        print("  Rates: \(oldTeamMember?.rates.count ?? 0) → \(updated.rates.count)")
        
        updateTeamMemberInOrganization(updated)
        
        // If name changed, update all WorkHour entries
        if oldName != updated.name {
            updateWorkHourTeamMemberNames(from: oldName, to: updated.name)
        }
        
        updateTeamMemberCaches() // Rebuild cache immediately
    }

    /// Remove a team member (and their rates) from the organization directory.
    func removeTeamMember(_ teamMember: TeamMember) {
        print("🗑️ Removing team member from organization: \(teamMember.name)")
        Task {
            await removeTeamMember(teamMember)
        }
        
        updateTeamMemberCaches() // Rebuild cache immediately
    }

    /// Delete a team member entirely: removes from organization directory,
    /// and also clears any logged hours for them on the current project.
    func deleteTeamMember(_ toDelete: TeamMember) {
        print("🗑️ Deleting team member entirely from organization: \(toDelete.name)")
        
        // 1) Remove from organization team member directory
        Task {
            await removeTeamMember(toDelete)
        }
        
        // 2) Strip out any logged hours under that name in the selected project
        guard let sel = selectedProject,
              let projIdx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { 
            updateTeamMemberCaches()
            return 
        }

        let beforeCount = organizationProjects[projIdx].loggedHours.count
        organizationProjects[projIdx].loggedHours.removeAll { hour in
            // Match by employeeID first, then fallback to name
            if let employeeID = hour.employeeID {
                return employeeID == toDelete.id
            } else {
                return hour.employee == toDelete.name
            }
        }
        let afterCount = organizationProjects[projIdx].loggedHours.count
        
        print("  Removed \(beforeCount - afterCount) logged hours for \(toDelete.name)")
        
        // re-assign to force view update
        selectedProject = organizationProjects[projIdx]
        
        updateTeamMemberCaches()
        recomputeLaborData()
        debouncedSaveProjects()
    }
    
    /// Update team member names in all WorkHour entries when a team member's name changes
    private func updateWorkHourTeamMemberNames(from oldName: String, to newName: String) {
        guard let sel = selectedProject,
              let projIdx = organizationProjects.firstIndex(where: { $0.id == sel.id }) else {
            return
        }
        
        var updatedCount = 0
        for i in 0..<organizationProjects[projIdx].loggedHours.count {
            if organizationProjects[projIdx].loggedHours[i].employee == oldName {
                organizationProjects[projIdx].loggedHours[i].employee = newName
                updatedCount += 1
            }
        }
        
        if updatedCount > 0 {
            print("  Updated \(updatedCount) work hour entries from '\(oldName)' to '\(newName)'")
            selectedProject = organizationProjects[projIdx]
            recomputeLaborData()
            debouncedSaveProjects()
        }
    }
    
    /// Debug method to print current team member state from organization
    func debugTeamMemberState() {
        print("🔍 Current Team Member State (from Organization):")
        print("  Total team members: \(teamMembers.count)")
        for (index, teamMember) in teamMembers.enumerated() {
            print("  [\(index)] \(teamMember.name) - \(teamMember.rates.count) rates - Role: \(teamMember.role.displayName)")
            for rate in teamMember.rates {
                print("    - \(rate.taskType): $\(rate.rate)")
            }
        }
        print("  Cache size: \(teamMembers.count)")
        print("  Organization: \(currentOrganizationID?.prefix(8).description ?? "None")...")
    }
    
    // MARK: - Backward Compatibility Methods (Updated for Organization)
    
    /// Backward compatibility for existing code - now reads from organization
    var employees: [TeamMember] {
        get { teamMembers }
        set { 
            print("⚠️ Setting employees array is deprecated - use organization team member methods instead")
            // For backward compatibility, we could update the organization, but this is not recommended
        }
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
        get { 
            // Convert teamMembers array to dictionary by name
            var cache: [String: TeamMember] = [:]
            for member in teamMembers {
                cache[member.name] = member
            }
            return cache
        }
        set { 
            print("⚠️ Setting employeeCache is deprecated - cache is now computed from organization")
        }
    }
    
    func rebuildEmployeeCache() {
        updateTeamMemberCaches()
    }
    
    func debouncedSaveEmployees() {
        debouncedSaveProjects()
    }
    
    var groupedHoursByEmployee: [String: [WorkHour]] {
        get { groupedHoursByTeamMember }
    }
    
    var laborTotalsByEmployee: [String: (unpaid: Double, paid: Double)] {
        get { laborTotalsByTeamMember }
    }
}