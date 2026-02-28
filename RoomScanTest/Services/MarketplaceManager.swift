//
//  MarketplaceManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage

/// Manages all marketplace CRUD operations against Cloud Firestore + Firebase Storage.
@MainActor
class MarketplaceManager: ObservableObject {

    // MARK: - Published state

    @Published var items: [MarketplaceItem] = []
    @Published var myUploads: [MarketplaceItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Firebase references

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var itemsCollection: CollectionReference { db.collection("marketplace_items") }
    private var usersCollection: CollectionReference { db.collection("marketplace_users") }

    // MARK: - Local download cache

    /// Directory where downloaded marketplace USDZ files are cached.
    static var downloadCacheDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MarketplaceCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - User Profile

    /// Ensure a Firestore user document exists for this UID.
    func ensureUserProfile(_ user: MarketplaceUser) async {
        let docRef = usersCollection.document(user.id)
        do {
            let snapshot = try await docRef.getDocument()
            if !snapshot.exists {
                try docRef.setData(from: user)
                print("[Marketplace] Created user profile: \(user.displayName)")
            }
        } catch {
            print("[Marketplace] Error ensuring user profile: \(error)")
        }
    }

    /// Fetch the Firestore profile for a UID.
    func fetchUserProfile(uid: String) async -> MarketplaceUser? {
        do {
            let snapshot = try await usersCollection.document(uid).getDocument()
            return try snapshot.data(as: MarketplaceUser.self)
        } catch {
            print("[Marketplace] Error fetching user profile: \(error)")
            return nil
        }
    }

    // MARK: - Browse Marketplace

    /// Fetch all marketplace items, optionally filtered by category.
    func fetchItems(category: String? = nil, searchText: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            var query: Query = itemsCollection.order(by: "uploadedAt", descending: true)
            if let category, !category.isEmpty, category != "all" {
                query = query.whereField("category", isEqualTo: category)
            }

            let snapshot = try await query.getDocuments()
            var fetched = snapshot.documents.compactMap { doc -> MarketplaceItem? in
                try? doc.data(as: MarketplaceItem.self)
            }

            // Client-side search filter (Firestore doesn't do full-text search natively)
            if let searchText, !searchText.isEmpty {
                let lower = searchText.lowercased()
                fetched = fetched.filter {
                    $0.name.lowercased().contains(lower) ||
                    $0.description.lowercased().contains(lower) ||
                    $0.tags.contains(where: { $0.lowercased().contains(lower) })
                }
            }

            items = fetched
        } catch {
            errorMessage = "Failed to load marketplace: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Fetch items uploaded by a specific user.
    func fetchMyUploads(uid: String) async {
        do {
            let snapshot = try await itemsCollection
                .whereField("uploaderUid", isEqualTo: uid)
                .order(by: "uploadedAt", descending: true)
                .getDocuments()
            myUploads = snapshot.documents.compactMap { try? $0.data(as: MarketplaceItem.self) }
        } catch {
            print("[Marketplace] Error fetching my uploads: \(error)")
        }
    }

    // MARK: - Upload

    /// Upload a scanned USDZ model to the marketplace.
    ///
    /// Steps:
    /// 1. Upload USDZ file to Firebase Storage
    /// 2. Generate & upload a thumbnail (placeholder for now)
    /// 3. Create Firestore document
    func uploadModel(
        name: String,
        description: String,
        category: String,
        tags: [String],
        usdzFileURL: URL,
        dimensions: [Double]?,
        uploader: MarketplaceUser
    ) async -> MarketplaceItem? {
        isLoading = true
        errorMessage = nil

        let itemId = UUID().uuidString
        let storagePath = "marketplace_models/\(uploader.id)/\(itemId).usdz"
        let storageRef = storage.reference().child(storagePath)

        do {
            // 1. Get file size
            let attrs = try FileManager.default.attributesOfItem(atPath: usdzFileURL.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0

            // 2. Upload USDZ to Storage
            let metadata = StorageMetadata()
            metadata.contentType = "model/vnd.usdz+zip"
            _ = try await storageRef.putFileAsync(from: usdzFileURL, metadata: metadata)
            let modelDownloadURL = try await storageRef.downloadURL().absoluteString

            // 3. Thumbnail placeholder (can be enhanced with QuickLook later)
            let thumbnailURL = ""  // No thumbnail for now

            // 4. Create Firestore document
            let item = MarketplaceItem(
                id: itemId,
                name: name,
                description: description,
                category: category,
                uploaderUid: uploader.id,
                uploaderName: uploader.displayName,
                uploadedAt: Date(),
                downloadCount: 0,
                likeCount: 0,
                thumbnailURL: thumbnailURL,
                modelURL: modelDownloadURL,
                fileSize: fileSize,
                tags: tags,
                dimensions: dimensions
            )

            try itemsCollection.document(itemId).setData(from: item)

            // 5. Increment user's upload count
            try await usersCollection.document(uploader.id).updateData([
                "uploadCount": FieldValue.increment(Int64(1))
            ])

            print("[Marketplace] Successfully uploaded: \(name)")
            isLoading = false
            return item

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            print("[Marketplace] Upload error: \(error)")
            isLoading = false
            return nil
        }
    }

    // MARK: - Download

    /// Download a marketplace USDZ model to local cache and return the local file URL.
    func downloadModel(_ item: MarketplaceItem) async -> URL? {
        let localURL = Self.downloadCacheDirectory.appendingPathComponent("\(item.id).usdz")

        // Return cached file if it already exists
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        isLoading = true
        do {
            let storageRef = storage.reference(forURL: item.modelURL)
            _ = try await storageRef.writeAsync(toFile: localURL)

            // Increment download count
            try await itemsCollection.document(item.id).updateData([
                "downloadCount": FieldValue.increment(Int64(1))
            ])

            // Increment uploader's total downloads
            try await usersCollection.document(item.uploaderUid).updateData([
                "totalDownloads": FieldValue.increment(Int64(1))
            ])

            // Register metadata locally so pickers can list this model
            DownloadedMarketplaceModel.register(
                DownloadedMarketplaceModel(id: item.id, name: item.name, category: item.category)
            )

            print("[Marketplace] Downloaded: \(item.name)")
            isLoading = false
            return localURL
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            print("[Marketplace] Download error: \(error)")
            isLoading = false
            return nil
        }
    }

    /// Check whether a marketplace model is already cached locally.
    func isModelCached(_ item: MarketplaceItem) -> Bool {
        let localURL = Self.downloadCacheDirectory.appendingPathComponent("\(item.id).usdz")
        return FileManager.default.fileExists(atPath: localURL.path)
    }

    /// Get the local file URL for a cached marketplace model.
    func cachedModelURL(for item: MarketplaceItem) -> URL? {
        let localURL = Self.downloadCacheDirectory.appendingPathComponent("\(item.id).usdz")
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }

    // MARK: - Like / Unlike

    func toggleLike(item: MarketplaceItem, userId: String) async {
        let likesRef = itemsCollection.document(item.id).collection("likes").document(userId)
        do {
            let doc = try await likesRef.getDocument()
            if doc.exists {
                // Unlike
                try await likesRef.delete()
                try await itemsCollection.document(item.id).updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                // Like
                try await likesRef.setData(["likedAt": Timestamp(date: Date())])
                try await itemsCollection.document(item.id).updateData([
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
            // Refresh items
            await fetchItems()
        } catch {
            print("[Marketplace] Like toggle error: \(error)")
        }
    }

    /// Check if a user has liked a specific item.
    func isLikedByUser(itemId: String, userId: String) async -> Bool {
        do {
            let doc = try await itemsCollection.document(itemId).collection("likes").document(userId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    // MARK: - Delete

    func deleteItem(_ item: MarketplaceItem) async {
        do {
            // Delete from Storage
            if !item.modelURL.isEmpty {
                let ref = storage.reference(forURL: item.modelURL)
                try await ref.delete()
            }

            // Delete Firestore document
            try await itemsCollection.document(item.id).delete()

            // Decrement user upload count
            try await usersCollection.document(item.uploaderUid).updateData([
                "uploadCount": FieldValue.increment(Int64(-1))
            ])

            // Remove from local cache & metadata
            let cacheURL = Self.downloadCacheDirectory.appendingPathComponent("\(item.id).usdz")
            try? FileManager.default.removeItem(at: cacheURL)
            DownloadedMarketplaceModel.unregister(id: item.id)

            // Update local arrays
            items.removeAll { $0.id == item.id }
            myUploads.removeAll { $0.id == item.id }

            print("[Marketplace] Deleted: \(item.name)")
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
}
