import SwiftUI

/// Category picker that only shows granular categories (not budget roll-ups)
struct DetailedCategoryPickerView: View {
    @Binding var selectedCategory: DetailedReceiptCategory
    @State private var selectedGroup: DetailedCategoryGroup = .structural
    
    /// Categories available for receipt entry (excludes budget roll-ups)
    private var availableCategories: [DetailedReceiptCategory] {
        return DetailedReceiptCategory.allCases.filter { category in
            // Exclude pure budget roll-up categories that users shouldn't select directly
            // Keep only granular categories
            switch category {
            case .projectManagement, .supervision, .utilities, .insurance,
                 .equipment, .transportation, .administrative,
                 .unforeseen, .changeOrders, .emergencyRepairs, .overruns:
                return true // These are selectable granular categories
            default:
                return true // All renovation phase categories are selectable
            }
        }
    }
    
    private var groupedCategories: [DetailedCategoryGroup: [DetailedReceiptCategory]] {
        Dictionary(grouping: availableCategories, by: { $0.categoryGroup })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Group selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DetailedCategoryGroup.allCases) { group in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGroup = group
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: group.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedGroup == group ? .white : group.color)
                                
                                Text(group.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedGroup == group ? .white : .primary)
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 80, minHeight: 60)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedGroup == group ? group.color : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 80)
            
            Divider()
            
            // Categories in selected group
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let categories = groupedCategories[selectedGroup] {
                        ForEach(categories.sorted(by: { $0.renovationSequence < $1.renovationSequence })) { category in
                            CategorySelectionRow(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Selected category preview
            if selectedCategory != .specialty {
                selectedCategoryPreview
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Set initial group based on current selection
            selectedGroup = selectedCategory.categoryGroup
        }
    }
    
    @ViewBuilder
    private var selectedCategoryPreview: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Image(systemName: selectedCategory.icon)
                    .font(.title2)
                    .foregroundColor(selectedCategory.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCategory.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Budget Category: \(selectedCategory.budgetCategory.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
}

struct CategorySelectionRow: View {
    let category: DetailedReceiptCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(category.color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("→ \(category.budgetCategory.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if category.hasPhaseScheduling {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Phase \(category.renovationSequence)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sheet Presentation Helper

struct DetailedCategoryPickerSheet: View {
    @Binding var selectedCategory: DetailedReceiptCategory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            DetailedCategoryPickerView(selectedCategory: $selectedCategory)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationView {
        DetailedCategoryPickerView(selectedCategory: .constant(.electrical))
    }
}

#Preview("Sheet") {
    Text("Tap to show picker")
        .sheet(isPresented: .constant(true)) {
            DetailedCategoryPickerSheet(selectedCategory: .constant(.electrical))
        }
}