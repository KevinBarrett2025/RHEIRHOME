import SwiftUI

struct ReceiptsView: View {
    @EnvironmentObject var projectVM: ProjectViewModel
    @Binding var selectedTab: Tab
    @State private var showingNewReceipt = false
    @State private var showingScanner = false
    @State private var receiptToEdit: Receipt? = nil
    @State private var showingDeleteAlert = false
    @State private var receiptToDelete: Receipt? = nil
    
    private var receipts: [Receipt] {
        return projectVM.selectedProject?.receipts.sorted { $0.date > $1.date } ?? []
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let project = projectVM.selectedProject {
                    receiptsListView(for: project)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Manual Entry") {
                            showingNewReceipt = true
                        }
                        Button("Scan Receipt") {
                            showingScanner = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(projectVM.selectedProject == nil)
                }
            }
            .sheet(isPresented: $showingNewReceipt) {
                if let project = projectVM.selectedProject {
                    ManualReceiptEntryView(isPresented: $showingNewReceipt, project: project)
                        .environmentObject(projectVM)
                }
            }
            .sheet(isPresented: $showingScanner) {
                if let project = projectVM.selectedProject {
                    ReceiptScannerView(isPresented: $showingScanner, project: project)
                        .environmentObject(projectVM)
                }
            }
            .sheet(item: $receiptToEdit) { receipt in
                ReceiptEditView(receipt: receipt, isPresented: Binding(
                    get: { receiptToEdit != nil },
                    set: { if !$0 { receiptToEdit = nil } }
                ))
                .environmentObject(projectVM)
            }
            .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    receiptToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let receipt = receiptToDelete {
                        deleteReceipt(receipt)
                    }
                }
            } message: {
                if let receipt = receiptToDelete {
                    Text("Are you sure you want to delete the receipt from \(receipt.vendor) for \(receipt.amount.formatAsCurrency())? This action cannot be undone.")
                }
            }
        }
    }
    
    private func receiptsListView(for project: Project) -> some View {
        Group {
            if receipts.isEmpty {
                emptyReceiptsView
            } else {
                List {
                    ForEach(receipts) { receipt in
                        NavigationLink(destination: ReceiptDetailView(receipt: receipt).environmentObject(projectVM)) {
                            ReceiptRowView(receipt: receipt)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                receiptToDelete = receipt
                                showingDeleteAlert = true
                            }
                            
                            Button("Edit") {
                                receiptToEdit = receipt
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("Edit") {
                                receiptToEdit = receipt
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func deleteReceipts(offsets: IndexSet) {
        guard let project = projectVM.selectedProject else { return }
        
        for index in offsets {
            let receipt = receipts[index]
            receiptToDelete = receipt
            showingDeleteAlert = true
            return // Only handle one at a time for confirmation
        }
    }
    
    private func deleteReceipt(_ receipt: Receipt) {
        guard projectVM.selectedProject != nil else { 
            receiptToDelete = nil
            return 
        }
        
        var updatedProject = projectVM.selectedProject!
        updatedProject.receipts.removeAll { $0.id == receipt.id }
        
        // Update vendor and payment method spending totals
        updateVendorSpending(for: receipt, isRemoving: true)
        updatePaymentMethodSpending(for: receipt, isRemoving: true)
        
        projectVM.save(updatedProject)
        projectVM.recomputeFilteredReceipts()
        
        receiptToDelete = nil
        
        print("🗑️ Deleted receipt from \(receipt.vendor) for \(receipt.amount.formatAsCurrency())")
    }
    
    private func updateVendorSpending(for receipt: Receipt, isRemoving: Bool) {
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        // Find the vendor and update spending
        let vendor = projectVM.vendorService.findOrCreateVendor(
            name: receipt.vendor,
            category: .other // Will be detected properly by the service
        )
        
        if let index = projectVM.vendorService.vendors.firstIndex(where: { $0.id == vendor.id }) {
            projectVM.vendorService.vendors[index].totalSpent += adjustmentAmount
            // Don't let spending go negative
            projectVM.vendorService.vendors[index].totalSpent = max(0, projectVM.vendorService.vendors[index].totalSpent)
        }
    }
    
    private func updatePaymentMethodSpending(for receipt: Receipt, isRemoving: Bool) {
        guard !receipt.paymentMethod.isEmpty else { return }
        
        let amount = receipt.isReturn ? -receipt.amount : receipt.amount
        let adjustmentAmount = isRemoving ? -amount : amount
        
        // Find the payment method and update spending
        let paymentMethod = projectVM.paymentMethodService.findOrCreatePaymentMethod(
            name: receipt.paymentMethod,
            type: .other // Will be detected properly by the service
        )
        
        if let index = projectVM.paymentMethodService.paymentMethods.firstIndex(where: { $0.id == paymentMethod.id }) {
            projectVM.paymentMethodService.paymentMethods[index].totalSpent += adjustmentAmount
            // Don't let spending go negative
            projectVM.paymentMethodService.paymentMethods[index].totalSpent = max(0, projectVM.paymentMethodService.paymentMethods[index].totalSpent)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Project Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a project from the Projects tab to view receipts")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Go to Projects") {
                selectedTab = .projects
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyReceiptsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Receipts Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add receipts by scanning or manual entry")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Scan Receipt") {
                    showingScanner = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Manual Entry") {
                    showingNewReceipt = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

struct ReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptsView(selectedTab: .constant(.receipts))
            .environmentObject(ProjectViewModel())
    }
}