//
//  ProjectViewModel+TeamMembers.swift
//  RheirMultiplatformApp
//
//  Created by Kevin Barrett on 5/14/25.
//

import Foundation
import CloudKit
import OSLog

extension Logger {
    static let teamMember = Logger(subsystem: "com.RheirHome.RHEIR", category: "teamMember")
}

struct TeamMemberStoreCaches {
    let byID: [UUID: TeamMember]
    let byName: [String: TeamMember]
}

struct TeamMemberStoreVerification {
    let members: [TeamMember]
    let filteredCount: Int
}

struct TeamMemberStoreUpdateResult {
    let members: [TeamMember]
    let previousName: String?
}

struct TeamMemberStoreUpsertResult {
    enum Action: Equatable {
        case inserted
        case updatedExisting
        case ignoredDuplicate

        var logLabel: String {
            switch self {
            case .inserted:
                return "inserted"
            case .updatedExisting:
                return "updatedExisting"
            case .ignoredDuplicate:
                return "ignoredDuplicate"
            }
        }
    }

    let members: [TeamMember]
    let action: Action
}

struct TeamMemberLoggedHourMutation {
    let project: Project
    let changedCount: Int
}

final class TeamMemberStore {
    func upsert(_ candidate: TeamMember, into existing: [TeamMember]) -> TeamMemberStoreUpsertResult {
        let duplicateIndex = existing.firstIndex { member in
            if let existingAppUserID = member.appUserID,
               let candidateAppUserID = candidate.appUserID,
               member.organizationID == candidate.organizationID {
                return existingAppUserID == candidateAppUserID
            }

            return member.name.lowercased() == candidate.name.lowercased()
                && member.organizationID == candidate.organizationID
        }

        guard let duplicateIndex else {
            return TeamMemberStoreUpsertResult(
                members: existing + [candidate],
                action: .inserted
            )
        }

        let existingMember = existing[duplicateIndex]
        let shouldMerge = candidate.rates.count > existingMember.rates.count
            || (!candidate.email.isEmpty && existingMember.email.isEmpty)
            || (!candidate.phone.isEmpty && existingMember.phone.isEmpty)
            || (!candidate.jobTitle.isEmpty && existingMember.jobTitle.isEmpty)

        guard shouldMerge else {
            return TeamMemberStoreUpsertResult(
                members: existing,
                action: .ignoredDuplicate
            )
        }

        var updatedMembers = existing
        updatedMembers[duplicateIndex] = candidate
        return TeamMemberStoreUpsertResult(
            members: updatedMembers,
            action: .updatedExisting
        )
    }

    func update(_ updated: TeamMember, in existing: [TeamMember]) -> TeamMemberStoreUpdateResult? {
        guard let index = existing.firstIndex(where: { $0.id == updated.id }) else {
            return nil
        }

        let previousName = existing[index].name
        var updatedMembers = existing
        updatedMembers[index] = updated
        return TeamMemberStoreUpdateResult(
            members: updatedMembers,
            previousName: previousName
        )
    }

    func remove(_ member: TeamMember, from existing: [TeamMember]) -> [TeamMember] {
        existing.filter { $0.id != member.id }
    }

    func verify(_ members: [TeamMember], for organizationID: String) -> TeamMemberStoreVerification {
        let verifiedMembers = members.filter { $0.organizationID == organizationID }
        return TeamMemberStoreVerification(
            members: verifiedMembers,
            filteredCount: members.count - verifiedMembers.count
        )
    }

    func mergeRecovered(_ recovered: [TeamMember], with existing: [TeamMember]) -> [TeamMember] {
        var mergedMembers: [TeamMember] = []
        var seenIDs: Set<UUID> = []

        for member in recovered where seenIDs.insert(member.id).inserted {
            mergedMembers.append(member)
        }

        for member in existing where seenIDs.insert(member.id).inserted {
            mergedMembers.append(member)
        }

        return mergedMembers
    }

    func renameLoggedHours(in project: Project, from oldName: String, to newName: String) -> TeamMemberLoggedHourMutation {
        var updatedProject = project
        var updatedCount = 0

        for index in updatedProject.loggedHours.indices where updatedProject.loggedHours[index].employee == oldName {
            updatedProject.loggedHours[index].employee = newName
            updatedCount += 1
        }

        return TeamMemberLoggedHourMutation(project: updatedProject, changedCount: updatedCount)
    }

    func removeLoggedHours(for member: TeamMember, in project: Project) -> TeamMemberLoggedHourMutation {
        var updatedProject = project
        let beforeCount = updatedProject.loggedHours.count
        updatedProject.loggedHours.removeAll { hour in
            if let employeeID = hour.employeeID {
                return employeeID == member.id
            }

            return hour.employee == member.name
        }

        return TeamMemberLoggedHourMutation(
            project: updatedProject,
            changedCount: beforeCount - updatedProject.loggedHours.count
        )
    }

    func buildCaches(from members: [TeamMember]) -> TeamMemberStoreCaches {
        var byName: [String: TeamMember] = [:]
        for member in members {
            byName[member.name] = member
        }

        return TeamMemberStoreCaches(
            byID: Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) }),
            byName: byName
        )
    }
}

@MainActor
extension ProjectViewModel {
    // MARK: – Team Members (Enterprise Single Source of Truth)

    /// Add a new team member to the organization directory.
    func addTeamMember(_ teamMember: TeamMember) {
        addTeamMemberToOrganization(teamMember)
    }

    /// Update an existing team member's details in the organization.
    func updateTeamMember(_ updated: TeamMember) {
        updateTeamMemberInOrganization(updated)
    }

    /// Remove a team member (and their rates) from the organization directory.
    func removeTeamMember(_ teamMember: TeamMember) {
        let updatedMembers = teamMemberStore.remove(teamMember, from: teamMembers)
        let removedCount = teamMembers.count - updatedMembers.count

        guard removedCount > 0 else {
            Logger.teamMember.warning("Ignored team-member removal because the member was not found.")
            return
        }

        teamMembers = updatedMembers
        updateTeamMemberCaches()
        saveOrganizationSpecificBackup()
        recomputeLaborData()

        Logger.teamMember.notice(
            "Removed team member from organization directory [remaining=\(self.teamMembers.count, privacy: .public)]"
        )

        Task {
            await removeTeamMember(teamMember)
        }
    }

    /// Delete a team member entirely: removes from organization directory,
    /// and also clears any logged hours for them on the current project.
    func deleteTeamMember(_ toDelete: TeamMember) {
        let updatedMembers = teamMemberStore.remove(toDelete, from: teamMembers)
        let removedDirectoryCount = teamMembers.count - updatedMembers.count
        teamMembers = updatedMembers
        updateTeamMemberCaches()

        Task {
            await removeTeamMember(toDelete)
        }

        guard let sel = selectedProject,
              let projIdx = organizationProjects.firstIndex(where: { $0.id == sel.id })
        else { 
            saveOrganizationSpecificBackup()
            recomputeLaborData()
            updateTeamMemberCaches()
            return 
        }

        let mutation = teamMemberStore.removeLoggedHours(for: toDelete, in: organizationProjects[projIdx])
        organizationProjects[projIdx] = mutation.project
        selectedProject = mutation.project

        saveOrganizationSpecificBackup()
        recomputeLaborData()
        debouncedSaveProjects()

        Logger.teamMember.notice(
            "Deleted team member and removed related logged hours [directoryRemoved=\(removedDirectoryCount, privacy: .public) hoursRemoved=\(mutation.changedCount, privacy: .public)]"
        )
    }
    
    /// Update team member names in all WorkHour entries when a team member's name changes
    func updateWorkHourTeamMemberNames(from oldName: String, to newName: String) {
        guard let sel = selectedProject,
              let projIdx = organizationProjects.firstIndex(where: { $0.id == sel.id }) else {
            return
        }

        let mutation = teamMemberStore.renameLoggedHours(
            in: organizationProjects[projIdx],
            from: oldName,
            to: newName
        )

        if mutation.changedCount > 0 {
            organizationProjects[projIdx] = mutation.project
            selectedProject = mutation.project
            saveOrganizationSpecificBackup()
            recomputeLaborData()
            debouncedSaveProjects()
            Logger.teamMember.info(
                "Renamed logged-hour team-member references [count=\(mutation.changedCount, privacy: .public)]"
            )
        }
    }
    
    /// Debug method to print current team member state from organization
    func debugTeamMemberState() {
        Logger.teamMember.debug("Current team-member directory snapshot follows.")
        Logger.teamMember.debug("Team member count: \(self.teamMembers.count, privacy: .public)")
        for (index, teamMember) in teamMembers.enumerated() {
            Logger.teamMember.debug(
                "[\(index, privacy: .public)] role=\(teamMember.role.displayName, privacy: .public) rates=\(teamMember.rates.count, privacy: .public)"
            )
            for rate in teamMember.rates {
                Logger.teamMember.debug(
                    "Rate taskType=\(rate.taskType, privacy: .public) amount=\(rate.rate, privacy: .public)"
                )
            }
        }
        Logger.teamMember.debug("Cache size: \(self.teamMembers.count, privacy: .public)")
    }
    
    // MARK: - Backward Compatibility Methods (Updated for Organization)
    
    /// Backward compatibility for existing code - now reads from organization
    var employees: [TeamMember] {
        get { teamMembers }
        set { 
            Logger.teamMember.warning("Setting employees directly is deprecated; use organization team-member methods.")
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
            var cache: [String: TeamMember] = [:]
            for member in teamMembers {
                cache[member.name] = member
            }
            return cache
        }
        set { 
            Logger.teamMember.warning("Setting employeeCache directly is deprecated; caches are derived from organization state.")
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
