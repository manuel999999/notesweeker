import SwiftUI

enum PasswordPromptKind {
    case create
    case unlock
}

struct PasswordPromptView: View {
    let kind: PasswordPromptKind
    let fileName: String
    var errorMessage: String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var passwordFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind == .create ? "Set a Password" : "Enter Password")
                    .font(.headline)
                Text(fileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($passwordFieldFocused)
                .onSubmit { submitIfValid() }

            if kind == .create {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.password)
                    .onSubmit { submitIfValid() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button(kind == .create ? "Create" : "Unlock") {
                    submitIfValid()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { passwordFieldFocused = true }
    }

    private var isValid: Bool {
        guard !password.isEmpty else { return false }
        if kind == .create { return password == confirmPassword }
        return true
    }

    private func submitIfValid() {
        guard isValid else { return }
        onSubmit(password)
    }
}
