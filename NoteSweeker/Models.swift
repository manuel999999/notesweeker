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

    /// Plaintext, or base64 AES-GCM ciphertext when `isEncrypted` is true.
    var value: String
    var isEncrypted: Bool = false

    /// Base64 PBKDF2 salt used to derive the encryption key. Present only when `isEncrypted`.
    var salt: String?

    init(value: String, isEncrypted: Bool = false, salt: String? = nil) {
        self.value = value
        self.isEncrypted = isEncrypted
        self.salt = salt
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case isEncrypted = "encrypted"
        case salt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(String.self, forKey: .value)
        isEncrypted = try container.decodeIfPresent(Bool.self, forKey: .isEncrypted) ?? false
        salt = try container.decodeIfPresent(String.self, forKey: .salt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        if isEncrypted {
            try container.encode(true, forKey: .isEncrypted)
            try container.encodeIfPresent(salt, forKey: .salt)
        }
    }
}
