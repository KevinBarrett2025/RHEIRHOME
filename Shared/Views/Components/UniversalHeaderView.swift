import SwiftUI

/// Universal header component that provides consistent branding and project context across all main tabs
struct UniversalHeaderView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    let showSettingsGear: Bool
    let showOrganizationSelector: Bool
    let showProjectContext: Bool
    
    init(
        showSettingsGear: Bool = true,
        showOrganizationSelector: Bool = false,
        showProjectContext: Bool = true
    ) {
        self.showSettingsGear = showSettingsGear
        self.showOrganizationSelector = showOrganizationSelector
        self.showProjectContext = showProjectContext
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main organization header
            HStack {
                // Organization branding
                organizationBranding
                
                Spacer()
                
                // Controls section
                headerControls
            }
            
            // Project context (when available and enabled)
            if showProjectContext && projectVM.selectedProject != nil {
                projectContextView
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var organizationBranding: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showOrganizationSelector {
                // Use the organization selector from LandingPageView
                OrganizationSelectorView()
                    .environmentObject(authVM)
            } else {
                // Simple organization name display
                if let org = authVM.currentOrg {
                    Text(org.name.uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("RHEIR HOME")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Role indicator for multi-org users
            if authVM.userOrganizations.count > 1,
               let role = authVM.currentOrganizationRole {
                Text(role.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var headerControls: some View {
        HStack(spacing: 16) {
            // Multi-org indicator
            if authVM.userOrganizations.count > 1 {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(authVM.userOrganizations.count) orgs")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Settings gear
            if showSettingsGear {
                NavigationLink {
                    MasterCompanySettingsView()
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var projectContextView: some View {
        if let project = projectVM.selectedProject {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Project")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Project status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(getStatusColor(for: project.status))
                        .frame(width: 8, height: 8)
                    
                    Text(project.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func getStatusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .active: return .green
        case .completed: return .blue
        case .onHold: return .orange
        case .cancelled: return .red
        case .planning: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            UniversalHeaderView()
            Spacer()
        }
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel())
    }
}