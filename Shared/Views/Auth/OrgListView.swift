import SwiftUI

struct OrgListView: View {
    @ObservedObject private var vm: AuthViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingCreateOrg = false
    @State private var newOrgName = ""
    @State private var isCreating = false
    
    init(vm: AuthViewModel) {
        self.vm = vm
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if vm.isLoadingOrgs {
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.organizations.isEmpty {
                    emptyStateView
                } else {
                    organizationsList
                }
            }
            .navigationTitle("Organizations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        showingCreateOrg = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.currentOrg != nil {
                        Button("Done") {
                            sessionStore.cancelOrganizationSelection()
                        }
                    } else {
                        Button("Sign Out") {
                            vm.signOut()
                        }
                    }
                }
            }
            .alert("Create Organization", isPresented: $showingCreateOrg) {
                TextField("Organization Name", text: $newOrgName)
                    .onChange(of: newOrgName) { oldValue, newValue in
                        // Auto-check name availability
                        vm.checkOrganizationNameAvailability(newValue)
                    }
                
                Button("Create") {
                    createOrganization()
                }
                .disabled(newOrgName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         vm.nameAvailabilityMessage.contains("❌"))
                
                Button("Cancel", role: .cancel) {
                    newOrgName = ""
                    vm.nameAvailabilityMessage = ""
                    vm.suggestedNames = []
                }
            } message: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter a name for your new organization")
                    
                    if !vm.nameAvailabilityMessage.isEmpty {
                        Text(vm.nameAvailabilityMessage)
                            .font(.caption)
                            .foregroundColor(vm.nameAvailabilityMessage.contains("✅") ? .green : .red)
                    }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") {
                    vm.errorMessage = nil
                }
            } message: {
                if let error = vm.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Organizations")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("You don't belong to any organizations yet.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("Create one to get started, or ask a team member to invite you.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button("Create Organization") {
                showingCreateOrg = true
            }
            .buttonStyle(.borderedProminent)
            
            if !vm.inviteStatus.isEmpty {
                Text(vm.inviteStatus)
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
    
    private var organizationsList: some View {
        List {
            ForEach(vm.organizations, id: \.id) { org in
                Button(action: {
                    sessionStore.selectOrganization(org)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(org.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(org.members.count) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if vm.currentOrg?.id == org.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            
            // Show invite status if available
            if !vm.inviteStatus.isEmpty {
                Section {
                    Text(vm.inviteStatus)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private func createOrganization() {
        guard !newOrgName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedName = newOrgName.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreating = true
        
        Task {
            do {
                _ = try await vm.createOrganizationWithValidation(named: trimmedName)
                await MainActor.run {
                    newOrgName = ""
                    isCreating = false
                    vm.nameAvailabilityMessage = ""
                    vm.suggestedNames = []
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

struct OrgListView_Previews: PreviewProvider {
    static var previews: some View {
        let authViewModel = AuthViewModel(service: PreviewAuthService())
        let projectViewModel = ProjectViewModel(offlineDataManager: OfflineDataManager())

        return OrgListView(vm: authViewModel)
            .environmentObject(
                SessionStore(
                    authViewModel: authViewModel,
                    projectViewModel: projectViewModel
                )
            )
    }
}
