//
//  ClientsProjectsComponents.swift
//  RHEIR
//
//  Created by AI Assistant on 1/8/25.
//

import SwiftUI

// MARK: - Client Project Group Card
struct ClientProjectGroupCard: View {
    let clientName: String
    let projects: [Project]
    let onProjectTap: (Project) -> Void
    
    private var totalValue: Double {
        projects.reduce(0) { $0 + $1.totalBudget }
    }
    
    private var averageValue: Double {
        projects.isEmpty ? 0 : totalValue / Double(projects.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Client Header
            HStack {
                Circle()
                    .fill(Color.teal.gradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(clientName.prefix(2).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(clientName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Label("\(projects.count) projects", systemImage: "folder.fill")
                        Label(totalValue.formatAsCurrency(), systemImage: "dollarsign.circle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Average Value")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(averageValue.formatAsCurrency())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                }
            }
            
            // Projects List - Use existing CompletedProjectRowView
            VStack(spacing: 8) {
                ForEach(projects.sorted { $0.endDate > $1.endDate }) { project in
                    Button {
                        onProjectTap(project)
                    } label: {
                        CompletedProjectRowView(project: project)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Client Summary Card
struct ClientSummaryCard: View {
    let clientName: String
    let projects: [Project]
    
    private var totalValue: Double {
        projects.reduce(0) { $0 + $1.totalBudget }
    }
    
    private var dateRange: String {
        guard !projects.isEmpty else { return "No projects" }
        
        let sortedProjects = projects.sorted { $0.startDate < $1.startDate }
        let startDate = sortedProjects.first?.startDate ?? Date()
        let endDate = sortedProjects.last?.endDate ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(clientName.prefix(2).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(clientName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label("\(projects.count) projects", systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(totalValue.formatAsCurrency(), systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(dateRange)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Relationship")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(relationshipStatus)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(relationshipColor)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var relationshipStatus: String {
        let monthsSinceLastProject = Calendar.current.dateComponents([.month], from: projects.map { $0.endDate }.max() ?? Date(), to: Date()).month ?? 0
        
        if monthsSinceLastProject <= 3 {
            return "Recent"
        } else if monthsSinceLastProject <= 12 {
            return "Active"
        } else {
            return "Past"
        }
    }
    
    private var relationshipColor: Color {
        let monthsSinceLastProject = Calendar.current.dateComponents([.month], from: projects.map { $0.endDate }.max() ?? Date(), to: Date()).month ?? 0
        
        if monthsSinceLastProject <= 3 {
            return .green
        } else if monthsSinceLastProject <= 12 {
            return .blue
        } else {
            return .orange
        }
    }
}

// MARK: - Project Summary Card
struct ProjectSummaryCard: View {
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            
                            Text(project.client)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(project.totalBudget.formatAsCurrency())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("Budget")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Label(project.endDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        Label("\(project.receipts.count) receipts", systemImage: "receipt")
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed")
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Financial Stat Card
struct FinancialStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Map Provider Info View
struct MapProviderInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Map Provider Selection")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose your preferred map provider for navigation and location features throughout the app.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        MapProviderCard(provider: .apple)
                        MapProviderCard(provider: .google)
                    }
                }
                .padding()
            }
            .navigationTitle("Map Providers")
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

struct MapProviderCard: View {
    let provider: MapProvider
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mapProviderIcon(provider))
                    .font(.title2)
                    .foregroundColor(mapProviderColor(provider))
                
                Text(provider.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(mapProviderDescription(provider))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Additional info based on provider
            VStack(alignment: .leading, spacing: 8) {
                switch provider {
                case .apple:
                    FeatureRow(icon: "iphone", text: "Native iOS integration")
                    FeatureRow(icon: "location.fill", text: "Privacy-focused")
                    FeatureRow(icon: "battery.100", text: "Optimized battery usage")
                    
                case .google:
                    FeatureRow(icon: "globe", text: "Comprehensive global data")
                    FeatureRow(icon: "car.fill", text: "Advanced routing options")
                    FeatureRow(icon: "magnifyingglass", text: "Superior search capabilities")
                }
            }
        }
        .padding()
        .background(mapProviderColor(provider).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func mapProviderIcon(_ provider: MapProvider) -> String {
        switch provider {
        case .apple: return "map.fill"
        case .google: return "globe.americas.fill"
        }
    }
    
    private func mapProviderColor(_ provider: MapProvider) -> Color {
        switch provider {
        case .apple: return .blue
        case .google: return .red
        }
    }
    
    private func mapProviderDescription(_ provider: MapProvider) -> String {
        switch provider {
        case .apple: return "Native iOS maps integration"
        case .google: return "Google Maps with enhanced features"
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}