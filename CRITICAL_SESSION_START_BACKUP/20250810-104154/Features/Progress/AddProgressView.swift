import SwiftUI

struct AddProgressView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var notes = ""
    @State private var workDescription = ""
    @State private var date = Date()
    @State private var images: [UIImage] = []
    @State private var selectedEmployees: Set<UUID> = []
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingEmployeePicker = false

    @StateObject private var cameraPerm = CameraPermission()
    
    private var selectedEmployeeNames: [String] {
        viewModel.teamMembers
            .filter { selectedEmployees.contains($0.id) }
            .map { $0.name }
            .sorted()
    }
    
    private var canSave: Bool {
        !workDescription.isEmpty || !notes.isEmpty || !images.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                dateSection
                workDescriptionSection
                notesSection
                teamMemberSection
            }
            .navigationTitle("Add Progress")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProgressLog()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    sourceType: imagePickerSource,
                    image: Binding(
                        get: { nil },
                        set: { if let img = $0 { images.append(img) } }
                    )
                )
            }
            .sheet(isPresented: $showingEmployeePicker) {
                MultiSelectTeamMembersView(selectedTeamMemberIDs: Binding(
                    get: { Array(selectedEmployees) },
                    set: { selectedEmployees = Set($0) }
                ))
                .environmentObject(viewModel)
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
        }
    }
    
    // MARK: - Broken down sections to reduce complex expressions
    
    @ViewBuilder
    private var photoSection: some View {
        Section("Photos") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    photoGrid
                    photoLibraryButton
                    cameraButton
                }
            }
        }
    }
    
    @ViewBuilder
    private var photoGrid: some View {
        ForEach(images.indices, id: \.self) { i in
            photoThumbnail(for: i)
        }
    }
    
    @ViewBuilder
    private func photoThumbnail(for index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
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
    private var photoLibraryButton: some View {
        Button {
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
            imagePickerSource = .photoLibrary
            showingImagePicker = true
        } label: {
            VStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var cameraButton: some View {
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
                Image(systemName: "camera")
                    .font(.largeTitle)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var dateSection: some View {
        Section("Date") {
            DatePicker("When", selection: $date, displayedComponents: .date)
        }
    }
    
    @ViewBuilder
    private var workDescriptionSection: some View {
        Section("Work Description") {
            TextField("What work was completed?", text: $workDescription, axis: .vertical)
                .lineLimit(2...4)
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        Section("Additional Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
    
    @ViewBuilder
    private var teamMemberSection: some View {
        Section("Who Worked") {
            if selectedEmployees.isEmpty {
                emptyTeamMemberState
            } else {
                populatedTeamMemberState
            }
        }
    }
    
    @ViewBuilder
    private var emptyTeamMemberState: some View {
        Button {
            showingEmployeePicker = true
        } label: {
            HStack {
                Image(systemName: "person.2.badge.plus")
                    .foregroundColor(.blue)
                Text("Select Team Members")
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private var populatedTeamMemberState: some View {
        VStack(alignment: .leading, spacing: 12) {
            teamMemberHeader
            teamMemberBubbles
        }
    }
    
    @ViewBuilder
    private var teamMemberHeader: some View {
        HStack {
            Text("Selected Team Members (\(selectedEmployees.count))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Edit") {
                showingEmployeePicker = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var teamMemberBubbles: some View {
        VStack(spacing: 8) {
            teamMemberList
            addTeamMemberButton
        }
    }
    
    @ViewBuilder
    private var teamMemberList: some View {
        ForEach(selectedEmployeeNames, id: \.self) { name in
            teamMemberBubble(for: name)
        }
    }
    
    @ViewBuilder
    private func teamMemberBubble(for name: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Button {
                    if let employee = viewModel.teamMembers.first(where: { $0.name == name }) {
                        selectedEmployees.remove(employee.id)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var addTeamMemberButton: some View {
        HStack {
            Button {
                showingEmployeePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                    Text("Add Team Member")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveProgressLog() {
        let log = ProgressLog(
            date: date,
            workDescription: workDescription.isEmpty ? "Daily progress update" : workDescription,
            notes: notes,
            employeeIDs: Array(selectedEmployees),
            category: "general",
            photoIDs: [] // TODO: Handle photo saving properly when photo service is implemented
        )
        
        // FIXED: Direct method call instead of dynamic member lookup
        viewModel.addProgressLog(log)
        dismiss()
    }
}