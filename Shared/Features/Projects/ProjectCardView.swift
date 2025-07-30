import SwiftUI

struct ProjectCardView: View {
    let project: Project
    @ObservedObject var projectVM: ProjectViewModel
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with project name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                }
                
                Spacer()
                
                // Status badge
                StatusBadgeView(status: project.status)
            }
            
            // Budget and progress information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Budget:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(project.totalBudget, specifier: "%.0f")")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                // Progress indicators
                if !project.progressLogs.isEmpty {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(project.progressLogs.count) updates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !project.receipts.isEmpty {
                            Image(systemName: "receipt.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("\(project.receipts.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Timeline
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(project.startDate, style: .date)
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("End:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(project.endDate, style: .date)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            projectVM.select(project)
        }
        .contextMenu {
            Button {
                projectVM.select(project)
            } label: {
                Label("View Details", systemImage: "eye")
            }
            
            if project.status != .completed {
                Button {
                    projectVM.markProjectAsCompleted(project)
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
        .alert("Delete Project", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                projectVM.deleteProjectPermanently(project) { success, error in
                    if !success {
                        print("❌ Failed to delete project: \(error ?? "Unknown error")")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete '\(project.name)'? This action cannot be undone.")
        }
    }
}

// MARK: - Supporting Views

private struct StatusBadgeView: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .active:
            return .blue.opacity(0.2)
        case .completed:
            return .green.opacity(0.2)
        case .onHold:
            return .orange.opacity(0.2)
        case .cancelled:
            return .red.opacity(0.2)
        case .planning:
            return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .active:
            return .blue
        case .completed:
            return .green
        case .onHold:
            return .orange
        case .cancelled:
            return .red
        case .planning:
            return .gray
        }
    }
}

#Preview {
    let sampleProject = Project(
        name: "Kitchen Renovation",
        client: "Smith Family",
        totalBudget: 25000,
        materialCost: 15000,
        laborCost: 8000,
        generalConditions: 1000,
        contingency: 1000,
        profit: 0,
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    )
    
    ProjectCardView(project: sampleProject, projectVM: ProjectViewModel(cloudKitService: CloudKitAuthService()))
        .padding()
}