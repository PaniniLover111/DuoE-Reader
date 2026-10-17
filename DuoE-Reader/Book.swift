import Foundation

struct Book: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var folder: String            // folder name inside Documents/Books
    var chapterPaths: [String]    // relative to folder, in reading order
    var coverPath: String?
    var lastChapter = 0
}
