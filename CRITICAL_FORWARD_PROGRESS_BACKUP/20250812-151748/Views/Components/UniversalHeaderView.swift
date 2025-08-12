import SwiftUI

/// Universal header component that provides consistent branding and project context across all main tabs
struct UniversalHeaderView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    let showSettingsGear: Bool
    let showProjectContext: Bool
    
    // Cache tier information for performance
    @State private var cachedTierInfo: (tier: SubscriptionTier, timestamp: Date)?
    private let cacheInterval: TimeInterval = 30 // Cache for 30 seconds
    
    init(
        showSettingsGear: Bool = true,
        showProjectContext: Bool = true
    ) {
        self.showSettingsGear = showSettingsGear
        self.showProjectContext = showProjectContext
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main organization header
            HStack {
                // Organization branding - simplified to just show name
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
        .onAppear {
            updateTierCache()
        }
        .onChange(of: authVM.currentOrg?.subscriptionTier) { _, _ in
            updateTierCache()
        }
    }
    
    private func updateTierCache() {
        if let currentOrg = authVM.currentOrg {
            cachedTierInfo = (tier: currentOrg.subscriptionTier, timestamp: Date())
        }
    }
    
    private var currentTier: SubscriptionTier? {
        // Use cached tier if available and fresh
        if let cache = cachedTierInfo,
           Date().timeIntervalSince(cache.timestamp) < cacheInterval {
            return cache.tier
        }
        
        // FIXED: Don't modify state during view rendering
        // Just return the current org tier directly if cache is stale
        return authVM.currentOrg?.subscriptionTier
    }
    
    @ViewBuilder
    private var organizationBranding: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Simple organization name display - no dropdown
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
            // Subscription tier indicator (optimized with caching)
            if let tier = currentTier {
                tierIndicator(tier)
            }
            
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
                    PersonalSettingsView()
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
    private func tierIndicator(_ tier: SubscriptionTier) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tierIcon(tier))
                .font(.caption2)
                .foregroundColor(tierColor(tier))
            
            Text(tierDisplayName(tier))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(tierColor(tier))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tierColor(tier).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tierColor(tier).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func tierIcon(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free, .starter: return "person.fill"
        case .professional, .standard: return "briefcase.fill"
        case .enterprise, .premium: return "crown.fill"
        }
    }
    
    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free, .starter: return .gray
        case .professional, .standard: return .blue
        case .enterprise, .premium: return .purple
        }
    }
    
    private func tierDisplayName(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "Free"
        case .starter: return "Starter"
        case .professional: return "Pro"
        case .standard: return "Standard"
        case .enterprise: return "Enterprise"
        case .premium: return "Premium"
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