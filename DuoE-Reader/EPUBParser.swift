import Foundation
import ZIPFoundation

struct ParsedEPUB {
    var title: String?
    var chapterPaths: [String]
    var coverPath: String?
}

enum EPUBError: LocalizedError {
    case badFile
    var errorDescription: String? { "That doesn't look like a valid EPUB." }
}

/// Collects every XML element (name, attributes, text) into a flat list.
final class XMLCollector: NSObject, XMLParserDelegate {
    struct El { var name: String; var attrs: [String: String]; var text = "" }
    var elements: [El] = []
    private var stack: [El] = []

    func run(_ data: Data) {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        stack.append(El(name: name, attrs: attributes))
    }
    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if !stack.isEmpty { stack[stack.count - 1].text += s }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if let e = stack.popLast() { elements.append(e) }
    }
}

enum EPUBParser {
    static func unzip(_ source: URL, to dest: URL) throws {
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: source, to: dest)
    }

    static func parse(folder: URL) throws -> ParsedEPUB {
        // 1. container.xml tells us where the OPF file is
        let containerURL = folder.appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL) else { throw EPUBError.badFile }
        let container = XMLCollector()
        container.run(containerData)
        guard let opfRel = container.elements.first(where: { $0.name == "rootfile" })?.attrs["full-path"],
              let opfData = try? Data(contentsOf: folder.appendingPathComponent(opfRel))
        else { throw EPUBError.badFile }

        let opfDir = (opfRel as NSString).deletingLastPathComponent
        func fullPath(_ href: String) -> String {
            let clean = href.removingPercentEncoding ?? href
            return (opfDir as NSString).appendingPathComponent(clean)
        }

        // 2. the OPF lists the title, all files (manifest) and reading order (spine)
        let opf = XMLCollector()
        opf.run(opfData)

        let title = opf.elements.first(where: { $0.name == "dc:title" })?
            .text.trimmingCharacters(in: .whitespacesAndNewlines)

        var manifest: [String: XMLCollector.El] = [:]
        for el in opf.elements where el.name == "item" {
            if let id = el.attrs["id"] { manifest[id] = el }
        }

        let chapterPaths = opf.elements
            .filter { $0.name == "itemref" }
            .compactMap { $0.attrs["idref"] }
            .compactMap { manifest[$0]?.attrs["href"] }
            .map(fullPath)
        guard !chapterPaths.isEmpty else { throw EPUBError.badFile }

        // 3. cover: EPUB3 "cover-image" property, or EPUB2 <meta name="cover">
        var coverHref = manifest.values.first(where: {
            ($0.attrs["properties"] ?? "").contains("cover-image")
        })?.attrs["href"]
        if coverHref == nil,
           let coverID = opf.elements.first(where: { $0.name == "meta" && $0.attrs["name"] == "cover" })?.attrs["content"] {
            coverHref = manifest[coverID]?.attrs["href"]
        }

        return ParsedEPUB(title: title?.isEmpty == false ? title : nil,
                          chapterPaths: chapterPaths,
                          coverPath: coverHref.map(fullPath))
    }
}
