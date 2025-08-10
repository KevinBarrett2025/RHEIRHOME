import SwiftUI
import UniformTypeIdentifiers

// MARK: - Temporary Stub ReportingService
@MainActor
class ReportingService: ObservableObject {
    func generateProjectReport(project: Project, teamMembers: [TeamMember], organization: Organization) async -> Data? {
        // Stub implementation
        return "Project Report Stub".data(using: .utf8)
    }
    
    func generateTimesheetReport(project: Project, teamMember: TeamMember, startDate: Date, endDate: Date, organization: Organization) async -> Data? {
        return "Timesheet Report Stub".data(using: .utf8)
    }
    
    func generateBudgetReport(project: Project, organization: Organization) async -> Data? {
        return "Budget Report Stub".data(using: .utf8)
    }
    
    func generateClientReport(project: Project, organization: Organization, includeFinancials: Bool) async -> Data? {
        return "Client Report Stub".data(using: .utf8)
    }
    
    func generateReceiptsCSV(project: Project) -> Data? {
        return "Receipts CSV Stub".data(using: .utf8)
    }
    
    func generateTimesheetCSV(project: Project, startDate: Date, endDate: Date) -> Data? {
        return "Timesheet CSV Stub".data(using: .utf8)
    }
    
    func generateTeamMemberSummaryCSV(teamMembers: [TeamMember], projects: [Project]) -> Data? {
        return "Team Summary CSV Stub".data(using: .utf8)
    }
    
    func generate1099PreparationData(teamMembers: [TeamMember], projects: [Project], taxYear: Int) -> Data? {
        return "1099 Data Stub".data(using: .utf8)
    }
}

struct ReportsMainView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var reportingService = ReportingService()
    
    @State private var selectedReportType: ReportType = .project
    @State private var selectedProject: Project?
    @State private var selectedTeamMember: TeamMember?
    @State private var startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var includeFinancials = false
    @State private var isGenerating = false
    @State private var generatedReportData: Data?
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportFormat: ExportFormat = .pdf
    @State private var reportTitle = ""
    
    enum ReportType: String, CaseIterable {
        case project = "Project Report"
        case timesheet = "Timesheet"
        case budget = "Budget Analysis"
        case client = "Client Report"
        case receipts = "Receipts Export"
        case teamSummary = "Team Summary"
        case taxPrep = "Tax Preparation"
    }
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Simplified UI for now
                Text("Reports & Export")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Report generation system is being updated...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Text("Available Projects: \(projectVM.organizationProjects.count)")
                    Text("Team Members: \(projectVM.teamMembers.count)")
                    Text("Total Receipts: \(projectVM.organizationProjects.flatMap { $0.receipts }.count)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Text("Full reporting functionality will be restored soon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Reports")
    }
}

// MARK: - Supporting Views (Simplified)
struct ReportTypeCard: View {
    let type: ReportsMainView.ReportType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(type.rawValue)
                .padding()
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

struct QuickStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
        }
    }
}

// MARK: - Document Wrapper for File Export
struct DocumentWrapper: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .commaSeparatedText, .json] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ReportsMainView()
        .environmentObject(ProjectViewModel(cloudKitService: CloudKitAuthService()))
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}