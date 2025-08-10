import SwiftUI

// MARK: - Budget Integration UI Components for Phase 2I Step 4

// MARK: - Category Budget Status View
struct CategoryBudgetStatusView: View {
    let category: ReceiptCategory
    let project: Project
    let projectVM: ProjectViewModel
    
    private var categoryBudget: Double {
        switch category {
        case .general: return project.generalConditions
        case .material: return project.materialCost
        case .contingency: return project.contingency
        default: return project.materialCost
        }
    }
    
    private var categorySpent: Double {
        project.receipts
            .filter { $0.category == category }
            .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    }
    
    private var remaining: Double {
        categoryBudget - categorySpent
    }
    
    private var utilization: Double {
        categoryBudget > 0 ? (categorySpent / categoryBudget) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text("\(category.rawValue) Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(utilization * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(utilization > 1.0 ? .red : utilization > 0.8 ? .orange : .green)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    utilization > 1.0 ? .red : utilization > 0.8 ? .orange : category.color,
                                    (utilization > 1.0 ? .red : utilization > 0.8 ? .orange : category.color).opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: min(geometry.size.width * utilization, geometry.size.width),
                            height: 6
                        )
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("Spent: \(categorySpent.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Remaining: \(remaining.formatAsCurrency())")
                    .font(.caption)
                    .foregroundColor(remaining < 0 ? .red : .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Team Member Spending Context View
struct TeamMemberSpendingContextView: View {
    let context: TeamMemberSpendingContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Spending Summary")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Spent")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(context.totalSpentOnProject.formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Receipts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(context.receiptCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Avg Amount")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(context.averageReceiptAmount.formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            if let lastDate = context.lastReceiptDate {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                    
                    Text("Last receipt: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - Vendor Budget Impact View
struct VendorBudgetImpactView: View {
    let vendor: Vendor
    let receiptAmount: Double
    let project: Project?
    
    private var vendorProjectSpending: Double {
        guard let project = project else { return 0 }
        return project.receipts
            .filter { $0.vendor.lowercased() == vendor.name.lowercased() }
            .reduce(0) { $0 + ($1.isReturn ? -$1.amount : $1.amount) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Vendor Impact")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(vendorProjectSpending.formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("After Receipt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text((vendorProjectSpending + receiptAmount).formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
}

// MARK: - Budget Utilization Bar
struct BudgetUtilizationBar: View {
    let current: Double
    let afterReceipt: Double
    let budget: Double
    let receiptAmount: Double
    
    private var currentUtilization: Double {
        budget > 0 ? current / budget : 0
    }
    
    private var afterUtilization: Double {
        budget > 0 ? afterReceipt / budget : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Budget Utilization")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(currentUtilization * 100))% → \(Int(afterUtilization * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(afterUtilization > 1.0 ? .red : .primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                        .cornerRadius(6)
                    
                    // Current utilization
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    currentUtilization > 1.0 ? .red : currentUtilization > 0.8 ? .orange : .blue,
                                    (currentUtilization > 1.0 ? .red : currentUtilization > 0.8 ? .orange : .blue).opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: min(geometry.size.width * currentUtilization, geometry.size.width),
                            height: 12
                        )
                        .cornerRadius(6)
                    
                    // Receipt impact overlay
                    Rectangle()
                        .fill(Color.purple.opacity(0.6))
                        .frame(
                            width: min(geometry.size.width * (receiptAmount / budget), geometry.size.width - min(geometry.size.width * currentUtilization, geometry.size.width)),
                            height: 12
                        )
                        .cornerRadius(6)
                        .offset(x: min(geometry.size.width * currentUtilization, geometry.size.width))
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Budget Warning Row
struct BudgetWarningRow: View {
    let warning: BudgetWarning
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: warning.severity.icon)
                .foregroundColor(warning.severity.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(warning.severity.color)
                
                Text(warning.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if let category = warning.category {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.caption2)
                        Text(category.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Severity indicator
            Rectangle()
                .fill(warning.severity.color)
                .frame(width: 4, height: 40)
                .cornerRadius(2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(warning.severity.color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(warning.severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Smart Category Suggestion Row
struct SmartCategorySuggestionRow: View {
    let suggestion: SmartCategorySuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.category.icon)
                    .foregroundColor(suggestion.category.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    // Confidence indicator
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(Double(index) < suggestion.confidence * 5 ? suggestion.category.color : Color.gray.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                    
                    if suggestion.willExceedBudget {
                        Text("Over budget")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        Text(suggestion.budgetRemaining.formatAsCurrency())
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Team Member Picker Sheet
struct TeamMemberPickerSheet: View {
    @Binding var selectedTeamMember: TeamMember?
    let teamMembers: [TeamMember]
    let onSelection: (TeamMember) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("No Team Member") {
                        selectedTeamMember = nil
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                Section("Available Team Members") {
                    ForEach(teamMembers.filter { $0.employmentStatus == .active }) { member in
                        Button {
                            onSelection(member)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.name)
                                        .font(.headline)
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
                                        
                                        if let rate = member.defaultRate {
                                            Text("• \(rate.rate.formatAsCurrency())/hr")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedTeamMember?.id == member.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !teamMembers.filter({ $0.employmentStatus != .active }).isEmpty {
                    Section("Other Team Members") {
                        ForEach(teamMembers.filter { $0.employmentStatus != .active }) { member in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.name)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(member.jobTitle) • \(member.employmentStatus.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Smart Category Picker Sheet
struct SmartCategoryPickerSheet: View {
    @Binding var selectedCategory: ReceiptCategory
    let suggestions: [SmartCategorySuggestion]
    let project: Project?
    let onSelection: (ReceiptCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !suggestions.isEmpty {
                    Section("Smart Suggestions") {
                        ForEach(suggestions.prefix(5), id: \.category) { suggestion in
                            SmartCategorySuggestionRow(suggestion: suggestion) {
                                onSelection(suggestion.category)
                                dismiss()
                            }
                        }
                    }
                }
                
                Section("All Categories") {
                    ForEach(ReceiptCategory.allCases) { category in
                        Button {
                            onSelection(category)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.rawValue)
                                        .foregroundColor(.primary)
                                    
                                    if let project = project {
                                        let budget = getBudgetForCategory(category, in: project)
                                        let spent = getSpentForCategory(category, in: project)
                                        let remaining = budget - spent
                                        
                                        Text("Budget: \(budget.formatAsCurrency()), Remaining: \(remaining.formatAsCurrency())")
                                            .font(.caption)
                                            .foregroundColor(remaining < 0 ? .red : .secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
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

// MARK: - Budget Impact Preview Sheet
struct BudgetImpactPreviewSheet: View {
    let impact: BudgetImpactAnalysis
    let project: Project
    let receiptAmount: Double
    let category: ReceiptCategory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Impact Summary
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Budget Impact Analysis")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("for \(project.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Before/After Cards
                        HStack(spacing: 16) {
                            ImpactCard(
                                title: "Before",
                                amount: impact.beforeAmount,
                                budget: impact.totalBudget,
                                color: .blue
                            )
                            
                            ImpactCard(
                                title: "After",
                                amount: impact.afterAmount,
                                budget: impact.totalBudget,
                                color: impact.willExceedBudget ? .red : .green
                            )
                        }
                    }
                    
                    // Detailed Analysis
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Detailed Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        AnalysisRow(
                            title: "Receipt Amount",
                            value: receiptAmount.formatAsCurrency(),
                            icon: "receipt.fill",
                            color: .purple
                        )
                        
                        AnalysisRow(
                            title: "Category",
                            value: category.rawValue,
                            icon: category.icon,
                            color: category.color
                        )
                        
                        AnalysisRow(
                            title: "Category Budget Remaining",
                            value: impact.categoryBudgetRemaining.formatAsCurrency(),
                            icon: "target",
                            color: impact.willExceedCategoryBudget ? .red : .green
                        )
                        
                        AnalysisRow(
                            title: "Project Budget Utilization",
                            value: "\(Int((impact.afterAmount / impact.totalBudget) * 100))%",
                            icon: "chart.pie.fill",
                            color: impact.willExceedBudget ? .red : .blue
                        )
                    }
                    
                    // Recommendations
                    if impact.willExceedBudget || impact.willExceedCategoryBudget {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recommendations")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if impact.willExceedBudget {
                                RecommendationCard(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "Project Budget Exceeded",
                                    description: "Consider reallocating funds from other categories or adjusting the project budget.",
                                    color: .red
                                )
                            }
                            
                            if impact.willExceedCategoryBudget {
                                RecommendationCard(
                                    icon: "arrow.triangle.2.circlepath",
                                    title: "Use Contingency Funds",
                                    description: "This overage can be covered by contingency funds if available.",
                                    color: .orange
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Budget Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components for Budget Impact Preview

struct ImpactCard: View {
    let title: String
    let amount: Double
    let budget: Double
    let color: Color
    
    private var utilization: Double {
        budget > 0 ? (amount / budget) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(amount.formatAsCurrency())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(Int(utilization * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AnalysisRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}