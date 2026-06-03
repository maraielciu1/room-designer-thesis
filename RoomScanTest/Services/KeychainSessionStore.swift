//
//  KeychainSessionStore.swift
//  RoomScanTest
//

import Foundation
import Security

enum KeychainSessionStore {
    private static let service = "MyClass.RoomScanTest.auth"
    private static let account = "current_user_id"

    static func saveUserId(_ id: UUID) {
        let data = Data(id.uuidString.utf8)
        deleteUserId()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadUserId() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              let id = UUID(uuidString: string) else { return nil }
        return id
    }

    static func deleteUserId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
