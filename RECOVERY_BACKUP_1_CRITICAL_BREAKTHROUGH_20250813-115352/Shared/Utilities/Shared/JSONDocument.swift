import SwiftUI
import UniformTypeIdentifiers

/// Wraps raw Data so SwiftUI can save it via the system file-exporter UI.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    // Called when exporting (write-only), so we only need this:
    init(data: Data) {
        self.data = data
    }

    // Not used for export, but required:
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}
