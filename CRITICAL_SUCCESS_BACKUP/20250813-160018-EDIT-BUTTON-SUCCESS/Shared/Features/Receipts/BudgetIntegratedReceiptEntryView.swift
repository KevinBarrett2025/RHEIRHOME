import SwiftUI

/// Phase 2I Step 4: Budget-Integrated Receipt Entry View
/// 
/// Features:
/// - Real-time budget impact preview
/// - Intelligent category suggestions based on budget usage
/// - Budget warning system for overages
/// - Seamless CloudKit team member workflow integration
/// - Smart receipt splitting with budget awareness
struct BudgetIntegratedReceiptEntryView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Receipt Input States
    @State private var vendor: String = ""
    @State private var selectedVendor: Vendor?
    @State private var paymentMethod: String = ""
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @State private var category: ReceiptCategory = .material
    @State private var notes: String = ""
    @State private var isReturn: Bool = false
    
    // MARK: - Budget Integration States
    @State private var budgetImpact: BudgetImpactAnalysis?
    @State private var budgetWarnings: [BudgetWarning] = []
    @State private var smartCategorySuggestions: [SmartCategorySuggestion] = []
    @State private var showingBudgetImpactPreview = false
    @State private var showingBudgetWarning = false
    
    // MARK: - Team Member Integration (CloudKit)
    @State private var selectedTeamMember: TeamMember?
    @State private var showingTeamMemberPicker = false
    @State private var teamMemberSpendingContext: TeamMemberSpendingContext?
    
    // MARK: - UI States
    @State private var showingVendorPicker = false
    @State private var showingPaymentMethodPicker = false
    @State private var showingCategoryPicker = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var isAnalyzingBudgetImpact = false
    
    private var currentProject: Project? {
        projectVM.selectedProject
    }
    
    private var canSave: Bool {
        let hasVendor = !vendor.isEmpty
        let hasPayment = !paymentMethod.isEmpty
        let hasAmount = Double(amountText) != nil && Double(amountText)! > 0
        return hasVendor && hasPayment && hasAmount
    }
    
    private var receiptAmount: Double {
        Double(amountText) ?? 0.0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Budget Context Section (NEW)
                if let project = currentProject {
                    budgetContextSection(for: project)
                }
                
                // Team Member Section (CloudKit Integration)
                teamMemberSection
                
                // Vendor Section (Enhanced with Budget Context)
                vendorSection
                
                // Payment Method Section
                paymentMethodSection
                
                // Receipt Details Section
                receiptDetailsSection
                
                // Smart Category Section (Budget-Aware)
                smartCategorySection
                
                // Budget Impact Preview Section (NEW)
                if let impact = budgetImpact {
                    budgetImpactSection(impact)
                }
                
                // Budget Warnings Section (NEW)
                if !budgetWarnings.isEmpty {
                    budgetWarningsSection
                }
                
                // Notes Section
                notesSection
            }
            .navigationTitle("Smart Receipt Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReceipt() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .foregroundColor(budgetWarnings.contains { $0.severity == .critical } ? .red : .blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingBudgetImpactPreview = true
                    } label: {
                        Image(systemName: "chart.pie.fill")
                    }
                    .disabled(receiptAmount == 0)
                }
            }
            .onChange(of: amountText) { _, _ in
                analyzeBudgetImpact()
            }
            .onChange(of: category) { _, _ in 
                analyzeBudgetImpact()
            }
            .onAppear {
                loadSmartSuggestions()
                if receiptAmount > 0 {
                    analyzeBudgetImpact()
                }
            }
            .alert("Receipt Added Successfully", isPresented: $showingSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(successMessage)
            }
            .alert("Budget Warning", isPresented: $showingBudgetWarning) {
                Button("Proceed Anyway", role: .destructive) { saveReceipt() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(budgetWarnings.first?.message ?? "This receipt will exceed budget limits.")
            }
            .sheet(isPresented: $showingBudgetImpactPreview) {
                if let impact = budgetImpact, let project = currentProject {
                    BudgetImpactPreviewSheet(
                        impact: impact,
                        project: project,
                        receiptAmount: receiptAmount,
                        category: category
                    )
                }
            }
            .sheet(isPresented: $showingTeamMemberPicker) {
                TeamMemberPickerSheet(
                    selectedTeamMember: $selectedTeamMember,
                    teamMembers: projectVM.teamMembers,
                    onSelection: { member in
                        selectedTeamMember = member
                        loadTeamMemberSpendingContext(member)
                    }
                )
            }
            .sheet(isPresented: $showingVendorPicker) {
                SimpleVendorPickerView(
                    selectedVendor: $selectedVendor,
                    vendorService: projectVM.vendorService,
                    onSelection: { vendor in
                        selectedVendor = vendor
                        self.vendor = vendor.name
                        analyzeBudgetImpact()
                    }
                )
            }
            .sheet(isPresented: $showingPaymentMethodPicker) {
                SimplePaymentMethodPickerView(
                    selectedPaymentMethod: $selectedPaymentMethod,
                    paymentMethodService: projectVM.paymentMethodService,
                    onSelection: { paymentMethod in
                        selectedPaymentMethod = paymentMethod
                        self.paymentMethod = paymentMethod.displayName
                    }
                )
            }
            .sheet(isPresented: $showingCategoryPicker) {
                SmartCategoryPickerSheet(
                    selectedCategory: $category,
                    suggestions: smartCategorySuggestions,
                    project: currentProject,
                    onSelection: { selectedCategory in
                        category = selectedCategory
                        analyzeBudgetImpact()
                    }
                )
            }
        }
    }
    
    // MARK: - Budget Context Section (NEW)
    
    @ViewBuilder
    private func budgetContextSection(for project: Project) -> some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.blue)
                    Text("Budget Context")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isAnalyzingBudgetImpact {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // Current Budget Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Project Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(project.totalBudget.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let totalSpent = projectVM.calculateTotalSpent(for: project)
                        Text(totalSpent.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(totalSpent > project.totalBudget ? .red : .primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let remaining = project.totalBudget - projectVM.calculateTotalSpent(for: project)
                        Text(remaining.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(remaining < 0 ? .red : .green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Category Budget Status (if category selected)
                if category != .material {
                    CategoryBudgetStatusView(
                        category: category,
                        project: project,
                        projectVM: projectVM
                    )
                }
            }
        } header: {
            Text("Project Budget Overview")
        }
    }
    
    // MARK: - Team Member Section (CloudKit Integration)
    
    @ViewBuilder
    private var teamMemberSection: some View {
        Section("Team Member") {
            Button(action: { showingTeamMemberPicker = true }) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let member = selectedTeamMember {
                            Text(member.name)
                                .foregroundColor(.primary)
                            HStack {
                                Text(member.jobTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if member.hasAppAccess {
                                    Image(systemName: "iphone")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Text("Select Team Member")
                                .foregroundColor(.secondary)
                            Text("Optional - for expense tracking")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Team Member Spending Context (NEW)
            if let context = teamMemberSpendingContext {
                TeamMemberSpendingContextView(context: context)
            }
        }
    }
    
    // MARK: - Enhanced Vendor Section
    
    @ViewBuilder
    private var vendorSection: some View {
        Section("Vendor") {
            Button(action: { showingVendorPicker = true }) {
                HStack {
                    Image(systemName: selectedVendor?.category.icon ?? "building.2.fill")
                        .foregroundColor(selectedVendor?.category.color ?? .blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let selectedVendor = selectedVendor {
                            Text(selectedVendor.name)
                                .foregroundColor(.primary)
                            HStack {
                                Text(selectedVendor.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if selectedVendor.totalSpent > 0 {
                                    Text("• \(selectedVendor.totalSpent.formatAsCurrency()) total")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if !vendor.isEmpty {
                            Text(vendor)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select Vendor")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Vendor Budget Impact (NEW)
            if let selectedVendor = selectedVendor, receiptAmount > 0 {
                VendorBudgetImpactView(
                    vendor: selectedVendor,
                    receiptAmount: receiptAmount,
                    project: currentProject
                )
            }
        }
    }
    
    // MARK: - Payment Method Section
    
    @ViewBuilder
    private var paymentMethodSection: some View {
        Section("Payment Method") {
            Button(action: { showingPaymentMethodPicker = true }) {
                HStack {
                    Image(systemName: selectedPaymentMethod?.type.icon ?? "creditcard.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let selectedPaymentMethod = selectedPaymentMethod {
                            Text(selectedPaymentMethod.displayName)
                                .foregroundColor(.primary)
                            HStack {
                                Text(selectedPaymentMethod.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !selectedPaymentMethod.lastFourDigits.isEmpty {
                                    Text("•••• \(selectedPaymentMethod.lastFourDigits)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if !paymentMethod.isEmpty {
                            Text(paymentMethod)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select Payment Method")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Receipt Details Section
    
    @ViewBuilder
    private var receiptDetailsSection: some View {
        Section("Receipt Details") {
            HStack {
                Text("Amount")
                Spacer()
                TextField("$0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(budgetWarnings.contains { $0.severity == .critical } ? .red : .primary)
            }
            
            DatePicker("Date", selection: $date, displayedComponents: [.date])
            
            Toggle("Return", isOn: $isReturn)
        }
    }
    
    // MARK: - Smart Category Section (Budget-Aware)
    
    @ViewBuilder
    private var smartCategorySection: some View {
        Section {
            Button(action: { showingCategoryPicker = true }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .foregroundColor(.primary)
                        
                        if let project = currentProject {
                            let categoryBudget = getBudgetForCategory(category, in: project)
                            let categorySpent = getSpentForCategory(category, in: project)
                            let remaining = categoryBudget - categorySpent
                            
                            Text("Budget: \(categoryBudget.formatAsCurrency()), Remaining: \(remaining.formatAsCurrency())")
                                .font(.caption)
                                .foregroundColor(remaining < receiptAmount ? .red : .secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Smart Category Suggestions (NEW)
            if !smartCategorySuggestions.isEmpty {
                DisclosureGroup("Smart Suggestions") {
                    ForEach(smartCategorySuggestions.prefix(3), id: \.category) { suggestion in
                        SmartCategorySuggestionRow(suggestion: suggestion) {
                            category = suggestion.category
                            analyzeBudgetImpact()
                        }
                    }
                }
                .font(.subheadline)
            }
        } header: {
            Text("Category (Budget-Aware)")
        }
    }
    
    // MARK: - Budget Impact Section (NEW)
    
    @ViewBuilder
    private func budgetImpactSection(_ impact: BudgetImpactAnalysis) -> some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.purple)
                    Text("Budget Impact Preview")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Details") {
                        showingBudgetImpactPreview = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                // Before/After Comparison
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(impact.beforeAmount.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("After")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(impact.afterAmount.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(impact.willExceedBudget ? .red : .primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Impact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(impact.impactAmount.formatAsCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Budget Utilization Bar
                BudgetUtilizationBar(
                    current: impact.beforeAmount,
                    afterReceipt: impact.afterAmount,
                    budget: impact.totalBudget,
                    receiptAmount: receiptAmount
                )
            }
        } header: {
            Text("Real-Time Budget Impact")
        }
    }
    
    // MARK: - Budget Warnings Section (NEW)
    
    @ViewBuilder
    private var budgetWarningsSection: some View {
        Section {
            ForEach(budgetWarnings, id: \.id) { warning in
                BudgetWarningRow(warning: warning)
            }
        } header: {
            Text("Budget Warnings")
        }
    }
    
    // MARK: - Notes Section
    
    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Smart Analysis Methods (NEW)
    
    private func loadSmartSuggestions() {
        guard let project = currentProject else { return }
        
        // Generate smart category suggestions based on:
        // 1. Budget remaining in each category
        // 2. Historical spending patterns
        // 3. Vendor type analysis
        // 4. Amount-based suggestions
        
        Task {
            let suggestions = await generateSmartCategorySuggestions(
                for: project,
                amount: receiptAmount,
                vendor: selectedVendor
            )
            
            await MainActor.run {
                self.smartCategorySuggestions = suggestions
            }
        }
    }
    
    private func analyzeBudgetImpact() {
        guard let project = currentProject, receiptAmount > 0 else {
            budgetImpact = nil
            budgetWarnings = []
            return
        }
        
        isAnalyzingBudgetImpact = true
        
        Task {
            let impact = await calculateBudgetImpact(
                project: project,
                category: category,
                amount: receiptAmount,
                isReturn: isReturn
            )
            
            let warnings = await generateBudgetWarnings(
                project: project,
                impact: impact,
                category: category,
                amount: receiptAmount
            )
            
            await MainActor.run {
                self.budgetImpact = impact
                self.budgetWarnings = warnings
                self.isAnalyzingBudgetImpact = false
            }
        }
    }
    
    private func loadTeamMemberSpendingContext(_ teamMember: TeamMember) {
        guard let project = currentProject else { return }
        
        Task {
            let context = await generateTeamMemberSpendingContext(
                teamMember: teamMember,
                project: project,
                projectVM: projectVM
            )
            
            await MainActor.run {
                self.teamMemberSpendingContext = context
            }
        }
    }
    
    // MARK: - Save Receipt (Enhanced)
    
    private func saveReceipt() {
        // Check for critical budget warnings
        if budgetWarnings.contains(where: { $0.severity == .critical }) {
            showingBudgetWarning = true
            return
        }
        
        performSaveReceipt()
    }
    
    private func performSaveReceipt() {
        guard let amountValue = Double(amountText) else { return }
        
        let finalAmount = isReturn ? -amountValue : amountValue
        
        var receipt = Receipt(
            vendor: selectedVendor?.name ?? vendor,
            vendorID: selectedVendor?.id.uuidString,
            date: date,
            amount: finalAmount,
            notes: notes,
            category: category,
            isReturn: isReturn,
            paymentMethod: selectedPaymentMethod?.displayName ?? paymentMethod,
            paymentMethodID: selectedPaymentMethod?.id.uuidString,
            processingStatus: .completed
        )
        
        // Add team member association (CloudKit integration)
        if let teamMember = selectedTeamMember {
            receipt.teamMemberID = teamMember.id
            receipt.teamMemberName = teamMember.name
        }
        
        // Add budget context metadata
        if let impact = budgetImpact {
            receipt.budgetImpactMetadata = BudgetImpactMetadata(
                beforeAmount: impact.beforeAmount,
                afterAmount: impact.afterAmount,
                categoryBudgetBefore: impact.categoryBudgetRemaining,
                categoryBudgetAfter: impact.categoryBudgetRemaining - amountValue,
                analysisTimestamp: Date()
            )
        }
        
        // Save receipt with enhanced intelligence
        projectVM.addReceipt(receipt)
        
        // Update team member activity (CloudKit sync)
        if let teamMember = selectedTeamMember {
            updateTeamMemberActivity(teamMember, receipt: receipt)
        }
        
        showSuccessMessage(receipt: receipt)
    }
    
    private func updateTeamMemberActivity(_ teamMember: TeamMember, receipt: Receipt) {
        // Update team member's last activity and spending patterns
        var updatedMember = teamMember
        updatedMember.lastReceiptDate = receipt.date
        updatedMember.totalReceiptSpending += receipt.amount
        
        projectVM.updateTeamMemberInOrganization(updatedMember)
    }
    
    private func showSuccessMessage(receipt: Receipt) {
        let budgetStatus = budgetImpact?.willExceedBudget == true ? " (Budget Alert!)" : ""
        let teamMemberText = selectedTeamMember != nil ? " for \(selectedTeamMember!.name)" : ""
        
        successMessage = "Added \(receipt.vendor) receipt (\(receipt.amount.formatAsCurrency())) to \(receipt.category.rawValue)\(teamMemberText)\(budgetStatus)"
        showingSuccessAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    // MARK: - Budget Helper Methods
    
    private func getBudgetForCategory(_ category: ReceiptCategory, in project: Project) -> Double {
        switch category {
        case .general: return project.generalConditions
        case .material: return project.materialCost
        case .contingency: return project.contingency
        default: return project.materialCost
        }
    }
    
    private func getSpentForCategory(_ category: ReceiptCategory, in project: Project) -> Double {
        return project.receipts
            .filter { $0.category == category }
            .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    }
}

// MARK: - Smart Analysis Functions

private func generateSmartCategorySuggestions(
    for project: Project,
    amount: Double,
    vendor: Vendor?
) async -> [SmartCategorySuggestion] {
    
    var suggestions: [SmartCategorySuggestion] = []
    
    // Analyze budget remaining in each category
    let categories: [ReceiptCategory] = [.material, .general, .contingency]
    
    for category in categories {
        let budgetAmount = getBudgetAmount(for: category, in: project)
        let spentAmount = getSpentAmount(for: category, in: project)
        let remaining = budgetAmount - spentAmount
        
        var confidence: Double = 0.5
        var reason = "Category has budget available"
        
        // Increase confidence based on budget availability
        if remaining >= amount {
            confidence += 0.3
            reason = "Sufficient budget remaining (\(remaining.formatAsCurrency()))"
        } else {
            confidence -= 0.2
            reason = "Limited budget remaining (\(remaining.formatAsCurrency()))"
        }
        
        // Vendor-based suggestions
        if let vendor = vendor {
            if vendorMatchesCategory(vendor, category) {
                confidence += 0.4
                reason += " • Vendor type matches category"
            }
        }
        
        // Amount-based suggestions
        if amountSuggestsCategory(amount, category, project) {
            confidence += 0.2
            reason += " • Amount typical for category"
        }
        
        if confidence > 0.3 {
            suggestions.append(SmartCategorySuggestion(
                category: category,
                confidence: confidence,
                reason: reason,
                budgetRemaining: remaining,
                willExceedBudget: amount > remaining
            ))
        }
    }
    
    return suggestions.sorted { $0.confidence > $1.confidence }
}

private func calculateBudgetImpact(
    project: Project,
    category: ReceiptCategory,
    amount: Double,
    isReturn: Bool
) async -> BudgetImpactAnalysis {
    
    let effectiveAmount = isReturn ? -amount : amount
    let totalSpent = project.receipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    let categorySpent = project.receipts
        .filter { $0.category == category }
        .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    
    let categoryBudget = getBudgetAmount(for: category, in: project)
    let categoryRemaining = categoryBudget - categorySpent
    
    return BudgetImpactAnalysis(
        beforeAmount: totalSpent,
        afterAmount: totalSpent + effectiveAmount,
        impactAmount: effectiveAmount,
        totalBudget: project.totalBudget,
        categoryBudgetRemaining: categoryRemaining,
        willExceedBudget: (totalSpent + effectiveAmount) > project.totalBudget,
        willExceedCategoryBudget: (categorySpent + effectiveAmount) > categoryBudget
    )
}

private func generateBudgetWarnings(
    project: Project,
    impact: BudgetImpactAnalysis,
    category: ReceiptCategory,
    amount: Double
) async -> [BudgetWarning] {
    
    var warnings: [BudgetWarning] = []
    
    // Critical: Will exceed total project budget
    if impact.willExceedBudget {
        let overage = impact.afterAmount - impact.totalBudget
        warnings.append(BudgetWarning(
            id: UUID(),
            severity: .critical,
            title: "Project Budget Exceeded",
            message: "This receipt will exceed the total project budget by \(overage.formatAsCurrency()). Consider using contingency funds or adjusting the budget.",
            category: nil,
            suggestedAction: .adjustBudget
        ))
    }
    
    // High: Will exceed category budget
    if impact.willExceedCategoryBudget {
        let overage = amount - impact.categoryBudgetRemaining
        warnings.append(BudgetWarning(
            id: UUID(),
            severity: .high,
            title: "Category Budget Exceeded",
            message: "This receipt will exceed the \(category.rawValue) budget by \(overage.formatAsCurrency()). The overage will be allocated from contingency.",
            category: category,
            suggestedAction: .useContingency
        ))
    }
    
    // Medium: Approaching budget limits
    let budgetUtilization = impact.afterAmount / impact.totalBudget
    if budgetUtilization > 0.9 && budgetUtilization <= 1.0 {
        warnings.append(BudgetWarning(
            id: UUID(),
            severity: .medium,
            title: "Approaching Budget Limit",
            message: "This receipt will bring the project to \(Int(budgetUtilization * 100))% of budget. Monitor remaining expenses carefully.",
            category: nil,
            suggestedAction: .monitor
        ))
    }
    
    return warnings
}

private func generateTeamMemberSpendingContext(
    teamMember: TeamMember,
    project: Project,
    projectVM: ProjectViewModel
) async -> TeamMemberSpendingContext {
    
    let memberReceipts = project.receipts.filter { $0.teamMemberID == teamMember.id }
    let totalSpent = memberReceipts.reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    let lastReceiptDate = memberReceipts.map { $0.date }.max()
    
    return TeamMemberSpendingContext(
        teamMember: teamMember,
        totalSpentOnProject: totalSpent,
        receiptCount: memberReceipts.count,
        lastReceiptDate: lastReceiptDate,
        averageReceiptAmount: memberReceipts.isEmpty ? 0 : totalSpent / Double(memberReceipts.count),
        topCategories: getTopCategories(from: memberReceipts)
    )
}

// MARK: - Helper Functions

private func getBudgetAmount(for category: ReceiptCategory, in project: Project) -> Double {
    switch category {
    case .general: return project.generalConditions
    case .material: return project.materialCost
    case .contingency: return project.contingency
    default: return project.materialCost
    }
}

private func getSpentAmount(for category: ReceiptCategory, in project: Project) -> Double {
    return project.receipts
        .filter { $0.category == category }
        .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
}

private func vendorMatchesCategory(_ vendor: Vendor, _ category: ReceiptCategory) -> Bool {
    switch (vendor.category, category) {
    case (.hardware, .material), (.lumber, .material), (.electrical, .material):
        return true
    case (.office, .general), (.professional, .general):
        return true
    default:
        return false
    }
}

private func amountSuggestsCategory(_ amount: Double, _ category: ReceiptCategory, _ project: Project) -> Bool {
    let categoryReceipts = project.receipts.filter { $0.category == category }
    guard !categoryReceipts.isEmpty else { return false }
    
    let averageAmount = categoryReceipts.reduce(0) { $0 + $1.amount } / Double(categoryReceipts.count)
    return abs(amount - averageAmount) < (averageAmount * 0.5)
}

private func getTopCategories(from receipts: [Receipt]) -> [ReceiptCategory] {
    let categoryTotals = Dictionary(grouping: receipts) { $0.category }
        .mapValues { receipts in
            receipts.reduce(0) { $0 + $1.amount }
        }
    
    return categoryTotals.sorted { $0.value > $1.value }
        .prefix(3)
        .map { $0.key }
}

// MARK: - Data Models (NEW)

struct BudgetImpactAnalysis {
    let beforeAmount: Double
    let afterAmount: Double
    let impactAmount: Double
    let totalBudget: Double
    let categoryBudgetRemaining: Double
    let willExceedBudget: Bool
    let willExceedCategoryBudget: Bool
}

struct BudgetWarning {
    let id: UUID
    let severity: BudgetWarningSeverity
    let title: String
    let message: String
    let category: ReceiptCategory?
    let suggestedAction: BudgetWarningAction
}

enum BudgetWarningSeverity {
    case low, medium, high, critical
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

enum BudgetWarningAction {
    case monitor, useContingency, adjustBudget, reallocate
}

struct SmartCategorySuggestion {
    let category: ReceiptCategory
    let confidence: Double
    let reason: String
    let budgetRemaining: Double
    let willExceedBudget: Bool
}

struct TeamMemberSpendingContext {
    let teamMember: TeamMember
    let totalSpentOnProject: Double
    let receiptCount: Int
    let lastReceiptDate: Date?
    let averageReceiptAmount: Double
    let topCategories: [ReceiptCategory]
}

struct BudgetImpactMetadata: Codable {
    let beforeAmount: Double
    let afterAmount: Double
    let categoryBudgetBefore: Double
    let categoryBudgetAfter: Double
    let analysisTimestamp: Date
}

// MARK: - Extension for Receipt Model
extension Receipt {
    var budgetImpactMetadata: BudgetImpactMetadata? {
        get { nil } // Would be stored in a separate metadata field
        set { } // Would update the metadata field
    }
}

// MARK: - Extension for TeamMember Model
extension TeamMember {
    var lastReceiptDate: Date? {
        get { nil } // Would be stored in team member data
        set { } // Would update team member data
    }
    
    var totalReceiptSpending: Double {
        get { 0.0 } // Would be calculated from receipts
        set { } // Would update spending total
    }
}

// MARK: - Extension for Vendor and Payment Types
extension VendorCategory {
    var icon: String {
        switch self {
        case .hardware: return "hammer.fill"
        case .lumber: return "tree.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .paint: return "paintbrush.fill"
        case .rental: return "wrench.and.screwdriver.fill"
        case .grocery: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .gas: return "fuelpump.fill"
        case .automotive: return "car.fill"
        case .professional: return "briefcase.fill"
        case .office: return "folder.fill"
        case .other: return "building.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .hardware: return .orange
        case .lumber: return .brown
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .paint: return .purple
        case .rental: return .green
        case .grocery: return .red
        case .restaurant: return .pink
        case .gas: return .black
        case .automotive: return .gray
        case .professional: return .indigo
        case .office: return .cyan
        case .other: return .secondary
        }
    }
}

extension PaymentType {
    var icon: String {
        switch self {
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .cash: return "dollarsign.circle.fill"
        case .check: return "doc.text.fill"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

extension ReceiptCategory {
    var icon: String {
        switch self {
        case .general: return "building.fill"
        case .material: return "hammer.fill"
        case .permits: return "doc.text.fill"
        case .cleanup: return "trash.fill"
        case .demolition: return "hammer.circle.fill"
        case .sitework: return "globe.fill"
        case .foundation: return "square.grid.3x1.folder.fill.badge"
        case .framing: return "square.grid.2x2.fill"
        case .roofing: return "house.fill"
        case .exterior: return "house.lodge.fill"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .insulation: return "thermometer"
        case .drywall: return "rectangle.grid.1x2.fill"
        case .flooring: return "square.grid.3x3.fill"
        case .trim: return "rectangle.portrait.fill"
        case .paint: return "paintbrush.fill"
        case .kitchen: return "oven.fill"
        case .bathroom: return "bathtub.fill"
        case .fixtures: return "lightbulb.fill"
        case .appliances: return "refrigerator.fill"
        case .landscaping: return "leaf.fill"
        case .lighting: return "lightbulb.2.fill"
        case .cabinetry: return "cabinet.fill"
        case .countertops: return "rectangle.fill"
        case .tile: return "grid.fill"
        case .windows: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .specialty: return "star.fill"
        case .contingency: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .material: return .orange
        case .permits: return .purple
        case .cleanup: return .gray
        case .demolition: return .red
        case .sitework: return .brown
        case .foundation: return .gray
        case .framing: return .brown
        case .roofing: return .red
        case .exterior: return .green
        case .electrical: return .yellow
        case .plumbing: return .blue
        case .hvac: return .cyan
        case .insulation: return .pink
        case .drywall: return .gray
        case .flooring: return .brown
        case .trim: return .orange
        case .paint: return .purple
        case .kitchen: return .red
        case .bathroom: return .blue
        case .fixtures: return .yellow
        case .appliances: return .indigo
        case .landscaping: return .green
        case .lighting: return .yellow
        case .cabinetry: return .brown
        case .countertops: return .gray
        case .tile: return .blue
        case .windows: return .cyan
        case .specialty: return .purple
        case .contingency: return .red
        }
    }
}

#Preview {
    BudgetIntegratedReceiptEntryView()
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}