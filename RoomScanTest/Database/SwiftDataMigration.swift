//
//  SwiftDataMigration.swift
//  RoomScanTest
//
//  One-shot migration from UserDefaults (UserScopedStorage) → SwiftData.
//  Runs once on first launch after the SwiftData layer was introduced.
//

import Foundation
import SwiftData

enum SwiftDataMigration {

    private static let migrationFlag = "swiftdata_migration_v1"

    /// Call this to force the migration to re-run on next launch (e.g. after restoring from backup).
    static func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationFlag)
    }

    static func runIfNeeded(modelContext: ModelContext, userManager: UserManager) {
        guard !UserDefaults.standard.bool(forKey: migrationFlag) else { return }

        // LegacyDataMigration (pre-auth consolidation) is driven by AuthenticationManager
        // at login time; by the time we reach here the UserDefaults keys are already normalised.

        migrateRooms(modelContext: modelContext)
        migrateProjects(modelContext: modelContext)
        migrateFurniture(modelContext: modelContext)
        migrateHistory(modelContext: modelContext)

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationFlag)
        print("[SwiftDataMigration] Migration complete.")
    }

    // MARK: - Per-type migration

    private static func migrateRooms(modelContext: ModelContext) {
        let allRooms = decodeAll([Room].self, baseKey: "saved_rooms")
        for room in allRooms {
            let roomId = room.id
            let descriptor = FetchDescriptor<RoomEntity>(predicate: #Predicate { $0.id == roomId })
            guard (try? modelContext.fetch(descriptor))?.isEmpty != false else { continue }

            let entity = RoomEntity(from: room)
            modelContext.insert(entity)
            for replacement in room.furnitureReplacements {
                let repEntity = FurnitureReplacementEntity(from: replacement)
                repEntity.room = entity
                entity.furnitureReplacements.append(repEntity)
            }
        }
        print("[SwiftDataMigration] Migrated \(allRooms.count) rooms.")
    }

    private static func migrateProjects(modelContext: ModelContext) {
        let all = decodeAll([Project].self, baseKey: "saved_projects")
        for item in all {
            let itemId = item.id
            let descriptor = FetchDescriptor<ProjectEntity>(predicate: #Predicate { $0.id == itemId })
            guard (try? modelContext.fetch(descriptor))?.isEmpty != false else { continue }
            modelContext.insert(ProjectEntity(from: item))
        }
        print("[SwiftDataMigration] Migrated \(all.count) projects.")
    }

    private static func migrateFurniture(modelContext: ModelContext) {
        let all = decodeAll([ScannedFurniture].self, baseKey: "scanned_furniture_items")
        for item in all {
            let itemId = item.id
            let descriptor = FetchDescriptor<ScannedFurnitureEntity>(predicate: #Predicate { $0.id == itemId })
            guard (try? modelContext.fetch(descriptor))?.isEmpty != false else { continue }
            modelContext.insert(ScannedFurnitureEntity(from: item))
        }
        print("[SwiftDataMigration] Migrated \(all.count) furniture items.")
    }

    private static func migrateHistory(modelContext: ModelContext) {
        let all = decodeAll([ReplacementHistory].self, baseKey: "replacement_history")
        for item in all {
            let itemId = item.id
            let descriptor = FetchDescriptor<ReplacementHistoryEntity>(predicate: #Predicate { $0.id == itemId })
            guard (try? modelContext.fetch(descriptor))?.isEmpty != false else { continue }
            modelContext.insert(ReplacementHistoryEntity(from: item))
        }
        print("[SwiftDataMigration] Migrated \(all.count) history entries.")
    }

    // MARK: - Helpers

    /// Read all scoped keys matching `<baseKey>_<UUID>` from UserDefaults and decode them.
    private static func decodeAll<T: Decodable>(_ type: T.Type, baseKey: String) -> [T.Element]
        where T: Collection
    {
        var results: [T.Element] = []
        let prefix = "\(baseKey)_"
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else { continue }
            results.append(contentsOf: decoded)
        }
        return results
    }
}
