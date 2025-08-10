import SwiftUI

struct InviteStatusView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if authVM.pendingInvites.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Pending Invites")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Invites you send will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(authVM.pendingInvites, id: \.self) { email in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(email)
                                    .font(.headline)
                                
                                Text("Invite sent")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "paperplane")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Invite Status")
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

#Preview {
    InviteStatusView(authVM: AuthViewModel(service: PreviewAuthService()))
}
