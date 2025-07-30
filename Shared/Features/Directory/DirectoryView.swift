import SwiftUI

struct DirectoryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAddEmployee = false
    @State private var teamMembers: [TeamMember] = []
    
    var body: some View {
        NavigationView {
            List {
                // Team Members Section
                Section(header: Text("Team Members")) {
                    if teamMembers.isEmpty {
                        DirectoryEmptyStateView {
                            showAddEmployee = true
                        }
                    } else {
                        ForEach(teamMembers) { teamMember in
                            DirectoryEmployeeRowView(employee: teamMember, authVM: authVM)
                        }
                        .onDelete(perform: deleteEmployee)
                    }
                }
                
                // Vendors Section
                DirectoryComingSoonSection(title: "Vendors", icon: "building.2")
                
                // Clients Section
                DirectoryComingSoonSection(title: "Clients", icon: "person.2")
            }
            .navigationTitle("\(authVM.currentOrg?.name ?? "Directory") Directory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddEmployee = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEmployee) {
                DirectoryAddTeamMemberView(teamMembers: $teamMembers)
            }
            .onAppear(perform: loadTeamMembers)
        }
    }
    
    // MARK: - Private Methods
    private func loadTeamMembers() {
        guard let orgID = authVM.currentOrg?.id else { return }
        
        if let data = UserDefaults.standard.data(forKey: "teamMembers_\(orgID)"),
           let members = try? JSONDecoder().decode([TeamMember].self, from: data) {
            teamMembers = members
        }
    }
    
    private func saveTeamMembers() {
        guard let orgID = authVM.currentOrg?.id else { return }
        
        if let data = try? JSONEncoder().encode(teamMembers) {
            UserDefaults.standard.set(data, forKey: "teamMembers_\(orgID)")
        }
    }
    
    private func deleteEmployee(at offsets: IndexSet) {
        teamMembers.remove(atOffsets: offsets)
        saveTeamMembers()
    }
}

// MARK: - Supporting Views
struct DirectoryEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.3")
                .foregroundColor(.gray)
            Text("No team members yet")
                .foregroundColor(.secondary)
            Spacer()
            Button("Add First Member", action: action)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }
}

struct DirectoryComingSoonSection: View {
    let title: String
    let icon: String
    
    var body: some View {
        Section(header: Text(title)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                Text("Coming Soon")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    DirectoryView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}