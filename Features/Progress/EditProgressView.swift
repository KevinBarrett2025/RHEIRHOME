import SwiftUI

struct EditProgressView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let original: ProgressLog
    @State private var notes: String
    @State private var date: Date
    @State private var workDescription: String
    @State private var images: [UIImage]
    @State private var selectedEmployees: [UUID]

    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingEmployeePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePhotoAlert = false
    @State private var imageToDelete: Int?

    @StateObject private var cameraPerm = CameraPermission()

    init(log: ProgressLog) {
        self.original = log
        _notes = State(initialValue: log.notes)
        _date = State(initialValue: log.date)
        _workDescription = State(initialValue: log.workDescription)
        _images = State(initialValue: [])
        _selectedEmployees = State(initialValue: Array(log.employeeIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Work Description") {
                    TextField("What work was completed?", text: $workDescription, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                photosSection
                dateSection
                notesSection
                teamMembersSection
            }
            .navigationTitle("Edit Progress")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingImagePicker) {
                imagePickerSheet
            }
            .sheet(isPresented: $showingEmployeePicker) {
                employeePickerSheet
            }
            .alert("Camera Access Needed",
                   isPresented: $cameraPerm.showSettingsAlert,
                   actions: {
                       Button("Cancel", role: .cancel) {}
                       Button("Settings") { cameraPerm.openSettings() }
                   },
                   message: {
                       Text("Please allow camera access in Settings so you can snap photos.")
                   }
            )
            .alert("Delete Photo", isPresented: $showingDeletePhotoAlert) {
                Button("Cancel", role: .cancel) {
                    imageToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let index = imageToDelete {
                        images.remove(at: index)
                        imageToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this photo?")
            }
            .confirmationDialog("Are you sure you want to delete this entry?",
                                isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    projectViewModel.removeProgressLog(original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var photosSection: some View {
        Section("Progress Photos") {
            VStack(alignment: .leading, spacing: 16) {
                if images.isEmpty {
                    // Empty state with action buttons
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Document Your Progress")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Add before/after photos to show the work completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            requestCameraAccess()
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                        
                        Button {
                            imagePickerSource = .photoLibrary
                            showingImagePicker = true
                        } label: {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    // Photo grid
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(images.indices, id: \.self) { index in
                                progressPhotoView(image: images[index], index: index)
                            }
                            
                            // Add more photos button
                            addMorePhotosButton
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func progressPhotoView(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            // Delete button with small X
            Button {
                imageToDelete = index
                showingDeletePhotoAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .red)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            }
            .offset(x: 6, y: -6)
        }
    }
    
    @ViewBuilder
    private var addMorePhotosButton: some View {
        Menu {
            Button {
                requestCameraAccess()
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            
            Button {
                imagePickerSource = .photoLibrary
                showingImagePicker = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Add More")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .frame(width: 120, height: 120)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5]))
                    .foregroundColor(Color.blue.opacity(0.3))
            )
        }
    }
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("When", selection: $date, displayedComponents: .date)
        }
    }
    
    private var notesSection: some View {
        Section("Additional Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
    
    private var teamMembersSection: some View {
        Section("Who Worked") {
            Button {
                showingEmployeePicker = true
            } label: {
                HStack {
                    Text(selectedTeamMemberNames)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(role: .destructive) {
                confirmDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveChanges()
            }
        }
    }
    
    private var imagePickerSheet: some View {
        ImagePicker(
            sourceType: imagePickerSource,
            image: Binding(
                get: { nil },
                set: { if let img = $0 { images.append(img) } }
            )
        )
    }
    
    private var employeePickerSheet: some View {
        MultiSelectTeamMembersView(
            selectedTeamMemberIDs: $selectedEmployees
        )
        .environmentObject(projectViewModel)
    }
    
    private var selectedTeamMemberNames: String {
        if selectedEmployees.isEmpty {
            return "Select…"
        } else {
            let selectedMembers = projectViewModel.teamMembers.filter { selectedEmployees.contains($0.id) }
            let names = selectedMembers.map(\.name)
            return names.joined(separator: ", ")
        }
    }

    private func requestCameraAccess() {
        cameraPerm.requestAccess { granted in
            guard granted,
                  UIImagePickerController.isSourceTypeAvailable(.camera) else { 
                return 
            }
            imagePickerSource = .camera
            showingImagePicker = true
        }
    }

    private func confirmDelete() {
        showingDeleteConfirmation = true
    }
    
    private func saveChanges() {
        var updated = original
        updated.workDescription = workDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.date = date
        updated.employeeIDs = selectedEmployees
        
        projectViewModel.updateProgressLog(
            updated,
            employees: selectedEmployees,
            images: images
        )
        dismiss()
    }
}