import Foundation
import Combine
import CloudKit

/// Enterprise team member management service
/// Manages team members as part of the organization's single source of truth
@MainActor
public class TeamMemberService: ObservableObject {
    @Published public var teamMembers: [TeamMember] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let organizationID: String
    private let cloudKitService: CloudKitAuthService
    
    public init(organizationID: String, cloudKitService: CloudKitAuthService = CloudKitAuthService()) {
        self.organizationID = organizationID
        self.cloudKitService = cloudKitService
    }
    
    // MARK: - Team Member CRUD Operations
    
    /// Add a new team member to the organization
    public func addTeamMember(_ teamMember: TeamMember) {
        var member = teamMember
        member.organizationID = organizationID
        
        teamMembers.append(member)
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("✅ Added team member: \(member.name) to organization")
    }
    
    /// Update an existing team member
    public func updateTeamMember(_ updatedMember: TeamMember) {
        guard let index = teamMembers.firstIndex(where: { $0.id == updatedMember.id }) else {
            errorMessage = "Team member not found"
            return
        }
        
        var member = updatedMember
        member.organizationID = organizationID
        
        teamMembers[index] = member
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("✅ Updated team member: \(member.name)")
    }
    
    /// Remove a team member (soft delete - marks as terminated)
    public func removeTeamMember(_ teamMemberID: UUID, reason: String = "Removed from organization") {
        guard let index = teamMembers.firstIndex(where: { $0.id == teamMemberID }) else {
            errorMessage = "Team member not found"
            return
        }
        
        // Soft delete - mark as terminated instead of removing
        teamMembers[index].terminate(reason: reason, type: .involuntary)
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("✅ Terminated team member: \(teamMembers[index].name)")
    }
    
    /// Permanently delete a team member (only for duplicates or never worked)
    public func permanentlyDeleteTeamMember(_ teamMemberID: UUID) -> Bool {
        guard let index = teamMembers.firstIndex(where: { $0.id == teamMemberID }),
              teamMembers[index].canBeDeleted else {
            errorMessage = "Cannot delete team member with work history"
            return false
        }
        
        let memberName = teamMembers[index].name
        teamMembers.remove(at: index)
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("🗑️ Permanently deleted team member: \(memberName)")
        return true
    }
    
    // MARK: - Team Member Queries
    
    /// Get team member by ID
    public func getTeamMember(by id: UUID) -> TeamMember? {
        return teamMembers.first { $0.id == id }
    }
    
    /// Get active team members
    public var activeTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.employmentStatus.isWorkingStatus }
    }
    
    /// Get team members available for assignment
    public var availableTeamMembers: [TeamMember] {
        return teamMembers.filter { $0.employmentStatus.canBeAssignedToProjects }
    }
    
    /// Get team members by employment type
    public func getTeamMembers(by type: EmploymentType) -> [TeamMember] {
        return teamMembers.filter { $0.employmentType == type }
    }
    
    /// Search team members by name or job title
    public func searchTeamMembers(_ query: String) -> [TeamMember] {
        guard !query.isEmpty else { return teamMembers }
        
        let lowercased = query.lowercased()
        return teamMembers.filter { member in
            member.name.lowercased().contains(lowercased) ||
            member.jobTitle.lowercased().contains(lowercased) ||
            member.email.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - Labor Hours Integration
    
    /// Get total labor hours for a team member across all projects
    public func getTotalLaborHours(for teamMemberID: UUID, in projects: [Project]) -> Double {
        return projects.reduce(0.0) { total, project in
            let memberHours = project.loggedHours.filter { hour in
                // This would need to be enhanced to link hours to specific team members
                // For now, we'll use a simple approach
                hour.employeeName.lowercased() == getTeamMember(by: teamMemberID)?.name.lowercased()
            }
            return total + memberHours.reduce(0.0) { $0 + $1.hours }
        }
    }
    
    /// Get total labor cost for a team member
    public func getTotalLaborCost(for teamMemberID: UUID, in projects: [Project]) -> Double {
        guard let member = getTeamMember(by: teamMemberID),
              let defaultRate = member.defaultRate else { return 0.0 }
        
        let totalHours = getTotalLaborHours(for: teamMemberID, in: projects)
        return totalHours * defaultRate.rate
    }
    
    /// Get team member labor summary
    public func getLaborSummary(for teamMemberID: UUID, in projects: [Project]) -> TeamMemberLaborSummary {
        let totalHours = getTotalLaborHours(for: teamMemberID, in: projects)
        let totalCost = getTotalLaborCost(for: teamMemberID, in: projects)
        
        return TeamMemberLaborSummary(
            teamMemberID: teamMemberID,
            totalHours: totalHours,
            totalCost: totalCost,
            averageHourlyRate: totalHours > 0 ? totalCost / totalHours : 0,
            projectCount: projects.count,
            lastWorked: Date() // This would be calculated from actual work logs
        )
    }
    
    // MARK: - Photo Management
    
    /// Upload team member photo
    public func uploadPhoto(_ image: UIImage, for teamMemberID: UUID) async -> Bool {
        // This would upload to CloudKit and return the asset ID
        // For now, we'll simulate it
        let photoID = UUID()
        
        guard let index = teamMembers.firstIndex(where: { $0.id == teamMemberID }) else {
            return false
        }
        
        teamMembers[index].photoID = photoID
        await saveTeamMembersToOrganization()
        
        print("📸 Uploaded photo for team member: \(teamMembers[index].name)")
        return true
    }
    
    /// Remove team member photo
    public func removePhoto(for teamMemberID: UUID) {
        guard let index = teamMembers.firstIndex(where: { $0.id == teamMemberID }) else {
            return
        }
        
        teamMembers[index].photoID = nil
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("🗑️ Removed photo for team member: \(teamMembers[index].name)")
    }
    
    // MARK: - Status Management
    
    /// Update all team member statuses based on project activity
    public func updateAllStatuses(basedOn projects: [Project]) {
        for i in 0..<teamMembers.count {
            teamMembers[i].updateStatusFromProjects(projects)
        }
        
        Task {
            await saveTeamMembersToOrganization()
        }
        
        print("🔄 Updated all team member statuses")
    }
    
    /// Get payroll summary for the organization
    public func getPayrollSummary() -> OrganizationPayrollSummary {
        let employees = teamMembers.filter { $0.employmentType == .employee }
        let contractors = teamMembers.filter { 
            $0.employmentType == .contractor || $0.employmentType == .subcontractor 
        }
        
        return OrganizationPayrollSummary(
            totalEmployees: employees.count,
            totalContractors: contractors.count,
            activeEmployees: employees.filter { $0.employmentStatus.isWorkingStatus }.count,
            activeContractors: contractors.filter { $0.employmentStatus.isWorkingStatus }.count,
            needsW9: teamMembers.filter { $0.employmentType.requiresW9 && !$0.w9OnFile }.count,
            needsI9: teamMembers.filter { $0.employmentType.requiresI9 && !$0.i9OnFile }.count
        )
    }
    
    // MARK: - Data Persistence
    
    /// Load team members from organization
    public func loadTeamMembers() async {
        isLoading = true
        defer { isLoading = false }
        
        // In a real implementation, this would fetch from CloudKit organization record
        // For now, we'll load from local storage
        if let data = UserDefaults.standard.data(forKey: "team_members_\(organizationID)"),
           let members = try? JSONDecoder().decode([TeamMember].self, from: data) {
            await MainActor.run {
                self.teamMembers = members
            }
        }
        
        print("📋 Loaded \(teamMembers.count) team members for organization")
    }
    
    /// Save team members to organization (both local and CloudKit)
    private func saveTeamMembersToOrganization() async {
        // Save locally
        if let data = try? JSONEncoder().encode(teamMembers) {
            UserDefaults.standard.set(data, forKey: "team_members_\(organizationID)")
        }
        
        // TODO: Save to CloudKit organization record
        // This would update the organization's teamMembers array in CloudKit
        
        print("💾 Saved \(teamMembers.count) team members to organization")
    }
}

// MARK: - Team Member Labor Summary

public struct TeamMemberLaborSummary: Codable, Sendable {
    public let teamMemberID: UUID
    public let totalHours: Double
    public let totalCost: Double
    public let averageHourlyRate: Double
    public let projectCount: Int
    public let lastWorked: Date
    
    public var hoursFormatted: String {
        return String(format: "%.1f hrs", totalHours)
    }
    
    public var costFormatted: String {
        return String(format: "$%.2f", totalCost)
    }
    
    public var rateFormatted: String {
        return String(format: "$%.2f/hr", averageHourlyRate)
    }
}