import CommonCrypto
import CryptoKit
import Foundation

enum ContentCryptoError: LocalizedError {
    case saltGenerationFailed
    case keyDerivationFailed
    case malformedPayload
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .saltGenerationFailed:
            return "Couldn't generate a secure salt."
        case .keyDerivationFailed:
            return "Couldn't derive an encryption key from the password."
        case .malformedPayload:
            return "The encrypted value is malformed."
        case .wrongPassword:
            return "Incorrect password."
        }
    }
}

/// Encrypts and decrypts individual note content values with AES-GCM, using a
/// per-value password-derived key (PBKDF2-HMAC-SHA256) so a wrong password
/// simply fails authentication instead of producing garbage plaintext.
enum ContentCrypto {
    private static let saltLength = 16
    private static let pbkdf2Rounds: UInt32 = 100_000
    private static let derivedKeyLength = 32

    static func encrypt(_ plaintext: String, password: String) throws -> (ciphertext: String, salt: String) {
        var saltBytes = [UInt8](repeating: 0, count: saltLength)
        guard SecRandomCopyBytes(kSecRandomDefault, saltLength, &saltBytes) == errSecSuccess else {
            throw ContentCryptoError.saltGenerationFailed
        }
        let salt = Data(saltBytes)

        let key = try deriveKey(password: password, salt: salt)
        let sealedBox = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = sealedBox.combined else {
            throw ContentCryptoError.malformedPayload
        }

        return (combined.base64EncodedString(), salt.base64EncodedString())
    }

    static func decrypt(_ ciphertextBase64: String, saltBase64: String, password: String) throws -> String {
        guard let combined = Data(base64Encoded: ciphertextBase64),
              let salt = Data(base64Encoded: saltBase64) else {
            throw ContentCryptoError.malformedPayload
        }

        let key = try deriveKey(password: password, salt: salt)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
                throw ContentCryptoError.malformedPayload
            }
            return plaintext
        } catch is CryptoKitError {
            // GCM tag verification failed: this is what a wrong password looks like.
            throw ContentCryptoError.wrongPassword
        }
    }

    private static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        var derivedKeyData = Data(repeating: 0, count: derivedKeyLength)
        let passwordData = Data(password.utf8)
        let keyLength = derivedKeyLength

        let status = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes -> Int32 in
            salt.withUnsafeBytes { saltBytes -> Int32 in
                passwordData.withUnsafeBytes { passwordBytes -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Rounds,
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw ContentCryptoError.keyDerivationFailed
        }
        return SymmetricKey(data: derivedKeyData)
    }
}
