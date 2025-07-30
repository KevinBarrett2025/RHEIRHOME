import SwiftUI

struct EditProgressView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let original: ProgressLog
    @State private var notes: String
    @State private var date: Date
    @State private var images: [UIImage]
    @State private var selectedEmployees: [UUID]

    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingEmployeePicker = false
    @State private var showingDeleteConfirmation = false

    @StateObject private var cameraPerm = CameraPermission()

    init(log: ProgressLog) {
        self.original = log
        _notes = State(initialValue: log.notes)
        _date = State(initialValue: log.date)
        _images = State(initialValue: [])
        _selectedEmployees = State(initialValue: Array(log.employeeIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .confirmationDialog("Are you sure you want to delete this entry?",
                                isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    viewModel.removeProgressLog(original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var photosSection: some View {
        Section("Photos") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images.indices, id: \.self) { i in
                        photoImageView(image: images[i], index: i)
                    }
                    photoButton(icon: "photo.on.rectangle.angled", source: .photoLibrary)
                    cameraButton()
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("When", selection: $date, displayedComponents: .date)
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
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
        .environmentObject(viewModel)
    }
    
    private var selectedTeamMemberNames: String {
        if selectedEmployees.isEmpty {
            return "Select…"
        } else {
            let selectedMembers = viewModel.teamMembers.filter { selectedEmployees.contains($0.id) }
            let names = selectedMembers.map(\.name)
            return names.joined(separator: ", ")
        }
    }

    private func confirmDelete() {
        showingDeleteConfirmation = true
    }
    
    private func saveChanges() {
        var updated = original
        updated.notes = notes
        updated.date = date
        updated.employeeIDs = selectedEmployees
        viewModel.updateProgressLog(
            updated,
            employees: selectedEmployees,
            images: images
        )
        dismiss()
    }

    @ViewBuilder
    private func photoButton(icon: String, source: UIImagePickerController.SourceType) -> some View {
        Button {
            guard UIImagePickerController.isSourceTypeAvailable(source) else { return }
            imagePickerSource = source
            showingImagePicker = true
        } label: {
            VStack {
                Image(systemName: icon).font(.largeTitle)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func photoImageView(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)

            Button {
                images.remove(at: index)
            } label: {
                Image(systemName: "x.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
            .offset(x: 6, y: -6)
        }
    }
    
    @ViewBuilder
    private func cameraButton() -> some View {
        Button {
            cameraPerm.requestAccess { granted in
                guard granted,
                      UIImagePickerController.isSourceTypeAvailable(.camera)
                else { return }
                imagePickerSource = .camera
                showingImagePicker = true
            }
        } label: {
            VStack {
                Image(systemName: "camera").font(.largeTitle)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}