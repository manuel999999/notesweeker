import Foundation
import CryptoKit
import UniformTypeIdentifiers

extension UTType {
    /// Ad-hoc type for our on-disk format; doesn't require an Info.plist declaration.
    static var swNote: UTType {
        UTType(filenameExtension: "swnote", conformingTo: .data) ?? .data
    }
}

enum NoteFileError: LocalizedError {
    case invalidFormat
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "This file is not a valid NoteSweeker note."
        case .wrongPassword:
            return "Incorrect password."
        }
    }
}

/// On-disk layout: "NSW1" magic (4 bytes) | salt (16 bytes) | AES-GCM combined (nonce + ciphertext + tag).
enum EncryptedNoteFile {
    private static let magic = Data("NSW1".utf8)

    static func encrypt(text: String, password: String) throws -> Data {
        let salt = CryptoService.randomBytes(count: CryptoService.saltLength)
        let key = CryptoService.deriveKey(password: password, salt: salt)
        let sealedBox = try AES.GCM.seal(Data(text.utf8), using: key)
        guard let combined = sealedBox.combined else {
            throw NoteFileError.invalidFormat
        }

        var fileData = Data()
        fileData.append(magic)
        fileData.append(salt)
        fileData.append(combined)
        return fileData
    }

    static func decrypt(data: Data, password: String) throws -> String {
        let headerLength = magic.count + CryptoService.saltLength
        guard data.count > headerLength, data.prefix(magic.count) == magic else {
            throw NoteFileError.invalidFormat
        }

        let salt = data.subdata(in: magic.count..<headerLength)
        let combined = data.subdata(in: headerLength..<data.count)
        let key = CryptoService.deriveKey(password: password, salt: salt)

        let plaintext: Data
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            plaintext = try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw NoteFileError.wrongPassword
        }

        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw NoteFileError.invalidFormat
        }
        return text
    }
}
