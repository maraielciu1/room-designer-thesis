//
//  UserStoragePaths.swift
//  RoomScanTest
//
//  Per-user directories for scan data and 3D models.
//

import Foundation

enum UserStoragePaths {
    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func userRoot(userId: UUID) -> URL {
        let dir = documents.appendingPathComponent("users/\(userId.uuidString)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func roomScans(userId: UUID) -> URL {
        let dir = userRoot(userId: userId).appendingPathComponent("RoomScans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func scannedFurniture(userId: UUID) -> URL {
        let dir = userRoot(userId: userId).appendingPathComponent("ScannedFurniture", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Legacy shared paths (pre–per-user storage).
    static var legacyRoomScans: URL {
        documents.appendingPathComponent("RoomScans", isDirectory: true)
    }

    static var legacyScannedFurniture: URL {
        documents.appendingPathComponent("ScannedFurniture", isDirectory: true)
    }
}
