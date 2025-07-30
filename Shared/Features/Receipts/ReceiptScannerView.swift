import SwiftUI

struct ReceiptScannerView: View {
    @Binding var isPresented: Bool
    let project: Project
    @EnvironmentObject var projectVM: ProjectViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Receipt Scanner")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Text("Receipt scanning with OCR and AI processing will be available in a future update.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
                
                Button("Use Manual Entry Instead") {
                    isPresented = false
                    // Trigger manual entry
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct ReceiptScannerView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            name: "Sample House",
            client: "John Doe",
            totalBudget: 50000,
            materialCost: 25000,
            laborCost: 15000,
            generalConditions: 5000,
            contingency: 5000,
            profit: 0,
            startDate: Date(),
            endDate: Date()
        )
        
        ReceiptScannerView(isPresented: .constant(true), project: sampleProject)
            .environmentObject(ProjectViewModel())
    }
}