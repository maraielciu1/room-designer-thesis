//
//  ScannedFurniture.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 20.02.2026.
//

import Foundation

/// Represents a piece of furniture that the user scanned with Object Capture.
/// The USDZ file is stored on disk; this struct holds metadata for the catalog.
struct ScannedFurniture: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var userId: UUID
    var usdzFileName: String          // e.g. "<uuid>.usdz" inside ScannedFurniture/
    var category: String              // user-chosen: "chair", "table", "sofa", …
    var createdAt: Date
    var fileSizeBytes: Int64?

    /// Real-world dimensions [width, height, depth] in metres, measured from the
    /// USDZ model's visual bounds right after Object Capture reconstruction.
    /// Because Object Capture preserves absolute scale (1 unit = 1 m), these
    /// values correspond directly to the physical object's size.
    var realWorldDimensions: [Double]?

    // ── Gaussian Splatting ──

    /// File name of the associated .ply Gaussian Splat (nil if none imported).
    var splatFileName: String?

    /// Number of Gaussians in the splat file (set when imported).
    var splatGaussianCount: Int?

    /// File size of the .ply splat file in bytes.
    var splatFileSizeBytes: Int64?

    /// Method used for reconstruction: "objectCapture", "gaussianSplat", or "both".
    var reconstructionMethod: String?

    init(id: UUID = UUID(), name: String, userId: UUID,
         usdzFileName: String, category: String = "other",
         createdAt: Date = Date(), fileSizeBytes: Int64? = nil,
         realWorldDimensions: [Double]? = nil,
         splatFileName: String? = nil,
         splatGaussianCount: Int? = nil,
         splatFileSizeBytes: Int64? = nil,
         reconstructionMethod: String? = nil) {
        self.id = id
        self.name = name
        self.userId = userId
        self.usdzFileName = usdzFileName
        self.category = category
        self.createdAt = createdAt
        self.fileSizeBytes = fileSizeBytes
        self.realWorldDimensions = realWorldDimensions
        self.splatFileName = splatFileName
        self.splatGaussianCount = splatGaussianCount
        self.splatFileSizeBytes = splatFileSizeBytes
        self.reconstructionMethod = reconstructionMethod
    }

    /// The real-world size as a SIMD3 vector (metres), or nil if not measured.
    var realWorldSize: SIMD3<Float>? {
        guard let d = realWorldDimensions, d.count >= 3 else { return nil }
        return SIMD3<Float>(Float(d[0]), Float(d[1]), Float(d[2]))
    }

    // MARK: - Identifiers for the replacement system

    /// The key stored in `FurnitureReplacement.replacedWithUSDZ` so the catalog
    /// manager knows to load this model from disk rather than the app bundle.
    var catalogKey: String { "scanned_\(id.uuidString)" }

    /// Absolute URL of the USDZ file on disk (per-user storage, with legacy fallback).
    var usdzURL: URL {
        let primary = UserStoragePaths.scannedFurniture(userId: userId).appendingPathComponent(usdzFileName)
        if FileManager.default.fileExists(atPath: primary.path) { return primary }
        return UserStoragePaths.legacyScannedFurniture.appendingPathComponent(usdzFileName)
    }

    /// Human-readable file size.
    var formattedSize: String {
        guard let bytes = fileSizeBytes else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Gaussian Splatting helpers

    /// Whether this object has an associated Gaussian Splat .ply file.
    var hasSplat: Bool { splatFileName != nil }

    /// Absolute URL of the .ply splat file on disk.
    var splatURL: URL? {
        guard let name = splatFileName else { return nil }
        let primary = UserStoragePaths.scannedFurniture(userId: userId).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: primary.path) { return primary }
        return UserStoragePaths.legacyScannedFurniture.appendingPathComponent(name)
    }

    /// Human-readable file size for the splat.
    var formattedSplatSize: String {
        guard let bytes = splatFileSizeBytes else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Whether both reconstruction methods are available.
    var hasBothMethods: Bool { hasSplat }
}

/// Available categories the user can assign when naming their scanned object.
enum FurnitureCategory: String, CaseIterable, Identifiable {
    case chair, table, sofa, storage, lamp, bed, desk, decoration, other

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .chair:      return "chair.fill"
        case .table:      return "table.furniture.fill"
        case .sofa:       return "sofa.fill"
        case .storage:    return "cabinet.fill"
        case .lamp:       return "lamp.desk.fill"
        case .bed:        return "bed.double.fill"
        case .desk:       return "desktopcomputer"
        case .decoration: return "photo.artframe"
        case .other:      return "cube.fill"
        }
    }
}
