import SwiftUI

struct NoteEditorView: View {
    @ObservedObject var session: NoteSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") {
                    if session.isDirty { session.save() }
                    onClose()
                }

                Spacer()

                Text(session.fileURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button("Save") { session.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!session.isDirty)
            }
            .padding()

            Divider()

            TextEditor(text: $session.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .onChange(of: session.text) { _, _ in
                    session.isDirty = true
                }
        }
        .frame(minWidth: 480, minHeight: 360)
        .alert(
            "Error",
            isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { isPresented in if !isPresented { session.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }
}
