import SwiftUI

struct EnhancedCategoryRowView: View {
    let title: String
    let spent: Double
    let total: Double
    let category: CategoryDrilldownView.CategoryType
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @State private var showingDrilldown = false
    @State private var isExpanded = false
    
    private var percentage: Double {
        total > 0 ? (spent / total) * 100 : 0
    }
    
    private var statusColor: Color {
        if spent > total {
            return .red
        } else if percentage > 80 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var topCategories: [(ReceiptCategory, Double)] {
        let breakdown = projectVM.getDetailedSpendingBreakdown(for: categoryBudgetType)
        return Array(breakdown.prefix(3))
    }
    
    private var categoryBudgetType: EnhancedBudgetCategory {
        switch category {
        case .generalConditions: return .generalConditions
        case .materials: return .materials
        case .labor: return .labor
        case .contingency: return .contingency
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main category row
            Button {
                showingDrilldown = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title and quick stats
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .frame(width: 20)
                            
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(spent.formatAsCurrency())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                                
                                Text("of \(total.formatAsCurrency())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Progress bar with enhanced visual feedback
                        VStack(spacing: 4) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    // Progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [statusColor, statusColor.opacity(0.7)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: min(geometry.size.width * (percentage / 100), geometry.size.width),
                                            height: 8
                                        )
                                        .overlay(
                                            // Percentage indicator
                                            HStack {
                                                Spacer()
                                                if percentage > 10 {
                                                    Text("\(Int(percentage))%")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .padding(.trailing, 4)
                                                }
                                            }
                                        )
                                }
                            }
                            .frame(height: 8)
                            
                            HStack {
                                Text("\(Int(percentage))% used")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Remaining: \((total - spent).formatAsCurrency())")
                                    .font(.caption2)
                                    .foregroundColor(spent > total ? .red : .secondary)
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Quick preview of top categories (expandable)
            if !topCategories.isEmpty && isExpanded {
                VStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Top Categories")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(spacing: 6) {
                        ForEach(Array(topCategories.enumerated()), id: \.offset) { index, categoryData in
                            HStack {
                                Circle()
                                    .fill(category.color.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                
                                Text(categoryData.0.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(categoryData.1.formatAsCurrency())
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("(\(spent > 0 ? Int((categoryData.1 / spent) * 100) : 0)%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // View all button
                        Button {
                            showingDrilldown = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("View All Categories")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 8)
                }
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .padding(.top, 4)
            } else if !topCategories.isEmpty {
                // Collapsed preview
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded = true
                    }
                } label: {
                    HStack {
                        Text("Quick Preview")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        // Show top 3 categories as dots
                        HStack(spacing: 4) {
                            ForEach(0..<min(3, topCategories.count), id: \.self) { _ in
                                Circle()
                                    .fill(category.color.opacity(0.6))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(6)
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showingDrilldown) {
            CategoryDrilldownView(
                category: category,
                project: project
            )
            .environmentObject(projectVM)
        }
    }
}

// MARK: - Mini Chart Components for iOS 15 Compatibility
struct MiniProgressChart: View {
    let data: [(String, Double)]
    let color: Color
    let maxValue: Double
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(item.1.formatAsCurrency())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.7))
                            .frame(
                                width: geometry.size.width * (item.1 / maxValue),
                                height: 2
                            )
                    }
                }
                .frame(height: 2)
            }
        }
    }
}

struct QuickStatsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}