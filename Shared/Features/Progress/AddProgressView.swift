import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddProgressView: View {
    let project: Project
    @Binding var isPresented: Bool
    @EnvironmentObject private var viewModel: ProjectViewModel
    
    @State private var workDescription = ""
    @State private var workDate = Date()
    @State private var hoursWorked: Double = 8.0
    @State private var selectedEmployees: Set<UUID> = []
    @State private var notes = ""
    @State private var selectedPhotos: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isLoading = false
    
    // Photo selection
    @State private var inputImage: UIImage?
    @State private var showingPhotoOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                workDetailsSection
                teamMembersSection
                photosSection
                notesSection
            }
            .navigationTitle("Add Progress")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") { saveProgress() }
                    .disabled(workDescription.isEmpty || isLoading)
            )
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
                Button("Camera") { showingCamera = true }
                Button("Photo Library") { showingImagePicker = true }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary, image: $inputImage)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, image: $inputImage)
            }
            .onChange(of: inputImage) { newImage in
                if let newImage = newImage {
                    selectedPhotos.append(newImage)
                    inputImage = nil
                }
            }
        }
    }
    
    private var workDetailsSection: some View {
        Section("Work Details") {
            TextField("Work Description", text: $workDescription, axis: .vertical)
                .lineLimit(3...6)
            
            DatePicker("Date", selection: $workDate, displayedComponents: .date)
            
            HStack {
                Text("Hours Worked")
                Spacer()
                TextField("Hours", value: $hoursWorked, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }
        }
    }
    
    private var teamMembersSection: some View {
        Section("Team Members") {
            if viewModel.teamMembers.isEmpty {
                Text("No team members available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.teamMembers, id: \.id) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        if selectedEmployees.contains(member.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedEmployees.contains(member.id) {
                            selectedEmployees.remove(member.id)
                        } else {
                            selectedEmployees.insert(member.id)
                        }
                    }
                }
            }
        }
    }
    
    private var photosSection: some View {
        Section("Photos") {
            if !selectedPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(selectedPhotos.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedPhotos[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    selectedPhotos.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Button(action: { showingPhotoOptions = true }) {
                Label("Add Photos", systemImage: "camera.fill")
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Additional notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func saveProgress() {
        guard !workDescription.isEmpty else { return }
        
        isLoading = true
        
        // Convert UIImages to photo IDs (for CloudKit compatibility)
        let photoIDs = selectedPhotos.enumerated().map { index, _ in
            UUID() // In a real implementation, these would be CloudKit record IDs
        }
        
        let log = ProgressLog(
            date: workDate,
            workDescription: workDescription,
            notes: notes,
            employeeIDs: Array(selectedEmployees),
            photoIDs: photoIDs
        )
        
        Task {
            await viewModel.addProgressLog(log, to: project.id)
            await MainActor.run {
                isLoading = false
                isPresented = false
            }
        }
    }
}

// MARK: - Remove duplicate ImagePicker (use the one from Shared/Utilities)

#Preview {
    AddProgressView(
        project: Project(
            name: "Sample Project",
            client: "John Doe",
            totalBudget: 50000,
            startDate: Date(),
            endDate: Date(),
            organizationID: "sample-org-id"
        ),
        isPresented: .constant(true)
    )
    .environmentObject({
        let vm = ProjectViewModel(offlineDataManager: OfflineDataManager())
        return vm
    }())
}