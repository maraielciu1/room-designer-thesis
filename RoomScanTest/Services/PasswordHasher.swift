//
//  PasswordHasher.swift
//  RoomScanTest
//

import Foundation
import CryptoKit

enum PasswordHasher {
    static func hash(password: String, salt: Data) -> String {
        var input = Data()
        input.append(salt)
        input.append(Data(password.utf8))
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
