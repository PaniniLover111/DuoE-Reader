//
//  ContentView.swift
//  DuoE-Reader
//
//  Created by Reuben on 17/10/2026.
//

import SwiftUI
import PDFKit
internal import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showPicker = false
    @State private var document: PDFDocument?

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PDFReaderView(document: document)
                } else {
                    ContentUnavailableView(
                        "No document",
                        systemImage: "book",
                        description: Text("Tap + to open a PDF.")
                    )
                }
            }
            .navigationTitle("Reader")
            .toolbar {
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                }
            }
            .fileImporter(isPresented: $showPicker,
                          allowedContentTypes: [.pdf]) { result in
                guard case .success(let url) = result else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    document = PDFDocument(data: data)
                }
            }
        }
    }
}
