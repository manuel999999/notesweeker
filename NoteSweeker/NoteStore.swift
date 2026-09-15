import AppKit
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published var noteGroups: [NoteGroup] = []
    @Published private(set) var fileURL: URL?
    @Published var errorMessage: String?

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
}
