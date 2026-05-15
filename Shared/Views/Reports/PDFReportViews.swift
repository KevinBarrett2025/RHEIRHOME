import SwiftUI

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

            // Tasks
            taskSummarySection
            
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
    private var taskSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TASK SUMMARY")
                .font(.headline)
                .fontWeight(.bold)

            let tasks = data.project.tasks
            let completed = tasks.filter { $0.isCompleted }.count
            let open = tasks.count - completed
            let overdue = tasks.filter { $0.isOverdue }.count
            let beforePhotos = tasks.reduce(0) { $0 + $1.photoIDs.count }
            let afterPhotos = tasks.reduce(0) { $0 + $1.completionPhotoIDs.count }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    Text("Total Tasks:")
                        .fontWeight(.medium)
                    Text("\(tasks.count)")
                    Text("Completed:")
                        .fontWeight(.medium)
                    Text("\(completed)")
                }

                GridRow {
                    Text("Open Tasks:")
                        .fontWeight(.medium)
                    Text("\(open)")
                    Text("Overdue:")
                        .fontWeight(.medium)
                    Text("\(overdue)")
                        .foregroundColor(overdue > 0 ? .orange : .primary)
                }

                GridRow {
                    Text("Before Photos:")
                        .fontWeight(.medium)
                    Text("\(beforePhotos)")
                    Text("After Photos:")
                        .fontWeight(.medium)
                    Text("\(afterPhotos)")
                }
            }
            .font(.caption)

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(tasks.sorted(by: reportTaskSort).prefix(5))) { task in
                        HStack(alignment: .top) {
                            Text(task.isCompleted ? "Done" : "Open")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(task.isCompleted ? .green : .secondary)
                                .frame(width: 42, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(taskReportDetail(for: task))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    private func reportTaskSort(_ lhs: ProjectTask, _ rhs: ProjectTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func taskReportDetail(for task: ProjectTask) -> String {
        var parts: [String] = [task.priority.displayName]
        if let dueDate = task.dueDate {
            parts.append("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
        }
        if task.photoCount > 0 {
            parts.append("\(task.photoIDs.count) before / \(task.completionPhotoIDs.count) after photos")
        }
        return parts.joined(separator: " | ")
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
