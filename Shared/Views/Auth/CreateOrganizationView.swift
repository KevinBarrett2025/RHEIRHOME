// CreateOrganizationView.swift

import SwiftUI

#if DEBUG
/// Deprecated: Use OrganizationSetupView for production organization creation
/// This view is kept for development/testing purposes only
@available(*, deprecated, message: "Use OrganizationSetupView for production organization creation")
struct CreateOrganizationView: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var orgName: String = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("⚠️ DEVELOPMENT ONLY")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
                
                Text("Create a New Organization")
                    .font(.headline)
                    .padding(.top, 40)

                TextField("Organization Name", text: $orgName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 32)

                Button(action: {
                    createOrganization()
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isCreating ? "Creating..." : "Create Organization")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(orgName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 32)
                .disabled(orgName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)

                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("New Organization (DEV)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: vm.currentOrg) { _, currentOrg in
                if currentOrg != nil {
                    print("✅ Organization created successfully, dismissing sheet")
                    // Organization was successfully created, dismiss the sheet
                    dismiss()
                }
            }
        }
    }
    
    private func createOrganization() {
        guard !orgName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmedName = orgName.trimmingCharacters(in: .whitespaces)
        
        isCreating = true
        
        Task {
            do {
                _ = try await vm.createOrganization(named: trimmedName)
                await MainActor.run {
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    vm.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CreateOrganizationView_Previews: PreviewProvider {
    static var previews: some View {
        CreateOrganizationView(vm: AuthViewModel(service: PreviewAuthService()))
    }
}

#endif