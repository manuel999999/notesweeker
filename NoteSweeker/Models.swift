import Foundation

struct NoteGroup: Codable, Identifiable, Equatable {
    var id = UUID()
    var noteName: String
    var contents: [NoteContent]

    private enum CodingKeys: String, CodingKey {
        case noteName, contents
    }
}

struct NoteContent: Codable, Identifiable, Equatable {
    var id = UUID()
    var value: String

    private enum CodingKeys: String, CodingKey {
        case value
    }
}
