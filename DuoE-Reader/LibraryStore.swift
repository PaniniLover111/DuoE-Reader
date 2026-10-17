import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    private let root: URL
    private let indexURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rootURL = docs.appendingPathComponent("Books", isDirectory: true)
        let indexFile = docs.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var loaded: [Book] = []
        if let data = try? Data(contentsOf: indexFile),
           let saved = try? JSONDecoder().decode([Book].self, from: data) {
            loaded = saved
        }

        self.root = rootURL
        self.indexURL = indexFile
        self.books = loaded
    }


    func folderURL(for book: Book) -> URL {
        root.appendingPathComponent(book.folder, isDirectory: true)
    }

    func importEPUB(from url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let folderName = UUID().uuidString
        let dest = root.appendingPathComponent(folderName, isDirectory: true)
        do {
            try EPUBParser.unzip(url, to: dest)
            let parsed = try EPUBParser.parse(folder: dest)
            books.append(Book(
                title: parsed.title ?? url.deletingPathExtension().lastPathComponent,
                folder: folderName,
                chapterPaths: parsed.chapterPaths,
                coverPath: parsed.coverPath))
            save()
        } catch {
            try? FileManager.default.removeItem(at: dest)
            throw error
        }
    }

    func setLastChapter(_ chapter: Int, for id: UUID) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].lastChapter = chapter
        save()
    }

    func delete(_ book: Book) {
        try? FileManager.default.removeItem(at: folderURL(for: book))
        books.removeAll { $0.id == book.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: indexURL)
        }
    }
}
