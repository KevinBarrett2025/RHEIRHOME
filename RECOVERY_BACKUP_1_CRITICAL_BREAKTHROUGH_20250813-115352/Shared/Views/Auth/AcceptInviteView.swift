import SwiftUI

// TEMPORARILY SIMPLIFIED - AWS invite functionality removed
struct AcceptInviteView: View {
    @ObservedObject var authVM: AuthViewModel
    let inviteToken: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Invitation System")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Coming Soon")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("CloudKit sharing will replace the AWS-based invite system")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AcceptInviteView(authVM: AuthViewModel(service: PreviewAuthService()), inviteToken: "test-token")
}
