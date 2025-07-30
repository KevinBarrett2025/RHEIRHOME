import SwiftUI

struct OrganizationSwitcherView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrganization: Organization?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerSection
                
                organizationsList
                
                Spacer()
                
                actionButtons
            }
            .padding()
            .navigationTitle("Switch Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Select Organization")
                .font(.title2)
                .fontWeight(.bold)
            
            if let currentOrg = authVM.currentOrg {
                Text("Currently viewing: \(currentOrg.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var organizationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(authVM.userOrganizations) { organization in
                    OrganizationRow(
                        organization: organization,
                        role: authVM.organizationRoles[organization.id] ?? .member,
                        isSelected: authVM.currentOrg?.id == organization.id,
                        onTap: {
                            selectedOrganization = organization
                        }
                    )
                }
                
                if authVM.userOrganizations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No Organizations")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Create an organization or ask someone to invite you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let selected = selectedOrganization,
               selected.id != authVM.currentOrg?.id {
                Button("Switch to \(selected.name)") {
                    authVM.switchToOrganization(selected)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button("Create New Organization") {
                // Navigate to organization creation
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
}

struct OrganizationRow: View {
    let organization: Organization
    let role: OrganizationRole
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Organization Icon
                Image(systemName: roleIcon)
                    .font(.system(size: 24))
                    .foregroundColor(roleColor)
                    .frame(width: 40, height: 40)
                    .background(roleColor.opacity(0.1))
                    .cornerRadius(8)
                
                // Organization Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(organization.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(role.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(roleColor.opacity(0.2))
                            .foregroundColor(roleColor)
                            .cornerRadius(4)
                        
                        Text("\(organization.members.count) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var roleIcon: String {
        switch role {
        case .admin: return "crown.fill"
        case .member: return "person.fill"
        case .contractor: return "hammer.fill"
        case .viewer: return "eye.fill"
        }
    }
    
    private var roleColor: Color {
        switch role {
        case .admin: return .orange
        case .member: return .blue
        case .contractor: return .green
        case .viewer: return .gray
        }
    }
}

#Preview {
    OrganizationSwitcherView()
        .environmentObject(AuthViewModel(service: CloudKitAuthService()))
}