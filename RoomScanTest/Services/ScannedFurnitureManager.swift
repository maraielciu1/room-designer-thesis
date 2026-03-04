//
//  ScannedFurnitureManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 20.02.2026.
//

import Foundation
import Combine
import RealityKit

/// Manages the user's personal library of scanned furniture USDZ files.
/// Metadata is persisted in UserDefaults; USDZ files live in Documents/ScannedFurniture/.
class ScannedFurnitureManager: ObservableObject {
    @Published var items: [ScannedFurniture] = []

    private let storageKey = "scanned_furniture_items"
    private let userManager: UserManager

    // MARK: - Shared directory paths

    /// Permanent directory for finished USDZ models.
    static var modelDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScannedFurniture", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Temporary directory used during an Object Capture session.
    static var captureSessionDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ObjectCaptureTemp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Init

    init(userManager: UserManager) {
        self.userManager = userManager
        loadItems()
    }

    // MARK: - CRUD

    func getFurnitureForCurrentUser() -> [ScannedFurniture] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return items.filter { $0.userId == userId }
    }

    /// Register a finished USDZ model in the library.
    ///
    /// If `realWorldDimensions` is nil the method will load the USDZ once
    /// to measure its visual bounds (Object Capture models use 1 unit = 1 m).
    @discardableResult
    func addFurniture(name: String, category: String, usdzURL: URL,
                      realWorldDimensions: [Double]? = nil) -> ScannedFurniture {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }

        // Move/copy USDZ to permanent directory with a stable name
        let id = UUID()
        let permanentFileName = "\(id.uuidString).usdz"
        let permanentURL = Self.modelDirectory.appendingPathComponent(permanentFileName)

        do {
            if FileManager.default.fileExists(atPath: permanentURL.path) {
                try FileManager.default.removeItem(at: permanentURL)
            }
            try FileManager.default.copyItem(at: usdzURL, to: permanentURL)
        } catch {
            print("[ScannedFurnitureManager] Failed to copy USDZ: \(error)")
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: permanentURL.path))?[.size] as? Int64

        // Measure real-world dimensions if not provided
        let dimensions = realWorldDimensions ?? Self.measureModelDimensions(at: permanentURL)
        if let dims = dimensions {
            print("[ScannedFurnitureManager] Stored real-world dimensions: "
                  + String(format: "%.3f x %.3f x %.3f m", dims[0], dims[1], dims[2]))
        }

        let item = ScannedFurniture(
            id: id,
            name: name,
            userId: userId,
            usdzFileName: permanentFileName,
            category: category,
            fileSizeBytes: fileSize,
            realWorldDimensions: dimensions
        )

        items.append(item)
        saveItems()
        return item
    }

    // MARK: - Dimension measurement

    /// Load a USDZ model from disk and return its visual extents in metres.
    /// Object Capture outputs use 1 unit = 1 m, so the extents correspond
    /// directly to the physical object's width × height × depth.
    ///
    /// Returns `[width, height, depth]` or `nil` if the model can't be loaded.
    static func measureModelDimensions(at url: URL) -> [Double]? {
        guard let model = try? Entity.load(contentsOf: url) else {
            print("[ScannedFurnitureManager] Could not load model for measurement: \(url.lastPathComponent)")
            return nil
        }
        let bounds = model.visualBounds(relativeTo: model)
        let ext = bounds.extents
        guard ext.x > 0.0001, ext.y > 0.0001, ext.z > 0.0001 else {
            print("[ScannedFurnitureManager] Model bounds are zero/tiny — skipping measurement")
            return nil
        }
        return [Double(ext.x), Double(ext.y), Double(ext.z)]
    }

    func deleteFurniture(_ item: ScannedFurniture) {
        // Remove USDZ file from disk
        let fileURL = Self.modelDirectory.appendingPathComponent(item.usdzFileName)
        try? FileManager.default.removeItem(at: fileURL)

        items.removeAll { $0.id == item.id }
        saveItems()
        print("[ScannedFurnitureManager] Deleted: \(item.name)")
    }

    func renameFurniture(_ item: ScannedFurniture, newName: String) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].name = newName
            saveItems()
        }
    }

    // MARK: - Gaussian Splatting

    /// Associate a trained Gaussian Splat .ply file with an existing scanned object.
    func attachSplat(to item: ScannedFurniture,
                     splatFileName: String,
                     gaussianCount: Int?,
                     fileSizeBytes: Int64?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].splatFileName = splatFileName
        items[idx].splatGaussianCount = gaussianCount
        items[idx].splatFileSizeBytes = fileSizeBytes
        items[idx].reconstructionMethod = "both"
        saveItems()
        print("[ScannedFurnitureManager] Attached splat (\(gaussianCount ?? 0) Gaussians) to '\(item.name)'")
    }

    /// Remove the Gaussian Splat from a scanned object (keeps the USDZ).
    func removeSplat(from item: ScannedFurniture) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        // Remove .ply file from disk
        if let splatName = items[idx].splatFileName {
            let splatURL = Self.modelDirectory.appendingPathComponent(splatName)
            try? FileManager.default.removeItem(at: splatURL)
        }
        items[idx].splatFileName = nil
        items[idx].splatGaussianCount = nil
        items[idx].splatFileSizeBytes = nil
        items[idx].reconstructionMethod = "objectCapture"
        saveItems()
        print("[ScannedFurnitureManager] Removed splat from '\(item.name)'")
    }

    // MARK: - Lookup (used by FurnitureCatalogManager)

    /// Resolve a `catalogKey` like `"scanned_<uuid>"` to a file URL.
    func resolveURL(forCatalogKey key: String) -> URL? {
        guard key.hasPrefix("scanned_") else { return nil }
        let uuidString = String(key.dropFirst("scanned_".count))
        guard let id = UUID(uuidString: uuidString) else { return nil }
        guard let item = items.first(where: { $0.id == id }) else { return nil }
        let url = Self.modelDirectory.appendingPathComponent(item.usdzFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Capture session helpers

    /// Create a fresh temporary directory for an Object Capture session.
    func createSessionDirectories() throws -> (images: URL, checkpoint: URL) {
        let sessionId = UUID().uuidString
        let base = Self.captureSessionDirectory.appendingPathComponent(sessionId)
        let imagesDir = base.appendingPathComponent("Images")
        let checkpointDir = base.appendingPathComponent("Checkpoints")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: checkpointDir, withIntermediateDirectories: true)
        return (imagesDir, checkpointDir)
    }

    /// Remove all temporary capture session files.
    func cleanupSessionFiles() {
        try? FileManager.default.removeItem(at: Self.captureSessionDirectory)
        // Recreate the empty directory for next time
        try? FileManager.default.createDirectory(at: Self.captureSessionDirectory, withIntermediateDirectories: true)
        print("[ScannedFurnitureManager] Cleaned up capture session files")
    }

    // MARK: - Persistence

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScannedFurniture].self, from: data) else { return }
        items = decoded
    }

    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
