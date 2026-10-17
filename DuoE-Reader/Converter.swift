import Foundation

enum ConversionError: LocalizedError {
    case notConfigured, failed
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "File conversion isn't set up yet."
        case .failed: return "The converter couldn't convert that file."
        }
    }
}

/// iOS has no built-in PDF/DOCX -> EPUB converter, so this sends the file to a
/// small server that does the work and returns an .epub.
enum Converter {
    /// Set this to your converter server's address once you have one.
    static let serverURL: URL? = nil   // e.g. URL(string: "https://your-server.example")

    static func convertToEPUB(_ source: URL) async throws -> URL {
        guard let serverURL else { throw ConversionError.notConfigured }

        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)

        var request = URLRequest(url: serverURL.appendingPathComponent("convert"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(source.pathExtension.lowercased(), forHTTPHeaderField: "X-File-Type")

        let (output, response) = try await URLSession.shared.upload(for: request, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ConversionError.failed }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".epub")
        try output.write(to: dest)
        return dest
    }
}
