import SwiftUI
import OSLog

struct EnhancedTeamMemberDetailView: View {
    let member: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditView = false
    @State private var showingTerminationView = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSensitiveInfo = false
    
    var body: some View {
        NavigationView {
            List {
                statusSection
                contactInformationSection
                employmentDetailsSection
                ratesSection
                
                if showingSensitiveInfo {
                    sensitiveInformationSection
                }
                
                if member.employmentStatus == .terminated {
                    terminationDetailsSection
                }
                
                documentationSection
                actionSection
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if member.employmentStatus == .active {
                        Button("Edit") {
                            showingEditView = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EnhancedEditTeamMemberView(member: member)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingTerminationView) {
            TeamMemberTerminationView(member: member)
                .environmentObject(projectVM)
        }
        .alert("Delete Team Member", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTeamMember()
            }
        } message: {
            Text("Are you sure you want to permanently delete \(member.name)? This action cannot be undone and will remove all associated data.")
        }
    }
    
    private var statusSection: some View {
        Section("Employment Status") {
            HStack {
                Circle()
                    .fill(member.employmentStatus == .active ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.employmentStatus.displayName)
                        .font(.headline)
                        .foregroundColor(member.employmentStatus == .active ? .green : .red)
                    
                    if member.employmentStatus == .active {
                        Text("Active since \(member.hireDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(member.employmentType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if member.hasAppAccess {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone")
                                .font(.caption)
                            Text("App Access")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private var contactInformationSection: some View {
        Section("Contact Information") {
            if !member.phone.isEmpty {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(member.phone)
                        .foregroundColor(.secondary)
                }
            }
            
            if !member.email.isEmpty {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(member.email)
                        .foregroundColor(.secondary)
                }
            }
            
            if let address = member.fullAddress {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.headline)
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !member.emergencyContact.isEmpty {
                HStack {
                    Text("Emergency Contact")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(member.emergencyContact)
                            .foregroundColor(.secondary)
                        if !member.emergencyPhone.isEmpty {
                            Text(member.emergencyPhone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var employmentDetailsSection: some View {
        Section("Employment Details") {
            HStack {
                Text("Job Title")
                Spacer()
                Text(member.jobTitle)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Hire Date")
                Spacer()
                Text(member.hireDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Employment Duration")
                Spacer()
                Text(member.employmentDuration)
                    .foregroundColor(.secondary)
            }
            
            if !member.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.headline)
                    Text(member.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var ratesSection: some View {
        Section("Pay Rates") {
            if member.rates.isEmpty {
                Text("No rates configured")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(member.rates) { rate in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rate.taskType)
                                    .font(.headline)
                                if rate.isDefault {
                                    Text("DEFAULT")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(2)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(rate.rate.formatAsCurrency() + "/hr")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private var sensitiveInformationSection: some View {
        Section("Sensitive Information") {
            if !member.taxID.isEmpty {
                HStack {
                    Text("Tax ID")
                    Spacer()
                    Text("***-**-\(member.taxID.suffix(4))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var terminationDetailsSection: some View {
        Section("Termination Details") {
            if let terminationDate = member.terminationDate {
                HStack {
                    Text("Termination Date")
                    Spacer()
                    Text(terminationDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.red)
                }
            }
            
            if let terminationType = member.terminationType {
                HStack {
                    Text("Termination Type")
                    Spacer()
                    Text(terminationType.displayName)
                        .foregroundColor(.red)
                }
            }
            
            if let terminationReason = member.terminationReason, !terminationReason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason")
                        .font(.headline)
                    Text(terminationReason)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var documentationSection: some View {
        Section("Documentation") {
            HStack {
                Text("W-9 on File")
                Spacer()
                Image(systemName: member.w9OnFile ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(member.w9OnFile ? .green : .red)
            }
            
            HStack {
                Text("I-9 on File")
                Spacer()
                Image(systemName: member.i9OnFile ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(member.i9OnFile ? .green : .red)
            }
            
            HStack {
                Text("Documentation Complete")
                Spacer()
                Image(systemName: member.hasCompleteDocumentation ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(member.hasCompleteDocumentation ? .green : .orange)
            }
        }
    }
    
    private var actionSection: some View {
        Section {
            Button(showingSensitiveInfo ? "Hide Sensitive Info" : "Show Sensitive Info") {
                withAnimation {
                    showingSensitiveInfo.toggle()
                }
            }
            .foregroundColor(showingSensitiveInfo ? .red : .blue)
            
            if member.employmentStatus == .active {
                Button("Terminate Employee") {
                    showingTerminationView = true
                }
                .foregroundColor(.red)
            }
            
            if member.canBeDeleted {
                Button("Delete Permanently", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
    }
    
    private func deleteTeamMember() {
        // Use the ProjectViewModel method to properly delete the team member
        projectVM.deleteTeamMember(member)
        Logger.teamMember.notice(
            "Deleted team member from detail view [teamMember=\(member.id.uuidString, privacy: .private(mask: .hash))]"
        )
        dismiss()
    }
}

// MARK: - Team Member Termination View

struct TeamMemberTerminationView: View {
    let member: TeamMember
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var terminationDate = Date()
    @State private var terminationType: TerminationType = .voluntary
    @State private var terminationReason = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Termination Details") {
                    DatePicker("Termination Date", selection: $terminationDate, displayedComponents: .date)
                    
                    Picker("Termination Type", selection: $terminationType) {
                        ForEach(TerminationType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason for Termination")
                            .font(.headline)
                        TextEditor(text: $terminationReason)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Section("Important Notice") {
                    Text("This will preserve all work history, hours logged, and project data for legal and tax purposes. The employee's data will be marked as terminated but not deleted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Terminate \(member.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminate") {
                        terminateEmployee()
                    }
                    .disabled(terminationReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func terminateEmployee() {
        guard !terminationReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        
        // Update team member with termination details through ProjectViewModel
        var terminatedMember = member
        terminatedMember.terminate(
            reason: terminationReason.trimmingCharacters(in: .whitespacesAndNewlines),
            type: terminationType,
            date: terminationDate
        )
        
        projectVM.updateTeamMember(terminatedMember)

        Logger.teamMember.notice(
            "Terminated team member from detail view [teamMember=\(member.id.uuidString, privacy: .private(mask: .hash)), terminationType=\(terminationType.displayName, privacy: .public), terminationDate=\(terminationDate.formatted(date: .abbreviated, time: .omitted), privacy: .public)]"
        )
        
        isSaving = false
        dismiss()
    }
}

#Preview {
    let sampleMember = TeamMember(
        name: "John Doe",
        email: "john@example.com",
        phone: "(555) 123-4567",
        jobTitle: "Construction Worker",
        organizationID: "test-org"
    )
    
    EnhancedTeamMemberDetailView(member: sampleMember)
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
