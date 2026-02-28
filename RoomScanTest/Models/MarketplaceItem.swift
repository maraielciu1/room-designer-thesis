//
//  MarketplaceItem.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import Foundation

/// Represents a 3D model published to the community marketplace.
/// Stored in Cloud Firestore; the USDZ file lives in Firebase Storage.
struct MarketplaceItem: Identifiable, Codable, Hashable {
    var id: String                     // Firestore document ID
    var name: String
    var description: String
    var category: String               // e.g. "chair", "table", "sofa"
    var uploaderUid: String
    var uploaderName: String
    var uploadedAt: Date
    var downloadCount: Int
    var likeCount: Int
    var thumbnailURL: String           // Firebase Storage download URL
    var modelURL: String               // Firebase Storage download URL for USDZ
    var fileSize: Int64                // bytes
    var tags: [String]
    var dimensions: [Double]?          // [width, height, depth] in metres

    /// Formatted file size for display.
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Category as a `FurnitureCategory` enum, falling back to `.other`.
    var furnitureCategory: FurnitureCategory {
        FurnitureCategory(rawValue: category) ?? .other
    }
}

/// Lightweight user profile stored in Firestore alongside marketplace items.
struct MarketplaceUser: Identifiable, Codable {
    var id: String                     // Firebase Auth UID
    var displayName: String
    var email: String
    var joinedAt: Date
    var uploadCount: Int
    var totalDownloads: Int

    init(id: String, displayName: String, email: String,
         joinedAt: Date = Date(), uploadCount: Int = 0, totalDownloads: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.joinedAt = joinedAt
        self.uploadCount = uploadCount
        self.totalDownloads = totalDownloads
    }
}

/// The two top-level modes the app can run in.
enum AppMode: String, Codable {
    case local
    case marketplace
}

// MARK: - Downloaded Marketplace Model (local metadata)

/// Lightweight metadata stored locally (UserDefaults) for marketplace models
/// that have been downloaded to the device.  This allows the furniture pickers
/// to list marketplace models even when offline or in Local mode.
struct DownloadedMarketplaceModel: Codable, Identifiable, Hashable {
    var id: String          // Same as MarketplaceItem.id
    var name: String
    var category: String

    /// The key used inside `FurnitureCatalogManager` to identify this model.
    var catalogKey: String { "marketplace_\(id)" }

    // MARK: - Persistence helpers

    private static let storageKey = "downloadedMarketplaceModels"

    /// Persist metadata for a newly downloaded model.
    static func register(_ model: DownloadedMarketplaceModel) {
        var all = loadAll()
        all.removeAll { $0.id == model.id }
        all.append(model)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Remove metadata when a model is deleted from the cache.
    static func unregister(id: String) {
        var all = loadAll()
        all.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Load every downloaded marketplace model's metadata.
    static func loadAll() -> [DownloadedMarketplaceModel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([DownloadedMarketplaceModel].self, from: data)) ?? []
    }
}
