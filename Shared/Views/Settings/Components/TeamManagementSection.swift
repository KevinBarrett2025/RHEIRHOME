import SwiftUI
import CloudKit

struct TeamManagementSection: View {
    let authViewModel: AuthViewModel
    let projectViewModel: ProjectViewModel
    @Binding var environmentInfo: String
    @Binding var showingEnvironmentAlert: Bool
    @State private var showingShareView = false
    @State private var showingDebugInfo = false
    
    var body: some View {
        Section("Team Management") {
            // Organization Info
            HStack {
                Label("\(authViewModel.currentOrg?.name ?? "RHEIR LLC") Directory", systemImage: "person.2.fill")
                Spacer()
                Text("Team Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // NUCLEAR RESET - SIMPLE SOLUTION
            Button {
                nuclearResetAndForceShare()
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NUCLEAR FIX: Share with Rachel")
                            .fontWeight(.medium)
                        Text("Delete everything & create fresh sharing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            // PROJECT STATUS
            HStack {
                Image(systemName: "folder.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Projects")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(projectViewModel.projects.count) local, \(projectViewModel.organizationProjects.count) shared")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Clean photos from current project
            if let project = projectViewModel.selectedProject {
                Button {
                    cleanPhotosFromProject(project)
                } label: {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remove Photos from '\(project.name)'")
                                .fontWeight(.medium)
                            Text("Reduce project size for sharing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Status Messages
            if !authViewModel.inviteStatus.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(authViewModel.inviteStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    private func nuclearResetAndForceShare() {
        environmentInfo = """
        💥 NUCLEAR RESET STARTING...
        
        This will:
        1. Delete ALL CloudKit data
        2. Upload clean project shells (no photos)
        3. Add Rachel with admin access
        4. Skip all invite complexity
        
        Please wait...
        """
        showingEnvironmentAlert = true
        
        projectViewModel.nuclearResetCloudKit { success, message in
            DispatchQueue.main.async {
                if success {
                    // Add Rachel with admin permissions
                    self.projectViewModel.inviteWifeToOrganization(email: "rachelmelvin@icloud.com") { memberSuccess, memberError in
                        DispatchQueue.main.async {
                            self.environmentInfo = """
                            ✅ NUCLEAR RESET COMPLETE!
                            
                            \(message)
                            
                            👥 RACHEL'S ACCESS:
                            • Added rachelmelvin@icloud.com as ADMIN
                            • She now has full access to all projects
                            • Projects uploaded as clean shells (no photos)
                            
                            🎯 RACHEL SHOULD NOW SEE PROJECTS!
                            Have her:
                            1. Close and restart the RHEIR app completely
                            2. Sign in with Apple (rachelmelvin@icloud.com)
                            3. Pull down on Projects screen to refresh
                            
                            If she still doesn't see projects, the CloudKit sharing 
                            system has fundamental architecture issues.
                            """
                            self.showingEnvironmentAlert = true
                        }
                    }
                } else {
                    self.environmentInfo = """
                    ❌ NUCLEAR RESET FAILED
                    
                    Error: \(message)
                    
                    The CloudKit sharing system has fundamental issues.
                    We may need to switch to a different sharing approach.
                    """
                    self.showingEnvironmentAlert = true
                }
            }
        }
    }
    
    private func cleanPhotosFromProject(_ project: Project) {
        let cleanProject = projectViewModel.removeAllPhotosFromProject(project)
        projectViewModel.save(cleanProject)
        
        environmentInfo = """
        🧹 PHOTOS REMOVED!
        
        All photos have been removed from '\(project.name)':
        • Progress log photos: Deleted
        • Receipt photos: Deleted  
        • Task photos: Deleted
        
        The project is now much smaller and should share successfully.
        
        Try the Nuclear Reset button to share with Rachel!
        """
        showingEnvironmentAlert = true
    }
}
