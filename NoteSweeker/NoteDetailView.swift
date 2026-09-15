import AppKit
import SwiftUI

struct NoteDetailView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.dismiss) private var dismiss

    let groupID: NoteGroup.ID

    @State private var newValue = ""

    /// Password entered in the unlock bar, used to attempt decrypting every encrypted
    /// content item in this note independently.
    @State private var unlockPassword = ""

    /// Session-only cache of successfully decrypted plaintext, keyed by content id.
    /// Never written back to the store or disk unless the user removes encryption.
    @State private var unlockedValues: [NoteContent.ID: String] = [:]

    @State private var contentToEncrypt: NoteContent?
    @State private var encryptPassword = ""
    @State private var isPresentingEncryptAlert = false

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

                    if group.contents.contains(where: { $0.isEncrypted }) {
                        unlockBar
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
            .alert("Encrypt Value", isPresented: $isPresentingEncryptAlert) {
                SecureField("Password", text: $encryptPassword)
                Button("Cancel", role: .cancel) {
                    contentToEncrypt = nil
                }
                Button("Encrypt") {
                    encryptPendingContent()
                }
                .disabled(encryptPassword.isEmpty)
            } message: {
                Text("This value will be encrypted with this password. You'll need the same password to view it again.")
            }
        }
        .frame(minWidth: 460, minHeight: 460)
    }

    @ViewBuilder
    private func row(for content: NoteContent, in group: NoteGroup) -> some View {
        HStack {
            if content.isEncrypted {
                if let plain = unlockedValues[content.id] {
                    Text(plain)
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
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
            } else {
                Text(content.value)
                Spacer()
                Button {
                    copyToPasteboard(content.value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Button {
                    contentToEncrypt = content
                    encryptPassword = ""
                    isPresentingEncryptAlert = true
                } label: {
                    Image(systemName: "lock")
                }
                .buttonStyle(.plain)
                .help("Encrypt this value")
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

    private var unlockBar: some View {
        HStack {
            SecureField("Password to unlock encrypted values", text: $unlockPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit(unlock)
            Button("Unlock", action: unlock)
                .disabled(unlockPassword.isEmpty)
            if !unlockedValues.isEmpty {
                Button("Lock") {
                    unlockedValues.removeAll()
                }
            }
        }
        .padding([.horizontal, .top])
    }

    private func unlock() {
        guard let group else { return }
        for content in group.contents where content.isEncrypted {
            guard let salt = content.salt else { continue }
            if let plaintext = try? ContentCrypto.decrypt(content.value, saltBase64: salt, password: unlockPassword) {
                unlockedValues[content.id] = plaintext
            }
        }
    }

    private func encryptPendingContent() {
        guard let content = contentToEncrypt, let group else { return }
        store.encryptContent(content, in: group, password: encryptPassword)
        contentToEncrypt = nil
        encryptPassword = ""
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
