import SwiftUI

struct MultiSelectTeamMembersView: View {
    @Binding var selectedTeamMemberIDs: [UUID]
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if projectViewModel.teamMembers.isEmpty {
                    Section {
                        Text("No team members available")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                } else {
                    Section("Select Team Members") {
                        ForEach(projectViewModel.teamMembers) { member in
                            TeamMemberSelectionRow(
                                member: member,
                                isSelected: selectedTeamMemberIDs.contains(member.id)
                            ) {
                                toggleSelection(for: member.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Team Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleSelection(for memberID: UUID) {
        if let index = selectedTeamMemberIDs.firstIndex(of: memberID) {
            selectedTeamMemberIDs.remove(at: index)
        } else {
            selectedTeamMemberIDs.append(memberID)
        }
    }
}

struct TeamMemberSelectionRow: View {
    let member: TeamMember
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if !member.jobTitle.isEmpty {
                        Text(member.jobTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
struct MultiSelectTeamMembersView_Previews: PreviewProvider {
    static var previews: some View {
        MultiSelectTeamMembersView(selectedTeamMemberIDs: .constant([]))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
#endif