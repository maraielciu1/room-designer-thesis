//
//  LegacyDataMigration.swift
//  RoomScanTest
//
//  One-time migration: merge pre-auth and orphan user data into Mara's account.
//

import Foundation

enum LegacyDataMigration {
    static let maraEmail = "ielciumara@yahoo.com"
    private static let globalFlag = "mara_legacy_migration_v1"

    private static let storageBaseKeys = [
        "saved_rooms",
        "saved_projects",
        "scanned_furniture_items",
        "replacement_history"
    ]

    /// Run once at launch; safe to call repeatedly.
    @MainActor
    static func migrateAllPreAuthDataToMara(database: UserDatabaseService) {
        guard !UserDefaults.standard.bool(forKey: globalFlag) else { return }

        guard let maraId = resolveMaraUserId(database: database) else {
            print("[LegacyDataMigration] Mara account not found — skipping migration")
            return
        }

        for baseKey in storageBaseKeys {
            migrateUserDefaults(for: baseKey, to: maraId)
        }
        migrateLegacyFiles(to: maraId)

        UserDefaults.standard.set(true, forKey: globalFlag)
        print("[LegacyDataMigration] Completed migration to user \(maraId.uuidString)")
    }

    // MARK: - Resolve Mara

    @MainActor
    private static func resolveMaraUserId(database: UserDatabaseService) -> UUID? {
        if let entity = try? database.fetchUser(email: maraEmail) {
            return entity.id
        }
        let all = (try? database.fetchAllUsers()) ?? []
        if let byName = all.first(where: { $0.name.lowercased() == "mara" }) {
            return byName.id
        }
        return nil
    }

    // MARK: - UserDefaults

    private static func migrateUserDefaults(for baseKey: String, to maraId: UUID) {
        var mergedRooms: [Room] = []
        var mergedProjects: [Project] = []
        var mergedFurniture: [ScannedFurniture] = []
        var mergedHistory: [ReplacementHistory] = []

        if let existing = UserScopedStorage.loadData(baseKey: baseKey, userId: maraId) {
            absorb(existing, baseKey: baseKey,
                   rooms: &mergedRooms, projects: &mergedProjects,
                   furniture: &mergedFurniture, history: &mergedHistory)
        }

        for data in allLegacyDataBlobs(for: baseKey, excludingUserId: maraId) {
            absorb(data, baseKey: baseKey,
                   rooms: &mergedRooms, projects: &mergedProjects,
                   furniture: &mergedFurniture, history: &mergedHistory)
        }

        switch baseKey {
        case "saved_rooms":
            let normalized = mergedRooms.map { reassign($0, userId: maraId) }
            UserScopedStorage.save(normalized, baseKey: baseKey, userId: maraId)
            UserDefaults.standard.removeObject(forKey: baseKey)
        case "saved_projects":
            let normalized = mergedProjects.map { reassign($0, userId: maraId) }
            UserScopedStorage.save(normalized, baseKey: baseKey, userId: maraId)
            UserDefaults.standard.removeObject(forKey: baseKey)
        case "scanned_furniture_items":
            let normalized = mergedFurniture.map { reassign($0, userId: maraId) }
            UserScopedStorage.save(normalized, baseKey: baseKey, userId: maraId)
            UserDefaults.standard.removeObject(forKey: baseKey)
        case "replacement_history":
            let normalized = mergedHistory.map { reassign($0, userId: maraId) }
            UserScopedStorage.save(normalized, baseKey: baseKey, userId: maraId)
            UserDefaults.standard.removeObject(forKey: baseKey)
        default:
            break
        }

        removeOrphanScopedKeys(for: baseKey, keepingUserId: maraId)
    }

    private static func allLegacyDataBlobs(for baseKey: String, excludingUserId: UUID) -> [Data] {
        var blobs: [Data] = []
        if let data = UserDefaults.standard.data(forKey: baseKey) {
            blobs.append(data)
        }
        let prefix = "\(baseKey)_"
        let maraScoped = UserScopedStorage.key(baseKey, userId: excludingUserId)
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            guard key.hasPrefix(prefix), key != maraScoped else { continue }
            if let data = UserDefaults.standard.data(forKey: key) {
                blobs.append(data)
            }
        }
        return blobs
    }

    private static func removeOrphanScopedKeys(for baseKey: String, keepingUserId: UUID) {
        let keep = UserScopedStorage.key(baseKey, userId: keepingUserId)
        let prefix = "\(baseKey)_"
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) && key != keep {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func absorb(
        _ data: Data,
        baseKey: String,
        rooms: inout [Room],
        projects: inout [Project],
        furniture: inout [ScannedFurniture],
        history: inout [ReplacementHistory]
    ) {
        switch baseKey {
        case "saved_rooms":
            if let decoded = try? JSONDecoder().decode([Room].self, from: data) {
                merge(&rooms, with: decoded)
            }
        case "saved_projects":
            if let decoded = try? JSONDecoder().decode([Project].self, from: data) {
                merge(&projects, with: decoded)
            }
        case "scanned_furniture_items":
            if let decoded = try? JSONDecoder().decode([ScannedFurniture].self, from: data) {
                merge(&furniture, with: decoded)
            }
        case "replacement_history":
            if let decoded = try? JSONDecoder().decode([ReplacementHistory].self, from: data) {
                merge(&history, with: decoded)
            }
        default:
            break
        }
    }

    private static func merge<T: Identifiable>(_ target: inout [T], with incoming: [T]) where T.ID == UUID {
        var seen = Set(target.map(\.id))
        for item in incoming where !seen.contains(item.id) {
            target.append(item)
            seen.insert(item.id)
        }
    }

    private static func reassign(_ room: Room, userId: UUID) -> Room {
        var copy = room
        copy.userId = userId
        return copy
    }

    private static func reassign(_ project: Project, userId: UUID) -> Project {
        var copy = project
        copy.userId = userId
        return copy
    }

    private static func reassign(_ item: ScannedFurniture, userId: UUID) -> ScannedFurniture {
        var copy = item
        copy.userId = userId
        return copy
    }

    private static func reassign(_ entry: ReplacementHistory, userId: UUID) -> ReplacementHistory {
        var copy = entry
        copy.userId = userId
        return copy
    }

    // MARK: - Files

    private static func migrateLegacyFiles(to userId: UUID) {
        copyDirectoryContents(
            from: UserStoragePaths.legacyRoomScans,
            to: UserStoragePaths.roomScans(userId: userId)
        )
        copyDirectoryContents(
            from: UserStoragePaths.legacyScannedFurniture,
            to: UserStoragePaths.scannedFurniture(userId: userId)
        )
    }

    private static func copyDirectoryContents(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path),
              let files = try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            let dest = destination.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: dest.path) { continue }
            try? fm.copyItem(at: file, to: dest)
        }
    }
}

// MARK: - UserScopedStorage helpers

extension UserScopedStorage {
    static func loadData(baseKey: String, userId: UUID) -> Data? {
        UserDefaults.standard.data(forKey: key(baseKey, userId: userId))
    }
}
