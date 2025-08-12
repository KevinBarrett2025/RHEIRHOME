import SwiftUI

/// Comprehensive Payment Dashboard for managing team member payments with analytics
struct ComprehensivePaymentDashboardView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @State private var selectedTab: DashboardTab = .overview
    @State private var selectedTeamMember: TeamMember?
    @State private var showingBatchPayment = false
    @State private var showingPaymentAnalytics = false
    @State private var showingExportOptions = false
    @State private var selectedTimeRange: TimeRange = .thisMonth
    
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case payments = "Payments"
        case analytics = "Analytics"
        case export = "Export"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.doc.horizontal"
            case .payments: return "dollarsign.circle"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .export: return "square.and.arrow.up"
            }
        }
        
        var color: Color {
            switch self {
            case .overview: return .blue
            case .payments: return .green
            case .analytics: return .purple
            case .export: return .orange
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisQuarter = "This Quarter"
        case thisYear = "This Year"
        case all = "All Time"
        
        var dateRange: (Date, Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisWeek:
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return (weekStart, now)
            case .thisMonth:
                let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return (monthStart, now)
            case .thisQuarter:
                let quarterStart = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
                return (quarterStart, now)
            case .thisYear:
                let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return (yearStart, now)
            case .all:
                return (Date.distantPast, now)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with summary stats
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content
                tabContent
            }
            .navigationTitle("Payment Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Batch Payment") {
                            showingBatchPayment = true
                        }
                        Button("Export Reports") {
                            showingExportOptions = true
                        }
                        Button("Payment Analytics") {
                            showingPaymentAnalytics = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingBatchPayment) {
            BatchPaymentProcessingView()
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingPaymentAnalytics) {
            PaymentAnalyticsView(timeRange: selectedTimeRange)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingExportOptions) {
            PaymentExportView(timeRange: selectedTimeRange)
                .environmentObject(projectVM)
        }
        .sheet(item: $selectedTeamMember) { member in
            LaborPaymentView(teamMember: member)
                .environmentObject(projectVM)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.rawValue) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            // Summary stats
            let stats = calculateSummaryStats()
            HStack {
                summaryStatCard(
                    title: "Total Unpaid",
                    value: stats.totalUnpaid.formatAsCurrency(),
                    icon: "clock.arrow.circlepath",
                    color: .orange
                )
                
                summaryStatCard(
                    title: "Paid \(selectedTimeRange.rawValue)",
                    value: stats.totalPaid.formatAsCurrency(),
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                summaryStatCard(
                    title: "Team Members",
                    value: "\(stats.activeMembers)",
                    icon: "person.3.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private func summaryStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                        }
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : tab.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? tab.color : tab.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .payments:
            paymentsContent
        case .analytics:
            analyticsContent
        case .export:
            exportContent
        }
    }
    
    @ViewBuilder
    private var overviewContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Team members with unpaid hours
                let membersWithUnpaidHours = getTeamMembersWithUnpaidHours()
                
                if !membersWithUnpaidHours.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Team Members Requiring Payment")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Button("Pay All") {
                                showingBatchPayment = true
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                        }
                        
                        ForEach(membersWithUnpaidHours, id: \.member.id) { memberData in
                            TeamMemberPaymentCard(
                                member: memberData.member,
                                unpaidHours: memberData.unpaidHours,
                                unpaidAmount: memberData.unpaidAmount,
                                onTap: {
                                    selectedTeamMember = memberData.member
                                }
                            )
                        }
                    }
                }
                
                // Recent payments
                let recentPayments = getRecentPayments()
                if !recentPayments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Payments")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        ForEach(recentPayments.prefix(5), id: \.id) { payment in
                            RecentPaymentRow(payment: payment)
                        }
                    }
                }
                
                // Payment method usage
                PaymentMethodUsageChart()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var paymentsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Quick actions
                HStack {
                    quickActionButton(
                        title: "Batch Payment",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    ) {
                        showingBatchPayment = true
                    }
                    
                    quickActionButton(
                        title: "Export Payroll",
                        icon: "square.and.arrow.up",
                        color: .blue
                    ) {
                        showingExportOptions = true
                    }
                }
                
                // All team members
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Team Members")
                        .font(.headline)
                    
                    ForEach(projectVM.teamMembers, id: \.id) { member in
                        let memberData = getTeamMemberPaymentData(member)
                        TeamMemberPaymentCard(
                            member: member,
                            unpaidHours: memberData.unpaidHours,
                            unpaidAmount: memberData.unpaidAmount,
                            showAllData: true,
                            onTap: {
                                selectedTeamMember = member
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var analyticsContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Payment trends chart
                PaymentTrendsChart(timeRange: selectedTimeRange)
                
                // Team member performance
                TeamMemberPerformanceChart()
                
                // Payment method breakdown
                PaymentMethodBreakdownChart()
                
                // Cost analysis
                LaborCostAnalysisView()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var exportContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ExportOptionsView(timeRange: selectedTimeRange)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Data Functions
    
    private func calculateSummaryStats() -> (totalUnpaid: Double, totalPaid: Double, activeMembers: Int) {
        let (startDate, endDate) = selectedTimeRange.dateRange
        
        var totalUnpaid: Double = 0
        var totalPaid: Double = 0
        let activeMembers = projectVM.teamMembers.filter { $0.isActive }.count
        
        for project in projectVM.organizationProjects {
            // Calculate unpaid hours
            let unpaidHours = project.loggedHours.filter { !$0.isPaid }
            totalUnpaid += unpaidHours.reduce(0) { $0 + ($1.hours * $1.rate) }
            
            // Calculate paid hours in date range
            let paidHours = project.loggedHours.filter { hour in
                hour.isPaid && 
                hour.date >= startDate && 
                hour.date <= endDate
            }
            totalPaid += paidHours.reduce(0) { $0 + ($1.hours * $1.rate) }
        }
        
        return (totalUnpaid, totalPaid, activeMembers)
    }
    
    private func getTeamMembersWithUnpaidHours() -> [(member: TeamMember, unpaidHours: Double, unpaidAmount: Double)] {
        return projectVM.teamMembers.compactMap { member in
            let memberData = getTeamMemberPaymentData(member)
            if memberData.unpaidHours > 0 {
                return (member, memberData.unpaidHours, memberData.unpaidAmount)
            }
            return nil
        }.sorted { $0.unpaidAmount > $1.unpaidAmount }
    }
    
    private func getTeamMemberPaymentData(_ member: TeamMember) -> (unpaidHours: Double, unpaidAmount: Double) {
        var unpaidHours: Double = 0
        var unpaidAmount: Double = 0
        
        for project in projectVM.organizationProjects {
            let memberUnpaidHours = project.loggedHours.filter { hour in
                (hour.employeeID == member.id || hour.employee.lowercased() == member.name.lowercased()) && !hour.isPaid
            }
            
            unpaidHours += memberUnpaidHours.reduce(0) { $0 + $1.hours }
            unpaidAmount += memberUnpaidHours.reduce(0) { $0 + ($1.hours * $1.rate) }
        }
        
        return (unpaidHours, unpaidAmount)
    }
    
    private func getRecentPayments() -> [WorkHour] {
        let (startDate, _) = selectedTimeRange.dateRange
        
        return projectVM.organizationProjects.flatMap { project in
            project.loggedHours.filter { hour in
                hour.isPaid && 
                (hour.paymentTimestamp ?? hour.date) >= startDate
            }
        }.sorted { 
            ($0.paymentTimestamp ?? $0.date) > ($1.paymentTimestamp ?? $1.date) 
        }
    }
}

// MARK: - Supporting Views

struct TeamMemberPaymentCard: View {
    let member: TeamMember
    let unpaidHours: Double
    let unpaidAmount: Double
    let showAllData: Bool
    let onTap: () -> Void
    
    init(member: TeamMember, unpaidHours: Double, unpaidAmount: Double, showAllData: Bool = false, onTap: @escaping () -> Void) {
        self.member = member
        self.unpaidHours = unpaidHours
        self.unpaidAmount = unpaidAmount
        self.showAllData = showAllData
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if unpaidHours > 0 {
                        Text("\(unpaidHours, specifier: "%.1f") unpaid hours")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if showAllData {
                        Text("All hours paid")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if unpaidAmount > 0 {
                        Text(unpaidAmount.formatAsCurrency())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Text("UNPAID")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else if showAllData {
                        Text("$0.00")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("PAID UP")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct RecentPaymentRow: View {
    let payment: WorkHour
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.employee)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(payment.paymentTimestamp?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text((payment.hours * payment.rate).formatAsCurrency())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("\(payment.hours, specifier: "%.1f")h @ \(payment.rate.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Placeholder views for charts - would implement with actual charting library
struct PaymentMethodUsageChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method Usage")
                .font(.headline)
            
            Text("Chart showing payment method distribution would go here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct PaymentTrendsChart: View {
    let timeRange: ComprehensivePaymentDashboardView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Trends - \(timeRange.rawValue)")
                .font(.headline)
            
            Text("Payment trends chart would go here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct TeamMemberPerformanceChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Member Performance")
                .font(.headline)
            
            Text("Performance comparison chart would go here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct PaymentMethodBreakdownChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method Breakdown")
                .font(.headline)
            
            Text("Payment method pie chart would go here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct LaborCostAnalysisView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Labor Cost Analysis")
                .font(.headline)
            
            Text("Labor cost breakdown and analysis would go here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct ExportOptionsView: View {
    let timeRange: ComprehensivePaymentDashboardView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Options - \(timeRange.rawValue)")
                .font(.headline)
            
            VStack(spacing: 12) {
                exportButton("Export Payroll CSV", icon: "doc.text") {
                    // Export payroll data
                }
                
                exportButton("Export Payment Report PDF", icon: "doc.richtext") {
                    // Export PDF report
                }
                
                exportButton("Export to QuickBooks", icon: "building.2") {
                    // Export to accounting software
                }
                
                exportButton("Export Time Sheets", icon: "clock") {
                    // Export time sheets
                }
            }
        }
    }
    
    @ViewBuilder
    private func exportButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
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
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// Placeholder views for additional features
struct BatchPaymentProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Batch Payment Processing")
                    .font(.title)
                
                Text("Batch payment interface would go here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Batch Payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct PaymentAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    let timeRange: ComprehensivePaymentDashboardView.TimeRange
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Payment Analytics")
                    .font(.title)
                
                Text("Advanced analytics for \(timeRange.rawValue) would go here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct PaymentExportView: View {
    @Environment(\.dismiss) private var dismiss
    let timeRange: ComprehensivePaymentDashboardView.TimeRange
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Export Payment Data")
                    .font(.title)
                
                Text("Export options for \(timeRange.rawValue) would go here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ComprehensivePaymentDashboardView()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}