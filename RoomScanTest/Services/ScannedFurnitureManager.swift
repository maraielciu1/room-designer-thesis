//
//  ScannedFurnitureManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 20.02.2026.
//

import Foundation
import Combine
import RealityKit
import SwiftData

/// Manages the user's personal library of scanned furniture USDZ files.
/// Metadata is persisted in SwiftData; USDZ files live in Documents/ScannedFurniture/.
class ScannedFurnitureManager: ObservableObject {
    @Published var items: [ScannedFurniture] = []

    private let userManager: UserManager
    private let modelContext: ModelContext

    // MARK: - Shared directory paths

    func modelDirectory() -> URL {
        guard let userId = userManager.currentUser?.id else {
            return UserStoragePaths.legacyScannedFurniture
        }
        return UserStoragePaths.scannedFurniture(userId: userId)
    }

    static var legacyModelDirectory: URL { UserStoragePaths.legacyScannedFurniture }

    static var captureSessionDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ObjectCaptureTemp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Init

    init(userManager: UserManager, modelContext: ModelContext) {
        self.userManager = userManager
        self.modelContext = modelContext
        reloadForCurrentUser()
    }

    func reloadForCurrentUser() {
        loadItems()
    }

    // MARK: - CRUD

    func getFurnitureForCurrentUser() -> [ScannedFurniture] {
        guard let userId = userManager.currentUser?.id else { return [] }
        return items.filter { $0.userId == userId }
    }

    @discardableResult
    func addFurniture(name: String, category: String, usdzURL: URL,
                      realWorldDimensions: [Double]? = nil) -> ScannedFurniture {
        guard let userId = userManager.currentUser?.id else {
            fatalError("No current user")
        }

        let id = UUID()
        let permanentFileName = "\(id.uuidString).usdz"
        let permanentURL = modelDirectory().appendingPathComponent(permanentFileName)

        do {
            if FileManager.default.fileExists(atPath: permanentURL.path) {
                try FileManager.default.removeItem(at: permanentURL)
            }
            try FileManager.default.copyItem(at: usdzURL, to: permanentURL)
        } catch {
            print("[ScannedFurnitureManager] Failed to copy USDZ: \(error)")
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: permanentURL.path))?[.size] as? Int64
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
        persist(item)
        return item
    }

    // MARK: - Dimension measurement

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
        let fileURL = item.usdzURL
        try? FileManager.default.removeItem(at: fileURL)
        items.removeAll { $0.id == item.id }
        deleteEntity(for: item)
        print("[ScannedFurnitureManager] Deleted: \(item.name)")
    }

    func renameFurniture(_ item: ScannedFurniture, newName: String) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].name = newName
            persist(items[idx])
        }
    }

    // MARK: - Gaussian Splatting

    func attachSplat(to item: ScannedFurniture,
                     splatFileName: String,
                     gaussianCount: Int?,
                     fileSizeBytes: Int64?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].splatFileName = splatFileName
        items[idx].splatGaussianCount = gaussianCount
        items[idx].splatFileSizeBytes = fileSizeBytes
        items[idx].reconstructionMethod = "both"
        persist(items[idx])
        print("[ScannedFurnitureManager] Attached splat (\(gaussianCount ?? 0) Gaussians) to '\(item.name)'")
    }

    func removeSplat(from item: ScannedFurniture) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if let splatName = items[idx].splatFileName {
            let splatURL = item.splatURL ?? modelDirectory().appendingPathComponent(splatName)
            try? FileManager.default.removeItem(at: splatURL)
        }
        items[idx].splatFileName = nil
        items[idx].splatGaussianCount = nil
        items[idx].splatFileSizeBytes = nil
        items[idx].reconstructionMethod = "objectCapture"
        persist(items[idx])
        print("[ScannedFurnitureManager] Removed splat from '\(item.name)'")
    }

    // MARK: - Lookup

    func resolveURL(forCatalogKey key: String) -> URL? {
        guard key.hasPrefix("scanned_") else { return nil }
        let uuidString = String(key.dropFirst("scanned_".count))
        guard let id = UUID(uuidString: uuidString) else { return nil }
        guard let item = items.first(where: { $0.id == id }) else { return nil }
        let url = item.usdzURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Capture session helpers

    func createSessionDirectories() throws -> (images: URL, checkpoint: URL) {
        let sessionId = UUID().uuidString
        let base = Self.captureSessionDirectory.appendingPathComponent(sessionId)
        let imagesDir = base.appendingPathComponent("Images")
        let checkpointDir = base.appendingPathComponent("Checkpoints")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: checkpointDir, withIntermediateDirectories: true)
        return (imagesDir, checkpointDir)
    }

    func cleanupSessionFiles() {
        try? FileManager.default.removeItem(at: Self.captureSessionDirectory)
        try? FileManager.default.createDirectory(at: Self.captureSessionDirectory, withIntermediateDirectories: true)
        print("[ScannedFurnitureManager] Cleaned up capture session files")
    }

    // MARK: - SwiftData persistence

    private func loadItems() {
        guard let userId = userManager.currentUser?.id else { items = []; return }
        let descriptor = FetchDescriptor<ScannedFurnitureEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        items = (try? modelContext.fetch(descriptor))?.map { $0.toScannedFurniture() } ?? []
    }

    private func persist(_ item: ScannedFurniture) {
        let itemId = item.id
        let descriptor = FetchDescriptor<ScannedFurnitureEntity>(predicate: #Predicate { $0.id == itemId })
        if let entity = try? modelContext.fetch(descriptor).first {
            entity.update(from: item)
        } else {
            modelContext.insert(ScannedFurnitureEntity(from: item))
        }
        try? modelContext.save()
    }

    private func deleteEntity(for item: ScannedFurniture) {
        let itemId = item.id
        let descriptor = FetchDescriptor<ScannedFurnitureEntity>(predicate: #Predicate { $0.id == itemId })
        if let entity = try? modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try? modelContext.save()
        }
    }
}
