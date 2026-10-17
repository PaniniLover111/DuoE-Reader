//
//  PDFReaderView.swift
//  DuoE-Reader
//
//  Created by Reuben on 17/10/2026.
//

import SwiftUI
import PDFKit

struct PDFReaderView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = document
    }
}
