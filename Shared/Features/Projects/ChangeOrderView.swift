#if canImport(UIKit)
import UIKit
import PhotosUI
#endif
import SwiftUI

struct ChangeOrderView: View {
    @EnvironmentObject var viewModel: ProjectViewModel

    // iOS‑only state for camera/photo
    #if os(iOS)
    @State private var description: String = ""
    @State private var costImpact: String = ""
    @State private var showAlert = false

    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var receiptImage: UIImage? = nil
    #endif

    var body: some View {
        NavigationStack {
            if let project = viewModel.selectedProject {
                ScrollView {
                    VStack(spacing: 16) {
                        #if os(iOS)
                        HeaderView(
                            receiptImage: $receiptImage,
                            showCamera: $showCamera,
                            pickedItem: $pickedItem
                        )
                        FormFieldsView(
                            description: $description,
                            costImpact: $costImpact,
                            showAlert: $showAlert,
                            receiptImage: $receiptImage
                        )
                        #endif

                        ChangeOrderHistoryView(project: project)
                    }
                }
                .navigationTitle("Change Orders")
                #if os(iOS)
                .fullScreenCover(isPresented: $showCamera) {
                    CameraCaptureView(image: $receiptImage)
                        .edgesIgnoringSafeArea(.all)
                }
                #endif
            } else {
                NoProjectSelectedView()
            }
        }
    }
}

#if os(iOS)
private struct HeaderView: View {
    @Binding var receiptImage: UIImage?
    @Binding var showCamera: Bool
    @Binding var pickedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            if let img = receiptImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                PhotosPicker(
                    selection: $pickedItem,
                    matching: .images
                ) {
                    Label("Choose from Library", systemImage: "photo")
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FormFieldsView: View {
    @Binding var description: String
    @Binding var costImpact: String
    @Binding var showAlert: Bool
    @Binding var receiptImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Description", text: $description)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            TextField("Cost Impact ($)", text: $costImpact)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Submit Change Order") {
                guard
                    !description.isEmpty,
                    let _ = Double(costImpact)
                else { return }

                // your logging logic here...
                description = ""
                costImpact = ""
                receiptImage = nil
                showAlert = true
            }
            .disabled(description.isEmpty || costImpact.isEmpty)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                (description.isEmpty || costImpact.isEmpty)
                    ? Color.gray.opacity(0.5)
                    : Color.blue
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .alert("Success", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Change order logged successfully")
            }
        }
    }
}
#endif

private struct ChangeOrderHistoryView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Change Order History")
                .font(.headline)
                .padding(.horizontal)
            
            if project.changeOrders.isEmpty {
                Text("No change orders logged yet.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(project.changeOrders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(order.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(order.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Change: $\(order.changeAmount, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundColor(order.changeAmount >= 0 ? .green : .red)
                            Spacer()
                            Text(order.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Status: \(order.status.rawValue)")
                                .foregroundColor(order.status.tintColor)
                            Spacer()
                            Button {
                                // approval toggle...
                            } label: {
                                Text(order.status == .approved ? "Implemented" : "Approve")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                    
                    Divider()
                }
            }
        }
        .frame(minHeight: 200)
    }
}

private struct NoProjectSelectedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No Selected Project")
                .font(.headline)
            Text("Please select a project in the Projects tab.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("Change Orders")
    }
}

struct ChangeOrderView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChangeOrderView()
                .environmentObject(ProjectViewModel(offlineDataManager: OfflineDataManager()))
        }
    }
}
