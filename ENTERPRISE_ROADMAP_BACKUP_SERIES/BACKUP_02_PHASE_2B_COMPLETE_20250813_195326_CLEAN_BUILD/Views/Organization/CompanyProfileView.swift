import SwiftUI

struct CompanyProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: CompanyProfileTab = .teamMembers
    @State private var showingAddTeamMember = false
    @State private var showingInviteTeamMember = false
    
    enum CompanyProfileTab: String, CaseIterable {
        case teamMembers = "Team Members"
        case vendors = "Vendors"
        case clients = "Clients"
        case paymentMethods = "Payment Methods"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .teamMembers: return "person.2.fill"
            case .vendors: return "storefront.fill"
            case .clients: return "person.crop.circle.fill"
            case .paymentMethods: return "creditcard.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .teamMembers: return .blue
            case .vendors: return .orange
            case .clients: return .green
            case .paymentMethods: return .purple
            case .settings: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentOrg = authVM.currentOrg {
                    // Company Header
                    companyHeader(currentOrg)
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content based on selected tab
                    tabContent
                } else {
                    noOrganizationView
                }
            }
            .navigationTitle("Company Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .teamMembers && authVM.canPerformAdminActions {
                        Menu {
                            Button("Add Internal Team Member") {
                                showingAddTeamMember = true
                            }
                            Button("Invite External Collaborator") {
                                showingInviteTeamMember = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTeamMember) {
                EnhancedAddTeamMemberView()
                    .environmentObject(projectVM)
            }
            .sheet(isPresented: $showingInviteTeamMember) {
                CreateTeamInviteView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
            }
        }
    }
    
    @ViewBuilder
    private func companyHeader(_ organization: Organization) -> some View {
        VStack(spacing: 16) {
            HStack {
                // Company Avatar/Logo placeholder
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(organization.name.prefix(2)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(organization.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let role = authVM.currentOrganizationRole {
                        Text("Your role: \(role.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(organization.members.count) team members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(projectVM.projects.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Projects")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Organization switching for multi-org users
            if authVM.userOrganizations.count > 1 {
                HStack {
                    Image(systemName: "building.2.crop.circle")
                        .foregroundColor(.blue)
                    Text("You belong to \(authVM.userOrganizations.count) organizations")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    Button("Switch") {
                        // This could trigger the organization selector
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CompanyProfileTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.title3)
                                .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                            
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? tab.color.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTab == tab ? tab.color : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .teamMembers:
                TeamMembersTabView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
            case .vendors:
                VendorsTabView()
                    .environmentObject(projectVM)
            case .clients:
                ClientsTabView()
                    .environmentObject(projectVM)
            case .paymentMethods:
                PaymentMethodsTabView()
                    .environmentObject(projectVM)
            case .settings:
                OrganizationSettingsTabView()
                    .environmentObject(authVM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var noOrganizationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Organization Selected")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select an organization to view its company profile")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Select Organization") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Team Members Tab
struct TeamMembersTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var showingTeamMemberDetail = false
    @State private var selectedTeamMember: TeamMember?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Invite section for admins
            if authVM.canPerformAdminActions {
                inviteSection
            }
            
            // Team members list
            teamMembersList
        }
        .padding()
        .sheet(item: $selectedTeamMember) { member in
            EnhancedTeamMemberDetailView(member: member)
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Team")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button {
                    // Create team member invite
                    if let inviteURL = authVM.getTeamMemberInviteLink() {
                        UIPasteboard.general.string = inviteURL
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invite Team Member")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                
                Button {
                    // Create contractor invite
                    let contractorURL = authVM.getContractorInviteURLForCopying()
                    UIPasteboard.general.string = contractorURL
                } label: {
                    HStack {
                        Image(systemName: "hammer.circle")
                        Text("Invite Contractor")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var teamMembersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Team Members")
                    .font(.headline)
                
                Spacer()
                
                Text("\(projectVM.teamMembers.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if projectVM.teamMembers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No team members yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Add internal team members or invite external collaborators")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(projectVM.teamMembers) { member in
                        TeamMemberRowView(member: member) {
                            selectedTeamMember = member
                            showingTeamMemberDetail = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Team Member Row
struct TeamMemberRowView: View {
    let member: TeamMember
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(member.employmentType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        if member.hasAppAccess {
                            Image(systemName: "iphone")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let defaultRate = member.rates.first(where: { $0.isDefault }) {
                        Text("$\(defaultRate.rate, specifier: "%.0f")/hr")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Other Tab Views (Simplified for now)
struct VendorsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Vendors")
                .font(.title)
            Text("Coming soon - Master vendor list with contact info and purchase history")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ClientsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Clients")
                .font(.title)
            Text("Coming soon - Client directory with contact info and project history")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct PaymentMethodsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Payment Methods")
                .font(.title)
            Text("Coming soon - Company payment methods and financial accounts")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct OrganizationSettingsTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        VStack {
            Text("Organization Settings")
                .font(.title)
            Text("Coming soon - Organization preferences and administrative settings")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    CompanyProfileView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}