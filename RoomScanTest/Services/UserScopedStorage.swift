//
//  UserScopedStorage.swift
//  RoomScanTest
//
//  UserDefaults keys scoped to the signed-in account.
//

import Foundation

enum UserScopedStorage {
    static func key(_ base: String, userId: UUID) -> String {
        "\(base)_\(userId.uuidString)"
    }

    static func load<T: Decodable>(_ type: T.Type, baseKey: String, userId: UUID) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key(baseKey, userId: userId)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, baseKey: String, userId: UUID) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key(baseKey, userId: userId))
    }

    /// Copy legacy global data into the first signed-in user (one-time migration).
    static func migrateLegacyDataIfNeeded(to userId: UUID) {
        let flag = "legacy_data_migrated_\(userId.uuidString)"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        let legacyKeys = ["saved_rooms", "saved_projects", "scanned_furniture_items", "replacement_history"]
        for legacy in legacyKeys {
            let scoped = key(legacy, userId: userId)
            if UserDefaults.standard.data(forKey: scoped) == nil,
               let data = UserDefaults.standard.data(forKey: legacy) {
                UserDefaults.standard.set(data, forKey: scoped)
            }
        }

        UserDefaults.standard.set(true, forKey: flag)
    }
}
