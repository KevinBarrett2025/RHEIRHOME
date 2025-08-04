import SwiftUI

struct EnhancedOrganizationDirectoryView: View {
    let organization: Organization
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var showingAddTeamMember = false
    @State private var showingSensitiveInfo = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingTeamMemberDetail = false
    @State private var showingTerminationDialog = false
    @State private var showingProjectAssignment = false
    @State private var teamMemberToTerminate: TeamMember?
    @State private var teamMemberToAssign: TeamMember?
    
    // Smart project-based team member categorization
    private var activeTeamMembers: [TeamMember] {
        return projectVM.teamMembers.compactMap { member in
            var updatedMember = member
            updatedMember.updateStatusFromProjects(projectVM.allProjects)
            return updatedMember.employmentStatus == .active ? updatedMember : nil
        }
    }
    
    private var betweenProjectsMembers: [TeamMember] {
        return projectVM.teamMembers.compactMap { member in
            var updatedMember = member
            updatedMember.updateStatusFromProjects(projectVM.allProjects)
            return updatedMember.employmentStatus == .betweenProjects ? updatedMember : nil
        }
    }
    
    private var completedTeamMembers: [TeamMember] {
        return projectVM.teamMembers.compactMap { member in
            var updatedMember = member
            updatedMember.updateStatusFromProjects(projectVM.allProjects)
            return updatedMember.employmentStatus == .completed ? updatedMember : nil
        }
    }
    
    private var inactiveTeamMembers: [TeamMember] {
        return projectVM.teamMembers.filter { 
            $0.employmentStatus == .terminated || 
            $0.employmentStatus == .suspended || 
            $0.employmentStatus == .onLeave 
        }
    }
    
    private var appUsers: Int {
        return activeTeamMembers.filter { $0.hasAppAccess }.count + 1 // +1 for current user
    }
    
    var body: some View {
        List {
            organizationOverviewSection
            businessDetailsSection
            activeTeamMembersSection
            
            if !betweenProjectsMembers.isEmpty {
                betweenProjectsSection
            }
            
            if !completedTeamMembers.isEmpty {
                completedTeamMembersSection
            }
            
            if !inactiveTeamMembers.isEmpty {
                inactiveTeamMembersSection
            }
        }
        .navigationTitle("\(organization.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Team Member") {
                    showingAddTeamMember = true
                }
            }
        }
        .sheet(isPresented: $showingAddTeamMember) {
            EnhancedAddTeamMemberView()
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingTeamMemberDetail) {
            if let member = selectedTeamMember {
                EnhancedTeamMemberDetailView(member: member)
                    .environmentObject(projectVM)
            }
        }
        .alert("Terminate Employee", isPresented: $showingTerminationDialog) {
            Button("Cancel", role: .cancel) {
                teamMemberToTerminate = nil
            }
            Button("Terminate", role: .destructive) {
                if let member = teamMemberToTerminate {
                    // This will show the termination detail view
                    selectedTeamMember = member
                    showingTeamMemberDetail = true
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
    }
    
    private var organizationOverviewSection: some View {
        Section("Team Status Overview") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active on Projects")
                        .font(.headline)
                    Text("Currently working")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(activeTeamMembers.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            if !betweenProjectsMembers.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Between Projects")
                            .font(.headline)
                        Text("Available for new work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(betweenProjectsMembers.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            if !completedTeamMembers.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projects Completed")
                            .font(.headline)
                        Text("All work finished")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(completedTeamMembers.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Users")
                        .font(.headline)
                    Text("iPhone app access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(appUsers)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
        }
    }
    
    private var businessDetailsSection: some View {
        Section("Business Information") {
            if let businessPhone = organization.businessPhone, !businessPhone.isEmpty {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(businessPhone)
                        .foregroundColor(.secondary)
                }
            }
            
            if let businessEmail = organization.businessEmail, !businessEmail.isEmpty {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(businessEmail)
                        .foregroundColor(.secondary)
                }
            }
            
            if let website = organization.website, !website.isEmpty {
                HStack {
                    Text("Website")
                    Spacer()
                    Text(website)
                        .foregroundColor(.secondary)
                }
            }
            
            if let address = organization.formattedBusinessAddress {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.headline)
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sensitive Information Section
            if showingSensitiveInfo {
                Group {
                    if let ein = organization.businessEIN, !ein.isEmpty {
                        HStack {
                            Text("EIN/Tax ID")
                            Spacer()
                            Text(ein)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    if let license = organization.businessLicense, !license.isEmpty {
                        HStack {
                            Text("Business License")
                            Spacer()
                            Text(license)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Button(showingSensitiveInfo ? "Hide Sensitive Info" : "Show Sensitive Info") {
                withAnimation {
                    showingSensitiveInfo.toggle()
                }
            }
            .foregroundColor(showingSensitiveInfo ? .red : .blue)
        }
    }
    
    private var activeTeamMembersSection: some View {
        Section("Active Team Members") {
            ForEach(activeTeamMembers) { member in
                teamMemberRow(member)
            }
        }
    }
    
    private var betweenProjectsSection: some View {
        Section("Available for Projects") {
            ForEach(betweenProjectsMembers) { member in
                availableTeamMemberRow(member)
            }
        }
    }
    
    private var completedTeamMembersSection: some View {
        Section("Projects Completed") {
            ForEach(completedTeamMembers) { member in
                completedTeamMemberRow(member)
            }
        }
    }
    
    private var inactiveTeamMembersSection: some View {
        Section("Inactive Team Members") {
            ForEach(inactiveTeamMembers) { member in
                inactiveTeamMemberRow(member)
            }
        }
    }
    
    private func teamMemberRow(_ member: TeamMember) -> some View {
        Button(action: {
            selectedTeamMember = member
            showingTeamMemberDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if member.hasAppAccess {
                            Image(systemName: "iphone")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text(member.employmentType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        if let defaultRate = member.defaultRate {
                            Text(defaultRate.rate.formatAsCurrency() + "/hr")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Show smart project-based status
                        let workStatus = member.getDetailedWorkStatus(from: projectVM.allProjects)
                        Text(workStatus.statusReason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !member.hasCompleteDocumentation {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(member.employmentStatus.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(member.employmentStatus == .active ? .green : .orange)
                    
                    Menu {
                        Button("View Details") {
                            selectedTeamMember = member
                            showingTeamMemberDetail = true
                        }
                        
                        Button("Terminate", role: .destructive) {
                            teamMemberToTerminate = member
                            showingTerminationDialog = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func completedTeamMemberRow(_ member: TeamMember) -> some View {
        Button(action: {
            selectedTeamMember = member
            showingTeamMemberDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Projects Complete")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                    
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Available for new projects")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Button("Assign to Project") {
                        teamMemberToAssign = member
                        showingProjectAssignment = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Menu {
                        Button("View Details") {
                            selectedTeamMember = member
                            showingTeamMemberDetail = true
                        }
                        
                        Button("Assign to Project") {
                            // TODO: Show project assignment
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func inactiveTeamMemberRow(_ member: TeamMember) -> some View {
        Button(action: {
            selectedTeamMember = member
            showingTeamMemberDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(member.employmentStatus.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                    
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let terminationDate = member.terminationDate {
                        Text("Terminated: \(terminationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("Duration: \(member.employmentDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("View History") {
                    selectedTeamMember = member
                    showingTeamMemberDetail = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func availableTeamMemberRow(_ member: TeamMember) -> some View {
        Button(action: {
            selectedTeamMember = member
            showingTeamMemberDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    let workStatus = member.getDetailedWorkStatus(from: projectVM.allProjects)
                    Text(workStatus.statusReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Button("Assign to Project") {
                        teamMemberToAssign = member
                        showingProjectAssignment = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    
                    Menu {
                        Button("View Details") {
                            selectedTeamMember = member
                            showingTeamMemberDetail = true
                        }
                        
                        Button("Assign to Project") {
                            // TODO: Show project assignment
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let sampleOrg = Organization(name: "RHEIR Construction")
    
    NavigationView {
        EnhancedOrganizationDirectoryView(organization: sampleOrg)
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
            .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
    }
}