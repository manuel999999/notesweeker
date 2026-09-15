import Foundation
import CryptoKit

enum CryptoService {
    static let saltLength = 16
    static let pbkdf2Iterations = 200_000
    static let keyLength = 32 // 256-bit key for AES-256-GCM

    static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate random bytes")
        return Data(bytes)
    }

    /// Derives a symmetric key from a password and salt using PBKDF2-HMAC-SHA256.
    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let derived = pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: pbkdf2Iterations,
            keyLength: keyLength
        )
        return SymmetricKey(data: derived)
    }

    private static func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        let hashLength = SHA256.Digest.byteCount
        let blockCount = Int(ceil(Double(keyLength) / Double(hashLength)))
        let hmacKey = SymmetricKey(data: password)
        var derivedKey = Data()

        for blockIndex in 1...blockCount {
            var blockIndexBigEndian = UInt32(blockIndex).bigEndian
            var salted = salt
            withUnsafeBytes(of: &blockIndexBigEndian) { salted.append(contentsOf: $0) }

            var previous = Data(HMAC<SHA256>.authenticationCode(for: salted, using: hmacKey))
            var block = previous

            if iterations > 1 {
                for _ in 2...iterations {
                    previous = Data(HMAC<SHA256>.authenticationCode(for: previous, using: hmacKey))
                    for i in 0..<block.count {
                        block[i] ^= previous[i]
                    }
                }
            }

            derivedKey.append(block)
        }

        return derivedKey.prefix(keyLength)
    }
}
