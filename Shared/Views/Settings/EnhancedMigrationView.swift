import SwiftUI

// TEMPORARILY SIMPLIFIED FOR COMPILATION
// This file will be enhanced once OrganizationDataMigrationService is properly integrated

struct EnhancedMigrationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Enhanced Migration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Coming Soon")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                if let org = authViewModel.currentOrg {
                    VStack(spacing: 8) {
                        Text("Organization: \(org.name)")
                        Text("Projects to migrate: \(projectViewModel.projects.count)")
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Enhanced Migration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    EnhancedMigrationView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
        .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
}
