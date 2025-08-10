import SwiftUI
import MessageUI

// MARK: - Budget Overview View (Extracted from BudgetBreakdownView)
struct BudgetOverviewView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Binding var selectedTab: Tab
    @State private var showCloseAlert = false
    @State private var showingEditProject = false
    @State private var showingReports = false

    var body: some View {
        if let project = projectVM.selectedProject {
            budgetContent(for: project)
        } else {
            emptyState
        }
    }
    
    @ViewBuilder
    private func budgetContent(for project: Project) -> some View {
        VStack(spacing: 0) {
            contentScrollView(for: project)
            actionBar(for: project)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: project)
                .environmentObject(projectVM)
        }
        .sheet(isPresented: $showingReports) {
            ProjectReportsView(project: project)
                .environmentObject(projectVM)
                .environmentObject(authVM)
        }
    }
    
    @ViewBuilder
    private func contentScrollView(for project: Project) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Client Information Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                        Text("Client Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    ClientCardView(project: project)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Budget Overview Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                        Text("Budget Breakdown")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    spentRemainingSection(for: project)
                    
                    categorySection(for: project)
                    
                    ProfitBarView(
                        totalBudget: project.totalBudget,
                        spentCosts: calculateTotalSpent()
                    )
                }
                
                Divider()
                
                // Quick Stats & Reports Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.purple)
                        Text("Project Analytics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    quickStatsSection(for: project)
                    
                    // Reports Access Card
                    reportsAccessCard
                }
            }
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func spentRemainingSection(for project: Project) -> some View {
        let spent = calculateTotalSpent()
        let remaining = project.totalBudget - spent
        let percentageUsed = project.totalBudget > 0 ? (spent / project.totalBudget) * 100 : 0
        
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(spent.formatAsCurrency())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(spent > project.totalBudget ? .red : .primary)
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("Budget Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(percentageUsed))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(percentageUsed > 100 ? .red : percentageUsed > 80 ? .orange : .green)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(remaining.formatAsCurrency())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(remaining < 0 ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func categorySection(for project: Project) -> some View {
        VStack(spacing: 16) {
            CategoryRowView(
                title: "General Conditions",
                spent: projectVM.spentGeneralConditions,
                total: project.generalConditions,
                linkCategory: .general,
                laborLink: false,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Materials",
                spent: projectVM.spentMaterials,
                total: project.materialCost,
                linkCategory: .material,
                laborLink: false,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Labor",
                spent: projectVM.spentLabor,
                total: project.laborCost,
                linkCategory: nil,
                laborLink: true,
                selectedTab: $selectedTab
            )
            
            CategoryRowView(
                title: "Contingency",
                spent: calculateContingencySpent(for: project),
                total: project.contingency,
                linkCategory: .contingency,
                laborLink: false,
                selectedTab: $selectedTab
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func quickStatsSection(for project: Project) -> some View {
        let totalReceipts = project.receipts.count
        let totalVendors = Set(project.receipts.map { $0.vendor.lowercased() }).count
        let averageReceiptAmount = totalReceipts > 0 ? calculateTotalSpent() / Double(totalReceipts) : 0
        let timeRemaining = project.endDate.timeIntervalSince(Date()) / (24 * 60 * 60) // days
        
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickStatCard(
                icon: "receipt.fill",
                title: "Total Receipts",
                value: "\(totalReceipts)",
                subtitle: "Avg: \(averageReceiptAmount.formatAsCurrency())",
                color: .blue
            )
            
            QuickStatCard(
                icon: "building.2.fill",
                title: "Active Vendors",
                value: "\(totalVendors)",
                subtitle: "View in Vendors tab",
                color: .orange
            )
            
            QuickStatCard(
                icon: "calendar.badge.clock",
                title: "Days Remaining",
                value: timeRemaining > 0 ? "\(Int(timeRemaining))" : "Overdue",
                subtitle: project.endDate.formatted(date: .abbreviated, time: .omitted),
                color: timeRemaining > 30 ? .green : timeRemaining > 7 ? .orange : .red
            )
            
            QuickStatCard(
                icon: "percent",
                title: "Budget Used",
                value: "\(Int((calculateTotalSpent() / project.totalBudget) * 100))%",
                subtitle: "of \(project.totalBudget.formatAsCurrency())",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var reportsAccessCard: some View {
        Button {
            showingReports = true
        } label: {
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("View Detailed Reports")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Access comprehensive project analytics, spending trends, and export options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func actionBar(for project: Project) -> some View {
        HStack(spacing: 16) {
            Button("Edit Project Details") {
                showingEditProject = true
            }
            .font(.subheadline.bold())
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)

            Button("Close-out") {
                showCloseAlert = true
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.red)
            .cornerRadius(10)
            .alert("Close Project?", isPresented: $showCloseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Close-out", role: .destructive) {
                    closeProject(project)
                }
            } message: {
                Text("Are you sure you want to close this project?")
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a project to view budget breakdown and analytics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    private func calculateTotalSpent() -> Double {
        let total = projectVM.spentGeneralConditions + 
                   projectVM.spentMaterials + 
                   projectVM.spentLabor + 
                   projectVM.spentContingency
        
        guard total.isFinite else {
            return 0
        }
        
        return max(0, total)
    }
    
    private func calculateContingencySpent(for project: Project) -> Double {
        let overageGeneral = max(0, projectVM.spentGeneralConditions - project.generalConditions)
        let overageMaterials = max(0, projectVM.spentMaterials - project.materialCost)
        let overageLabor = max(0, projectVM.spentLabor - project.laborCost)
        
        let result = projectVM.spentContingency + overageGeneral + overageMaterials + overageLabor
        
        guard result.isFinite else {
            return 0
        }
        
        return max(0, result)
    }

    private func closeProject(_ project: Project) {
        var copy = project
        copy.status = .completed
        projectVM.updateProject(copy)
        selectedTab = .more
    }
}

// MARK: - Project Reports View
struct ProjectReportsView: View {
    let project: Project
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Placeholder for detailed reports
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Detailed Reports")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Comprehensive project analytics and reporting will be available here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Quick actions
                        VStack(spacing: 12) {
                            Button("Export Project Summary") {
                                // TODO: Implement export functionality
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                            
                            Button("View Spending Trends") {
                                // TODO: Navigate to trends view
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Project Reports")
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