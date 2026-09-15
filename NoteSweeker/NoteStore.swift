import AppKit
import Foundation
import SwiftUI

enum NoteFontSize: CGFloat, CaseIterable, Identifiable {
    case small = 12
    case medium = 14
    case large = 17
    case extraLarge = 20

    var id: CGFloat { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

enum NoteAccentColor: String, CaseIterable, Identifiable {
    case blue, purple, green, orange, pink, gray

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .gray: return .gray
        }
    }

    /// Background tint for odd rows in a list.
    var alternateRowColor: Color {
        color.opacity(0.15)
    }

    /// Subtler background tint for even rows in a list.
    var baseRowColor: Color {
        color.opacity(0.05)
    }
}

@MainActor
final class NoteStore: ObservableObject {
    @Published var noteGroups: [NoteGroup] = []
    @Published private(set) var fileURL: URL?
    @Published var errorMessage: String?

    /// Session-only password used to encrypt new values and to auto-decrypt
    /// encrypted content when a note is opened. Never persisted to disk.
    @Published var password: String = ""

    /// Text size used for note names and content values. Persisted across launches.
    @Published var fontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: Self.fontSizeDefaultsKey)
        }
    }

    /// Accent color used to tint alternating list rows. Persisted across launches.
    @Published var accentColor: NoteAccentColor {
        didSet {
            UserDefaults.standard.set(accentColor.rawValue, forKey: Self.accentColorDefaultsKey)
        }
    }

    private static let fontSizeDefaultsKey = "NoteSweeker.fontSize"
    private static let accentColorDefaultsKey = "NoteSweeker.accentColor"

    init() {
        let storedFontSize = UserDefaults.standard.double(forKey: Self.fontSizeDefaultsKey)
        fontSize = storedFontSize > 0 ? CGFloat(storedFontSize) : NoteFontSize.medium.rawValue

        let storedColorName = UserDefaults.standard.string(forKey: Self.accentColorDefaultsKey)
        accentColor = NoteAccentColor(rawValue: storedColorName ?? "") ?? .blue
    }

    // MARK: - Opening / creating files

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a notes JSON file to open"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    func newFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Notes.json"
        panel.message = "Choose where to create your notes file"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try write([], to: url)
            fileURL = url
            noteGroups = []
        } catch {
            errorMessage = "Couldn't create file: \(error.localizedDescription)"
        }
    }

    private func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let groups = try JSONDecoder().decode([NoteGroup].self, from: data)
            fileURL = url
            noteGroups = groups
        } catch {
            errorMessage = "Couldn't open file: \(error.localizedDescription)"
        }
    }

    // MARK: - Saving

    private func write(_ groups: [NoteGroup], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(groups)
        try data.write(to: url, options: .atomic)
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try write(noteGroups, to: fileURL)
        } catch {
            errorMessage = "Couldn't save file: \(error.localizedDescription)"
        }
    }

    // MARK: - NoteGroup mutations

    func addNoteGroup(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        noteGroups.append(NoteGroup(noteName: trimmed, contents: []))
        save()
    }

    func removeNoteGroup(_ group: NoteGroup) {
        noteGroups.removeAll { $0.id == group.id }
        save()
    }

    func removeNoteGroups(at offsets: IndexSet) {
        noteGroups.remove(atOffsets: offsets)
        save()
    }

    // MARK: - NoteContent mutations

    func addNoteContent(_ value: String, to group: NoteGroup) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = noteGroups.firstIndex(where: { $0.id == group.id }) else { return }
        noteGroups[index].contents.append(NoteContent(value: trimmed))
        save()
    }

    func removeNoteContent(_ content: NoteContent, from group: NoteGroup) {
        guard let index = noteGroups.firstIndex(where: { $0.id == group.id }) else { return }
        noteGroups[index].contents.removeAll { $0.id == content.id }
        save()
    }

    func removeNoteContents(at offsets: IndexSet, from group: NoteGroup) {
        guard let index = noteGroups.firstIndex(where: { $0.id == group.id }) else { return }
        noteGroups[index].contents.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Encryption

    /// Encrypts a content value in place with the given password and persists the ciphertext.
    func encryptContent(_ content: NoteContent, in group: NoteGroup, password: String) {
        guard !password.isEmpty,
              let groupIndex = noteGroups.firstIndex(where: { $0.id == group.id }),
              let contentIndex = noteGroups[groupIndex].contents.firstIndex(where: { $0.id == content.id }),
              !noteGroups[groupIndex].contents[contentIndex].isEncrypted else { return }

        do {
            let (ciphertext, salt) = try ContentCrypto.encrypt(
                noteGroups[groupIndex].contents[contentIndex].value,
                password: password
            )
            noteGroups[groupIndex].contents[contentIndex].value = ciphertext
            noteGroups[groupIndex].contents[contentIndex].isEncrypted = true
            noteGroups[groupIndex].contents[contentIndex].salt = salt
            save()
        } catch {
            errorMessage = "Couldn't encrypt value: \(error.localizedDescription)"
        }
    }

    /// Permanently replaces an encrypted content value with its already-decrypted plaintext and persists it.
    func removeEncryption(from content: NoteContent, in group: NoteGroup, decryptedValue: String) {
        guard let groupIndex = noteGroups.firstIndex(where: { $0.id == group.id }),
              let contentIndex = noteGroups[groupIndex].contents.firstIndex(where: { $0.id == content.id }) else { return }

        noteGroups[groupIndex].contents[contentIndex].value = decryptedValue
        noteGroups[groupIndex].contents[contentIndex].isEncrypted = false
        noteGroups[groupIndex].contents[contentIndex].salt = nil
        save()
    }
}
