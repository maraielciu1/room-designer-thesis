//
//  Room.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import RoomPlan

struct Room: Identifiable, Codable {
    let id: UUID
    var name: String
    var userId: UUID
    var createdAt: Date
    var updatedAt: Date
    var capturedRoomExportURL: String? // Legacy — kept for backward compat
    var furnitureReplacements: [FurnitureReplacement]
    
    /// Wall / floor colours captured from ARKit frames during the RoomPlan scan.
    /// nil when the scan didn't capture colour data (e.g. older rooms).
    var roomMaterials: RoomMaterials?
    
    /// Optional reference to a multi-room project.
    /// nil when the room is standalone (not part of any project).
    var projectId: UUID?
    
    init(id: UUID = UUID(), name: String, userId: UUID, createdAt: Date = Date(),
         updatedAt: Date = Date(), capturedRoomExportURL: String? = nil,
         furnitureReplacements: [FurnitureReplacement] = [],
         roomMaterials: RoomMaterials? = nil,
         projectId: UUID? = nil) {
        self.id = id
        self.name = name
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.capturedRoomExportURL = capturedRoomExportURL
        self.furnitureReplacements = furnitureReplacements
        self.roomMaterials = roomMaterials
        self.projectId = projectId
    }
}

// MARK: - CapturedRoom Persistence

extension Room {

    // ── In-memory cache (fast access while app is running) ──────
    static var inMemoryRooms: [UUID: CapturedRoom] = [:]

    // ── Disk storage directory ──────────────────────────────────

    private func roomDataDirectory(for userId: UUID) -> URL {
        UserStoragePaths.roomScans(userId: userId)
    }

    /// Path to this room's scan data JSON file (per-user folder).
    private var scanDataURL: URL {
        roomDataDirectory(for: userId).appendingPathComponent("\(id.uuidString).json")
    }

    private var legacyScanDataURL: URL {
        UserStoragePaths.legacyRoomScans.appendingPathComponent("\(id.uuidString).json")
    }

    // ── Public API ──────────────────────────────────────────────

    /// Whether a saved scan file exists on disk for this room
    var hasScanData: Bool {
        Room.inMemoryRooms[self.id] != nil
            || FileManager.default.fileExists(atPath: scanDataURL.path)
            || FileManager.default.fileExists(atPath: legacyScanDataURL.path)
    }

    /// Get the CapturedRoom — checks memory cache first, then loads from disk
    func getCapturedRoom() -> CapturedRoom? {
        // 1. Check in-memory cache
        if let cached = Room.inMemoryRooms[self.id] {
            return cached
        }

        // 2. Try loading from disk
        if let loaded = loadFromDisk() {
            Room.inMemoryRooms[self.id] = loaded
            return loaded
        }

        return nil
    }

    /// Store a CapturedRoom — writes to both memory cache and disk
    mutating func setCapturedRoom(_ room: CapturedRoom) {
        Room.inMemoryRooms[self.id] = room
        self.updatedAt = Date()
        saveToDisk(room)
    }

    /// Remove the scan data from memory and disk (used when deleting a room)
    func deleteScanData() {
        Room.inMemoryRooms.removeValue(forKey: self.id)
        if FileManager.default.fileExists(atPath: scanDataURL.path) {
            try? FileManager.default.removeItem(at: scanDataURL)
            print("[Room] Deleted scan data for: \(name)")
        }
    }

    // ── Private disk I/O ────────────────────────────────────────

    /// Serialize CapturedRoom to JSON and write to Documents/RoomScans/
    private func saveToDisk(_ capturedRoom: CapturedRoom) {
        do {
            let data = try JSONEncoder().encode(capturedRoom)
            try data.write(to: scanDataURL, options: [.atomic])
            print("[Room] Saved scan (\(data.count / 1024) KB) → \(scanDataURL.lastPathComponent)")
        } catch {
            print("[Room] ⚠️ Failed to save scan: \(error.localizedDescription)")
        }
    }

    /// Load CapturedRoom from its JSON file on disk
    private func loadFromDisk() -> CapturedRoom? {
        let url: URL
        if FileManager.default.fileExists(atPath: scanDataURL.path) {
            url = scanDataURL
        } else if FileManager.default.fileExists(atPath: legacyScanDataURL.path) {
            url = legacyScanDataURL
        } else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let room = try JSONDecoder().decode(CapturedRoom.self, from: data)
            print("[Room] Loaded scan (\(data.count / 1024) KB) ← \(url.lastPathComponent)")
            return room
        } catch {
            print("[Room] ⚠️ Failed to load scan: \(error.localizedDescription)")
            return nil
        }
    }

    // ── Maintenance ─────────────────────────────────────────────

    /// Remove orphaned scan files that no longer have a matching Room
    static func cleanOrphanedScanFiles(userId: UUID, existingRoomIds: Set<UUID>) {
        let directories = [UserStoragePaths.roomScans(userId: userId), UserStoragePaths.legacyRoomScans]
        for directory in directories {
            guard FileManager.default.fileExists(atPath: directory.path),
                  let files = try? FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil
                  ) else { continue }

            for file in files where file.pathExtension == "json" {
                let stem = file.deletingPathExtension().lastPathComponent
                if let fileId = UUID(uuidString: stem), !existingRoomIds.contains(fileId) {
                    try? FileManager.default.removeItem(at: file)
                    print("[Room] Cleaned orphaned scan: \(file.lastPathComponent)")
                }
            }
        }
    }
}
