import SwiftUI

// TEMPORARILY SIMPLIFIED FOR COMPILATION
// This file will be enhanced once CloudKitOrganizationSharingService is properly integrated

struct OrganizationSharingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "shared.with.you")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Organization Sharing")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Coming Soon")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                if let org = authViewModel.currentOrg {
                    Text("Current Organization: \(org.name)")
                        .font(.callout)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Organization Sharing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    OrganizationSharingView()
        .environmentObject(AuthViewModel(service: PreviewAuthService()))
}
