import SwiftUI
import MessageUI

// MARK: - Supporting Data Structures 

struct VendorSpendingItem {
    let vendor: Vendor
    let totalSpent: Double
    let receiptCount: Int
}

struct PaymentMethodSpendingItem {
    let paymentMethod: PaymentMethod
    let totalSpent: Double
    let receiptCount: Int
}

// MARK: - Main Tabbed Budget View
struct BudgetBreakdownView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var selectedBudgetTab: BudgetTab = .breakdown
    
    private enum BudgetTab: String, CaseIterable {
        case breakdown = "Breakdown"
        case estimator = "Estimator"
        case teamMembers = "Team"
        case vendors = "Vendors"
        case payments = "Payments"
        
        var icon: String {
            switch self {
            case .breakdown: return "chart.pie.fill"
            case .estimator: return "sparkles.rectangle.stack.fill"
            case .teamMembers: return "person.2.fill"
            case .vendors: return "building.2.fill"
            case .payments: return "creditcard.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            UniversalHeaderView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
            
            // Custom tab bar
            customTabBar
            
            // Tab content
            TabView(selection: $selectedBudgetTab) {
                BudgetBreakdownContentView(selectedTab: $selectedTab)
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .tag(BudgetTab.breakdown)

                if let project = projectVM.selectedProject {
                    AIProjectCalculatorView(project: project)
                        .environmentObject(projectVM)
                        .environmentObject(authVM)
                        .tag(BudgetTab.estimator)
                } else {
                    ContentUnavailableView("Select a Project", systemImage: "sparkles.rectangle.stack")
                        .tag(BudgetTab.estimator)
                }
                
                ProjectTeamMembersView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .tag(BudgetTab.teamMembers)
                
                SpendingByVendorView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .tag(BudgetTab.vendors)
                
                SpendingByPaymentMethodView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
                    .tag(BudgetTab.payments)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BudgetTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedBudgetTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundColor(selectedBudgetTab == tab ? .blue : .secondary)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedBudgetTab == tab ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedBudgetTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("budget-tab-\(tab.rawValue.lowercased())")
                .accessibilityValue(selectedBudgetTab == tab ? "selected" : "unselected")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
}

// MARK: - Budget Breakdown Content View
struct BudgetBreakdownContentView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showCloseAlert = false
    @State private var showingEditProject = false
    @State private var showingReports = false

    var body: some View {
        if let project = projectVM.selectedProject {
            budgetContent(for: project)
        } else {
            emptyState
        }
    }
    
    @ViewBuilder
    private func budgetContent(for project: Project) -> some View {
        VStack(spacing: 0) {
            contentScrollView(for: project)
            actionBar(for: project)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: project)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingReports) {
            ProjectReportsView(project: project)
                .environmentObject(projectVM)
                .environmentObject(authVM)
        }
    }
    
    @ViewBuilder
    private func contentScrollView(for project: Project) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Client Information Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                        Text("Client Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    ClientCardView(project: project)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Budget Overview Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                        Text("Budget Breakdown")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    spentRemainingSection(for: project)
                    
                    categorySection(for: project)
                    
                    ProfitBarView(
                        totalBudget: project.totalBudget,
                        spentCosts: calculateTotalSpent()
                    )
                }
                
                Divider()
                
                // Quick Stats & Reports Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.purple)
                        Text("Project Analytics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    quickStatsSection(for: project)
                    
                    // Reports Access Card
                    reportsAccessCard
                }
            }
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func spentRemainingSection(for project: Project) -> some View {
        let spent = calculateTotalSpent()
        let remaining = project.totalBudget - spent
        let percentageUsed = project.totalBudget > 0 ? (spent / project.totalBudget) * 100 : 0
        
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(spent.formatAsCurrency())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(spent > project.totalBudget ? .red : .primary)
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("Budget Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(percentageUsed))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(percentageUsed > 100 ? .red : percentageUsed > 80 ? .orange : .green)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(remaining.formatAsCurrency())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(remaining < 0 ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func categorySection(for project: Project) -> some View {
        VStack(spacing: 16) {
            CategoryRowView(
                title: "General Conditions",
                spent: projectVM.spentGeneralConditions,
                total: project.generalConditions,
                linkCategory: .general,
                laborLink: false,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Materials",
                spent: projectVM.spentMaterials,
                total: project.materialCost,
                linkCategory: .material,
                laborLink: false,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Labor",
                spent: projectVM.spentLabor,
                total: project.laborCost,
                linkCategory: nil,
                laborLink: true,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Contingency",
                spent: calculateContingencySpent(for: project),
                total: project.contingency,
                linkCategory: .contingency,
                laborLink: false,
                selectedTab: $selectedTab
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func quickStatsSection(for project: Project) -> some View {
        let totalReceipts = project.receipts.count
        let totalVendors = Set(project.receipts.map { $0.vendor.lowercased() }).count
        let averageReceiptAmount = totalReceipts > 0 ? calculateTotalSpent() / Double(totalReceipts) : 0
        let timeRemaining = project.endDate.timeIntervalSince(Date()) / (24 * 60 * 60) // days
        
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickStatCard(
                icon: "receipt.fill",
                title: "Total Receipts",
                value: "\(totalReceipts)",
                subtitle: "Avg: \(averageReceiptAmount.formatAsCurrency())",
                color: .blue
            )
            
            QuickStatCard(
                icon: "building.2.fill",
                title: "Active Vendors",
                value: "\(totalVendors)",
                subtitle: "View in Vendors tab",
                color: .orange
            )
            
            QuickStatCard(
                icon: "calendar.badge.clock",
                title: "Days Remaining",
                value: timeRemaining > 0 ? "\(Int(timeRemaining))" : "Overdue",
                subtitle: project.endDate.formatted(date: .abbreviated, time: .omitted),
                color: timeRemaining > 30 ? .green : timeRemaining > 7 ? .orange : .red
            )
            
            QuickStatCard(
                icon: "percent",
                title: "Budget Used",
                value: "\(Int((calculateTotalSpent() / project.totalBudget) * 100))%",
                subtitle: "of \(project.totalBudget.formatAsCurrency())",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var reportsAccessCard: some View {
        Button {
            showingReports = true
        } label: {
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("View Detailed Reports")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Access comprehensive project analytics, spending trends, and export options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func actionBar(for project: Project) -> some View {
        HStack(spacing: 16) {
            Button("Edit Project Details") {
                showingEditProject = true
            }
            .font(.subheadline.bold())
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)

            Button("Close-out") {
                showCloseAlert = true
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.red)
            .cornerRadius(10)
            .alert("Close Project?", isPresented: $showCloseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Close-out", role: .destructive) {
                    closeProject(project)
                }
            } message: {
                Text("Are you sure you want to close this project?")
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view budget breakdown and analytics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    private func calculateTotalSpent() -> Double {
        let total = projectVM.spentGeneralConditions + 
                   projectVM.spentMaterials + 
                   projectVM.spentLabor + 
                   projectVM.spentContingency
        
        guard total.isFinite else {
            return 0
        }
        
        return max(0, total)
    }
    
    private func calculateContingencySpent(for project: Project) -> Double {
        let overageGeneral = max(0, projectVM.spentGeneralConditions - project.generalConditions)
        let overageMaterials = max(0, projectVM.spentMaterials - project.materialCost)
        let overageLabor = max(0, projectVM.spentLabor - project.laborCost)
        
        let result = projectVM.spentContingency + overageGeneral + overageMaterials + overageLabor
        
        guard result.isFinite else {
            return 0
        }
        
        return max(0, result)
    }

    private func closeProject(_ project: Project) {
        var copy = project
        copy.status = .completed
        Task {
            await projectVM.updateProject(copy)
        }
        selectedTab = .company
    }
}

// MARK: - Project Team Members View
struct ProjectTeamMembersView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingAddTeamMember = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingMemberDetail = false
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    // Team members currently working on this project (based on receipts, hours, progress)
    private var projectTeamMembers: [TeamMember] {
        guard let project = project else { return [] }
        
        // Find team members explicitly assigned to the project
        let assignedMemberIDs = Set(project.assignedTeamMemberIDs.compactMap { UUID(uuidString: $0) })
        
        // Find team members who have worked on this project
        let receiptMemberIDs = project.receipts.compactMap { $0.teamMemberID }
        let progressMemberIDs = project.progressReports.flatMap { $0.employeeIDs }
        
        // Also check logged hours (work hours) for team member activity
        let loggedHoursMemberIDs = project.loggedHours.compactMap { workHour in
            workHour.employeeID
        }
        
        // Combine all sets
        let workingMemberIDs = Set(receiptMemberIDs + progressMemberIDs + loggedHoursMemberIDs)
        let allRelevantMemberIDs = assignedMemberIDs.union(workingMemberIDs)
        
        return projectVM.teamMembers.filter { member in
            // Include if explicitly assigned or has worked on the project (including logged hours)
            allRelevantMemberIDs.contains(member.id) || 
            // Or if they're active and belong to the organization
            (member.employmentStatus.canBeAssignedToProjects && member.organizationID == project.organizationID)
        }.filter { member in
            // Filter to only show active members or those who have actually worked
            member.employmentStatus == .active ||
            assignedMemberIDs.contains(member.id) ||
            hasWorkedOnProject(member, project)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let project = project {
                projectTeamContent(for: project)
            } else {
                emptyProjectView
            }
        }
        .sheet(isPresented: $showingAddTeamMember) {
            EnhancedAddTeamMemberView()
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingMemberDetail) {
            if let member = selectedTeamMember {
                EnhancedTeamMemberDetailView(member: member)
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
        }
    }
    
    @ViewBuilder
    private func projectTeamContent(for project: Project) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Project Header
                projectHeaderSection(for: project)
                
                Divider()
                
                // Team Overview Stats
                teamOverviewSection
                
                Divider()
                
                // Current Project Team
                if projectTeamMembers.isEmpty {
                    emptyTeamSection
                } else {
                    activeTeamSection
                }
                
                Divider()
                
                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func projectHeaderSection(for project: Project) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("for \(project.name)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Project Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(project.status.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(project.status == .active ? .green : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Client")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(project.client)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var teamOverviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Team Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                TeamStatCard(
                    icon: "person.fill.checkmark",
                    title: "Active on Project",
                    value: "\(projectTeamMembers.count)",
                    subtitle: "Currently assigned",
                    color: .green
                )
                
                TeamStatCard(
                    icon: "person.badge.plus",
                    title: "Organization Members",
                    value: "\(projectVM.teamMembers.count)",
                    subtitle: "Total team size",
                    color: .blue
                )
                
                TeamStatCard(
                    icon: "dollarsign.circle",
                    title: "Total Labor Cost",
                    value: projectVM.calculateTotalLaborCost().formatAsCurrency(),
                    subtitle: "Estimated project cost",
                    color: .orange
                )
                
                TeamStatCard(
                    icon: "clock.fill",
                    title: "Hours Logged",
                    value: "\(projectVM.calculateTotalHours())",
                    subtitle: "Total project hours",
                    color: .purple
                )
            }
        }
    }
    
    @ViewBuilder
    private var activeTeamSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Project Team Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Member") {
                    showingAddTeamMember = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(projectTeamMembers) { member in
                    ProjectTeamMemberCard(member: member, project: project!) {
                        selectedTeamMember = member
                        showingMemberDetail = true
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyTeamSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Team Members Assigned")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Assign team members to this project to track their work, hours, and contributions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Team Members") {
                showingAddTeamMember = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 32)
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                QuickActionCard(
                    icon: "person.badge.plus.fill",
                    title: "Add New Team Member",
                    description: "Create a new team member and add them to your organization",
                    color: .green
                ) {
                    showingAddTeamMember = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view and manage team member assignments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func hasWorkedOnProject(_ member: TeamMember, _ project: Project) -> Bool {
        // Check if member has receipts, progress reports, or hours logged on this project
        let hasReceipts = project.receipts.contains { receipt in
            receipt.teamMemberID == member.id
        }
        let hasProgress = project.progressReports.contains { log in
            log.employeeIDs.contains(member.id)
        }
        // Also check logged hours (work hours)
        let hasLoggedHours = project.loggedHours.contains { hour in
            hour.employeeID == member.id
        }
        
        return hasReceipts || hasProgress || hasLoggedHours
    }
    
    private func getLastActivityDateForMember(_ member: TeamMember, in project: Project) -> Date? {
        let receiptDates = project.receipts.filter { receipt in
            receipt.teamMemberID == member.id
        }.map { $0.date }
        
        let progressDates = project.progressReports.filter { log in
            log.employeeIDs.contains(member.id)
        }.map { $0.date }
        
        let hourDates = project.loggedHours.filter { hour in
            hour.employeeID == member.id
        }.map { $0.date }
        
        let allDates = receiptDates + progressDates + hourDates
        return allDates.max()
    }
}

// MARK: - Spending by Vendor View
struct SpendingByVendorView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingVendorDetails = false
    @State private var showingVendorManagement = false
    @State private var selectedVendorID: UUID? = nil
    @State private var searchText = ""
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    private var vendorSpending: [VendorSpendingItem] {
        guard let project = project else { return [] }
        
        return calculateVendorSpending(for: project)
    }
    
    private var filteredVendorSpending: [VendorSpendingItem] {
        if searchText.isEmpty {
            return vendorSpending
        } else {
            return vendorSpending.filter { 
                $0.vendor.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var totalSpent: Double {
        vendorSpending.reduce(0) { $0 + $1.totalSpent }
    }
    
    var body: some View {
        if let project = project {
            VStack(spacing: 0) {
                headerSection
                
                if vendorSpending.isEmpty {
                    emptyStateView
                } else {
                    vendorListSection
                }
            }
            .searchable(text: $searchText, prompt: "Search vendors...")
            .sheet(isPresented: $showingVendorDetails) {
                if let vendorID = selectedVendorID,
                   let orgId = authVM.currentOrg?.id {
                    SimpleVendorDetailView(
                        vendorID: vendorID,
                        project: project,
                        organizationId: orgId
                    )
                    .environmentObject(projectVM)
                }
            }
            .sheet(isPresented: $showingVendorManagement) {
                VendorManagementView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
        } else {
            emptyProjectView
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Project info
            if let project = project {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Client: \(project.client)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button("Manage") {
                        showingVendorManagement = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1))
                }
            }
            
            // Summary stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Active Vendors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vendorSpending.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
    
    @ViewBuilder
    private var vendorListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredVendorSpending, id: \.vendor.id) { item in
                    VendorSpendingRowView(
                        vendor: item.vendor,
                        totalSpent: item.totalSpent,
                        receiptCount: item.receiptCount,
                        percentage: totalSpent > 0 ? item.totalSpent / totalSpent : 0
                    ) {
                        selectedVendorID = item.vendor.id
                        showingVendorDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Vendor Spending")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Receipt spending will appear here organized by vendor.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view vendor spending analysis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func calculateVendorSpending(for project: Project) -> [VendorSpendingItem] {
        // Group receipts by vendor
        let receiptsByVendor = Dictionary(grouping: project.receipts) { receipt -> String in
            return receipt.vendor.lowercased()
        }
        
        var vendorSpending: [VendorSpendingItem] = []
        
        for (vendorName, receipts) in receiptsByVendor {
            let totalSpent = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            if totalSpent > 0 {
                // Use the vendor service to get or create vendor
                let vendor = projectVM.vendorService.findOrCreateVendor(
                    name: receipts.first?.vendor ?? vendorName,
                    category: detectVendorCategory(from: vendorName)
                )
                
                vendorSpending.append(VendorSpendingItem(
                    vendor: vendor,
                    totalSpent: totalSpent,
                    receiptCount: receipts.count
                ))
            }
        }
        
        return vendorSpending.sorted { $0.totalSpent > $1.totalSpent }
    }
    
    private func detectVendorCategory(from vendorName: String) -> VendorCategory {
        let name = vendorName.lowercased()
        
        if name.contains("home depot") || name.contains("lowe") || name.contains("menards") {
            return .hardware
        } else if name.contains("lumber") || name.contains("84 lumber") {
            return .lumber
        } else if name.contains("sherwin") || name.contains("paint") {
            return .paint
        } else if name.contains("electrical") {
            return .electrical
        } else if name.contains("plumbing") {
            return .plumbing
        } else if name.contains("rental") {
            return .rental
        } else if name.contains("gas") || name.contains("shell") || name.contains("bp") || name.contains("exxon") {
            return .gas
        } else if name.contains("grocery") || name.contains("walmart") || name.contains("target") {
            return .grocery
        } else if name.contains("restaurant") || name.contains("food") {
            return .restaurant
        }
        
        return .other
    }
}

// MARK: - Spending by Payment Method View
struct SpendingByPaymentMethodView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showingPaymentDetails = false
    @State private var showingPaymentMethodManagement = false
    @State private var selectedPaymentMethodID: UUID? = nil
    @State private var searchText = ""
    
    private var project: Project? {
        projectVM.selectedProject
    }
    
    private var paymentSpending: [PaymentMethodSpendingItem] {
        guard let project = project else { return [] }
        return calculatePaymentMethodSpending(for: project)
    }
    
    private var filteredPaymentSpending: [PaymentMethodSpendingItem] {
        if searchText.isEmpty {
            return paymentSpending
        } else {
            return paymentSpending.filter {
                $0.paymentMethod.name.localizedCaseInsensitiveContains(searchText) ||
                $0.paymentMethod.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var totalSpent: Double {
        paymentSpending.reduce(0) { $0 + $1.totalSpent }
    }
    
    var body: some View {
        if let project = project {
            VStack(spacing: 0) {
                headerSection
                
                if paymentSpending.isEmpty {
                    emptyStateView
                } else {
                    paymentMethodListSection
                }
            }
            .searchable(text: $searchText, prompt: "Search payment methods...")
            .sheet(isPresented: $showingPaymentDetails) {
                if let paymentMethodID = selectedPaymentMethodID,
                   let orgId = authVM.currentOrg?.id {
                    SimplePaymentMethodDetailView(
                        paymentMethodID: paymentMethodID,
                        project: project,
                        organizationId: orgId
                    )
                    .environmentObject(projectVM)
                }
            }
            .sheet(isPresented: $showingPaymentMethodManagement) {
                PaymentMethodManagementView()
                    .environmentObject(projectVM)
                    .environmentObject(authVM)
            }
        } else {
            emptyProjectView
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Project info
            if let project = project {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Client: \(project.client)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button("Manage") {
                        showingPaymentMethodManagement = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.blue, lineWidth: 1))
                }
            }
            
            // Summary stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Payment Methods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(paymentSpending.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
    
    @ViewBuilder
    private var paymentMethodListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPaymentSpending, id: \.paymentMethod.id) { item in
                    PaymentMethodSpendingRowView(
                        paymentMethod: item.paymentMethod,
                        totalSpent: item.totalSpent,
                        receiptCount: item.receiptCount,
                        percentage: totalSpent > 0 ? item.totalSpent / totalSpent : 0
                    ) {
                        selectedPaymentMethodID = item.paymentMethod.id
                        showingPaymentDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Payment Method Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Receipt spending will appear here organized by payment method.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyProjectView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view payment method spending analysis.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func calculatePaymentMethodSpending(for project: Project) -> [PaymentMethodSpendingItem] {
        // Group receipts by payment method name to calculate totals
        let receiptsByPaymentMethod = Dictionary(grouping: project.receipts) { receipt in
            receipt.paymentMethod.lowercased().trimmingCharacters(in: .whitespaces)
        }
        
        var paymentSpending: [PaymentMethodSpendingItem] = []
        
        for (paymentMethodName, receipts) in receiptsByPaymentMethod {
            guard !paymentMethodName.isEmpty else { continue }
            
            let totalSpent = receipts.reduce(0) { acc, receipt in
                acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
            }
            
            if totalSpent > 0 {
                // Use the payment method service to get or create payment method
                let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
                    name: receipts.first?.paymentMethod ?? paymentMethodName,
                    type: determinePaymentType(from: paymentMethodName)
                )
                
                // Always use the actual calculated total from receipts, not the stored total
                paymentSpending.append(PaymentMethodSpendingItem(
                    paymentMethod: paymentMethod,
                    totalSpent: totalSpent,  // Use calculated total, not paymentMethod.totalSpent
                    receiptCount: receipts.count
                ))
            }
        }
        
        return paymentSpending.sorted { $0.totalSpent > $1.totalSpent }
    }
    
    // Helper function to guess payment type from payment method name
    private func determinePaymentType(from paymentMethodName: String) -> PaymentType {
        let lowercased = paymentMethodName.lowercased()
        
        if lowercased.contains("visa") || lowercased.contains("mastercard") || 
           lowercased.contains("amex") || lowercased.contains("discover") ||
           lowercased.contains("credit") || lowercased.contains("card") {
            return .creditCard
        } else if lowercased.contains("debit") {
            return .debitCard
        } else if lowercased.contains("cash") {
            return .cash
        } else if lowercased.contains("check") {
            return .check
        } else if lowercased.contains("transfer") || lowercased.contains("bank") {
            return .bankTransfer
        } else {
            return .other
        }
    }
}

// MARK: - Quick Stat Card Component
struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Project Reports View (Placeholder)
struct ProjectReportsView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Placeholder for detailed reports
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Detailed Reports")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Comprehensive project analytics and reporting will be available here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Quick actions
                        VStack(spacing: 12) {
                            Button("Export Project Summary") {
                                // TODO: Implement export functionality
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                            
                            Button("View Spending Trends") {
                                // TODO: Navigate to trends view
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Project Reports")
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
}

// MARK: - Simple Detail Views
struct SimpleVendorDetailView: View {
    let vendorID: UUID
    let project: Project
    let organizationId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    private var vendor: Vendor? {
        projectVM.vendorService.getVendor(by: vendorID)
    }
    
    private var vendorReceipts: [Receipt] {
        project.receipts.filter { receipt in
            // Convert vendorID from String? to UUID for comparison
            (receipt.vendorID.flatMap { UUID(uuidString: $0) } == vendorID) || 
            (vendor != nil && receipt.vendor.lowercased() == vendor!.name.lowercased())
        }
    }
    
    private var totalSpent: Double {
        vendorReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let vendor = vendor {
                        vendorHeaderSection(vendor)
                        spendingSummarySection
                        receiptsListSection
                    } else {
                        Text("Vendor not found")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Vendor Details")
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
    private func vendorHeaderSection(_ vendor: Vendor) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: vendorIcon(for: vendor.category))
                    .foregroundColor(.blue)
                Text(vendor.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var spendingSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Project Spending Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Total Spent", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalSpent >= 0 ? .primary : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Receipts", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(vendorReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Receipts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if vendorReceipts.isEmpty {
                Text("No receipts found for this vendor")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vendorReceipts.sorted { $0.date > $1.date }) { receipt in
                        VendorReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    private func vendorIcon(for category: VendorCategory) -> String {
        switch category {
        case .hardware: return "hammer.fill"
        case .lumber: return "tree.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .paint: return "paintbrush.fill"
        case .rental: return "wrench.and.screwdriver.fill"
        case .grocery: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .gas: return "fuelpump.fill"
        case .automotive: return "car.fill"
        case .professional: return "briefcase.fill"
        case .office: return "folder.fill"
        case .other: return "building.2.fill"
        }
    }
}

struct SimplePaymentMethodDetailView: View {
    let paymentMethodID: UUID
    let project: Project
    let organizationId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectVM: ProjectViewModel
    
    private var paymentMethod: PaymentMethod? {
        projectVM.paymentMethodService.getPaymentMethod(by: paymentMethodID)
    }
    
    private var paymentReceipts: [Receipt] {
        project.receipts.filter { receipt in
            // Convert paymentMethodID from String? to UUID for comparison
            (receipt.paymentMethodID.flatMap { UUID(uuidString: $0) } == paymentMethodID) || 
            (paymentMethod != nil && (
                receipt.paymentMethod.lowercased() == paymentMethod!.name.lowercased() ||
                receipt.paymentMethod.lowercased() == paymentMethod!.displayName.lowercased()
            ))
        }
    }
    
    private var totalSpent: Double {
        paymentReceipts.reduce(0) { acc, receipt in
            acc + (receipt.isReturn ? -receipt.amount : receipt.amount)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let paymentMethod = paymentMethod {
                        paymentMethodHeaderSection(paymentMethod)
                        spendingSummarySection
                        receiptsListSection
                    } else {
                        Text("Payment method not found")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Payment Details")
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
    private func paymentMethodHeaderSection(_ paymentMethod: PaymentMethod) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: paymentIcon(for: paymentMethod.type))
                    .foregroundColor(.green)
                Text(paymentMethod.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var spendingSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Project Spending Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Total Spent", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalSpent.formatAsCurrency())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalSpent >= 0 ? .primary : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Transactions", systemImage: "receipt.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(paymentReceipts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var receiptsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if paymentReceipts.isEmpty {
                Text("No transactions found for this payment method")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(paymentReceipts.sorted { $0.date > $1.date }) { receipt in
                        PaymentReceiptRowCard(receipt: receipt)
                    }
                }
            }
        }
    }
    
    private func paymentIcon(for type: PaymentType) -> String {
        switch type {
        case .creditCard, .debitCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Row Components

// MARK: - Vendor Spending Row View
struct VendorSpendingRowView: View {
    let vendor: Vendor
    let totalSpent: Double
    let receiptCount: Int
    let percentage: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Vendor icon and info
                HStack(spacing: 12) {
                    Image(systemName: vendorIcon)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendor.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(vendor.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(categoryColor.opacity(0.2))
                                .foregroundColor(categoryColor)
                                .cornerRadius(4)
                            
                            Text("\(receiptCount) receipt\(receiptCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Amount and percentage
                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalSpent.formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var vendorIcon: String {
        switch vendor.category {
        case .hardware: return "hammer.fill"
        case .lumber: return "tree.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .paint: return "paintbrush.fill"
        case .rental: return "wrench.and.screwdriver.fill"
        case .grocery: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .gas: return "fuelpump.fill"
        case .automotive: return "car.fill"
        case .professional: return "briefcase.fill"
        case .office: return "folder.fill"
        case .other: return "building.2.fill"
        }
    }
    
    private var categoryColor: Color {
        switch vendor.category {
        case .hardware: return .orange
        case .lumber: return .brown
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .paint: return .purple
        case .rental: return .green
        case .grocery: return .red
        case .restaurant: return .pink
        case .gas: return .black
        case .automotive: return .gray
        case .professional: return .indigo
        case .office: return .cyan
        case .other: return .secondary
        }
    }
}

// MARK: - Payment Method Spending Row View
struct PaymentMethodSpendingRowView: View {
    let paymentMethod: PaymentMethod
    let totalSpent: Double
    let receiptCount: Int
    let percentage: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Payment method icon and info
                HStack(spacing: 12) {
                    Image(systemName: paymentIcon)
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(paymentMethod.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(paymentMethod.type.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(typeColor.opacity(0.2))
                                .foregroundColor(typeColor)
                                .cornerRadius(4)
                            
                            if !paymentMethod.lastFourDigits.isEmpty {
                                Text("•••• \(paymentMethod.lastFourDigits)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(receiptCount) transaction\(receiptCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Amount and percentage
                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalSpent.formatAsCurrency())
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var paymentIcon: String {
        switch paymentMethod.type {
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    private var typeColor: Color {
        switch paymentMethod.type {
        case .creditCard: return .blue
        case .debitCard: return .green
        case .cash: return .orange
        case .check: return .purple
        case .bankTransfer: return .indigo
        case .other: return .secondary
        }
    }
}

// MARK: - Team Stat Card Component
struct TeamStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Project Team Member Card
struct ProjectTeamMemberCard: View {
    let member: TeamMember
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Member Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if member.hasAppAccess {
                            Image(systemName: "iphone")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Activity indicators
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastActivity = getLastActivityDateForMember(member, in: project) {
                        Text(lastActivity, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch member.employmentStatus {
        case .active: return .green
        case .betweenProjects: return .orange
        case .terminated: return .red
        default: return .gray
        }
    }
    
    private func getLastActivityDateForMember(_ member: TeamMember, in project: Project) -> Date? {
        let receiptDates = project.receipts.filter { receipt in
            receipt.teamMemberID == member.id
        }.map { $0.date }
        
        let progressDates = project.progressReports.filter { log in
            log.employeeIDs.contains(member.id)
        }.map { $0.date }
        
        let hourDates = project.loggedHours.filter { hour in
            hour.employeeID == member.id
        }.map { $0.date }
        
        let allDates = receiptDates + progressDates + hourDates
        return allDates.max()
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Receipt Row Cards for detail views
struct VendorReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.notes.isEmpty ? "Receipt" : receipt.notes)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if receipt.isReturn {
                        Text("RETURN")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                    
                    Text(receipt.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(receipt.isReturn ? .red : .primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PaymentReceiptRowCard: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.notes.isEmpty ? "Transaction" : receipt.notes)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(receipt.vendor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if receipt.isReturn {
                        Text("RETURN")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(receipt.isReturn ? .red : .primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AIProjectCalculatorView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    private let projectID: UUID

    @StateObject private var viewModel: AIProjectCalculatorViewModel
    @State private var selectedProposalMode: ProposalMode = .internalBudget
    @State private var selectedBudgetLineID: UUID?
    @State private var selectedMappingSource: MappingSource?
    @State private var clarificationDrafts: [UUID: String] = [:]

    init(project: Project) {
        projectID = project.id
        _viewModel = StateObject(wrappedValue: AIProjectCalculatorViewModel(project: project))
    }

    private enum ProposalMode: String, CaseIterable, Identifiable {
        case internalBudget = "Internal"
        case clientProposal = "Proposal"

        var id: Self { self }
    }

    private enum MappingSource: Identifiable {
        case receipt(Receipt)
        case workHour(WorkHour)
        case task(ProjectTask)

        var id: String {
            switch self {
            case .receipt(let receipt):
                return "receipt-\(receipt.id)"
            case .workHour(let workHour):
                return "hour-\(workHour.id.uuidString)"
            case .task(let task):
                return "task-\(task.id.uuidString)"
            }
        }

        var title: String {
            switch self {
            case .receipt(let receipt):
                return receipt.vendor
            case .workHour(let workHour):
                return "\(workHour.employee) • \(workHour.totalPay.formatAsCurrency())"
            case .task(let task):
                return task.title
            }
        }

        var buttonAccessibilityID: String {
            "ai-project-calculator-map-\(id)"
        }
    }

    private var project: Project? {
        if let matchingProject = projectVM.organizationProjects.first(where: { $0.id == projectID }) {
            return matchingProject
        }

        if let selectedProject = projectVM.selectedProject, selectedProject.id == projectID {
            return selectedProject
        }

        return nil
    }

    var body: some View {
        Group {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        statusCard(project: project)
                        intakeSection(project: project)
                        clarificationSection(project: project)
                        draftSection(project: project)
                        approvedBaselineSection(project: project)
                        mappingQueueSection(project: project)
                    }
                    .padding()
                }
                .task(id: project.id) {
                    await viewModel.load(project: project)
                }
                .sheet(item: $selectedMappingSource) { source in
                    NavigationStack {
                        Form {
                            Section("Map Actual Cost") {
                                Text(source.title)
                                    .accessibilityIdentifier("ai-project-calculator-mapping-source")
                            }

                            Section("Budget Line") {
                                Picker("Budget Line", selection: Binding(
                                    get: { selectedBudgetLineID ?? viewModel.approvedBaseline?.lines.first?.id },
                                    set: { selectedBudgetLineID = $0 }
                                )) {
                                    if let lines = viewModel.approvedBaseline?.lines {
                                        ForEach(lines) { line in
                                            Text("\(line.phase) • \(line.title)")
                                                .tag(Optional(line.id))
                                        }
                                    }
                                }
                                .accessibilityIdentifier("ai-project-calculator-mapping-line")
                            }
                        }
                        .navigationTitle("Map Cost")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    selectedBudgetLineID = nil
                                    selectedMappingSource = nil
                                }
                                .accessibilityIdentifier("ai-project-calculator-mapping-cancel")
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Save") {
                                    guard let budgetLineID = selectedBudgetLineID ?? viewModel.approvedBaseline?.lines.first?.id else {
                                        return
                                    }

                                    Task {
                                        switch source {
                                        case .receipt(let receipt):
                                            await viewModel.mapReceipt(receipt, to: budgetLineID, project: project)
                                        case .workHour(let workHour):
                                            await viewModel.mapWorkHour(workHour, to: budgetLineID, project: project)
                                        case .task(let task):
                                            await viewModel.mapTask(task, to: budgetLineID, project: project)
                                            if let baseline = viewModel.approvedBaseline,
                                               let line = baseline.lines.first(where: { $0.id == budgetLineID }) {
                                                var updatedTask = task
                                                updatedTask.budgetLineID = budgetLineID
                                                updatedTask.estimateVersionID = baseline.estimateVersionID
                                                updatedTask.phaseName = line.phase
                                                await projectVM.updateTask(updatedTask, in: project.id)
                                                if let refreshedProject = projectVM.selectedProject,
                                                   refreshedProject.id == project.id {
                                                    viewModel.rebuildVariance(project: refreshedProject)
                                                }
                                            }
                                        }
                                        selectedBudgetLineID = nil
                                        selectedMappingSource = nil
                                    }
                                }
                                .accessibilityIdentifier("ai-project-calculator-mapping-save")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Select a Project", systemImage: "folder.badge.questionmark")
            }
        }
    }

    @ViewBuilder
    private func statusCard(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Project Calculator")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(viewModel.serviceModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let baseline = viewModel.approvedBaseline {
                    Text("Baseline \(baseline.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.14), in: Capsule())
                } else {
                    Text("Draft Mode")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                }
            }

            Text("Managed backend orchestration is the long-term path. This build ships the endpoint contract plus a deterministic local fallback so baseline planning is available immediately.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let baseline = viewModel.approvedBaseline {
                let totals = baseline.totals
                HStack {
                    summaryMetric(title: "Internal", value: totals.internalTotal)
                    summaryMetric(title: "Client", value: totals.clientTotal)
                    summaryMetric(title: "Contingency", value: totals.contingency)
                }
            } else {
                Text("Start with a structured scope prompt, location, and vendor context. Approving a draft locks the live budget baseline and enables variance tracking.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func intakeSection(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Intake")
                .font(.headline)

            Picker("Project Type", selection: $viewModel.input.projectType) {
                ForEach(EstimateProjectType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            TextField("ZIP / Postal Code", text: $viewModel.input.zipCode)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("ai-project-calculator-zip")

            TextField("Preferred Vendors (comma separated)", text: Binding(
                get: { viewModel.input.preferredVendors.joined(separator: ", ") },
                set: { viewModel.input.preferredVendors = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            ))
            .accessibilityIdentifier("ai-project-calculator-vendors")

            TextField("Preferred Stores (comma separated)", text: Binding(
                get: { viewModel.input.preferredStores.joined(separator: ", ") },
                set: { viewModel.input.preferredStores = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            ))
            .accessibilityIdentifier("ai-project-calculator-stores")

            Picker("Quality", selection: $viewModel.input.qualityLevel) {
                ForEach(EstimateQualityLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }

            Picker("Schedule", selection: $viewModel.input.scheduleIntent) {
                ForEach(EstimateScheduleIntent.allCases) { schedule in
                    Text(schedule.rawValue).tag(schedule)
                }
            }

            Picker("Labor Strategy", selection: $viewModel.input.laborStrategy) {
                ForEach(EstimateLaborStrategy.allCases) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }

            Picker("Proposal Style", selection: $viewModel.input.proposalStyle) {
                ForEach(EstimateProposalStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Project Prompt")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $viewModel.input.scopePrompt)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("ai-project-calculator-prompt")
            }

            Stepper(
                "Contingency \(Int(viewModel.input.contingencyPercent))%",
                value: $viewModel.input.contingencyPercent,
                in: 0...25,
                step: 1
            )

            Toggle("Generate starter tasks on approval", isOn: $viewModel.autoGenerateStarterTasks)
                .accessibilityIdentifier("ai-project-calculator-auto-generate-tasks")

            Button {
                Task {
                    await viewModel.createSessionAndDraft(
                        project: project,
                        organizationProjects: projectVM.organizationProjects
                    )
                }
            } label: {
                Label("Build Draft Estimate", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("ai-project-calculator-build")
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func clarificationSection(project: Project) -> some View {
        if let session = viewModel.session, session.clarifications.isEmpty == false, session.isReadyForDraft == false {
            VStack(alignment: .leading, spacing: 12) {
                Text("Clarifications")
                    .font(.headline)

                ForEach(session.clarifications) { clarification in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(clarification.question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField(
                            "Answer",
                            text: Binding(
                                get: { clarificationDrafts[clarification.id] ?? clarification.answer },
                                set: { clarificationDrafts[clarification.id] = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        Button("Save Answer") {
                            Task {
                                await viewModel.answerClarification(
                                    clarification.id,
                                    answer: clarificationDrafts[clarification.id] ?? clarification.answer,
                                    project: project,
                                    organizationProjects: projectVM.organizationProjects
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func draftSection(project: Project) -> some View {
        if let draft = viewModel.draft {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Draft Review")
                        .font(.headline)
                        .accessibilityIdentifier("ai-project-calculator-draft-review")
                    Spacer()
                    Text("\(Int(draft.confidence * 100))% confidence")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                }

                Picker("View", selection: $selectedProposalMode) {
                    ForEach(ProposalMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if selectedProposalMode == .internalBudget {
                    VStack(spacing: 12) {
                        HStack {
                            summaryMetric(title: "Materials", value: draft.totals.materials)
                            summaryMetric(title: "Labor", value: draft.totals.labor + draft.totals.subcontract)
                            summaryMetric(title: "Client Total", value: draft.totals.clientTotal)
                        }

                        ForEach(Array(Dictionary(grouping: draft.lines, by: \.phase).keys.sorted()), id: \.self) { phase in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(phase)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                ForEach(draft.lines.filter { $0.phase == phase }) { line in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(line.title)
                                                .font(.subheadline)
                                            Text(line.detail)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(line.totalCost.formatAsCurrency())
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(line.lineType.rawValue.capitalized)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(draft.proposalView.executiveSummary)
                            .font(.subheadline)
                        ForEach(draft.proposalView.sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(section.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let total = section.total {
                                        Text(total.formatAsCurrency())
                                            .font(.subheadline)
                                    }
                                }
                                Text(section.body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                if draft.assumptions.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assumptions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ForEach(draft.assumptions, id: \.self) { assumption in
                            Text("• \(assumption)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button {
                    Task {
                        await viewModel.approveDraft(
                            project: project,
                            organizationProjects: projectVM.organizationProjects,
                            approvedByUserID: authVM.user?.id,
                            applyBaseline: { baseline in
                                await projectVM.applyApprovedBudgetBaseline(baseline, to: project.id)
                            },
                            generateTasks: { baseline, versionID in
                                await projectVM.generateStarterTasks(from: baseline, versionID: versionID, for: project.id)
                            }
                        )
                    }
                } label: {
                    Label("Approve Draft Baseline", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ai-project-calculator-approve")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func approvedBaselineSection(project: Project) -> some View {
        if let baseline = viewModel.approvedBaseline,
           let varianceSnapshot = viewModel.varianceSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                Text("Variance Dashboard")
                    .font(.headline)
                    .accessibilityIdentifier("ai-project-calculator-variance-dashboard")

                HStack {
                    summaryMetric(title: "Budgeted", value: varianceSnapshot.totalBudgeted, accessibilityIdentifier: "ai-project-calculator-summary-budgeted")
                    summaryMetric(title: "Committed", value: varianceSnapshot.totalCommitted, accessibilityIdentifier: "ai-project-calculator-summary-committed")
                    summaryMetric(title: "Actual", value: varianceSnapshot.totalActual, accessibilityIdentifier: "ai-project-calculator-summary-actual")
                }

                HStack {
                    summaryMetric(title: "Remaining", value: varianceSnapshot.totalRemaining, accessibilityIdentifier: "ai-project-calculator-summary-remaining")
                    summaryMetric(title: "Forecast", value: varianceSnapshot.totalForecast, accessibilityIdentifier: "ai-project-calculator-summary-forecast")
                    summaryMetric(title: "Lines", value: Double(baseline.lines.count), formatAsCurrency: false, accessibilityIdentifier: "ai-project-calculator-summary-lines")
                }

                ForEach(varianceSnapshot.lines) { line in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(line.phase)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(line.budgeted.formatAsCurrency())
                                .font(.subheadline)
                        }

                        HStack {
                            metricChip(title: "Actual", value: line.actual)
                            metricChip(title: "Committed", value: line.committed)
                            metricChip(title: "Forecast", value: line.forecast)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func mappingQueueSection(project: Project) -> some View {
        if viewModel.approvedBaseline != nil {
            let receipts = viewModel.unmatchedReceipts(for: project)
            let workHours = viewModel.unmatchedWorkHours(for: project)
            let tasks = viewModel.unmatchedTasks(for: project)

            VStack(alignment: .leading, spacing: 12) {
                Text("Needs Mapping")
                    .font(.headline)
                    .accessibilityIdentifier("ai-project-calculator-needs-mapping")

                if receipts.isEmpty && workHours.isEmpty && tasks.isEmpty {
                    Text("All current receipts, labor hours, and tasks are linked to the approved budget baseline.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("ai-project-calculator-needs-mapping-empty")
                } else {
                    ForEach(receipts, id: \.id) { receipt in
                        mappingRow(
                            title: receipt.vendor,
                            subtitle: "Receipt • \(receipt.amount.formatAsCurrency())",
                            identifier: MappingSource.receipt(receipt).buttonAccessibilityID,
                            action: {
                                selectedBudgetLineID = nil
                                selectedMappingSource = .receipt(receipt)
                            }
                        )
                    }
                    ForEach(workHours, id: \.id) { workHour in
                        mappingRow(
                            title: workHour.employee,
                            subtitle: "Labor Hour • \(workHour.totalPay.formatAsCurrency())",
                            identifier: MappingSource.workHour(workHour).buttonAccessibilityID,
                            action: {
                                selectedBudgetLineID = nil
                                selectedMappingSource = .workHour(workHour)
                            }
                        )
                    }
                    ForEach(tasks, id: \.id) { task in
                        mappingRow(
                            title: task.title,
                            subtitle: "Task • \(task.estimatedHours.formatted()) est. hrs",
                            identifier: MappingSource.task(task).buttonAccessibilityID,
                            action: {
                                selectedBudgetLineID = nil
                                selectedMappingSource = .task(task)
                            }
                        )
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func mappingRow(
        title: String,
        subtitle: String,
        identifier: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Map", action: action)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(identifier ?? "ai-project-calculator-map-action")
        }
    }

    @ViewBuilder
    private func summaryMetric(
        title: String,
        value: Double,
        formatAsCurrency: Bool = true,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        let formattedValue = formatAsCurrency ? value.formatAsCurrency() : value.formatted()
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formattedValue)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            accessibilityIdentifier
                ?? "ai-project-calculator-summary-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        )
        .accessibilityValue(formattedValue)
    }

    @ViewBuilder
    private func metricChip(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value.formatAsCurrency())
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
}
