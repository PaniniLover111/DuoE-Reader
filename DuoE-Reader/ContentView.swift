import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = LibraryStore()
    @State private var search = ""
    @State private var showImporter = false
    @State private var allowedTypes: [UTType] = [.epub]
    @State private var isWorking = false
    @State private var errorMessage: String?

    private static let docx = UTType(filenameExtension: "docx")
    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 16)]

    private var shown: [Book] {
        search.isEmpty ? store.books
                       : store.books.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(shown) { book in
                        NavigationLink(value: book.id) {
                            VStack {
                                CoverView(book: book, store: store).frame(height: 180)
                                Text(book.title).font(.caption).lineLimit(2).foregroundStyle(.primary)
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.delete(book) }
                        }
                    }
                }
                .padding()
            }
            .overlay {
                if store.books.isEmpty {
                    ContentUnavailableView("No books yet", systemImage: "books.vertical",
                                           description: Text("Tap + to import an EPUB."))
                }
            }
            .overlay { if isWorking { ProgressView() } }
            .navigationTitle("Library")
            .searchable(text: $search)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Import EPUB", systemImage: "square.and.arrow.down") {
                            allowedTypes = [.epub]
                            showImporter = true
                        }
                        Button("Convert PDF or DOCX", systemImage: "arrow.triangle.2.circlepath") {
                            allowedTypes = [.pdf] + [Self.docx].compactMap { $0 }
                            showImporter = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ReaderView(bookID: id, store: store)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: allowedTypes) { result in
                guard case .success(let url) = result else { return }
                Task { await handle(url) }
            }
            .alert("Couldn't add book",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// Looks at the file extension and does the right thing.
    private func handle(_ url: URL) async {
        isWorking = true
        defer { isWorking = false }
        do {
            switch url.pathExtension.lowercased() {
            case "epub":
                try store.importEPUB(from: url)
            case "pdf", "docx":
                let epub = try await Converter.convertToEPUB(url)
                try store.importEPUB(from: epub)
            default:
                errorMessage = "Unsupported file type."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CoverView: View {
    let book: Book
    let store: LibraryStore

    var body: some View {
        if let path = book.coverPath,
           let image = UIImage(contentsOfFile: store.folderURL(for: book)
                                .appendingPathComponent(path).path) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay(Image(systemName: "book.closed").font(.largeTitle))
        }
    }
}
