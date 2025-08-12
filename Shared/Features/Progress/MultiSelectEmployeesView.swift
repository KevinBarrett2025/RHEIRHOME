// MultiSelectTeamMembersView.swift
import SwiftUI

struct MultiSelectTeamMembersView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedTeamMemberIDs: [UUID]
    
    private var availableTeamMembers: [TeamMember] {
        viewModel.teamMembers.filter { !$0.isArchived }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if availableTeamMembers.isEmpty {
                    ContentUnavailableView(
                        "No Team Members",
                        systemImage: "person.3.fill",
                        description: Text("Add team members in the Labor section to assign them to progress logs.")
                    )
                } else {
                    List {
                        ForEach(availableTeamMembers) { teamMember in
                            TeamMemberSelectionRow(
                                teamMember: teamMember,
                                isSelected: selectedTeamMemberIDs.contains(teamMember.id)
                            ) {
                                toggleTeamMemberSelection(teamMember.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func toggleTeamMemberSelection(_ teamMemberID: UUID) {
        if selectedTeamMemberIDs.contains(teamMemberID) {
            selectedTeamMemberIDs.removeAll { $0 == teamMemberID }
        } else {
            selectedTeamMemberIDs.append(teamMemberID)
        }
    }
}

struct TeamMemberSelectionRow: View {
    let teamMember: TeamMember
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(teamMember.name)
                    .font(.headline)
                
                Text(teamMember.jobTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    RoleBadge(role: teamMember.role)
                    Spacer()
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct RoleBadge: View {
    let role: TeamMemberRole
    
    var body: some View {
        Text(role.displayName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(roleColor.opacity(0.2))
            .foregroundColor(roleColor)
            .cornerRadius(4)
    }
    
    private var roleColor: Color {
        switch role {
        case .admin: return .red
        case .member: return .blue
        case .viewer: return .gray
        }
    }
}

// MARK: - Backward Compatibility
typealias MultiSelectEmployeesView = MultiSelectTeamMembersView

#if DEBUG
struct MultiSelectTeamMembersView_Previews: PreviewProvider {
    static var previews: some View {
        MultiSelectTeamMembersView(selectedTeamMemberIDs: .constant([]))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
#endif
