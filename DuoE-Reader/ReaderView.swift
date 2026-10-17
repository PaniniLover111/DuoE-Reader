import SwiftUI
import WebKit

struct ReaderView: View {
    let bookID: UUID
    @ObservedObject var store: LibraryStore
    @State private var chapter = 0

    var body: some View {
        if let book = store.books.first(where: { $0.id == bookID }) {
            let folder = store.folderURL(for: book)
            TabView(selection: $chapter) {
                ForEach(book.chapterPaths.indices, id: \.self) { i in
                    ChapterWebView(fileURL: folder.appendingPathComponent(book.chapterPaths[i]),
                                   readAccess: folder)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { chapter = book.lastChapter }
            .onChange(of: chapter) { _, new in store.setLastChapter(new, for: bookID) }
        }
    }
}

struct ChapterWebView: UIViewRepresentable {
    let fileURL: URL
    let readAccess: URL

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if web.url != fileURL {
            web.loadFileURL(fileURL, allowingReadAccessTo: readAccess)
        }
    }
}
