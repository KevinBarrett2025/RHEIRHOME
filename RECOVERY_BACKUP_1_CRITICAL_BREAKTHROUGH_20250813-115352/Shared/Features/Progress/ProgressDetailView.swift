import SwiftUI

struct ProgressDetailView: View {
    @EnvironmentObject var viewModel: ProjectViewModel
    let log: ProgressLog

    // Wrap selected image in Identifiable for sheet
    private struct ImageHolder: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var imageHolder: ImageHolder?

    private var employeeNames: [String] {
        viewModel.teamMembers
            .filter { log.employeeIDs.contains($0.id) }
            .map(\.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: Photos
                if !log.photoIDs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(log.photoIDs, id: \.self) { photoID in
                                // TODO: Load actual images from photo service when implemented
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                        .frame(width: 120, height: 80)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    Text("Photo ID: \(photoID.uuidString.prefix(8))...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .onTapGesture {
                                    // TODO: Load and display actual image when photo service is implemented
                                    print("Tapped photo ID: \(photoID)")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Date
                Text(log.date, style: .date)
                    .font(.headline)

                // MARK: Work Description
                if !log.workDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Work Description:")
                            .bold()
                        Text(log.workDescription)
                    }
                }

                // MARK: Employees
                if !employeeNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Worked by:")
                            .bold()
                        ForEach(employeeNames, id: \.self) { name in
                            Text(name)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }

                // MARK: Notes
                if !log.notes.isEmpty {
                    Text("Notes:")
                        .bold()
                    Text(log.notes)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Progress Detail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Edit") {
                    EditProgressView(log: log)
                        .environmentObject(viewModel)
                }
            }
        }
        // TODO: Re-implement image viewing when photo service is ready
        .sheet(item: $imageHolder) { holder in
            NavigationStack {
                ZoomableImageView(image: holder.image)
                    .ignoresSafeArea()
                    .background(Color.black)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                imageHolder = nil
                            }
                        }
                    }
            }
        }
    }
}

// MARK: – WrapHStack (unchanged)
struct WrapHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    init(items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            var x: CGFloat = 0
            ZStack(alignment: .topLeading) {
                ForEach(Array(items), id: \.self) { item in
                    content(item)
                        .padding(4)
                        .alignmentGuide(.leading) { d in
                            if abs(x - d.width) > geo.size.width {
                                x = 0
                            }
                            let result = x
                            x += d.width
                            return result
                        }
                        .alignmentGuide(.top) { _ in 0 }
                }
            }
        }
        .frame(height: 60)
    }
}
