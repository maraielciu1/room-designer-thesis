//
//  FurnitureCatalogManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import Combine
import RoomPlan
import RealityKit

class FurnitureCatalogManager: ObservableObject {
    @Published var availableUSDZFiles: [String] = []
    
    // Maps RoomPlan categories to available USDZ files
    static let categoryMappings: [String: [String]] = [
        "chair": ["simple_chair", "wooden_chair"],
        "table": ["round_table"],
        "storage": ["multiple_squares_shelf"],
        "sofa": ["sofa"],
        "other": ["quitar"] // For objects that don't match standard categories
    ]
    
    init() {
        loadAvailableUSDZFiles()
    }
    
    func getModelsForCategory(_ category: CapturedRoom.Object.Category) -> [String] {
        let categoryKey = "\(category)".replacingOccurrences(of: ".", with: "")
        return FurnitureCatalogManager.categoryMappings[categoryKey] ?? []
    }
    
    func getAllAvailableModels() -> [String] {
        return availableUSDZFiles
    }
    
    // MARK: - Model file URL resolution

    /// Returns the on-disk file URL for any model — bundle or user-scanned.
    /// Used by `USDZThumbnailView` to generate preview images.
    func modelFileURL(for name: String) -> URL? {
        if isScannedModel(name) {
            return scannedModelURL(for: name)
        }
        // Try bundle — USDZ first, then USDC
        if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "usdc") {
            return url
        }
        return nil
    }

    // MARK: - Model loading (bundle + user-scanned)

    /// Whether a model key refers to a user-scanned object (e.g. "scanned_<uuid>").
    func isScannedModel(_ name: String) -> Bool {
        name.hasPrefix("scanned_")
    }

    /// Locate a scanned USDZ in per-user folders or the legacy shared directory.
    static func findScannedModelURL(fileName: String) -> URL? {
        let legacy = UserStoragePaths.legacyScannedFurniture.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: legacy.path) { return legacy }

        let usersRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("users", isDirectory: true)
        guard let userDirs = try? FileManager.default.contentsOfDirectory(
            at: usersRoot, includingPropertiesForKeys: nil
        ) else { return nil }

        for userDir in userDirs {
            let candidate = userDir
                .appendingPathComponent("ScannedFurniture", isDirectory: true)
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Resolve a scanned-model catalog key to its USDZ file URL on disk.
    func scannedModelURL(for name: String) -> URL? {
        guard isScannedModel(name) else { return nil }
        let uuidString = String(name.dropFirst("scanned_".count))
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        let fileName = "\(uuid.uuidString).usdz"
        return Self.findScannedModelURL(fileName: fileName)
    }

    /// Load a model entity — app-bundle or user-scanned USDZ.
    func loadModel(named fileName: String) -> Entity? {
        if isScannedModel(fileName), let url = scannedModelURL(for: fileName) {
            return try? Entity.load(contentsOf: url)
        }
        return try? Entity.load(named: fileName)
    }
    
    // MARK: - Known dimensions for built-in models (metres)

    /// Approximate real-world dimensions [width, height, depth] for the
    /// USDZ files that ship with the app.  When a model is authored at
    /// 1 unit = 1 m these match its visual bounds; otherwise they serve
    /// as a sensible reference so `loadAndScaleModel` can still produce
    /// correctly-proportioned results.
    static let knownBuiltInDimensions: [String: SIMD3<Float>] = [
        "simple_chair":           SIMD3<Float>(0.45, 0.85, 0.45),
        "wooden_chair":           SIMD3<Float>(0.50, 0.90, 0.50),
        "round_table":            SIMD3<Float>(0.90, 0.75, 0.90),
        "multiple_squares_shelf": SIMD3<Float>(0.80, 1.80, 0.35),
        "sofa":                   SIMD3<Float>(2.00, 0.85, 0.90),
        "quitar":                 SIMD3<Float>(0.40, 1.10, 0.12),
    ]

    // MARK: - Real-world-scale loading (for scanned objects)

    /// Load a USDZ model at its **native** (real-world) scale.
    ///
    /// Object Capture outputs use 1 unit = 1 m, so the model already
    /// represents the physical size — no rescaling is applied.
    ///
    /// The model is wrapped in a container entity, centred horizontally,
    /// and its bottom is aligned with the detected RoomPlan object's
    /// bottom (= `−targetDimensions.y / 2` below the anchor point) so
    /// that furniture sits on the floor.
    ///
    /// - Parameters:
    ///   - fileName: The model identifier (e.g. `"scanned_<uuid>"`).
    ///   - targetDimensions: The detected object's bounding-box size.
    ///     Only `y` is used — for vertical (ground) alignment.
    func loadAtRealWorldScale(named fileName: String,
                              targetDimensions: SIMD3<Float>) -> Entity? {
        guard let model = loadModel(named: fileName) else {
            print("REAL-SCALE ERROR: Could not load model: \(fileName)")
            return nil
        }

        let bounds = model.visualBounds(relativeTo: model)
        let ext = bounds.extents
        print("REAL-WORLD SCALE [\(fileName)]:")
        print("  Native extents: x=\(String(format: "%.3f", ext.x))m  "
            + "y=\(String(format: "%.3f", ext.y))m  "
            + "z=\(String(format: "%.3f", ext.z))m")

        // ─ No scaling - keep the model at 1:1 real-world size ─
        // model.scale stays at whatever the USDZ file defines (typically 1,1,1)

        // Wrap in a container and CENTER the model
        let container = Entity()
        container.addChild(model)

        let boundsInContainer = model.visualBounds(relativeTo: container)
        let visualCenter = boundsInContainer.center
        model.position = SIMD3<Float>(-visualCenter.x, -visualCenter.y, -visualCenter.z)

        // GROUND ALIGNMENT — sit on the floor
        let centeredBounds = model.visualBounds(relativeTo: container)
        let modelBottom  = centeredBounds.min.y
        let targetBottom = -targetDimensions.y / 2.0
        model.position.y += (targetBottom - modelBottom)

        let finalBounds = model.visualBounds(relativeTo: container)
        let finalSize = finalBounds.extents
        print("  Final size:   x=\(String(format: "%.3f", finalSize.x))m  "
            + "y=\(String(format: "%.3f", finalSize.y))m  "
            + "z=\(String(format: "%.3f", finalSize.z))m")
        print("  Final bottom: y=\(String(format: "%.3f", finalBounds.min.y))m  "
            + "(target: \(String(format: "%.3f", targetBottom))m)")

        return container
    }

    // MARK: - Fit-to-bounding-box loading (for built-in catalogue models)

    /// Load a USDZ model, scale it to fit within the target dimensions, center it,
    /// and align its bottom to the target volume's bottom (so furniture sits on the floor).
    ///
    /// Returns a container Entity with the model centered inside.
    ///
    /// KEY INSIGHT: We use `visualBounds(relativeTo: model)` — NOT `relativeTo: nil`.
    /// `relativeTo: model`  → bounds in model's LOCAL space (before model.scale is applied)
    /// Since we SET `model.scale`, we need the local-space extents so the math works:
    ///   newScale = target / localExtents → final = localExtents × newScale = target  ✓
    func loadAndScaleModel(named fileName: String, targetDimensions: SIMD3<Float>) -> Entity? {
        // Load from disk for scanned models, from bundle for built-in
        let model: Entity?
        if isScannedModel(fileName), let url = scannedModelURL(for: fileName) {
            model = try? Entity.load(contentsOf: url)
        } else {
            model = try? Entity.load(named: fileName)
        }
        guard let model else {
            print("SCALE ERROR: Could not load model: \(fileName)")
            return nil
        }
        
        // ── 1. Log the model's original scale from the USDZ ──
        let originalScale = model.scale
        print("SCALE [\(fileName)]:")
        print("  USDZ root scale: (\(String(format: "%.4f", originalScale.x)), \(String(format: "%.4f", originalScale.y)), \(String(format: "%.4f", originalScale.z)))")
        
        // ── 2. Get bounds in model's LOCAL space (before model.scale) ──
        let bounds = model.visualBounds(relativeTo: model)
        let localExtents = bounds.extents
        
        print("  Local extents: x=\(String(format: "%.3f", localExtents.x))  y=\(String(format: "%.3f", localExtents.y))  z=\(String(format: "%.3f", localExtents.z))")
        print("  Target dims:   x=\(String(format: "%.3f", targetDimensions.x))  y=\(String(format: "%.3f", targetDimensions.y))  z=\(String(format: "%.3f", targetDimensions.z))")
        
        // ── 3. Validate bounds ──
        guard localExtents.x > 0.001, localExtents.y > 0.001, localExtents.z > 0.001 else {
            print("  WARNING: Bounds are zero/tiny — using fallback scale 0.01")
            model.scale = SIMD3<Float>(repeating: 0.01)
            return model
        }
        
        // ── 4. Calculate uniform scale = min(target / local) × 90% ──
        let uniformScale = USDFurnitureFitScale.uniformScale(
            targetSize: targetDimensions,
            modelSize: localExtents,
            margin: 0.90
        )
        
        // ── 5. Apply scale ──
        model.scale = SIMD3<Float>(repeating: uniformScale)
        
        // ── 6. Wrap in a container and CENTER the model ──
        // USDZ models often have their origin at an arbitrary point (foot, corner, etc.).
        // We shift the model so its visual center aligns with (0,0,0) — the anchor point.
        let container = Entity()
        container.addChild(model)
        
        let scaledBounds = model.visualBounds(relativeTo: container)
        let visualCenter = scaledBounds.center
        model.position = SIMD3<Float>(-visualCenter.x, -visualCenter.y, -visualCenter.z)
        
        // ── 7. GROUND ALIGNMENT ──
        // RoomPlan's anchor is at the center of the detected object volume.
        // Furniture should sit on the floor, so we align the model's bottom
        // with the scanned object's bottom (= −targetDimensions.y / 2).
        let centeredBounds = model.visualBounds(relativeTo: container)
        let modelBottom = centeredBounds.min.y          // model's current bottom
        let targetBottom = -targetDimensions.y / 2.0    // scanned object's bottom
        model.position.y += (targetBottom - modelBottom)
        
        // ── 8. Verify ──
        let finalBounds = model.visualBounds(relativeTo: container)
        let finalSize = finalBounds.extents
        print("  Uniform scale:  \(String(format: "%.6f", uniformScale))")
        print("  Final size:     x=\(String(format: "%.3f", finalSize.x))m  y=\(String(format: "%.3f", finalSize.y))m  z=\(String(format: "%.3f", finalSize.z))m")
        print("  Final bottom:   y=\(String(format: "%.3f", finalBounds.min.y))m  (target bottom: \(String(format: "%.3f", targetBottom))m)")
        
        return container
    }
    
    func getModelForCategory(_ category: CapturedRoom.Object.Category, preferredModel: String? = nil) -> Entity? {
        let categoryKey = "\(category)".replacingOccurrences(of: ".", with: "")
        
        if let preferred = preferredModel, availableUSDZFiles.contains(preferred) {
            return loadModel(named: preferred)
        }
        
        // Try to get first available model for this category
        if let models = FurnitureCatalogManager.categoryMappings[categoryKey],
           let firstModel = models.first(where: { availableUSDZFiles.contains($0) }) {
            return loadModel(named: firstModel)
        }
        
        return nil
    }
    
    private func loadAvailableUSDZFiles() {
        // In a real app, you'd scan the bundle for USDZ files
        // For now, we'll use the known files
        availableUSDZFiles = [
            "simple_chair",
            "wooden_chair",
            "round_table",
            "multiple_squares_shelf",
            "sofa",
            "quitar"
        ]
    }
}
