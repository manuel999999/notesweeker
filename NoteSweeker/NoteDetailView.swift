import AppKit
import SwiftUI

struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.dismiss) private var dismiss

    let groupID: NoteGroup.ID

    @State private var newValue = ""

    private var group: NoteGroup? {
        store.noteGroups.first { $0.id == groupID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let group {
                    List {
                        ForEach(group.contents) { content in
                            HStack {
                                Text(content.value)
                                Spacer()
                                Button {
                                    copyToPasteboard(content.value)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")

                                Button(role: .destructive) {
                                    store.removeNoteContent(content, from: group)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        TextField("New value", text: $newValue)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addValue)
                        Button("Add", action: addValue)
                            .disabled(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                } else {
                    Text("This note no longer exists.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(group?.noteName ?? "Note")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    private func addValue() {
        guard let group else { return }
        store.addNoteContent(newValue, to: group)
        newValue = ""
    }

    private func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
