import Foundation
import PDFKit
import SwiftUI

@MainActor
public class ReportingService: ObservableObject {
    
    public init() {}
    
    // MARK: - PDF Report Generation
    
    /// Generate a comprehensive project report as PDF
    public func generateProjectReport(
        project: Project,
        teamMembers: [TeamMember],
        organization: Organization
    ) async -> Data? {
        let reportData = ProjectReportData(
            project: project,
            teamMembers: teamMembers,
            organization: organization,
            generatedAt: Date()
        )
        
        return await generatePDF(from: ProjectReportView(data: reportData))
    }
    
    /// Generate timesheet report for payroll
    public func generateTimesheetReport(
        project: Project,
        teamMember: TeamMember,
        startDate: Date,
        endDate: Date,
        organization: Organization
    ) async -> Data? {
        let timesheetData = TimesheetReportData(
            project: project,
            teamMember: teamMember,
            startDate: startDate,
            endDate: endDate,
            organization: organization,
            workHours: getWorkHours(for: teamMember, in: project, from: startDate, to: endDate)
        )
        
        return await generatePDF(from: TimesheetReportView(data: timesheetData))
    }
    
    /// Generate budget analysis report
    public func generateBudgetReport(
        project: Project,
        organization: Organization
    ) async -> Data? {
        let budgetData = BudgetReportData(
            project: project,
            organization: organization,
            spendingBreakdown: calculateSpendingBreakdown(for: project),
            generatedAt: Date()
        )
        
        return await generatePDF(from: BudgetReportView(data: budgetData))
    }
    
    /// Generate client-facing project status report
    public func generateClientReport(
        project: Project,
        organization: Organization,
        includeFinancials: Bool = false
    ) async -> Data? {
        let clientData = ClientReportData(
            project: project,
            organization: organization,
            includeFinancials: includeFinancials,
            progressReports: project.progressLogs.sorted { $0.date > $1.date },
            generatedAt: Date()
        )
        
        return await generatePDF(from: ClientReportView(data: clientData))
    }
    
    // MARK: - CSV Export Generation
    
    /// Export receipts as CSV for accounting
    public func generateReceiptsCSV(project: Project) -> Data? {
        var csvContent = "Date,Vendor,Category,Amount,Tax,Payment Method,Receipt Number,Notes,Is Return\n"
        
        for receipt in project.receipts.sorted(by: { $0.date < $1.date }) {
            let row = [
                receipt.date.formatted(date: .numeric, time: .omitted),
                escapeCSV(receipt.vendor),
                receipt.category.rawValue,
                String(format: "%.2f", receipt.amount),
                String(format: "%.2f", receipt.taxAmount),
                escapeCSV(receipt.paymentMethod),
                escapeCSV(receipt.receiptNumber),
                escapeCSV(receipt.notes),
                receipt.isReturn ? "Yes" : "No"
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    /// Export timesheets as CSV for payroll
    public func generateTimesheetCSV(
        project: Project,
        startDate: Date,
        endDate: Date
    ) -> Data? {
        var csvContent = "Date,Employee,Start Time,End Time,Regular Hours,Overtime Hours,Rate,Regular Pay,Overtime Pay,Total Pay,Category,Approved\n"
        
        let filteredHours = project.loggedHours.filter { hour in
            hour.startTime >= startDate && hour.startTime <= endDate && hour.endTime != nil
        }.sorted { $0.startTime < $1.startTime }
        
        for hour in filteredHours {
            let row = [
                hour.date.formatted(date: .numeric, time: .omitted),
                escapeCSV(hour.employee),
                hour.startTime.formatted(date: .omitted, time: .shortened),
                hour.endTime?.formatted(date: .omitted, time: .shortened) ?? "",
                String(format: "%.2f", hour.regularHours),
                String(format: "%.2f", hour.overtimeHours),
                String(format: "%.2f", hour.rate),
                String(format: "%.2f", hour.regularPay),
                String(format: "%.2f", hour.overtimePay),
                String(format: "%.2f", hour.totalPay),
                escapeCSV(hour.category),
                hour.isApproved ? "Yes" : "No"
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    /// Export project summary as CSV
    public func generateProjectSummaryCSV(projects: [Project]) -> Data? {
        var csvContent = "Project Name,Client,Status,Total Budget,Spent,Remaining,Start Date,End Date,Team Members\n"
        
        for project in projects.sorted(by: { $0.name < $1.name }) {
            let spent = calculateTotalSpent(for: project)
            let remaining = project.totalBudget - spent
            let teamMemberCount = Set(project.loggedHours.compactMap { $0.employeeID }).count
            
            let row = [
                escapeCSV(project.name),
                escapeCSV(project.client),
                project.status.displayName,
                String(format: "%.2f", project.totalBudget),
                String(format: "%.2f", spent),
                String(format: "%.2f", remaining),
                project.startDate.formatted(date: .numeric, time: .omitted),
                project.endDate.formatted(date: .numeric, time: .omitted),
                String(teamMemberCount)
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    /// Export team member summary as CSV
    public func generateTeamMemberSummaryCSV(teamMembers: [TeamMember], projects: [Project]) -> Data? {
        var csvContent = "Name,Job Title,Employment Status,Hire Date,Email,Phone,Default Rate,Projects Worked,Total Hours,Total Earnings\n"
        
        for member in teamMembers.sorted(by: { $0.name < $1.name }) {
            let memberProjects = projects.filter { project in
                project.loggedHours.contains { $0.employeeID == member.id }
            }
            
            let totalHours = projects.flatMap { $0.loggedHours }
                .filter { $0.employeeID == member.id }
                .reduce(0) { $0 + $1.hours }
            
            let totalEarnings = projects.flatMap { $0.loggedHours }
                .filter { $0.employeeID == member.id }
                .reduce(0) { $0 + $1.totalPay }
            
            let row = [
                escapeCSV(member.name),
                escapeCSV(member.jobTitle),
                member.employmentStatus.displayName,
                member.hireDate.formatted(date: .numeric, time: .omitted),
                escapeCSV(member.email),
                escapeCSV(member.phone),
                String(format: "%.2f", member.defaultRate?.rate ?? 0),
                String(memberProjects.count),
                String(format: "%.2f", totalHours),
                String(format: "%.2f", totalEarnings)
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    // MARK: - Tax and Compliance Reports
    
    /// Generate 1099 preparation data
    public func generate1099PreparationData(
        teamMembers: [TeamMember],
        projects: [Project],
        taxYear: Int
    ) -> Data? {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: taxYear, month: 12, day: 31))!
        
        var csvContent = "Contractor Name,Tax ID,Address,Total Payments,Employment Type,Hire Date\n"
        
        let contractors = teamMembers.filter { 
            $0.employmentType == .contractor || $0.employmentType == .subcontractor 
        }
        
        for contractor in contractors {
            let totalPayments = projects.flatMap { $0.loggedHours }
                .filter { hour in
                    hour.employeeID == contractor.id &&
                    hour.startTime >= startOfYear &&
                    hour.startTime <= endOfYear &&
                    hour.isPaid
                }
                .reduce(0) { $0 + $1.totalPay }
            
            if totalPayments >= 600 { // IRS threshold for 1099
                let row = [
                    escapeCSV(contractor.name),
                    escapeCSV(contractor.taxID),
                    escapeCSV(contractor.fullAddress ?? ""),
                    String(format: "%.2f", totalPayments),
                    contractor.employmentType.displayName,
                    contractor.hireDate.formatted(date: .numeric, time: .omitted)
                ].joined(separator: ",")
                
                csvContent += row + "\n"
            }
        }
        
        return csvContent.data(using: .utf8)
    }
    
    /// Generate annual tax summary
    public func generateAnnualTaxSummary(projects: [Project], taxYear: Int) -> Data? {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: taxYear, month: 12, day: 31))!
        
        let yearReceipts = projects.flatMap { $0.receipts }.filter { receipt in
            receipt.date >= startOfYear && receipt.date <= endOfYear
        }
        
        var csvContent = "Category,Total Spent,Tax Paid,Receipt Count,Deductible Amount\n"
        
        let categoryTotals = Dictionary(grouping: yearReceipts, by: { $0.category })
            .mapValues { receipts in
                (
                    total: receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) },
                    tax: receipts.reduce(0) { $0 + $1.taxAmount },
                    count: receipts.count
                )
            }
        
        for (category, totals) in categoryTotals {
            let row = [
                category.rawValue,
                String(format: "%.2f", totals.total),
                String(format: "%.2f", totals.tax),
                String(totals.count),
                String(format: "%.2f", totals.total) // Assuming all business expenses are deductible
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    // MARK: - Helper Methods
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
    
    private func calculateTotalSpent(for project: Project) -> Double {
        let receiptTotal = project.receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
        let laborTotal = project.loggedHours.reduce(0) { $0 + $1.totalPay }
        return receiptTotal + laborTotal
    }
    
    private func calculateSpendingBreakdown(for project: Project) -> SpendingBreakdown {
        let receiptsByCategory = Dictionary(grouping: project.receipts, by: { $0.category })
            .mapValues { receipts in
                receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
            }
        
        let laborByCategory = Dictionary(grouping: project.loggedHours, by: { $0.category })
            .mapValues { hours in
                hours.reduce(0) { $0 + $1.totalPay }
            }
        
        return SpendingBreakdown(
            materialCosts: receiptsByCategory[.material] ?? 0,
            laborCosts: laborByCategory["Labor"] ?? 0,
            generalConditions: (receiptsByCategory[.general] ?? 0) + (laborByCategory["General Conditions"] ?? 0),
            contingency: (receiptsByCategory[.contingency] ?? 0) + (laborByCategory["Contingency"] ?? 0)
        )
    }
    
    private func getWorkHours(
        for teamMember: TeamMember,
        in project: Project,
        from startDate: Date,
        to endDate: Date
    ) -> [WorkHour] {
        return project.loggedHours.filter { hour in
            hour.employeeID == teamMember.id &&
            hour.startTime >= startDate &&
            hour.startTime <= endDate
        }.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF(from view: some View) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let renderer = ImageRenderer(content: view.frame(width: 612, height: 792)) // 8.5" x 11" at 72 DPI
                renderer.scale = 2.0
                
                if let pdfData = renderer.pdf {
                    continuation.resume(returning: pdfData)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Report Data Models

public struct ProjectReportData {
    public let project: Project
    public let teamMembers: [TeamMember]
    public let organization: Organization
    public let generatedAt: Date
    
    public init(project: Project, teamMembers: [TeamMember], organization: Organization, generatedAt: Date) {
        self.project = project
        self.teamMembers = teamMembers
        self.organization = organization
        self.generatedAt = generatedAt
    }
}

public struct TimesheetReportData {
    public let project: Project
    public let teamMember: TeamMember
    public let startDate: Date
    public let endDate: Date
    public let organization: Organization
    public let workHours: [WorkHour]
    
    public init(project: Project, teamMember: TeamMember, startDate: Date, endDate: Date, organization: Organization, workHours: [WorkHour]) {
        self.project = project
        self.teamMember = teamMember
        self.startDate = startDate
        self.endDate = endDate
        self.organization = organization
        self.workHours = workHours
    }
}

public struct BudgetReportData {
    public let project: Project
    public let organization: Organization
    public let spendingBreakdown: SpendingBreakdown
    public let generatedAt: Date
    
    public init(project: Project, organization: Organization, spendingBreakdown: SpendingBreakdown, generatedAt: Date) {
        self.project = project
        self.organization = organization
        self.spendingBreakdown = spendingBreakdown
        self.generatedAt = generatedAt
    }
}

public struct ClientReportData {
    public let project: Project
    public let organization: Organization
    public let includeFinancials: Bool
    public let progressReports: [ProgressLog]
    public let generatedAt: Date
    
    public init(project: Project, organization: Organization, includeFinancials: Bool, progressReports: [ProgressLog], generatedAt: Date) {
        self.project = project
        self.organization = organization
        self.includeFinancials = includeFinancials
        self.progressReports = progressReports
        self.generatedAt = generatedAt
    }
}

public struct SpendingBreakdown {
    public let materialCosts: Double
    public let laborCosts: Double
    public let generalConditions: Double
    public let contingency: Double
    
    public var total: Double {
        materialCosts + laborCosts + generalConditions + contingency
    }
    
    public init(materialCosts: Double, laborCosts: Double, generalConditions: Double, contingency: Double) {
        self.materialCosts = materialCosts
        self.laborCosts = laborCosts
        self.generalConditions = generalConditions
        self.contingency = contingency
    }
}