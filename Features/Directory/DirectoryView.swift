import SwiftUI

struct DirectoryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var showAddEmployee = false
    
    var body: some View {
        VStack(spacing: 0) {
            // CRITICAL FIX: Add UniversalHeaderView for consistency
            UniversalHeaderView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
            
            List {
                // Team Members Section
                Section(header: Text("Team Members")) {
                    if projectVM.teamMembers.isEmpty {
                        DirectoryEmptyStateView {
                            showAddEmployee = true
                        }
                    } else {
                        ForEach(projectVM.teamMembers) { teamMember in
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
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddEmployee = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEmployee) {
            DirectoryAddTeamMemberView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
        }
    }
    
    // MARK: - Private Methods
    private func deleteEmployee(at offsets: IndexSet) {
        // Handle deletions through the proper methods
        for index in offsets {
            if index < projectVM.teamMembers.count {
                let teamMember = projectVM.teamMembers[index]
                projectVM.deleteTeamMember(teamMember)
            }
        }
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
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}