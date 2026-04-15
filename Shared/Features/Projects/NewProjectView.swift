import SwiftUI
import OSLog

struct NewProjectView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var client = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var notes = ""
    @State private var totalBudget = ""
    @State private var generalConditions = ""
    @State private var materials = ""
    @State private var labor = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    
    // PHASE 2B: Enterprise Intelligence Pre-Population
    @State private var showingSmartSuggestions = false
    @State private var smartSuggestionsData: String? = nil
    @State private var suggestedVendors: [String] = []
    @State private var suggestedPaymentMethods: [String] = []
    
    // Computed contingency with safe math
    private var contingencyAmount: Double {
        let total = Double(totalBudget) ?? 0
        let gc = Double(generalConditions) ?? 0
        let mat = Double(materials) ?? 0
        let lab = Double(labor) ?? 0
        
        // Ensure all values are valid and non-negative
        guard total >= 0, gc >= 0, mat >= 0, lab >= 0 else {
            return 0
        }
        
        let result = total - gc - mat - lab
        
        // Ensure result is valid and non-negative
        guard result.isFinite && result >= 0 else {
            return 0
        }
        
        return result
    }
    
    private var isValidForm: Bool {
        !name.isEmpty && !client.isEmpty && !totalBudget.isEmpty && contingencyAmount >= 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background blur effect
                Color.clear
                
                ScrollView {
                    VStack(spacing: 20) {
                        // PHASE 2B: Smart Suggestions Banner
                        if projectVM.isEnterpriseIntelligenceReady {
                            smartSuggestionsSection
                        }
                        
                        projectDetailsSection
                        addressSection
                        budgetBreakdownSection
                        timelineSection
                        notesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(!isValidForm)
                    .foregroundColor(isValidForm ? .blue : .secondary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadSmartSuggestions()
            }
            .sheet(isPresented: $showingSmartSuggestions) {
                SmartProjectSuggestionsView(
                    suggestionsData: smartSuggestionsData ?? "No suggestions available",
                    onApplySuggestions: { vendors, paymentMethods in
                        suggestedVendors = vendors
                        suggestedPaymentMethods = paymentMethods
                        showingSmartSuggestions = false
                    }
                )
            }
        }
        .presentationBackground(.thinMaterial)
    }
    
    // MARK: - PHASE 2B: Smart Suggestions Section
    
    @ViewBuilder
    private var smartSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("Enterprise Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View Suggestions") {
                    showingSmartSuggestions = true
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
            
            if !suggestedVendors.isEmpty || !suggestedPaymentMethods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Smart suggestions applied")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    if !suggestedVendors.isEmpty {
                        HStack {
                            Text("Suggested Vendors:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(suggestedVendors.prefix(3).joined(separator: ", "))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if !suggestedPaymentMethods.isEmpty {
                        HStack {
                            Text("Preferred Payment Methods:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(suggestedPaymentMethods.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Get smart pre-population based on your organization's data")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var projectDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Project Details")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentTextField(title: "Project Name", text: $name, isRequired: true)
                SemiTransparentTextField(title: "Client Name", text: $client, isRequired: true)
                SemiTransparentTextField(title: "Phone", text: $phone, keyboardType: .phonePad)
                SemiTransparentTextField(title: "Email", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder 
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Address")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentTextField(title: "Street Address", text: $street)
                
                HStack(spacing: 12) {
                    SemiTransparentTextField(title: "City", text: $city)
                    SemiTransparentTextField(title: "State", text: $state)
                        .frame(maxWidth: 100)
                    SemiTransparentTextField(title: "Zip", text: $zip, keyboardType: .numberPad)
                        .frame(maxWidth: 100)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var budgetBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Budget Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentCurrencyField(title: "Total Budget", text: $totalBudget, isRequired: true)
                SemiTransparentCurrencyField(title: "General Conditions", text: $generalConditions)
                SemiTransparentCurrencyField(title: "Materials", text: $materials)
                SemiTransparentCurrencyField(title: "Labor", text: $labor)
                
                // Auto-calculated contingency display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Contingency")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(Auto-calculated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Remaining budget after all expenses")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(contingencyAmount.formatAsCurrency())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(contingencyAmount >= 0 ? .green : .red)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                SemiTransparentDatePicker(title: "Start Date", selection: $startDate)
                SemiTransparentDatePicker(title: "End Date", selection: $endDate)
                
                // Duration display
                HStack {
                    Text("Project Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let duration = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                    Text("\(duration) days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(duration > 0 ? .primary : .red)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .font(.title2) 
                    .foregroundColor(.indigo)
                Text("Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            TextField("Additional notes about the project...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .lineLimit(3...6)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func createProject() {
        // Validate all numeric inputs
        let totalBudgetValue = Double(totalBudget) ?? 0
        let materialsValue = Double(materials) ?? 0
        let laborValue = Double(labor) ?? 0
        let generalConditionsValue = Double(generalConditions) ?? 0
        
        // Ensure all values are valid
        guard totalBudgetValue.isFinite && totalBudgetValue >= 0,
              materialsValue.isFinite && materialsValue >= 0,
              laborValue.isFinite && laborValue >= 0,
              generalConditionsValue.isFinite && generalConditionsValue >= 0,
              contingencyAmount.isFinite && contingencyAmount >= 0 else {
            Logger.project.warning("New project creation aborted because of invalid budget values.")
            return
        }
        
        // Build clientAddress from components
        var addressComponents: [String] = []
        if !street.isEmpty { addressComponents.append(street) }
        if !city.isEmpty { addressComponents.append(city) }
        if !state.isEmpty || !zip.isEmpty { 
            let stateZip = [state, zip].filter { !$0.isEmpty }.joined(separator: " ")
            if !stateZip.isEmpty { addressComponents.append(stateZip) }
        }
        let clientAddress = addressComponents.joined(separator: ", ")
        
        let project = Project(
            name: name,
            client: client,
            clientEmail: email.isEmpty ? nil : email,
            clientPhone: phone.isEmpty ? nil : phone,
            clientAddress: clientAddress.isEmpty ? nil : clientAddress,
            description: notes,
            totalBudget: totalBudgetValue,
            materialCost: materialsValue,
            laborCost: laborValue,
            generalConditions: generalConditionsValue,
            contingency: contingencyAmount,
            startDate: startDate,
            endDate: endDate,
            organizationID: projectVM.currentOrganizationID ?? "unknown"
        )
        
        Task {
            try await projectVM.createNewProject(project: project)
        }
        isPresented = false
    }
    
    // MARK: - PHASE 2D: Load Smart Suggestions (Enhanced)
    
    private func loadSmartSuggestions() {
        guard projectVM.isEnterpriseIntelligenceReady else { 
            Logger.project.info("Enterprise intelligence is not ready for new-project suggestions.")
            return 
        }
        
        Logger.project.info("Loading organizational intelligence suggestions for new project flow.")
        
        let receiptRecords = projectVM.getReceiptIntelligenceRecords()
        
        // Generate suggestions data
        smartSuggestionsData = """
        Enterprise Intelligence Report:
        • \(projectVM.organizationProjects.count) projects analyzed
        • \(receiptRecords.count) receipts processed
        • Intelligence Status: ACTIVE
        
        Ready for smart project pre-population.
        """
        
        // Get real top vendors from intelligence data
        let topVendorsBySpending = projectVM.getTopVendorsBySpending(limit: 5)
        suggestedVendors = topVendorsBySpending.map { $0.vendor }
        
        // Get real top payment methods from intelligence data  
        let topPaymentMethodsByUsage = projectVM.getTopPaymentMethodsByUsage(limit: 3)
        suggestedPaymentMethods = topPaymentMethodsByUsage.map { $0.paymentMethod }
        
        Logger.project.notice(
            "Loaded organizational intelligence suggestions [vendors=\(suggestedVendors.count, privacy: .public) paymentMethods=\(suggestedPaymentMethods.count, privacy: .public) receipts=\(receiptRecords.count, privacy: .public)]"
        )
    }
}

// MARK: - Semi-Transparent Components for NewProjectView

struct SemiTransparentTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentCurrencyField: View {
    let title: String
    @Binding var text: String
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("$")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("0", text: $text)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentDatePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - PHASE 2D: Enhanced Smart Project Suggestions View

struct SmartProjectSuggestionsView: View {
    let suggestionsData: String
    let onApplySuggestions: ([String], [String]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVendors: Set<String> = []
    @State private var selectedPaymentMethods: Set<String> = []
    
    // PHASE 2D: Get real intelligence data from environment
    @EnvironmentObject var projectVM: ProjectViewModel
    
    // Real intelligence data
    private var intelligentVendors: [String] {
        return projectVM.getTopVendorsBySpending(limit: 8).map { $0.vendor }
    }
    
    private var intelligentPaymentMethods: [String] {
        return projectVM.getTopPaymentMethodsByUsage(limit: 6).map { $0.paymentMethod }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Intelligence Report
                    intelligenceReportSection
                    
                    // Real-Time Intelligence Status
                    intelligenceStatusSection
                    
                    // Vendor Suggestions (Real Data)
                    enhancedVendorSuggestionsSection
                    
                    // Payment Method Suggestions (Real Data)
                    enhancedPaymentMethodSuggestionsSection
                    
                    // Apply Button
                    applyButton
                }
                .padding()
            }
            .navigationTitle("Smart Project Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var intelligenceReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("Organizational Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Intelligence status indicator
                HStack {
                    Circle()
                        .fill(projectVM.isEnterpriseIntelligenceReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(projectVM.isEnterpriseIntelligenceReady ? "ACTIVE" : "INITIALIZING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(projectVM.isEnterpriseIntelligenceReady ? .green : .orange)
                }
            }
            
            Text(suggestionsData)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // PHASE 2D: Intelligence Status Section
    @ViewBuilder
    private var intelligenceStatusSection: some View {
        let intelligenceRecords = projectVM.getReceiptIntelligenceRecords()
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Intelligence Data Available")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Intelligence Records")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(intelligenceRecords.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Vendors Analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(intelligentVendors.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Payment Methods")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(intelligentPaymentMethods.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // PHASE 2D: Enhanced Vendor Suggestions (Real Intelligence Data)
    @ViewBuilder
    private var enhancedVendorSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("AI-Recommended Vendors")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                    Text("From Intelligence")
                }
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if intelligentVendors.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("No vendor intelligence data available yet")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Add receipts to build vendor intelligence and get smart recommendations!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(intelligentVendors, id: \.self) { vendor in
                        HStack {
                            Button {
                                if selectedVendors.contains(vendor) {
                                    selectedVendors.remove(vendor)
                                } else {
                                    selectedVendors.insert(vendor)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedVendors.contains(vendor) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedVendors.contains(vendor) ? .green : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vendor)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Image(systemName: "brain.head.profile")
                                                .font(.caption2)
                                            Text("AI analyzed • High organization usage")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("🧠 AI Choice")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        
                                        if let spendingData = projectVM.getTopVendorsBySpending(limit: 20).first(where: { $0.vendor == vendor }) {
                                            Text("$\(String(format: "%.0f", spendingData.amount))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(selectedVendors.contains(vendor) ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // PHASE 2D: Enhanced Payment Method Suggestions (Real Intelligence Data)
    @ViewBuilder
    private var enhancedPaymentMethodSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("AI-Preferred Payment Methods")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                    Text("From Intelligence")
                }
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if intelligentPaymentMethods.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.purple)
                        Text("No payment method intelligence data available yet")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    
                    Text("Add receipts with payment methods to build usage intelligence!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(intelligentPaymentMethods, id: \.self) { paymentMethod in
                        HStack {
                            Button {
                                if selectedPaymentMethods.contains(paymentMethod) {
                                    selectedPaymentMethods.remove(paymentMethod)
                                } else {
                                    selectedPaymentMethods.insert(paymentMethod)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedPaymentMethods.contains(paymentMethod) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedPaymentMethods.contains(paymentMethod) ? .green : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(paymentMethod)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Image(systemName: "brain.head.profile")
                                                .font(.caption2)
                                            Text("AI analyzed • Frequently used by organization")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("🧠 AI Choice")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                        
                                        if let usageData = projectVM.getTopPaymentMethodsByUsage(limit: 20).first(where: { $0.paymentMethod == paymentMethod }) {
                                            Text("\(usageData.count) uses")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(selectedPaymentMethods.contains(paymentMethod) ? Color.purple.opacity(0.1) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var applyButton: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected for Pre-Population:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if selectedVendors.isEmpty && selectedPaymentMethods.isEmpty {
                        Text("No AI suggestions selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            if !selectedVendors.isEmpty {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("AI Vendors: \(selectedVendors.sorted().joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !selectedPaymentMethods.isEmpty {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                    Text("AI Payment Methods: \(selectedPaymentMethods.sorted().joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            Button {
                Logger.project.notice(
                    "Applying AI suggestions in new project flow [vendors=\(selectedVendors.count, privacy: .public) paymentMethods=\(selectedPaymentMethods.count, privacy: .public)]"
                )
                onApplySuggestions(Array(selectedVendors), Array(selectedPaymentMethods))
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile.fill")
                    Text("Apply AI Suggestions")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct NewProjectView_Previews: PreviewProvider {
    static var previews: some View {
        NewProjectView(isPresented: .constant(true))
            .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
    }
}
