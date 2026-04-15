import SwiftUI
import OSLog

extension Logger {
    static let company = Logger(subsystem: "com.RheirHome.RHEIR", category: "company")
}

struct MasterCompanySettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    
    @State private var selectedTab: CompanySettingsTab = .teamMembers
    @State private var showingAddTeamMember = false
    @State private var showingInviteTeamMember = false
    @State private var showingProjectInvite = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingTeamMemberDetail = false
    
    // ENTERPRISE FEATURE: Edit Company Details
    @State private var showingEditCompanyDetails = false
    
    // Simplified settings state
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum CompanySettingsTab: String, CaseIterable {
        case teamMembers = "Team"
        case vendors = "Vendors"
        case clients = "Clients"
        case paymentMethods = "Payments"
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

                    if authVM.canPerformAdminActions {
                        tabSelector
                        tabContent
                    } else {
                        restrictedAccessView
                    }
                } else {
                    noOrganizationView
                }
            }
            .navigationTitle("Company Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .teamMembers && authVM.canPerformAdminActions {
                        Menu {
                            Button("Add Internal Team Member") {
                                showingAddTeamMember = true
                            }
                            Button("Invite Team Members to Projects") {
                                showingProjectInvite = true
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
            .sheet(isPresented: $showingProjectInvite) {
                InviteTeamMemberToProjectView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
            }
            .sheet(item: $selectedTeamMember) { member in
                EnhancedTeamMemberDetailView(member: member)
                    .environmentObject(projectVM)
            }
            .alert("Status", isPresented: $showingStatusAlert) {
                Button("OK") { }
            } message: {
                Text(statusMessage)
            }
            .alert("Action Complete", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    @ViewBuilder
    private func companyHeader(_ organization: Organization) -> some View {
        VStack(spacing: 16) {
            HStack {
                // Company Avatar/Logo
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
                    HStack {
                        Text(organization.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // ENTERPRISE FEATURE: Edit Company Details Button
                        if authVM.canPerformAdminActions {
                            Button {
                                showingEditCompanyDetails = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if let role = authVM.currentOrganizationRole {
                        Text("Your role: \(role.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(projectVM.teamMembers.filter { $0.employmentStatus == .active }.count + 1) team members")
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
                        sessionStore.showOrganizationSelector()
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
        .sheet(isPresented: $showingEditCompanyDetails) {
            if let currentOrg = authVM.currentOrg {
                OrganizationEditView(organization: currentOrg)
                    .environmentObject(authVM)
            }
        }
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CompanySettingsTab.allCases, id: \.rawValue) { tab in
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
                MasterTeamMembersTabView(
                    showingAddTeamMember: $showingAddTeamMember,
                    selectedTeamMember: $selectedTeamMember
                )
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
                MasterOrganizationSettingsTabView(
                    showingStatusAlert: $showingStatusAlert,
                    statusMessage: $statusMessage,
                    showingAlert: $showingAlert,
                    alertMessage: $alertMessage
                )
                .environmentObject(authVM)
                .environmentObject(projectVM)
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
            
            Text("Select an organization to view its settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Select Organization") {
                sessionStore.showOrganizationSelector()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private var restrictedAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("Administrator Access Required")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Company management, team administration, and organization settings are only available to administrators.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if authVM.userOrganizations.count > 1 {
                Button("Switch Organization") {
                    sessionStore.showOrganizationSelector()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Master Team Members Tab (Single Source of Truth)
struct MasterTeamMembersTabView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    private let companyStore = CompanyStore()
    
    @Binding var showingAddTeamMember: Bool
    @Binding var selectedTeamMember: TeamMember?
    @State private var showingTerminationDialog = false
    @State private var showingProjectAssignment = false
    @State private var showingProjectInvite = false
    @State private var teamMemberToTerminate: TeamMember?
    @State private var teamMemberToAssign: TeamMember?
    @State private var showingInviteCopiedAlert = false
    @State private var inviteCopiedMessage = ""
    
    // Smart project-based team member categorization
    private var teamBuckets: CompanyTeamBuckets {
        companyStore.teamBuckets(teamMembers: projectVM.teamMembers, projects: projectVM.allProjects)
    }

    private var activeTeamMembers: [TeamMember] {
        teamBuckets.active
    }
    
    private var betweenProjectsMembers: [TeamMember] {
        teamBuckets.betweenProjects
    }
    
    private var completedTeamMembers: [TeamMember] {
        teamBuckets.completed
    }
    
    private var inactiveTeamMembers: [TeamMember] {
        teamBuckets.inactive
    }
    
    private var appUsers: Int {
        teamBuckets.appUsers
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Team Status Overview
                teamStatusOverview
                
                // Invite section for admins
                if authVM.canPerformAdminActions {
                    inviteSection
                }
                
                // Active Team Members
                if !activeTeamMembers.isEmpty {
                    teamMembersSection("Active on Projects", activeTeamMembers, .green)
                }
                
                // Available Team Members
                if !betweenProjectsMembers.isEmpty {
                    availableTeamMembersSection
                }
                
                // Completed Projects Team Members
                if !completedTeamMembers.isEmpty {
                    teamMembersSection("Projects Completed", completedTeamMembers, .gray)
                }
                
                // Inactive Team Members
                if !inactiveTeamMembers.isEmpty {
                    inactiveTeamMembersSection
                }
                
                // Empty state if no team members
                if projectVM.teamMembers.isEmpty {
                    emptyTeamState
                }
            }
            .padding()
        }
        .alert("Terminate Employee", isPresented: $showingTerminationDialog) {
            Button("Cancel", role: .cancel) {
                teamMemberToTerminate = nil
            }
            Button("Terminate", role: .destructive) {
                if let member = teamMemberToTerminate {
                    selectedTeamMember = member
                }
                teamMemberToTerminate = nil
            }
        } message: {
            if let member = teamMemberToTerminate {
                Text("Are you sure you want to terminate \(member.name)? This will preserve all their work history for legal and tax purposes.")
            }
        }
        .sheet(isPresented: $showingProjectAssignment) {
            if let member = teamMemberToAssign {
                ProjectAssignmentView(teamMember: member)
                    .environmentObject(projectVM)
            }
        }
        .sheet(isPresented: $showingProjectInvite) {
            InviteTeamMemberToProjectView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
        }
        .alert("Invite Copied", isPresented: $showingInviteCopiedAlert) {
            Button("OK") { }
        } message: {
            Text(inviteCopiedMessage)
        }
    }
    
    @ViewBuilder
    private var teamStatusOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Status Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statusCard("Active", "\(activeTeamMembers.count)", "Currently working", .green)
                statusCard("App Users", "\(appUsers)", "iPhone access", .purple)
                
                if !betweenProjectsMembers.isEmpty {
                    statusCard("Available", "\(betweenProjectsMembers.count)", "Ready for projects", .blue)
                }
                
                if !completedTeamMembers.isEmpty {
                    statusCard("Completed", "\(completedTeamMembers.count)", "All work finished", .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func statusCard(_ title: String, _ count: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(count)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Team")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    showingAddTeamMember = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add Internal Team Member")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                if !projectVM.teamMembers.isEmpty {
                    Button {
                        showingProjectInvite = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.circle")
                            Text("Invite Team Members to Projects")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Add team members first before you can invite them to projects")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("The team invitation flow requires existing team members in your organization.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func teamMembersSection(_ title: String, _ members: [TeamMember], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(members.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(members) { member in
                    MasterTeamMemberRowView(member: member, statusColor: color) {
                        selectedTeamMember = member
                    } onAssign: {
                        teamMemberToAssign = member
                        showingProjectAssignment = true
                    } onTerminate: {
                        teamMemberToTerminate = member
                        showingTerminationDialog = true
                    }
                    .environmentObject(projectVM)
                }
            }
        }
    }
    
    @ViewBuilder
    private var availableTeamMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available for Projects")
                    .font(.headline)
                
                Spacer()
                
                Text("\(betweenProjectsMembers.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(betweenProjectsMembers) { member in
                    AvailableTeamMemberRowView(member: member) {
                        selectedTeamMember = member
                    } onAssign: {
                        teamMemberToAssign = member
                        showingProjectAssignment = true
                    }
                    .environmentObject(projectVM)
                }
            }
        }
    }
    
    @ViewBuilder
    private var inactiveTeamMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inactive Team Members")
                    .font(.headline)
                
                Spacer()
                
                Text("\(inactiveTeamMembers.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(inactiveTeamMembers) { member in
                    InactiveTeamMemberRowView(member: member) {
                        selectedTeamMember = member
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyTeamState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No team members yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Add internal team members or invite external collaborators to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if authVM.canPerformAdminActions {
                Button("Add First Team Member") {
                    showingAddTeamMember = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
}

// MARK: - Master Team Member Row View
struct MasterTeamMemberRowView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    private let companyStore = CompanyStore()
    let member: TeamMember
    let statusColor: Color
    let onTap: () -> Void
    let onAssign: () -> Void
    let onTerminate: () -> Void
    
    private var assignedProjects: [Project] {
        companyStore.assignedProjects(for: member, in: projectVM.allProjects)
    }
    
    private var activeProjects: [Project] {
        return assignedProjects.filter { $0.status == .active }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                Circle()
                    .fill(statusColor.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if member.hasAppAccess {
                            Image(systemName: "iphone")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(member.employmentType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(4)
                        
                        // Show assigned projects
                        if !activeProjects.isEmpty {
                            Text("Active on \(activeProjects.count) project\(activeProjects.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            if !assignedProjects.isEmpty {
                                Text("All projects completed")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            } else {
                                Text("Not assigned to projects")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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
                    
                    Menu {
                        Button("View Details") { onTap() }
                        
                        if !activeProjects.isEmpty {
                            Divider()
                            ForEach(activeProjects.prefix(3)) { project in
                                Button("View \(project.name)") {
                                    // Navigate to project or show project details
                                }
                            }
                            if activeProjects.count > 3 {
                                Button("View All Projects...") { onTap() }
                            }
                        } else {
                            Button("Assign to Project") { onAssign() }
                        }
                        
                        Divider()
                        
                        Button("Terminate", role: .destructive) { onTerminate() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Available Team Member Row View
struct AvailableTeamMemberRowView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    private let companyStore = CompanyStore()
    let member: TeamMember
    let onTap: () -> Void
    let onAssign: () -> Void
    
    private var availableProjects: [Project] {
        companyStore.availableProjects(for: member, in: projectVM.allProjects)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
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
                    HStack {
                        Text(member.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Available")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Can be assigned to \(availableProjects.count) active project\(availableProjects.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if !availableProjects.isEmpty {
                    Button("Assign to Project") {
                        onAssign()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("No active projects")
                        .font(.caption2)
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

// MARK: - Inactive Team Member Row View
struct InactiveTeamMemberRowView: View {
    let member: TeamMember
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(Color.red.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(member.employmentStatus.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                    
                    Text(member.jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let terminationDate = member.terminationDate {
                        Text("Terminated: \(terminationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Button("View History") {
                    onTap()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Simplified Organization Settings Tab
struct MasterOrganizationSettingsTabView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    private let companyStore = CompanyStore()
    
    @Binding var showingStatusAlert: Bool
    @Binding var statusMessage: String
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Organization Information
                if let currentOrg = authVM.currentOrg {
                    organizationInfoSection(currentOrg)
                }
                
                // Organization Subscription
                organizationSubscriptionSection
                
                // Organization Policies
                organizationPoliciesSection
                
                // Essential Debug Tools (only for admins)
                if authVM.canPerformAdminActions {
                    essentialDebugSection
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func organizationInfoSection(_ organization: Organization) -> some View {
        let summary = companyStore.summary(
            organization: organization,
            projects: projectVM.projects,
            teamMembers: projectVM.teamMembers
        )

        VStack(alignment: .leading, spacing: 12) {
            Text("Organization Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                infoRow("Organization ID", organization.id, isMonospace: true)
                infoRow("Total Members", "\(summary.totalMembers)")
                infoRow("Active Projects", "\(summary.activeProjects)")
                infoRow("CloudKit Members", "\(summary.cloudKitMembers) app users")
                
                if let businessPhone = organization.businessPhone, !businessPhone.isEmpty {
                    infoRow("Phone", businessPhone)
                }
                
                if let businessEmail = organization.businessEmail, !businessEmail.isEmpty {
                    infoRow("Email", businessEmail)
                }
                
                if let website = organization.website, !website.isEmpty {
                    infoRow("Website", website)
                }
                
                if let address = organization.formattedBusinessAddress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var organizationSubscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription & Billing")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let currentOrg = authVM.currentOrg {
                    let summary = companyStore.summary(
                        organization: currentOrg,
                        projects: projectVM.projects,
                        teamMembers: projectVM.teamMembers
                    )
                    infoRow("Current Plan", currentOrg.subscriptionTier.displayName)
                    infoRow("Monthly Cost", currentOrg.subscriptionTier.monthlyPrice > 0 ? "$\(String(format: "%.0f", currentOrg.subscriptionTier.monthlyPrice))" : "Free")
                    infoRow("Project Limit", currentOrg.subscriptionTier.projectLimitDisplay == "∞" ? "Unlimited" : "\(currentOrg.subscriptionTier.projectLimitDisplay) projects max")
                    infoRow("Team Limit", currentOrg.subscriptionTier.teamMemberLimitDisplay == "∞" ? "Unlimited" : "\(currentOrg.subscriptionTier.teamMemberLimitDisplay) members max")
                    infoRow("Features", "\(currentOrg.subscriptionTier.features.count) included")
                    
                    // Current usage
                    infoRow("Projects Used", currentOrg.subscriptionTier.projectUsageDisplay(current: summary.currentProjects))
                    infoRow("Team Members", currentOrg.subscriptionTier.teamMemberUsageDisplay(current: summary.currentTeamMembers))
                }
                
                // Upgrade/Manage Subscription Button
                Button("Manage Subscription") {
                    // TODO: Navigate to subscription management
                    Logger.company.info("Subscription management action requested from company settings.")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var organizationPoliciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization Policies")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Retention")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Projects kept for 1 year after completion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Team Access")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Admins can manage all organization data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("All data automatically synced to CloudKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String, isMonospace: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(isMonospace ? .system(.caption, design: .monospaced) : .caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var essentialDebugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization Management")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Only keep essential production features
                Button {
                    Task {
                        statusMessage = await authVM.checkCloudKitStatus()
                        showingStatusAlert = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Check CloudKit Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Verify connectivity & permissions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Force CloudKit Sync Method
    @MainActor
    private func forceCloudKitSync() async {
        Logger.company.info("Starting force CloudKit sync from company settings.")
        
        // Step 1: Clear all local cache using AuthViewModel's nuclear clear method
        authVM.clearAllLocalCache()

        Logger.company.notice("Cleared local cache before CloudKit sync.")
        
        // Step 2: Force comprehensive CloudKit sync  
        Task {
            let syncResult = await authVM.forceCloudKitSync()
            Logger.company.notice("CloudKit sync completed from company settings [result=\(syncResult, privacy: .public)]")
            
            // Step 3: Reload organization data
            authVM.reloadOrganizationData()
            Logger.company.info("Reloaded organization data after company settings sync.")
            
            // Step 4: If current organization is set, trigger ProjectViewModel sync
            if let currentOrg = authVM.currentOrg {
                await projectVM.organizationDidChange(currentOrg.id)
                Logger.company.notice(
                    "Project view model synchronized after company settings sync [org=\(currentOrg.id, privacy: .private(mask: .hash))]"
                )
                
                alertMessage = "✅ CloudKit Sync Complete!\n\nOrganizations: \(authVM.userOrganizations.count)\nCurrent: \(currentOrg.name)\nCloudKit is now the single source of truth!"
            } else {
                alertMessage = "⚠️ CloudKit sync completed but no organizations found.\n\nYou may need to create or join an organization."
            }
            
            showingAlert = true
        }
    }
    
    @ViewBuilder
    private func debugLinkRow(_ title: String, _ icon: String, _ color: Color, _ subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func debugButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MasterCompanySettingsView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
