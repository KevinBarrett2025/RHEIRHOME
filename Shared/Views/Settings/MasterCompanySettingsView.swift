import SwiftUI

struct MasterCompanySettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: CompanySettingsTab = .teamMembers
    @State private var showingAddTeamMember = false
    @State private var showingInviteTeamMember = false
    @State private var showingProjectInvite = false
    @State private var selectedTeamMember: TeamMember?
    @State private var showingTeamMemberDetail = false
    
    // Settings-related state
    @AppStorage("preferredMapProvider") private var preferredMapProvider: MapProvider = .apple
    @StateObject private var resetService = CompleteDataResetService()
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    @State private var showingNuclearResetAlert = false
    @State private var isResetting = false
    @State private var resetProgress = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingInviteCopiedAlert = false
    @State private var inviteCopiedMessage = ""
    
    enum CompanySettingsTab: String, CaseIterable {
        case teamMembers = "Team"
        case vendors = "Vendors"
        case clients = "Clients"
        case paymentMethods = "Payments"
        case businessIntelligence = "Intelligence"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .teamMembers: return "person.2.fill"
            case .vendors: return "storefront.fill"
            case .clients: return "person.crop.circle.fill"
            case .paymentMethods: return "creditcard.fill"
            case .businessIntelligence: return "brain.head.profile"
            case .settings: return "gearshape.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .teamMembers: return .blue
            case .vendors: return .orange
            case .clients: return .green
            case .paymentMethods: return .purple
            case .businessIntelligence: return .pink
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
            .navigationTitle("Company Settings")
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
            .alert("CloudKit Status", isPresented: $showingStatusAlert) {
                Button("OK") { }
            } message: {
                Text(statusMessage)
            }
            .alert("Nuclear Reset", isPresented: $showingNuclearResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset All Data", role: .destructive) {
                    performNuclearReset()
                }
            } message: {
                Text("This will permanently delete ALL local data and CloudKit data including:\n\n• All organizations\n• All team members\n• All vendors & payment methods\n• All cached projects\n• All settings\n\nThe app will restart automatically after reset. This cannot be undone.")
            }
            .alert("Debug Action", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Invite Copied", isPresented: $showingInviteCopiedAlert) {
                Button("OK") { }
            } message: {
                Text(inviteCopiedMessage)
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
                    Text(organization.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
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
                        dismiss()
                        // This will trigger the organization selector in the main view
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
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
                CompanyVendorsTabView()
                    .environmentObject(projectVM)
            case .clients:
                CompanyClientsTabView()
                    .environmentObject(projectVM)
            case .paymentMethods:
                CompanyPaymentMethodsTabView()
                    .environmentObject(projectVM)
            case .businessIntelligence:
                BusinessIntelligenceTabView()
                    .environmentObject(authVM)
                    .environmentObject(projectVM)
            case .settings:
                MasterOrganizationSettingsTabView(
                    preferredMapProvider: $preferredMapProvider,
                    showingStatusAlert: $showingStatusAlert,
                    statusMessage: $statusMessage,
                    showingNuclearResetAlert: $showingNuclearResetAlert,
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
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func performNuclearReset() {
        isResetting = true
        resetProgress = "Starting nuclear reset..."
        
        Task {
            do {
                try await resetService.performCompleteReset()
                
                await MainActor.run {
                    resetProgress = "Reset complete! Restarting app..."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        restartApp()
                    }
                }
            } catch {
                await MainActor.run {
                    isResetting = false
                    statusMessage = "❌ Nuclear reset failed: \(error.localizedDescription)"
                    showingStatusAlert = true
                }
            }
        }
    }
    
    private func restartApp() {
        #if os(iOS)
        exit(0)
        #else
        NSApplication.shared.terminate(nil)
        #endif
    }
}

// MARK: - Business Intelligence Tab (Enterprise Intelligence Dashboard)
struct BusinessIntelligenceTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var annualReport: String? = nil
    @State private var isLoadingReport = false
    @State private var showingFullReport = false
    @State private var isActivatingIntelligence = false
    @State private var intelligenceStatus: String = ""
    @State private var showingIntelligenceStatus = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Enterprise Intelligence Status
                enterpriseIntelligenceStatus
                
                // Intelligence Activation Section (Phase 2D)
                intelligenceActivationSection
                
                // Real-Time Organizational Metrics
                organizationalMetrics
                
                // Vendor Intelligence (Enhanced with Real Data)
                enhancedVendorIntelligence
                
                // Payment Method Analytics (Enhanced with Real Data)
                enhancedPaymentMethodAnalytics
                
                // Financial Intelligence
                financialIntelligence
                
                // Annual Business Reports
                annualReportsSection
                
                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
        .navigationTitle("Business Intelligence")
        .onAppear {
            loadInitialIntelligenceData()
        }
        .sheet(isPresented: $showingFullReport) {
            AnnualReportDetailView(report: annualReport ?? "No report available", year: selectedYear)
        }
        .sheet(isPresented: $showingIntelligenceStatus) {
            IntelligenceStatusDetailView(status: intelligenceStatus)
        }
    }
    
    @ViewBuilder
    private var enterpriseIntelligenceStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("Enterprise Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if projectVM.isEnterpriseIntelligenceReady {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("ACTIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("INITIALIZING")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let intelligenceReport = projectVM.getBusinessIntelligenceReport() {
                Text(intelligenceReport)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Enterprise Intelligence is building your organizational knowledge...")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Add receipts and work with projects to build your business intelligence!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Intelligence Activation Section (Phase 2D)
    @ViewBuilder
    private var intelligenceActivationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Intelligence Control Center")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                // Activate Intelligence Button
                Button {
                    activateIntelligence()
                } label: {
                    HStack {
                        if isActivatingIntelligence {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "brain.head.profile.fill")
                        }
                        Text(isActivatingIntelligence ? "Activating Intelligence..." : "Activate Real-Time Intelligence")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .foregroundColor(.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isActivatingIntelligence)
                .buttonStyle(PlainButtonStyle())
                
                // Intelligence Status Button
                Button {
                    viewIntelligenceStatus()
                } label: {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text("View Detailed Intelligence Status")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Quick intelligence stats
                let intelligenceRecords = projectVM.getReceiptIntelligenceRecords()
                if !intelligenceRecords.isEmpty {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Intelligence Records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(intelligenceRecords.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Last Updated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let lastRecord = intelligenceRecords.last,
                               let timestamp = lastRecord["date"] as? Double {
                                Text(Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Never")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var organizationalMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Organizational Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCard("Active Projects", "\(projectVM.organizationProjects.filter { $0.status == .active }.count)", "Currently running", .blue)
                metricCard("Team Members", "\(projectVM.teamMembers.count)", "In organization", .green)
                metricCard("Vendors", "\(projectVM.vendorService.vendorsSortedByName.count)", "Business partners", .orange)
                metricCard("Payment Methods", "\(projectVM.paymentMethodService.paymentMethodsSortedByName.count)", "Active methods", .purple)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var enhancedVendorIntelligence: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Smart Vendor Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All Vendors") {
                    // This would navigate to vendor management
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            let topVendorsBySpending = projectVM.getTopVendorsBySpending(limit: 5)
            
            if !topVendorsBySpending.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(topVendorsBySpending.enumerated()), id: \.offset) { index, vendorData in
                        enhancedVendorIntelligenceRow(vendorData, rank: index + 1)
                    }
                }
                
                let totalIntelligenceSpending = topVendorsBySpending.reduce(0) { $0 + $1.amount }
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.orange)
                    Text("Intelligence tracked: \(String(format: "$%.2f", totalIntelligenceSpending)) across top vendors")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("No vendor intelligence data available yet")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Add receipts and activate intelligence to build vendor spending insights!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Activate Intelligence Now") {
                        activateIntelligence()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var enhancedPaymentMethodAnalytics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Smart Payment Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Manage Methods") {
                    // This would navigate to payment method management
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            let topPaymentMethodsByUsage = projectVM.getTopPaymentMethodsByUsage(limit: 3)
            
            if !topPaymentMethodsByUsage.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(topPaymentMethodsByUsage.enumerated()), id: \.offset) { index, paymentData in
                        enhancedPaymentMethodAnalyticsRow(paymentData, rank: index + 1)
                    }
                }
                
                let totalTransactions = topPaymentMethodsByUsage.reduce(0) { $0 + $1.count }
                let totalIntelligenceAmount = topPaymentMethodsByUsage.reduce(0) { $0 + $1.amount }
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Intelligence: \(totalTransactions) transactions, \(String(format: "$%.2f", totalIntelligenceAmount)) tracked")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.purple)
                        Text("No payment method intelligence data available yet")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    
                    Text("Add receipts with payment methods and activate intelligence to build usage analytics!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Activate Intelligence Now") {
                        activateIntelligence()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var financialIntelligence: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Financial Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            let totalSpending = projectVM.organizationProjects.flatMap { $0.receipts }.reduce(0) { $0 + $1.amount }
            let averageProjectBudget = projectVM.organizationProjects.isEmpty ? 0 : projectVM.organizationProjects.reduce(0) { $0 + $1.totalBudget } / Double(projectVM.organizationProjects.count)
            let monthlySpending = totalSpending / 12.0 // Rough estimate
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                financialCard("Total Spending", "$\(String(format: "%.2f", totalSpending))", "Organization wide", .green)
                financialCard("Avg Project Budget", "$\(String(format: "%.2f", averageProjectBudget))", "Per project", .blue)
                financialCard("Monthly Spending", "$\(String(format: "%.2f", monthlySpending))", "Estimated average", .orange)
                financialCard("Active Budgets", "$\(String(format: "%.2f", projectVM.organizationProjects.filter { $0.status == .active }.reduce(0) { $0 + $1.totalBudget }))", "Current projects", .purple)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var annualReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                Text("Annual Business Reports")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Generate report for year:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach(2020...2030, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Button {
                    generateAnnualReport()
                } label: {
                    HStack {
                        if isLoadingReport {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.badge.gearshape")
                        }
                        Text(isLoadingReport ? "Generating Report..." : "Generate Annual Report")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo.opacity(0.1))
                    .foregroundColor(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isLoadingReport)
                .buttonStyle(PlainButtonStyle())
                
                if annualReport != nil {
                    Button {
                        showingFullReport = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Last Generated Report (\(selectedYear))")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton("Refresh Intelligence", "arrow.clockwise", .blue) {
                    loadInitialIntelligenceData()
                }
                
                quickActionButton("Export Data", "square.and.arrow.up", .green) {
                    // Export business intelligence data
                }
                
                quickActionButton("Sync CloudKit", "icloud.and.arrow.up", .purple) {
                    // Sync with CloudKit
                }
                
                quickActionButton("View Insights", "chart.line.uptrend.xyaxis", .orange) {
                    // Navigate to detailed insights
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func enhancedVendorIntelligenceRow(_ vendorData: (vendor: String, amount: Double), rank: Int) -> some View {
        HStack {
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.orange)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(vendorData.vendor)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Intelligence tracked: $\(String(format: "%.2f", vendorData.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                    Text("AI Tracked")
                }
                .font(.caption2)
                .foregroundColor(.orange)
                
                Text("From receipts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func enhancedPaymentMethodAnalyticsRow(_ paymentData: (paymentMethod: String, count: Int, amount: Double), rank: Int) -> some View {
        HStack {
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.purple)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(paymentData.paymentMethod)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Intelligence: \(paymentData.count) uses, $\(String(format: "%.2f", paymentData.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                    Text("AI Tracked")
                }
                .font(.caption2)
                .foregroundColor(.purple)
                
                Text("\(paymentData.count) transactions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func metricCard(_ title: String, _ value: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func financialCard(_ title: String, _ value: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func quickActionButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func activateIntelligence() {
        isActivatingIntelligence = true
        
        Task {
            print("User triggered intelligence activation from UI!")
            await projectVM.activateRealTimeIntelligence()
            
            await MainActor.run {
                isActivatingIntelligence = false
                projectVM.objectWillChange.send()
                print("Intelligence activation complete - UI refreshed!")
            }
        }
    }
    
    private func viewIntelligenceStatus() {
        intelligenceStatus = projectVM.getIntelligenceStatus()
        showingIntelligenceStatus = true
    }
    
    private func loadInitialIntelligenceData() {
        print("Loading intelligence data for dashboard...")
        
        let records = projectVM.getReceiptIntelligenceRecords()
        if records.isEmpty && !projectVM.organizationProjects.flatMap({ $0.receipts }).isEmpty {
            print("Found receipts but no intelligence records - suggesting activation")
        }
        
        projectVM.objectWillChange.send()
        
        print("Intelligence dashboard data loaded!")
    }
    
    private func generateAnnualReport() {
        isLoadingReport = true
        
        Task {
            let report = await projectVM.getAnnualBusinessReport(year: selectedYear)
            
            await MainActor.run {
                annualReport = report
                isLoadingReport = false
            }
        }
    }
}

// MARK: - Intelligence Status Detail View
struct IntelligenceStatusDetailView: View {
    let status: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(status)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .navigationTitle("Intelligence Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MasterTeamMembersTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @Binding var showingAddTeamMember: Bool
    @Binding var selectedTeamMember: TeamMember?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Master Team Members")
                    .font(.headline)
                
                Text("This integrates with the enhanced team member management system")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if authVM.canPerformAdminActions {
                    Button("Add Team Member") {
                        showingAddTeamMember = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

struct CompanyVendorsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Vendor Management")
                .font(.headline)
            Text("This will integrate with VendorManagementView")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct CompanyClientsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Client Management")
                .font(.headline)
            Text("Client directory and project history")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            let uniqueClients = Array(Set(projectVM.organizationProjects.map { $0.client })).sorted()
            
            LazyVStack {
                ForEach(uniqueClients, id: \.self) { client in
                    HStack {
                        Text(client)
                        Spacer()
                        Text("\(projectVM.organizationProjects.filter { $0.client == client }.count) projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}

struct CompanyPaymentMethodsTabView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        VStack {
            Text("Payment Method Management")
                .font(.headline)
            Text("This will integrate with PaymentMethodManagementView")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MasterOrganizationSettingsTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var projectVM: ProjectViewModel
    
    @Binding var preferredMapProvider: MapProvider
    @Binding var showingStatusAlert: Bool
    @Binding var statusMessage: String
    @Binding var showingNuclearResetAlert: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Organization Settings")
                    .font(.headline)
                
                Text("Advanced organization management and preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if authVM.canPerformAdminActions {
                    VStack(spacing: 12) {
                        Button("Debug Organization Data") {
                            alertMessage = "Organization ID: \(authVM.currentOrg?.id ?? "None")\nTeam Members: \(projectVM.teamMembers.count)"
                            showingAlert = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Nuclear Reset", role: .destructive) {
                            showingNuclearResetAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
    }
}

struct AnnualReportDetailView: View {
    let report: String
    let year: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(report)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .navigationTitle("Annual Report \(year)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        // Share the report
                    }
                }
            }
        }
    }
}

#Preview {
    MasterCompanySettingsView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
}