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
    @State private var editingHour: WorkHour?
    @State private var correctingPaymentHour: WorkHour?
    @State private var showingLogHours = false
    
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

    private var totalOverpaidAmount: Double {
        allMemberHours.reduce(0) { $0 + $1.overpaidAmount }
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
        .sheet(item: $editingHour) { hour in
            LaborHourEditorView(teamMember: teamMember, hour: hour)
                .environmentObject(projectVM)
        }
        .sheet(item: $correctingPaymentHour) { hour in
            LaborPaymentCorrectionView(teamMember: teamMember, hour: hour)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingLogHours) {
            LogHoursView(
                isPresented: $showingLogHours,
                preselectedTeamMember: teamMember
            )
            .environmentObject(projectVM)
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
                statBox(totalOverpaidAmount > 0 ? "Overpaid" : "Total Earned",
                        (totalOverpaidAmount > 0 ? totalOverpaidAmount : calculateTotalEarned()).formatAsCurrency(),
                        totalOverpaidAmount > 0 ? .red : .blue)
            }

            HStack {
                Spacer()
                Button {
                    showingLogHours = true
                } label: {
                    Label("Add Hours", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("labor-payment-add-hours-button")
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PaymentTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                            selectedHours.removeAll()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .imageScale(.small)
                            Text(tab.rawValue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            
                            if tab == .unpaid {
                                Text("(\(memberUnpaidHours.count))")
                                    .foregroundColor(.secondary)
                            } else if tab == .paid {
                                Text("(\(memberPaidHours.count))")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption.weight(selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(selectedTab == tab ? tab.color.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(selectedTab == tab ? tab.color : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("labor-payment-tab-\(tab.rawValue.lowercased())")
                }
            }
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
                                },
                                onEdit: {
                                    editingHour = currentHour(for: hour) ?? hour
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
                            PaidWorkHourRowView(
                                hour: hour,
                                onEditHour: {
                                    editingHour = currentHour(for: hour) ?? hour
                                },
                                onCorrectPayment: {
                                    correctingPaymentHour = currentHour(for: hour) ?? hour
                                },
                                onUnpay: {
                                    projectVM.reverseLaborPayments(for: hour)
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
                        if totalOverpaidAmount > 0 {
                            summaryRow("Overpaid Balance", totalOverpaidAmount.formatAsCurrency())
                        }
                        
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

    private func currentHour(for hour: WorkHour) -> WorkHour? {
        projectVM.selectedProject?.loggedHours.first { $0.id == hour.id }
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
        return memberPaidHours.reduce(0) { $0 + $1.totalPaidAmount }
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
        }.reduce(0) { $0 + $1.totalPaidAmount }
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
    let onEdit: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .green : .secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("labor-unpaid-hour-\(hour.id.uuidString)")
                
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

            Button("Edit", action: onEdit)
                .font(.caption)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("labor-hour-edit-\(hour.id.uuidString)")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.green.opacity(0.12) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.green : Color(.separator).opacity(0.7), lineWidth: isSelected ? 2 : 1)
        )
    }
}

struct PaidWorkHourRowView: View {
    let hour: WorkHour
    var onEditHour: (() -> Void)? = nil
    var onCorrectPayment: (() -> Void)? = nil
    var onUnpay: (() -> Void)? = nil

    private var latestPayment: LaborPaymentEntry? {
        hour.paymentEntries.last(where: { !$0.isReversal })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hour.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))

                    if let paymentDate = hour.paymentTimestamp {
                        Text("Paid \(paymentDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(hour.hours, specifier: "%.1f") hrs")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                paymentDetailRow("Earned", hour.straightTimePay.formatAsCurrency(), .primary)
                paymentDetailRow("Paid", hour.totalPaidAmount.formatAsCurrency(), .green)
                if hour.overpaidAmount > 0 {
                    paymentDetailRow("Overpaid", hour.overpaidAmount.formatAsCurrency(), .red)
                } else if hour.effectiveUnpaidAmount > 0 {
                    paymentDetailRow("Balance", hour.effectiveUnpaidAmount.formatAsCurrency(), .orange)
                }
                if let method = hour.paymentMethod {
                    paymentDetailRow("Method", method, .secondary)
                }
                if let reference = latestPayment?.reference, !reference.isEmpty {
                    paymentDetailRow("Reference", reference, .secondary)
                }
            }

            if onEditHour != nil || onCorrectPayment != nil || onUnpay != nil {
                Divider()

                HStack(spacing: 8) {
                    if let onEditHour {
                        Button("Edit Hours", action: onEditHour)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("labor-hour-edit-\(hour.id.uuidString)")
                    }

                    if let onCorrectPayment {
                        Button("Edit Payment", action: onCorrectPayment)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("labor-payment-edit-\(hour.id.uuidString)")
                    }

                    if let onUnpay {
                        Button("Unpay", action: onUnpay)
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .accessibilityIdentifier("labor-payment-unpay-\(hour.id.uuidString)")
                    }
                }
                .font(.caption.weight(.semibold))
            }
            
            if let notes = hour.paymentNote, !notes.isEmpty {
                Text("Note: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.7), lineWidth: 1)
        )
        .accessibilityIdentifier("labor-paid-hour-\(hour.id.uuidString)")
    }

    @ViewBuilder
    private func paymentDetailRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Labor Edit Views

struct LaborHourEditorView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let teamMember: TeamMember
    let hour: WorkHour

    @State private var workDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var lunchHours: String
    @State private var selectedRateID: UUID?
    @State private var customRateText: String
    @State private var category: String

    init(teamMember: TeamMember, hour: WorkHour) {
        self.teamMember = teamMember
        self.hour = hour
        _workDate = State(initialValue: hour.date)
        _startTime = State(initialValue: hour.startTime)
        _endTime = State(initialValue: hour.endTime ?? hour.startTime.addingTimeInterval(3600))
        _lunchHours = State(initialValue: hour.lunchBreakDuration.map { String(format: "%.2f", $0) } ?? "")
        _selectedRateID = State(initialValue: teamMember.rates.first { $0.taskType == hour.category && abs($0.rate - hour.rate) < 0.005 }?.id)
        _customRateText = State(initialValue: String(format: "%.2f", hour.rate))
        _category = State(initialValue: hour.category)
    }

    private var selectedRate: EmployeeRate? {
        guard let selectedRateID else { return nil }
        return teamMember.rates.first { $0.id == selectedRateID }
    }

    private var resolvedRate: Double {
        selectedRate?.rate ?? Double(customRateText) ?? hour.rate
    }

    private var resolvedCategory: String {
        selectedRate?.taskType ?? category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        endDateTime > startDateTime &&
        resolvedRate > 0 &&
        !resolvedCategory.isEmpty
    }

    private var startDateTime: Date {
        combine(date: workDate, time: startTime)
    }

    private var endDateTime: Date {
        combine(date: workDate, time: endTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $workDate, displayedComponents: .date)
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("Lunch hours", text: $lunchHours)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("labor-hour-lunch-field")
                }

                Section("Work Type") {
                    if !teamMember.rates.isEmpty {
                        Picker("Rate", selection: $selectedRateID) {
                            Text("Custom").tag(Optional<UUID>.none)
                            ForEach(teamMember.rates) { rate in
                                Text("\(rate.taskType) - \(rate.rate.formatAsCurrency())/hr")
                                    .tag(Optional(rate.id))
                            }
                        }
                    }

                    if selectedRate == nil {
                        TextField("Work type", text: $category)
                            .accessibilityIdentifier("labor-hour-category-field")
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Hourly rate", text: $customRateText)
                                .keyboardType(.decimalPad)
                                .accessibilityIdentifier("labor-hour-rate-field")
                        }
                    }
                }

                Section("Updated Total") {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text(String(format: "%.2f", max(0, editedHours)))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Gross")
                        Spacer()
                        Text((max(0, editedHours) * resolvedRate).formatAsCurrency())
                            .fontWeight(.semibold)
                    }
                    if hour.totalPaidAmount > 0 {
                        Text("Existing payment entries remain attached. Paid cash stays unchanged; unpaid or overpaid balances recalculate from the edited hours and rate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("labor-hour-save-button")
                }
            }
        }
    }

    private var editedHours: Double {
        let totalHours = endDateTime.timeIntervalSince(startDateTime) / 3600
        return totalHours - (Double(lunchHours) ?? 0)
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateParts = calendar.dateComponents([.year, .month, .day], from: date)
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: time)
        var components = DateComponents()
        components.year = dateParts.year
        components.month = dateParts.month
        components.day = dateParts.day
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        components.second = timeParts.second
        return calendar.date(from: components) ?? date
    }

    private func save() {
        let lunchDuration = max(0, Double(lunchHours) ?? 0)
        var lunchStart: Date?
        var lunchEnd: Date?
        if lunchDuration > 0 {
            let shiftSeconds = endDateTime.timeIntervalSince(startDateTime)
            let beforeLunch = max(0, (shiftSeconds - lunchDuration * 3600) / 2)
            lunchStart = startDateTime.addingTimeInterval(beforeLunch)
            lunchEnd = lunchStart?.addingTimeInterval(lunchDuration * 3600)
        }

        var updated = WorkHour(
            id: hour.id,
            date: workDate,
            startTime: startDateTime,
            endTime: endDateTime,
            lunchStart: lunchStart,
            lunchEnd: lunchEnd,
            employee: teamMember.name,
            employeeID: teamMember.id,
            rate: resolvedRate,
            category: resolvedCategory,
            isPaid: hour.isPaid,
            paymentMethod: hour.paymentMethod,
            paymentNote: hour.paymentNote,
            paymentTimestamp: hour.paymentTimestamp,
            paymentEntries: hour.paymentEntries,
            clockInLocation: hour.clockInLocation,
            clockOutLocation: hour.clockOutLocation
        )
        updated.isApproved = hour.isApproved
        updated.approvedBy = hour.approvedBy
        updated.approvedAt = hour.approvedAt
        updated.validationNotes = hour.validationNotes

        projectVM.updateHours(updated)
        dismiss()
    }
}

struct LaborPaymentCorrectionView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let teamMember: TeamMember
    let hour: WorkHour

    @State private var amountText: String
    @State private var method: String
    @State private var reference: String
    @State private var note: String

    private let paymentMethods = ["Cash", "Check", "Bank Transfer", "Venmo", "PayPal", "Zelle", "Other"]

    init(teamMember: TeamMember, hour: WorkHour) {
        self.teamMember = teamMember
        self.hour = hour
        let latestPayment = hour.paymentEntries.last(where: { !$0.isReversal })
        _amountText = State(initialValue: String(format: "%.2f", hour.totalPaidAmount))
        _method = State(initialValue: latestPayment?.method ?? hour.paymentMethod ?? "Cash")
        _reference = State(initialValue: latestPayment?.reference ?? "")
        _note = State(initialValue: latestPayment?.note ?? hour.paymentNote ?? "")
    }

    private var resolvedAmount: Double {
        max(0, Double(amountText) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    HStack {
                        Text("Worker")
                        Spacer()
                        Text(teamMember.name)
                            .foregroundColor(.secondary)
                    }
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("labor-payment-edit-amount")
                    Picker("Method", selection: $method) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    TextField("Reference", text: $reference)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("labor-payment-edit-reference")
                }

                Section("Note") {
                    TextField("Correction note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("Saving reverses the current paid balance and records the corrected payment so the audit trail remains intact.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        projectVM.replaceLaborPayment(
                            for: hour,
                            amount: resolvedAmount,
                            method: method,
                            reference: reference,
                            note: note
                        )
                        dismiss()
                    }
                    .disabled(resolvedAmount <= 0)
                    .accessibilityIdentifier("labor-payment-edit-save-button")
                }
            }
        }
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
