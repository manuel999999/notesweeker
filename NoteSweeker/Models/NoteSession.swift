import Foundation

/// Holds a decrypted note in memory for as long as it's open, along with the
/// password needed to re-encrypt it on save.
@MainActor
final class NoteSession: ObservableObject {
    let fileURL: URL
    private let password: String

    @Published var text: String
    @Published var isDirty = false
    @Published var errorMessage: String?

    init(fileURL: URL, password: String, text: String) {
        self.fileURL = fileURL
        self.password = password
        self.text = text
    }

    func save() {
        do {
            let data = try EncryptedNoteFile.encrypt(text: text, password: password)
            try data.write(to: fileURL, options: .atomic)
            isDirty = false
        } catch {
            errorMessage = "Couldn't save the note: \(error.localizedDescription)"
        }
    }
}
