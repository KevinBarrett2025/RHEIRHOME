import SwiftUI

// MARK: - Temporary Stub Types (to be moved to proper location)
struct ProjectReportData {
    let project: Project
    let teamMembers: [TeamMember]
    let organization: Organization
    let generatedAt: Date
}

struct TimesheetReportData {
    let project: Project
    let teamMember: TeamMember
    let startDate: Date
    let endDate: Date
    let organization: Organization
    let workHours: [WorkHour]
}

struct BudgetReportData {
    let project: Project
    let organization: Organization
    let spendingBreakdown: SpendingBreakdown
    let generatedAt: Date
}

struct ClientReportData {
    let project: Project
    let organization: Organization
    let includeFinancials: Bool
    let progressReports: [ProgressLog]
    let generatedAt: Date
}

struct SpendingBreakdown {
    let materialCosts: Double
    let laborCosts: Double
    let generalConditions: Double
    let contingency: Double
    
    var total: Double {
        return materialCosts + laborCosts + generalConditions + contingency
    }
}

// MARK: - Project Report PDF Template
struct ProjectReportView: View {
    let data: ProjectReportData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            reportHeader
            
            // Project Overview
            projectOverviewSection
            
            // Financial Summary
            financialSummarySection
            
            // Team Members
            teamMembersSection
            
            // Recent Activity
            recentActivitySection
            
            // Footer
            reportFooter
        }
        .frame(width: 612, height: 792) // 8.5" x 11"
        .background(Color.white)
    }
    
    @ViewBuilder
    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(data.organization.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let address = data.organization.formattedBusinessAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("PROJECT REPORT")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Generated: \(data.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
        }
        .padding()
    }
    
    @ViewBuilder
    private var projectOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROJECT OVERVIEW")
                .font(.headline)
                .fontWeight(.bold)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Project Name:")
                        .fontWeight(.medium)
                    Text(data.project.name)
                }
                
                GridRow {
                    Text("Client:")
                        .fontWeight(.medium)
                    Text(data.project.client)
                }
                
                GridRow {
                    Text("Status:")
                        .fontWeight(.medium)
                    Text(data.project.status.rawValue)
                        .foregroundColor(data.project.status == .active ? .green : .orange)
                }
                
                GridRow {
                    Text("Start Date:")
                        .fontWeight(.medium)
                    Text(data.project.startDate.formatted(date: .abbreviated, time: .omitted))
                }
                
                GridRow {
                    Text("End Date:")
                        .fontWeight(.medium)
                    Text(data.project.endDate.formatted(date: .abbreviated, time: .omitted))
                }
                
                GridRow {
                    Text("Total Budget:")
                        .fontWeight(.medium)
                    Text(data.project.totalBudget.formatAsCurrency())
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var financialSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINANCIAL SUMMARY")
                .font(.headline)
                .fontWeight(.bold)
            
            let receiptTotal = data.project.receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            let laborTotal = data.project.loggedHours.reduce(0) { $0 + $1.totalPay }
            let totalSpent = receiptTotal + laborTotal
            let remaining = data.project.totalBudget - totalSpent
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Material Costs:")
                        .fontWeight(.medium)
                    Text(receiptTotal.formatAsCurrency())
                }
                
                GridRow {
                    Text("Labor Costs:")
                        .fontWeight(.medium)
                    Text(laborTotal.formatAsCurrency())
                }
                
                GridRow {
                    Text("Total Spent:")
                        .fontWeight(.medium)
                    Text(totalSpent.formatAsCurrency())
                        .fontWeight(.semibold)
                }
                
                GridRow {
                    Text("Remaining Budget:")
                        .fontWeight(.medium)
                    Text(remaining.formatAsCurrency())
                        .fontWeight(.semibold)
                        .foregroundColor(remaining < 0 ? .red : .green)
                }
                
                GridRow {
                    Text("Budget Usage:")
                        .fontWeight(.medium)
                    Text("\(Int((totalSpent / data.project.totalBudget) * 100))%")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var teamMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEAM MEMBERS")
                .font(.headline)
                .fontWeight(.bold)
            
            let activeMembers = data.teamMembers.filter { member in
                data.project.loggedHours.contains { $0.employeeID == member.id }
            }
            
            if activeMembers.isEmpty {
                Text("No team members assigned to this project")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(activeMembers.prefix(10)) { member in
                        let memberHours = data.project.loggedHours.filter { $0.employeeID == member.id }.reduce(0) { $0 + $1.hours }
                        let memberEarnings = data.project.loggedHours.filter { $0.employeeID == member.id }.reduce(0) { $0 + $1.totalPay }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text(member.name)
                                    .fontWeight(.medium)
                                Text(member.jobTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("\(memberHours, specifier: "%.1f") hrs")
                                    .font(.caption)
                                Text(memberEarnings.formatAsCurrency())
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    if activeMembers.count > 10 {
                        Text("... and \(activeMembers.count - 10) more team members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.headline)
                .fontWeight(.bold)
            
            let recentReceipts = data.project.receipts.sorted { $0.date > $1.date }.prefix(5)
            
            if recentReceipts.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(recentReceipts)) { receipt in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(receipt.vendor)
                                    .fontWeight(.medium)
                                Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(receipt.amount.formatAsCurrency())
                                    .fontWeight(.medium)
                                    .foregroundColor(receipt.isReturn ? .red : .primary)
                                Text(receipt.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var reportFooter: some View {
        Spacer()
        
        VStack {
            Divider()
            
            HStack {
                Text("This report was generated automatically by RHEIR Construction Management")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Page 1 of 1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Timesheet Report PDF Template (Minimal Implementation)
struct TimesheetReportView: View {
    let data: TimesheetReportData
    
    var body: some View {
        VStack {
            Text("Timesheet Report")
                .font(.title)
            Text("(Implementation in progress)")
                .foregroundColor(.secondary)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - Budget Report PDF Template (Minimal Implementation)
struct BudgetReportView: View {
    let data: BudgetReportData
    
    var body: some View {
        VStack {
            Text("Budget Report")
                .font(.title)
            Text("(Implementation in progress)")
                .foregroundColor(.secondary)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

// MARK: - Client Report PDF Template (Minimal Implementation)
struct ClientReportView: View {
    let data: ClientReportData
    
    var body: some View {
        VStack {
            Text("Client Report")
                .font(.title)
            Text("(Implementation in progress)")
                .foregroundColor(.secondary)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}