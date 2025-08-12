//  DashboardView.swift
//  RheirMultiplatformApp

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            // CRITICAL FIX: Add UniversalHeaderView for consistency
            UniversalHeaderView()
                .environmentObject(authVM)
                .environmentObject(projectVM)
            
            ScrollView {
                VStack(spacing: 16) {
                    if let p = projectVM.selectedProject {
                        // Enhanced project overview card
                        projectOverviewCard(for: p)
                        
                        // Key metrics grid
                        keyMetricsGrid(for: p)
                        
                        // Quick actions section
                        quickActionsSection
                    } else {
                        emptyDashboardState
                    }
                }
                .padding()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func projectOverviewCard(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Client: \(project.client)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Project progress bar
            let totalSpent = projectVM.spentGeneralConditions + projectVM.spentMaterials + projectVM.spentContingency
            let budgetProgress = project.totalBudget > 0 ? totalSpent / project.totalBudget : 0
            
            VStack(spacing: 8) {
                HStack {
                    Text("Budget Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(budgetProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(budgetProgress > 1.0 ? .red : .blue)
                }
                
                ProgressView(value: min(budgetProgress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: budgetProgress > 1.0 ? .red : .blue))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func keyMetricsGrid(for project: Project) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            DashboardMetricCard(
                title: "Labor Budget",
                value: project.laborCost.formatAsCurrency(),
                subtitle: "Allocated",
                icon: "person.2.fill",
                color: .blue
            )
            
            DashboardMetricCard(
                title: "Material Expenses",
                value: projectVM.spentMaterials.formatAsCurrency(),
                subtitle: "Spent",
                icon: "hammer.fill",
                color: .orange
            )
            
            DashboardMetricCard(
                title: "Total Budget",
                value: project.totalBudget.formatAsCurrency(),
                subtitle: "Available",
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            DashboardMetricCard(
                title: "General Conditions",
                value: projectVM.spentGeneralConditions.formatAsCurrency(),
                subtitle: "Spent",
                icon: "building.2.fill",
                color: .purple
            )
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                QuickActionCard(
                    icon: "receipt.fill",
                    title: "Add Receipt",
                    description: "Scan or manually add a new receipt",
                    color: .blue
                ) {
                    // TODO: Navigate to receipt scanner
                }
                
                QuickActionCard(
                    icon: "clock.fill",
                    title: "Log Hours",
                    description: "Record team member work hours",
                    color: .green
                ) {
                    // TODO: Navigate to log hours
                }
                
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Add Progress",
                    description: "Log daily progress and photos",
                    color: .orange
                ) {
                    // TODO: Navigate to add progress
                }
                
                QuickActionCard(
                    icon: "chart.pie.fill",
                    title: "View Budget",
                    description: "See detailed budget breakdown",
                    color: .purple
                ) {
                    // TODO: Navigate to budget breakdown
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyDashboardState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Welcome to RHEIR")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select a project to view your dashboard overview and key metrics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Get Started") {
                // TODO: Navigate to project selection or creation
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Supporting Views

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // match your Project initializer exactly
        let sampleProject = Project(
            id: UUID(),
            name: "Demo Project",
            client: "Acme Corp",
            phone: "",
            street: "",
            city: "",
            state: "",
            zip: "",
            notes: "",
            totalBudget: 5_000,
            materialCost:      200,
            laborCost:         300,
            generalConditions: 100,
            contingency:       50,
            spentContingency:  25,
            profit:            500,
            startDate: .now.addingTimeInterval(-86_400),
            endDate:   .now.addingTimeInterval(86_400),
            loggedHours:    [],
            tasks:          [],
            communications: [],
            progressLogs:   [],
            changeOrders:   [],
            receipts:       [],
            taskTemplates:  [],
            status: .active
        )

        let vm = ProjectViewModel(offlineDataManager: OfflineDataManager())
        vm.organizationProjects = [sampleProject]
        vm.selectedProject = sampleProject

        return DashboardView()
            .environmentObject(vm)
            .environmentObject(AuthViewModel(service: PreviewAuthService()))
    }
}