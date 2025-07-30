import SwiftUI

struct InviteUserView: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Invite Team Member")
                    .font(.headline)
                    .padding(.top, 20)

                TextField("Email Address", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 32)

                Button(action: {
                    guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    vm.invite(email: email.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }) {
                    Text("Send Invitation")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 32)
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)

                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Invite User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InviteUserView_Previews: PreviewProvider {
    static var previews: some View {
        InviteUserView(vm: AuthViewModel(service: CloudKitAuthService()))
    }
}