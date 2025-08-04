import SwiftUI

struct OrganizationSelectorView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showingOrganizationMenu = false
    @State private var showingEditOrganization = false
    @State private var showingDeleteConfirmation = false
    @State private var organizationToDelete: Organization?
    
    var body: some View {
        HStack {
            Button(action: {
                showingOrganizationMenu = true
            }) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let currentOrg = authVM.currentOrg {
                            Text(currentOrg.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                if let role = authVM.currentOrganizationRole {
                                    Text(role.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(authVM.userOrganizations.count) orgs")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                // Show multi-org indicator if user belongs to multiple orgs
                                if authVM.userOrganizations.count > 1 {
                                    Image(systemName: "building.2.crop.circle")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Text("No Organization")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Tap to select")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Quick switch button for multi-org users
            if authVM.userOrganizations.count > 1 {
                Menu {
                    ForEach(authVM.userOrganizations.prefix(3)) { org in
                        if org.id != authVM.currentOrg?.id {
                            Button(action: {
                                authVM.switchToOrganization(org)
                            }) {
                                HStack {
                                    Text(org.name)
                                    if let role = authVM.organizationRoles[org.id] {
                                        Text("(\(role.displayName))")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if authVM.userOrganizations.count > 3 {
                        Divider()
                        Button("View All Organizations...") {
                            showingOrganizationMenu = true
                        }
                    }
                    
                    Divider()
                    Button("Previous Organization") {
                        authVM.switchToPreviousOrganization()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
        .sheet(isPresented: $showingOrganizationMenu) {
            OrganizationMenuView(
                showingEditOrganization: $showingEditOrganization,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                organizationToDelete: $organizationToDelete
            )
            .environmentObject(authVM)
        }
        .sheet(isPresented: $showingEditOrganization) {
            if let currentOrg = authVM.currentOrg {
                OrganizationEditView(organization: currentOrg)
                    .environmentObject(authVM)
            }
        }
        .alert(authVM.organizationRoles[organizationToDelete?.id ?? ""] == .admin ? "Delete Organization" : "Leave Organization", 
               isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                organizationToDelete = nil
            }
            Button(authVM.organizationRoles[organizationToDelete?.id ?? ""] == .admin ? "Delete" : "Leave", 
                   role: .destructive) {
                if let org = organizationToDelete {
                    deleteOrganization(org)
                }
            }
        } message: {
            if let org = organizationToDelete {
                let isAdmin = authVM.organizationRoles[org.id] == .admin
                Text(isAdmin ? 
                     "Are you sure you want to delete '\(org.name)'? This action cannot be undone and will remove all associated projects and data." :
                     "Are you sure you want to leave '\(org.name)'? You will lose access to all projects and data in this organization.")
            }
        }
    }
    
    private func deleteOrganization(_ organization: Organization) {
        guard let role = authVM.organizationRoles[organization.id] else {
            print("❌ Unable to determine role for organization")
            return
        }
        
        if role == .admin {
            // Delete organization
            authVM.deleteOrganization(organization) { success, message in
                if success {
                    print("✅ Organization deleted: \(message ?? "")")
                } else {
                    print("❌ Failed to delete organization: \(message ?? "")")
                }
            }
        } else {
            // Leave organization
            authVM.leaveOrganization(organization) { success, message in
                if success {
                    print("✅ Left organization: \(message ?? "")")
                } else {
                    print("❌ Failed to leave organization: \(message ?? "")")
                }
            }
        }
        
        organizationToDelete = nil
    }
}

struct OrganizationMenuView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var showingEditOrganization: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var organizationToDelete: Organization?
    
    @State private var showingCompanyProfile = false
    
    private var adminOrganizations: [Organization] {
        return authVM.adminOrganizations
    }
    
    private var memberOrganizations: [Organization] {
        return authVM.userOrganizations.filter { org in
            let role = authVM.organizationRoles[org.id]
            return role == .member || role == .viewer
        }
    }
    
    private var contractorOrganizations: [Organization] {
        return authVM.contractorOrganizations
    }
    
    var body: some View {
        NavigationView {
            List {
                // Company Profile Section
                if let currentOrg = authVM.currentOrg {
                    Section {
                        Button(action: {
                            showingCompanyProfile = true
                        }) {
                            HStack {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Company Profile")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Team • Vendors • Clients • Settings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Multi-Organization Context Section (for contractors)
                if authVM.userOrganizations.count > 1 {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "building.2.crop.circle")
                                    .foregroundColor(.blue)
                                Text("Multi-Organization User")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Text(authVM.getOrganizationSwitchingContext())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if UserDefaults.standard.string(forKey: "previousOrganizationID") != nil {
                                Button("Switch to Previous Organization") {
                                    authVM.switchToPreviousOrganization()
                                    dismiss()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Current Organization Section
                if let currentOrg = authVM.currentOrg {
                    Section("Current Organization") {
                        currentOrganizationRow(currentOrg)
                    }
                }
                
                // Admin Organizations (ones you own)
                if !adminOrganizations.isEmpty {
                    Section("Your Organizations") {
                        ForEach(adminOrganizations, id: \.id) { organization in
                            organizationRow(organization)
                        }
                    }
                }
                
                // Member Organizations (ones you're part of)
                if !memberOrganizations.isEmpty {
                    Section("Team Member") {
                        ForEach(memberOrganizations, id: \.id) { organization in
                            organizationRow(organization)
                        }
                    }
                }
                
                // Contractor Organizations (limited access)
                if !contractorOrganizations.isEmpty {
                    Section("Contractor Access") {
                        ForEach(contractorOrganizations, id: \.id) { organization in
                            contractorOrganizationRow(organization)
                        }
                    }
                }
                
                // Create New Organization
                Section {
                    Button(action: {
                        dismiss()
                        // Use the AuthViewModel's state management to trigger organization setup
                        authVM.showOrganizationSetup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Create New Organization")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Invite Management for Multi-Org Users
                if authVM.userOrganizations.count > 1 && authVM.canPerformAdminActions {
                    Section("Invite Management") {
                        Button(action: {
                            let teamInvite = authVM.getTeamMemberInviteLink() ?? "Unable to create invite"
                            UIPasteboard.general.string = teamInvite
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.green)
                                Text("Create Team Member Invite")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: {
                            let contractorInvite = authVM.getContractorInviteURLForCopying()
                            UIPasteboard.general.string = contractorInvite
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "hammer.circle")
                                    .foregroundColor(.orange)
                                Text("Create Contractor Invite")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Organizations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCompanyProfile) {
                CompanyProfileView()
                    .environmentObject(authVM)
            }
        }
    }
    
    private func currentOrganizationRow(_ organization: Organization) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(organization.name)
                        .font(.headline)
                    
                    if let role = authVM.organizationRoles[organization.id] {
                        Text(role.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(role == .admin ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(role == .admin ? .blue : .green)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(organization.members.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons for current org
            HStack(spacing: 16) {
                if authVM.organizationRoles[organization.id] == .admin {
                    Button(action: {
                        dismiss()
                        showingEditOrganization = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: {
                        organizationToDelete = organization
                        dismiss()
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: authVM.organizationRoles[organization.id] == .admin ? "trash" : "rectangle.portrait.and.arrow.right")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(authVM.organizationRoles[organization.id] == .admin ? "Delete" : "Leave")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Text("CURRENT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func organizationRow(_ organization: Organization) -> some View {
        Button(action: {
            authVM.switchToOrganization(organization)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(organization.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let role = authVM.organizationRoles[organization.id] {
                            Text(role.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(role == .admin ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundColor(role == .admin ? .blue : .green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(organization.members.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if organization.id == authVM.currentOrg?.id {
                    Text("CURRENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
    
    private func contractorOrganizationRow(_ organization: Organization) -> some View {
        Button(action: {
            authVM.switchToOrganization(organization)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(organization.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Contractor")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    Text("Limited project access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if organization.id == authVM.currentOrg?.id {
                    Text("CURRENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Switch")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
}

#Preview {
    OrganizationSelectorView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}