import OSLog
import SwiftUI

/// Comprehensive Labor Payment Management View
struct LaborPaymentView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss
    
    let teamMember: TeamMember
    
    @State private var selectedTab: PaymentTab = .unpaid
    @State private var showingPaymentModal = false
    @State private var selectedHours: Set<WorkHour> = []
    @State private var paymentMethod = "Cash"
    @State private var paymentNotes = ""
    @State private var paymentReference = ""
    @State private var bulkPaymentAmount: Double = 0
    
    enum PaymentTab: String, CaseIterable {
        case unpaid = "Unpaid"
        case paid = "Paid"
        case summary = "Summary"
        
        var icon: String {
            switch self {
            case .unpaid: return "clock.arrow.circlepath"
            case .paid: return "checkmark.circle.fill"
            case .summary: return "chart.bar.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .unpaid: return .orange
            case .paid: return .green
            case .summary: return .blue
            }
        }
    }
    
    private var memberUnpaidHours: [WorkHour] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.loggedHours.filter { hour in
            (hour.employeeID == teamMember.id || hour.employee.lowercased() == teamMember.name.lowercased())
                && hour.effectiveUnpaidAmount > 0
        }.sorted { $0.date > $1.date }
    }
    
    private var memberPaidHours: [WorkHour] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.loggedHours.filter { hour in
            (hour.employeeID == teamMember.id || hour.employee.lowercased() == teamMember.name.lowercased())
                && hour.hasAnyPayment
        }.sorted { $0.paymentTimestamp ?? $0.date > $1.paymentTimestamp ?? $1.date }
    }

    private var allMemberHours: [WorkHour] {
        guard let project = projectVM.selectedProject else { return [] }
        return project.loggedHours.filter { hour in
            hour.employeeID == teamMember.id || hour.employee.lowercased() == teamMember.name.lowercased()
        }
    }
    
    private var totalUnpaidAmount: Double {
        memberUnpaidHours.reduce(0) { $0 + $1.effectiveUnpaidAmount }
    }
    
    private var totalUnpaidHours: Double {
        memberUnpaidHours.reduce(0) { $0 + $1.hours }
    }
    
    private var selectedHoursAmount: Double {
        selectedHours.reduce(0) { $0 + $1.effectiveUnpaidAmount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with team member info
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content
                tabContent
            }
            .navigationTitle("Labor Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .unpaid && !memberUnpaidHours.isEmpty {
                        Menu {
                            Button("Pay All Unpaid Hours") {
                                selectedHours = Set(memberUnpaidHours)
                                bulkPaymentAmount = totalUnpaidAmount
                                showingPaymentModal = true
                            }
                            Button("Pay Selected Hours") {
                                if !selectedHours.isEmpty {
                                    bulkPaymentAmount = selectedHoursAmount
                                    showingPaymentModal = true
                                }
                            }
                        } label: {
                            Image(systemName: "dollarsign.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaymentModal) {
            PaymentProcessingView(
                teamMember: teamMember,
                hoursToProcess: Array(selectedHours),
                totalAmount: bulkPaymentAmount,
                onPaymentComplete: { amount, method, reference, notes in
                    processPayment(amount: amount, method: method, reference: reference, notes: notes)
                }
            )
        }
        .accessibilityIdentifier("labor-payment-view")
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Team member avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(teamMember.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(teamMember.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(teamMember.jobTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(teamMember.employmentType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        if teamMember.employmentStatus == .betweenProjects {
                            Text("Between Projects")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(totalUnpaidHours, specifier: "%.1f") hrs")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("UNPAID")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
            
            // Quick stats
            HStack {
                statBox("Unpaid Amount", totalUnpaidAmount.formatAsCurrency(), .orange)
                statBox("Paid This Month", calculatePaidThisMonth().formatAsCurrency(), .green)
                statBox("Total Earned", calculateTotalEarned().formatAsCurrency(), .blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private func statBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var tabSelector: some View {
        HStack {
            ForEach(PaymentTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        selectedHours.removeAll() // Clear selection when switching tabs
                    }
                } label: {
                    HStack {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                        
                        // Show counts
                        if tab == .unpaid {
                            Text("(\(memberUnpaidHours.count))")
                                .foregroundColor(.secondary)
                        } else if tab == .paid {
                            Text("(\(memberPaidHours.count))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedTab == tab ? tab.color.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(selectedTab == tab ? tab.color : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("labor-payment-tab-\(tab.rawValue.lowercased())")
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .unpaid:
            unpaidHoursTab
        case .paid:
            paidHoursTab
        case .summary:
            summaryTab
        }
    }
    
    @ViewBuilder
    private var unpaidHoursTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if memberUnpaidHours.isEmpty {
                emptyStateView("No unpaid hours", "All hours have been paid for this team member")
            } else {
                // Selection info
                if !selectedHours.isEmpty {
                    HStack {
                        Text("Selected: \(selectedHours.count) entries")
                        Spacer()
                        Text("Total: \(selectedHoursAmount.formatAsCurrency())")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(memberUnpaidHours, id: \.id) { hour in
                            WorkHourRowView(
                                hour: hour,
                                isSelected: selectedHours.contains(hour),
                                onToggle: {
                                    toggleHourSelection(hour)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var paidHoursTab: some View {
        VStack {
            if memberPaidHours.isEmpty {
                emptyStateView("No paid hours", "No payments have been processed yet")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(memberPaidHours, id: \.id) { hour in
                            PaidWorkHourRowView(hour: hour) {
                                projectVM.reverseLaborPayments(for: hour)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private var summaryTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Payment history chart placeholder
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Summary")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        summaryRow("Total Hours Worked", String(format: "%.1f hrs", calculateTotalHours()))
                        summaryRow("Total Amount Earned", calculateTotalEarned().formatAsCurrency())
                        summaryRow("Amount Paid", calculateTotalPaid().formatAsCurrency())
                        summaryRow("Amount Outstanding", totalUnpaidAmount.formatAsCurrency())
                        
                        Divider()
                        
                        summaryRow("Average Hourly Rate", calculateAverageRate().formatAsCurrency() + "/hr")
                        summaryRow("Payments This Month", calculatePaidThisMonth().formatAsCurrency())
                        summaryRow("Hours This Month", String(format: "%.1f hrs", calculateHoursThisMonth()))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Recent payments
                if !memberPaidHours.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Payments")
                            .font(.headline)
                        
                        ForEach(Array(memberPaidHours.prefix(5)), id: \.id) { hour in
                            PaidWorkHourRowView(hour: hour)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private func emptyStateView(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func toggleHourSelection(_ hour: WorkHour) {
        if selectedHours.contains(hour) {
            selectedHours.remove(hour)
        } else {
            selectedHours.insert(hour)
        }
    }
    
    private func processPayment(amount: Double, method: String, reference: String, notes: String) {
        let processedCount = selectedHours.count
        projectVM.recordLaborPayment(
            for: Array(selectedHours),
            amount: amount,
            method: method,
            reference: reference,
            note: notes
        )
        
        selectedHours.removeAll()
        showingPaymentModal = false
        
        Logger.labor.notice(
            "Processed labor payment batch [count=\(processedCount) method=\(method, privacy: .public)]"
        )
    }
    
    private func calculateTotalHours() -> Double {
        allMemberHours.reduce(0) { $0 + $1.hours }
    }
    
    private func calculateTotalEarned() -> Double {
        allMemberHours.reduce(0) { $0 + $1.straightTimePay }
    }
    
    private func calculateTotalPaid() -> Double {
        return memberPaidHours.reduce(0) { $0 + $1.effectivePaidAmount }
    }
    
    private func calculateAverageRate() -> Double {
        guard !allMemberHours.isEmpty else { return 0 }
        
        let totalEarned = allMemberHours.reduce(0) { $0 + $1.straightTimePay }
        let totalHours = allMemberHours.reduce(0) { $0 + $1.hours }
        
        return totalHours > 0 ? totalEarned / totalHours : 0
    }
    
    private func calculatePaidThisMonth() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        return memberPaidHours.filter { hour in
            guard let paymentDate = hour.paymentTimestamp else { return false }
            return calendar.isDate(paymentDate, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.effectivePaidAmount }
    }
    
    private func calculateHoursThisMonth() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        return allMemberHours.filter { hour in
            calendar.isDate(hour.date, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.hours }
    }
}

// MARK: - Work Hour Row Views

struct WorkHourRowView: View {
    let hour: WorkHour
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(hour.hours, specifier: "%.1f") hrs")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("\(hour.startTime.formatted(date: .omitted, time: .shortened)) - \(hour.endTime?.formatted(date: .omitted, time: .shortened) ?? "Active")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("@ \(hour.rate.formatAsCurrency())/hr")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(hour.category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(hour.effectiveUnpaidAmount.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("labor-unpaid-hour-\(hour.id.uuidString)")
    }
}

struct PaidWorkHourRowView: View {
    let hour: WorkHour
    var onUnpay: (() -> Void)? = nil

    private var latestPayment: LaborPaymentEntry? {
        hour.paymentEntries.last(where: { !$0.isReversal })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(hour.hours, specifier: "%.1f") hrs")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid: \(hour.effectivePaidAmount.formatAsCurrency())")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    if let method = hour.paymentMethod {
                        Text("Method: \(method)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let reference = latestPayment?.reference, !reference.isEmpty {
                        Text("Reference: \(reference)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    if let paymentDate = hour.paymentTimestamp {
                        Text("Paid \(paymentDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let onUnpay {
                        Button {
                            onUnpay()
                        } label: {
                            Text("Unpay")
                                .accessibilityIdentifier("labor-payment-unpay-label-\(hour.id.uuidString)")
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .accessibilityIdentifier("labor-payment-unpay-\(hour.id.uuidString)")
                    }
                }
            }
            
            if let notes = hour.paymentNote, !notes.isEmpty {
                Text("Note: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityIdentifier("labor-paid-hour-\(hour.id.uuidString)")
    }
}

// MARK: - Payment Processing View

struct PaymentProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    
    let teamMember: TeamMember
    let hoursToProcess: [WorkHour]
    let totalAmount: Double
    let onPaymentComplete: (Double, String, String, String) -> Void
    
    @State private var selectedMethod = "Cash"
    @State private var paymentAmount = ""
    @State private var paymentReference = ""
    @State private var paymentNotes = ""
    @State private var isProcessing = false
    
    private let paymentMethods = ["Cash", "Check", "Bank Transfer", "Venmo", "PayPal", "Zelle", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Details") {
                    HStack {
                        Text("Team Member")
                        Spacer()
                        Text(teamMember.name)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Hours to Pay")
                        Spacer()
                        Text("\(hoursToProcess.count) entries")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        Text(totalAmount.formatAsCurrency())
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    TextField("Payment amount", text: $paymentAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("labor-payment-amount")
                }
                
                Section("Payment Method") {
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Section("Reference") {
                    TextField("Check number, transaction ID, or note", text: $paymentReference)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("labor-payment-reference")
                }
                
                Section("Notes (Optional)") {
                    TextField("Payment notes...", text: $paymentNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Confirmation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I confirm that I have paid \(teamMember.name) \(resolvedPaymentAmount.formatAsCurrency()) via \(selectedMethod)")
                            .font(.subheadline)
                        
                        Text("This payment can be reversed later if a check is lost, entered incorrectly, or needs to be reissued.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Process Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Process Payment") {
                        processPayment()
                    }
                    .disabled(isProcessing || resolvedPaymentAmount <= 0)
                }
            }
        }
        .onAppear {
            if paymentAmount.isEmpty {
                paymentAmount = String(format: "%.2f", totalAmount)
            }
        }
    }

    private var resolvedPaymentAmount: Double {
        guard let parsedAmount = Double(paymentAmount) else { return 0 }
        return min(max(0, parsedAmount), totalAmount)
    }
    
    private func processPayment() {
        isProcessing = true
        
        // Add timestamp to notes
        let timestampedNotes = paymentNotes.isEmpty ? 
            "Paid on \(Date().formatted())" : 
            "\(paymentNotes) (Paid on \(Date().formatted()))"
        
        // Process the payment
        onPaymentComplete(resolvedPaymentAmount, selectedMethod, paymentReference, timestampedNotes)
        
        dismiss()
    }
}

#Preview {
    LaborPaymentView(
        teamMember: TeamMember(
            name: "Preview Worker",
            email: "preview@example.com",
            jobTitle: "Lead Carpenter",
            organizationID: "preview-org"
        )
    )
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
