import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WelcomeView: View {
    private enum PendingAction {
        case create(URL)
        case open(URL)

        var url: URL {
            switch self {
            case .create(let url), .open(let url):
                return url
            }
        }

        var kind: PasswordPromptKind {
            switch self {
            case .create: return .create
            case .open: return .unlock
            }
        }
    }

    @StateObject private var session = SessionBox()
    @State private var pendingAction: PendingAction?
    @State private var showPasswordSheet = false
    @State private var promptError: String?
    @State private var attemptID = 0
    @State private var alertMessage: String?

    var body: some View {
        Group {
            if let noteSession = session.value {
                NoteEditorView(session: noteSession) {
                    session.value = nil
                }
            } else {
                welcomeContent
            }
        }
        .frame(minWidth: 480, minHeight: 340)
        .sheet(isPresented: $showPasswordSheet) {
            if let pendingAction {
                PasswordPromptView(
                    kind: pendingAction.kind,
                    fileName: pendingAction.url.lastPathComponent,
                    errorMessage: promptError,
                    onSubmit: { password in handlePassword(password, for: pendingAction) },
                    onCancel: { showPasswordSheet = false }
                )
                .id(attemptID)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { isPresented in if !isPresented { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 20) {
            Text("NoteSweeker")
                .font(.largeTitle.bold())
            Text("Encrypted notes, protected by a password.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("New Note…") { createNote() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Note…") { openNote() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    private func createNote() {
        let panel = NSSavePanel()
        panel.title = "Create New Note"
        panel.allowedContentTypes = [.swNote]
        panel.nameFieldStringValue = "Untitled.swnote"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        promptError = nil
        attemptID += 1
        pendingAction = .create(url)
        showPasswordSheet = true
    }

    private func openNote() {
        let panel = NSOpenPanel()
        panel.title = "Open Note"
        panel.allowedContentTypes = [.swNote]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        promptError = nil
        attemptID += 1
        pendingAction = .open(url)
        showPasswordSheet = true
    }

    private func handlePassword(_ password: String, for action: PendingAction) {
        switch action {
        case .create(let url):
            do {
                let title = url.deletingPathExtension().lastPathComponent
                let data = try EncryptedNoteFile.encrypt(text: title, password: password)
                try data.write(to: url, options: .atomic)
                showPasswordSheet = false
                pendingAction = nil
                session.value = NoteSession(fileURL: url, password: password, text: title)
            } catch {
                showPasswordSheet = false
                alertMessage = "Couldn't create the note: \(error.localizedDescription)"
            }

        case .open(let url):
            do {
                let data = try Data(contentsOf: url)
                let text = try EncryptedNoteFile.decrypt(data: data, password: password)
                showPasswordSheet = false
                pendingAction = nil
                session.value = NoteSession(fileURL: url, password: password, text: text)
            } catch NoteFileError.wrongPassword {
                attemptID += 1
                promptError = "Incorrect password. Try again."
            } catch {
                showPasswordSheet = false
                alertMessage = "Couldn't open the note: \(error.localizedDescription)"
            }
        }
    }
}

/// Small observable box so switching between the welcome screen and the
/// editor is a simple, animatable state change.
@MainActor
private final class SessionBox: ObservableObject {
    @Published var value: NoteSession?
}
