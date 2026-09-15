import AppKit
import SwiftUI

struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.dismiss) private var dismiss

    let groupID: NoteGroup.ID

    @State private var newValue = ""

    /// Session-only cache of successfully decrypted plaintext, keyed by content id.
    /// Never written back to the store or disk unless the user removes encryption.
    @State private var unlockedValues: [NoteContent.ID: String] = [:]

    private var group: NoteGroup? {
        store.noteGroups.first { $0.id == groupID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let group {
                    List {
                        ForEach(group.contents) { content in
                            row(for: content, in: group)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        unlockedValues.removeAll()
                    } label: {
                        Image(systemName: "lock")
                    }
                    .help("Hide decrypted values")
                    .disabled(unlockedValues.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 460)
        .onAppear(perform: unlockWithStoredPassword)
        .onChange(of: store.password) {
            unlockWithStoredPassword()
        }
    }

    @ViewBuilder
    private func row(for content: NoteContent, in group: NoteGroup) -> some View {
        HStack {
            if content.isEncrypted {
                if let plain = unlockedValues[content.id] {
                    Text(plain)
                        .font(.system(size: store.fontSize))
                    Spacer()
                    Button {
                        copyToPasteboard(plain)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")

                    Button {
                        store.removeEncryption(from: content, in: group, decryptedValue: plain)
                        unlockedValues[content.id] = nil
                    } label: {
                        Image(systemName: "lock.open")
                    }
                    .buttonStyle(.plain)
                    .help("Remove encryption")
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Encrypted")
                        .font(.system(size: store.fontSize))
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
            } else {
                Text(content.value)
                    .font(.system(size: store.fontSize))
                Spacer()
                Button {
                    copyToPasteboard(content.value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Button {
                    store.encryptContent(content, in: group, password: store.password)
                } label: {
                    Image(systemName: "lock")
                }
                .buttonStyle(.plain)
                .disabled(store.password.isEmpty)
                .help(
                    store.password.isEmpty
                        ? "Enter a password in the main window first"
                        : "Encrypt this value"
                )
            }

            Button(role: .destructive) {
                store.removeNoteContent(content, from: group)
                unlockedValues[content.id] = nil
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }

    private func unlockWithStoredPassword() {
        guard let group, !store.password.isEmpty else { return }
        for content in group.contents where content.isEncrypted {
            guard let salt = content.salt else { continue }
            if let plaintext = try? ContentCrypto.decrypt(content.value, saltBase64: salt, password: store.password) {
                unlockedValues[content.id] = plaintext
            }
        }
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
