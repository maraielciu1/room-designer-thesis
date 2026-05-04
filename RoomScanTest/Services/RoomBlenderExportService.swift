//
//  RoomBlenderExportService.swift
//  RoomScanTest
//
//  Exports a saved room as a .zip for Blender / other DCC tools:
//  • room_scene.gltf + room_scene.bin — walls, floors, doors, windows, placeholders
//  • textures/ — procedural wall/floor patterns when used
//  • furniture/*.usdz — copies of replacement models
//  • wall_art/*.jpg — wall art source images
//  • README.txt — import hints
//

import Foundation
import UIKit
import simd
import RoomPlan
import RealityKit

// MARK: - Public API

enum RoomBlenderExportService {

    /// Resolves persisted materials when exporting from the room list (no live editor state).
    static func materialsForListExport(room: Room) -> (wall: UIColor, floor: UIColor, wallPattern: SurfacePattern, floorPattern: SurfacePattern) {
        if let m = room.roomMaterials {
            return (m.wallColor.uiColor, m.floorColor.uiColor, m.wallPattern, m.floorPattern)
        }
        let w = UIColor(red: 0.7, green: 0.75, blue: 0.85, alpha: 1)
        let f = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        return (w, f, .none, .none)
    }

    /// Builds a zip archive under the system temp directory. Caller should delete the URL after sharing.
    @MainActor
    static func makeExportZip(
        room: Room,
        capturedRoom: CapturedRoom,
        wallColor: UIColor,
        floorColor: UIColor,
        wallPattern: SurfacePattern,
        floorPattern: SurfacePattern,
        catalog: FurnitureCatalogManager
    ) throws -> URL {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoomExport_\(room.id.uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: work.path) {
            try FileManager.default.removeItem(at: work)
        }
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let innerName = "\(room.name.sanitizedForPath)_\(room.id.uuidString.prefix(8))"
        let root = work.appendingPathComponent(innerName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let texDir = root.appendingPathComponent("textures", isDirectory: true)
        let furnDir = root.appendingPathComponent("furniture", isDirectory: true)
        let artDir = root.appendingPathComponent("wall_art", isDirectory: true)
        try FileManager.default.createDirectory(at: texDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: furnDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: artDir, withIntermediateDirectories: true)

        var builder = GltfMiniBuilder()
        var textureFileCounter = 0
        var furnitureIndex = 0
        var usdzNodes: [(name: String, file: String, matrix: simd_float4x4)] = []

        let arResolver = ExportPoseResolver(catalog: catalog)

        // ── Structure: walls ──
        for (i, wall) in capturedRoom.walls.enumerated() {
            let d = clampDims(wall.dimensions)
            let texRel: String?
            if wallPattern != .none {
                let texW = max(d.x, d.z)
                let texH = d.y
                if let cg = TextureGenerator.texture(for: wallPattern, color: wallColor, widthM: texW, heightM: texH),
                   let png = UIImage(cgImage: cg).pngData() {
                    textureFileCounter += 1
                    let fn = "textures/wall_\(i)_\(textureFileCounter).png"
                    try png.write(to: root.appendingPathComponent(fn))
                    texRel = fn
                } else { texRel = nil }
            } else { texRel = nil }
            let rgba = rgbaFloats(wallColor)
            try builder.addBox(
                name: "wall_\(i)",
                transform: wall.transform,
                halfExtents: d * 0.5,
                baseColor: rgba,
                textureRelativePath: texRel
            )
        }

        // ── Floors ──
        for (i, floor) in capturedRoom.floors.enumerated() {
            let d = clampDims(floor.dimensions)
            let texRel: String?
            if floorPattern != .none {
                let texW = d.x
                let texH = d.z
                if let cg = TextureGenerator.texture(for: floorPattern, color: floorColor, widthM: texW, heightM: texH),
                   let png = UIImage(cgImage: cg).pngData() {
                    textureFileCounter += 1
                    let fn = "textures/floor_\(i)_\(textureFileCounter).png"
                    try png.write(to: root.appendingPathComponent(fn))
                    texRel = fn
                } else { texRel = nil }
            } else { texRel = nil }
            let rgba = rgbaFloats(floorColor)
            try builder.addBox(
                name: "floor_\(i)",
                transform: floor.transform,
                halfExtents: d * 0.5,
                baseColor: rgba,
                textureRelativePath: texRel
            )
        }

        // ── Doors / windows (semi-transparent in editor) ──
        for (i, door) in capturedRoom.doors.enumerated() {
            let d = clampDims(door.dimensions)
            let c = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.25)
            try builder.addBox(
                name: "door_\(i)",
                transform: door.transform,
                halfExtents: d * 0.5,
                baseColor: rgbaFloats(c),
                textureRelativePath: nil,
                alphaMode: "BLEND"
            )
        }
        for (i, window) in capturedRoom.windows.enumerated() {
            let d = clampDims(window.dimensions)
            let c = UIColor(red: 0.3, green: 0.8, blue: 0.95, alpha: 0.2)
            try builder.addBox(
                name: "window_\(i)",
                transform: window.transform,
                halfExtents: d * 0.5,
                baseColor: rgbaFloats(c),
                textureRelativePath: nil,
                alphaMode: "BLEND"
            )
        }

        // ── Scanned furniture: replaced (USDZ) vs wireframe placeholder ──
        for (index, object) in capturedRoom.objects.enumerated() {
            guard isFurnitureObject(object) else { continue }
            let target = clampDims(object.dimensions)
            if let rep = replacementForScannedObject(object: object, room: room), !rep.isDecor {
                guard let srcURL = catalog.modelFileURL(for: rep.replacedWithUSDZ) else { continue }
                let destName = "\(String(format: "%02d", furnitureIndex))_\(rep.replacedWithUSDZ).usdz"
                furnitureIndex += 1
                let destURL = furnDir.appendingPathComponent(destName)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.copyItem(at: srcURL, to: destURL)

                if let world = arResolver.worldMatrixForUSDZFurniture(
                    objectTransform: object.transform,
                    targetDimensions: target,
                    replacement: rep
                ) {
                    let nodeName = Self.blenderReferenceEmptyName(usdzFileName: destName)
                    usdzNodes.append((nodeName, "furniture/\(destName)", world))
                }
            } else {
                let cat = categoryKey(object)
                let wc = RoomModelSceneView.wireframeColor(for: cat)
                try builder.addBox(
                    name: "furniture_placeholder_\(index)_\(cat)",
                    transform: object.transform,
                    halfExtents: target * 0.5,
                    baseColor: rgbaFloats(wc),
                    textureRelativePath: nil
                )
            }
        }

        // ── Free-placed furniture (originalCategory == "added") ──
        for rep in room.furnitureReplacements where rep.originalCategory == "added" {
            guard let xform = rep.getTransformMatrix(),
                  let srcURL = catalog.modelFileURL(for: rep.replacedWithUSDZ)
            else { continue }
            let destName = "\(String(format: "%02d", furnitureIndex))_\(rep.replacedWithUSDZ).usdz"
            furnitureIndex += 1
            let destURL = furnDir.appendingPathComponent(destName)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.copyItem(at: srcURL, to: destURL)

            let defaultDims = FurnitureCatalogManager.knownBuiltInDimensions[rep.replacedWithUSDZ]
                ?? SIMD3<Float>(0.5, 0.5, 0.5)
            if let world = arResolver.worldMatrixForAddedFurniture(
                baseTransform: xform,
                modelName: rep.replacedWithUSDZ,
                defaultDims: defaultDims,
                replacement: rep
            ) {
                let nodeName = Self.blenderReferenceEmptyName(usdzFileName: destName)
                usdzNodes.append((nodeName, "furniture/\(destName)", world))
            }
        }

        // ── Wall art: textured plane in glTF + copy JPEG ──
        for rep in room.furnitureReplacements where rep.isWallArt {
            guard let xform = rep.getTransformMatrix(),
                  let imageFile = rep.wallArtImageFile,
                  let frameSizeRaw = rep.wallArtFrameSize,
                  let frameStyleRaw = rep.wallArtFrameStyle,
                  let fSize = FrameSize(rawValue: frameSizeRaw),
                  let fStyle = FrameStyle(rawValue: frameStyleRaw),
                  let srcImg = DecorManager.loadImage(named: imageFile),
                  let png = srcImg.pngData()
            else { continue }

            let artName = "wallart_\(rep.id.uuidString.prefix(8)).png"
            try png.write(to: artDir.appendingPathComponent(artName))
            let texRel = "wall_art/\(artName)"

            if let world = arResolver.worldMatrixForWallArt(
                transform: xform,
                frameSize: fSize,
                frameStyle: fStyle,
                replacement: rep
            ) {
                let rgba = rgbaFloats(.white)
                try builder.addTexturedVerticalPlane(
                    name: "wall_art_\(rep.id.uuidString.prefix(8))",
                    worldMatrix: world,
                    width: fSize.widthM,
                    height: fSize.heightM,
                    textureRelativePath: texRel,
                    tint: rgba
                )
            }
        }

        // ── Lighting & carpet: coloured boxes approximating footprint ──
        for rep in room.furnitureReplacements where rep.isLighting {
            guard let xform = rep.getTransformMatrix(),
                  let fixtureRaw = rep.lightFixtureType,
                  let fixtureType = LightFixtureType(rawValue: fixtureRaw)
            else { continue }
            let color: UIColor
            if let rgb = rep.lightColorRGB, rgb.count >= 3 {
                color = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
            } else { color = .white }
            let dims = SIMD3<Float>(0.45, 0.55, 0.45)
            if let world = arResolver.worldMatrixForSimpleDecor(
                transform: xform,
                replacement: rep,
                attach: {
                    DecorManager.createLightFixture(type: fixtureType, color: color, intensity: Float(rep.lightIntensity ?? 3000))
                }
            ) {
                try builder.addBox(
                    name: "lighting_\(rep.id.uuidString.prefix(8))",
                    transform: world,
                    halfExtents: dims * 0.5,
                    baseColor: rgbaFloats(color.withAlphaComponent(0.85)),
                    textureRelativePath: nil
                )
            }
        }

        for rep in room.furnitureReplacements where rep.isCarpet {
            guard let xform = rep.getTransformMatrix(),
                  let sizeRaw = rep.carpetSize,
                  let patternRaw = rep.carpetPattern,
                  let carpetPattern = CarpetPattern(rawValue: patternRaw)
            else { continue }
            let carpetSize = CarpetSize(rawValue: sizeRaw)
            let widthM: Float
            let depthM: Float
            if carpetSize == .custom,
               let cw = rep.carpetCustomWidthCm,
               let cd = rep.carpetCustomDepthCm {
                widthM = Float(cw) / 100
                depthM = Float(cd) / 100
            } else {
                widthM = carpetSize?.widthM ?? 1.5
                depthM = carpetSize?.depthM ?? 2.0
            }
            let isRound = carpetSize?.isRound ?? false
            let carpetColor: UIColor
            if let rgb = rep.carpetColorRGB, rgb.count >= 3 {
                carpetColor = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
            } else {
                carpetColor = UIColor(red: 0.55, green: 0.40, blue: 0.30, alpha: 1)
            }
            if let world = arResolver.worldMatrixForSimpleDecor(
                transform: xform,
                replacement: rep,
                attach: {
                    DecorManager.createCarpetEntity(
                        widthM: widthM, depthM: depthM,
                        isRound: isRound, color: carpetColor,
                        pattern: carpetPattern
                    )
                }
            ) {
                let ext = SIMD3<Float>(max(widthM, 0.2), 0.03, max(depthM, 0.2))
                try builder.addBox(
                    name: "carpet_\(rep.id.uuidString.prefix(8))",
                    transform: world,
                    halfExtents: ext * 0.5,
                    baseColor: rgbaFloats(carpetColor),
                    textureRelativePath: nil
                )
            }
        }

        for node in usdzNodes {
            builder.addEmptyNode(name: node.name, matrix: node.matrix)
        }

        let (gltfDict, binData) = try builder.build(rootName: innerName)
        let gltfData = try JSONSerialization.data(withJSONObject: gltfDict, options: [.prettyPrinted, .sortedKeys])
        try gltfData.write(to: root.appendingPathComponent("room_scene.gltf"), options: .atomic)
        try binData.write(to: root.appendingPathComponent("room_scene.bin"), options: .atomic)

        let readme = Self.readmeText(innerFolderName: innerName)
        try readme.data(using: .utf8)?.write(to: root.appendingPathComponent("README.txt"), options: .atomic)

        try Data(Self.blenderApplyFurnitureScriptUTF8.utf8).write(
            to: root.appendingPathComponent("blender_apply_furniture.py"),
            options: [.atomic]
        )

        let zipBytes = try ZipStoreArchive.zip(directory: root, stripPrefix: work.path + "/")
        try FileManager.default.removeItem(at: work)

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(innerName).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try zipBytes.write(to: zipURL, options: .atomic)
        return zipURL
    }

    /// Empty name prefix in glTF; matches USDZ stem: `RF_<stem>` ↔ `furniture/<stem>.usdz`
    private static let blenderEmptyPrefix = "RF_"

    private static func blenderReferenceEmptyName(usdzFileName: String) -> String {
        let stem = (usdzFileName as NSString).deletingPathExtension
        // Keep the exact stem (including UUID hyphens) so RF_<stem> maps 1:1
        // to furniture/<stem>.usdz inside the Blender helper script.
        return "\(blenderEmptyPrefix)\(stem)"
    }

    private static let blenderApplyFurnitureScriptUTF8 = """
    # RoomScanTest — import USDZ furniture and place via RF_* empties from room_scene.gltf
    # Usage:
    #   1) Import room_scene.gltf
    #   2) Open this script in Blender's Scripting workspace and Run Script
    # This avoids name-matching and importer-axis ambiguities by importing each USDZ from
    # ./furniture and applying the reference empty's matrix_world to the imported roots.

    import os
    import math
    import bpy

    PREFIX = "\(blenderEmptyPrefix)"
    # Blender USD importer often yields assets with a different axis/unit basis than glTF.
    # These defaults fix the common case (USD authored in centimeters, Y-up).
    USD_UNIT_SCALE = 0.01
    USD_AXIS_FIX_EULER_DEG = (-90.0, 0.0, 0.0)  # applied in XYZ order

    def script_dir():
        txt = bpy.context.space_data.text if bpy.context.space_data else None
        if txt and txt.filepath:
            return os.path.dirname(bpy.path.abspath(txt.filepath))
        if bpy.data.filepath:
            return os.path.dirname(bpy.path.abspath(bpy.data.filepath))
        return os.getcwd()

    def candidate_base_dirs():
        cands = []
        cands.append(script_dir())
        if bpy.data.filepath:
            cands.append(os.path.dirname(bpy.path.abspath(bpy.data.filepath)))
        cands.append(os.getcwd())
        # Directories referenced by imported images from glTF (often beside room_scene.gltf)
        for img in bpy.data.images:
            fp = getattr(img, "filepath", None)
            if fp:
                cands.append(os.path.dirname(bpy.path.abspath(fp)))
        # De-duplicate while keeping order
        out = []
        seen = set()
        for d in cands:
            if not d:
                continue
            d = os.path.normpath(d)
            if d not in seen:
                seen.add(d)
                out.append(d)
        return out

    def find_furniture_dir(ref_stems):
        # First pass: immediate "furniture" subdir near likely bases
        for base in candidate_base_dirs():
            fd = os.path.join(base, "furniture")
            if os.path.isdir(fd):
                return fd
            # If base is already the extracted room folder, also check parent/furniture
            parent_fd = os.path.join(os.path.dirname(base), "furniture")
            if os.path.isdir(parent_fd):
                return parent_fd
        # Second pass: shallow recursive search for a folder containing expected usdz names
        wanted = set(stem + ".usdz" for stem in ref_stems if stem)
        for base in candidate_base_dirs():
            try:
                for root, dirs, files in os.walk(base):
                    if os.path.basename(root).lower() != "furniture":
                        continue
                    file_set = set(files)
                    if wanted & file_set:
                        return root
            except Exception:
                pass
        return None

    def roots_of(objs):
        s = set(objs)
        return [o for o in objs if o.parent not in s]

    def import_usdz(filepath):
        before = set(bpy.data.objects)
        if not hasattr(bpy.ops.wm, "usd_import"):
            raise RuntimeError("Blender USD importer is unavailable (bpy.ops.wm.usd_import missing)")
        bpy.ops.wm.usd_import(filepath=filepath)
        after = [o for o in bpy.data.objects if o not in before]
        return after

    def choose_anchor_root(roots):
        active = bpy.context.view_layer.objects.active
        if active:
            r = active
            while r.parent:
                r = r.parent
            if r in roots:
                return r
        # Fallback: root with most descendants (usually the meaningful import root)
        def score(obj):
            return len(obj.children_recursive)
        return max(roots, key=score)

    def group_roots_under_wrapper(roots, stem):
        anchor = choose_anchor_root(roots)
        placement = bpy.data.objects.new("RS_PLACE_" + stem, None)
        placement.empty_display_type = 'PLAIN_AXES'
        bpy.context.scene.collection.objects.link(placement)
        placement.matrix_world = anchor.matrix_world.copy()

        asset = bpy.data.objects.new("RS_ASSET_" + stem, None)
        asset.empty_display_type = 'PLAIN_AXES'
        bpy.context.scene.collection.objects.link(asset)
        asset.parent = placement
        asset.matrix_parent_inverse.identity()
        asset.rotation_mode = 'XYZ'
        asset.rotation_euler = tuple(math.radians(v) for v in USD_AXIS_FIX_EULER_DEG)
        asset.scale = (USD_UNIT_SCALE, USD_UNIT_SCALE, USD_UNIT_SCALE)

        for r in roots:
            world = r.matrix_world.copy()
            r.parent = asset
            r.matrix_world = world
        return placement, asset

    def main():
        refs = [o for o in bpy.data.objects if o.type == "EMPTY" and o.name.startswith(PREFIX)]
        if not refs:
            print("No RF_* empties found. Import room_scene.gltf first.")
            return

        stems = [e.name[len(PREFIX):] for e in refs if len(e.name) > len(PREFIX)]
        furniture_dir = find_furniture_dir(stems)
        if not furniture_dir:
            print("Missing furniture folder. Checked bases:")
            for b in candidate_base_dirs():
                print("  -", b)
            return
        print("Using furniture folder:", furniture_dir)

        for e in refs:
            stem = e.name[len(PREFIX):]
            if not stem:
                continue
            usdz = os.path.join(furniture_dir, stem + ".usdz")
            # Backward compatibility for older exports where RF stem replaced '-' with '_'
            if not os.path.exists(usdz):
                alt = os.path.join(furniture_dir, stem.replace("_", "-") + ".usdz")
                if os.path.exists(alt):
                    usdz = alt
            if not os.path.exists(usdz):
                print("Skip", e.name, "-> missing file", usdz)
                continue

            try:
                imported = import_usdz(usdz)
            except Exception as ex:
                print("Skip", e.name, "-> usd import failed:", ex)
                continue
            if not imported:
                print("Skip", e.name, "-> USD import produced no objects")
                continue

            roots = roots_of(imported)
            if not roots:
                print("Skip", e.name, "-> no import roots")
                continue

            placement, asset = group_roots_under_wrapper(roots, stem)
            placement.parent = None
            placement.matrix_world = e.matrix_world.copy()
            placement["roomscan_ref"] = e.name
            placement["roomscan_usdz"] = os.path.basename(usdz)
            placement["roomscan_scale_hint"] = USD_UNIT_SCALE
            placement["roomscan_axis_fix_deg"] = str(USD_AXIS_FIX_EULER_DEG)
            print("Imported + aligned", os.path.basename(usdz), "to", e.name)

    main()
    """

    private static func readmeText(innerFolderName: String) -> String {
        """
        Room export for Blender / 3D tools
        ===================================

        1. Unzip this archive. Open the folder "\(innerFolderName)".

        2. Import the room: File → Import → glTF 2.0 — pick "room_scene.gltf".
           Keep "room_scene.bin", "textures/", and "wall_art/" beside it (same layout as this folder).

        3. Open the Scripting workspace and run "blender_apply_furniture.py" from this folder.
           The script imports every USDZ from "furniture/" and aligns it to matching
           reference empties named "RF_<usdz_filename_without_extension>".
           It also applies a USD correction transform (unit scale + axis fix) to avoid
           oversized or rotated models caused by glTF-vs-USD importer differences.
           You can tweak constants at the top of the script:
             USD_UNIT_SCALE (default 0.01)
             USD_AXIS_FIX_EULER_DEG (default -90, 0, 0)

        4. Units are metres.

        Generated by RoomScanTest.
        """
    }

    // MARK: - Helpers

    private static func clampDims(_ d: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(max(d.x, 0.01), max(d.y, 0.01), max(d.z, 0.01))
    }

    private static func rgbaFloats(_ c: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }

    private static func categoryKey(_ object: CapturedRoom.Object) -> String {
        "\(object.category)".replacingOccurrences(of: ".", with: "")
    }

    private static func isFurnitureObject(_ object: CapturedRoom.Object) -> Bool {
        let cat = categoryKey(object)
        return FurnitureCatalogManager.categoryMappings.keys.contains(cat)
            || cat.contains("chair") || cat.contains("table")
            || cat.contains("sofa") || cat.contains("storage") || cat.contains("bed")
    }

    private static func replacementForScannedObject(object: CapturedRoom.Object, room: Room) -> FurnitureReplacement? {
        room.furnitureReplacements.first { rep in
            guard !rep.isDecor, rep.originalCategory != "added",
                  let t = rep.getTransformMatrix() else { return false }
            let d = t.columns.3 - object.transform.columns.3
            return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
        }
    }
}

// MARK: - String sanitization

private extension String {
    func sanitizedForPath() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Room" }
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>()")
        return trimmed.unicodeScalars.map { illegal.contains($0) ? "_" : Character($0) }
            .map { String($0) }.joined()
    }

    /// Valid Blender object name segment (letters, digits, underscore; max length).
    func sanitizedForBlenderObjectName() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ""
        out.reserveCapacity(Swift.min(trimmed.count, 63))
        for ch in trimmed {
            if ch.isLetter || ch.isNumber || ch == "_" {
                out.append(ch)
            } else if ch == "-" || ch == "." || ch == " " {
                out.append("_")
            }
        }
        while out.contains("__") {
            out = out.replacingOccurrences(of: "__", with: "_")
        }
        let collapsed = out.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if collapsed.isEmpty { return "model" }
        return String(collapsed.prefix(63))
    }
}

// MARK: - Pose resolution (matches editor hierarchy)

@MainActor
private final class ExportPoseResolver {
    private let catalog: FurnitureCatalogManager
    private let arView = ARView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))

    init(catalog: FurnitureCatalogManager) {
        self.catalog = catalog
    }

    private func clearScene() {
        for a in arView.scene.anchors { arView.scene.removeAnchor(a) }
    }

    func worldMatrixForUSDZFurniture(
        objectTransform: simd_float4x4,
        targetDimensions: SIMD3<Float>,
        replacement: FurnitureReplacement
    ) -> simd_float4x4? {
        let modelName = replacement.replacedWithUSDZ
        let useRealScale = catalog.isScannedModel(modelName)
        guard let model = useRealScale
            ? catalog.loadAtRealWorldScale(named: modelName, targetDimensions: targetDimensions)
            : catalog.loadAndScaleModel(named: modelName, targetDimensions: targetDimensions)
        else { return nil }

        if let yRot = replacement.yRotation {
            model.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
        }
        if let cs = replacement.customScale {
            model.scale *= Float(cs)
        }

        clearScene()
        let anchor = AnchorEntity(world: objectTransform)
        let mover = Entity()
        anchor.addChild(mover)
        mover.addChild(model)
        arView.scene.addAnchor(anchor)

        if let off = replacement.positionOffset, off.count >= 3 {
            let o = objectTransform.columns.3
            let orig = SIMD3<Float>(o.x, o.y, o.z)
            let targetPos = orig + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
            mover.setPosition(targetPos, relativeTo: nil)
        }

        let m = model.transformMatrix(relativeTo: nil)
        clearScene()
        return m
    }

    func worldMatrixForAddedFurniture(
        baseTransform: simd_float4x4,
        modelName: String,
        defaultDims: SIMD3<Float>,
        replacement: FurnitureReplacement
    ) -> simd_float4x4? {
        let useRealScale = catalog.isScannedModel(modelName)
        let model: Entity?
        if useRealScale {
            model = catalog.loadAtRealWorldScale(named: modelName, targetDimensions: defaultDims)
        } else {
            model = catalog.loadAndScaleModel(named: modelName, targetDimensions: defaultDims)
        }
        guard let model else { return nil }

        if let yRot = replacement.yRotation {
            model.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
        }
        if let cs = replacement.customScale {
            model.scale *= Float(cs)
        }

        clearScene()
        let anchor = AnchorEntity(world: baseTransform)
        let mover = Entity()
        anchor.addChild(mover)
        mover.addChild(model)
        arView.scene.addAnchor(anchor)

        if let off = replacement.positionOffset, off.count >= 3 {
            let o = baseTransform.columns.3
            let orig = SIMD3<Float>(o.x, o.y, o.z)
            let targetPos = orig + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
            mover.setPosition(targetPos, relativeTo: nil)
        }

        let m = model.transformMatrix(relativeTo: nil)
        clearScene()
        return m
    }

    func worldMatrixForWallArt(
        transform: simd_float4x4,
        frameSize: FrameSize,
        frameStyle: FrameStyle,
        replacement: FurnitureReplacement
    ) -> simd_float4x4? {
        guard let imageFile = replacement.wallArtImageFile,
              let entity = DecorManager.createWallArtEntity(
                imageFileName: imageFile, frameSize: frameSize, frameStyle: frameStyle
              )
        else { return nil }

        if let yRot = replacement.yRotation {
            entity.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
        }

        clearScene()
        let anchor = AnchorEntity(world: transform)
        let mover = Entity()
        anchor.addChild(mover)
        mover.addChild(entity)
        arView.scene.addAnchor(anchor)

        if let off = replacement.positionOffset, off.count >= 3 {
            let o = transform.columns.3
            let orig = SIMD3<Float>(o.x, o.y, o.z)
            let targetPos = orig + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
            mover.setPosition(targetPos, relativeTo: nil)
        }

        let m = entity.transformMatrix(relativeTo: nil)
        clearScene()
        return m
    }

    func worldMatrixForSimpleDecor(
        transform: simd_float4x4,
        replacement: FurnitureReplacement,
        attach: () -> Entity?
    ) -> simd_float4x4? {
        clearScene()
        guard let content = attach() else { return nil }
        if let yRot = replacement.yRotation {
            content.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
        }

        let anchor = AnchorEntity(world: transform)
        let mover = Entity()
        anchor.addChild(mover)
        mover.addChild(content)
        arView.scene.addAnchor(anchor)

        if let off = replacement.positionOffset, off.count >= 3 {
            let o = transform.columns.3
            let orig = SIMD3<Float>(o.x, o.y, o.z)
            let targetPos = orig + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
            mover.setPosition(targetPos, relativeTo: nil)
        }

        let m = content.transformMatrix(relativeTo: nil)
        clearScene()
        return m
    }
}

// MARK: - Minimal glTF 2.0 writer (single .bin, external PNG textures)

private struct GltfMiniBuilder {
    private var bin = Data()
    private var meshes: [[String: Any]] = []
    private var materials: [[String: Any]] = []
    private var textures: [[String: Any]] = []
    private var images: [[String: Any]] = []
    private var accessors: [[String: Any]] = []
    private var bufferViews: [[String: Any]] = []
    private var nodes: [[String: Any]] = []
    private var nodeChildren: [Int] = []

    mutating func addEmptyNode(name: String, matrix: simd_float4x4) {
        let idx = nodes.count
        nodes.append([
            "name": name,
            "matrix": gltfMatrixArray(matrix)
        ])
        nodeChildren.append(idx)
    }

    mutating func addBox(
        name: String,
        transform: simd_float4x4,
        halfExtents: SIMD3<Float>,
        baseColor: SIMD4<Float>,
        textureRelativePath: String?,
        alphaMode: String = "OPAQUE"
    ) throws {
        var positions: [Float] = []
        var normals: [Float] = []
        var uvs: [Float] = []
        appendUnitCubeFaces(halfExtents: halfExtents, transform: transform, positions: &positions, normals: &normals, uvs: &uvs)

        let vCount = positions.count / 3
        let posMin = minVec(positions)
        let posMax = maxVec(positions)

        alignBin(4)
        let posOffset = bin.count
        positions.withUnsafeBytes { bin.append(contentsOf: $0) }
        alignBin(4)
        let nrmOffset = bin.count
        normals.withUnsafeBytes { bin.append(contentsOf: $0) }
        alignBin(4)
        let uvOffset = bin.count
        uvs.withUnsafeBytes { bin.append(contentsOf: $0) }

        let bvPos = appendBufferView(byteOffset: posOffset, byteLength: positions.count * 4, target: 34962)
        let bvNrm = appendBufferView(byteOffset: nrmOffset, byteLength: normals.count * 4, target: 34962)
        let bvUv = appendBufferView(byteOffset: uvOffset, byteLength: uvs.count * 4, target: 34962)

        let accPos = appendAccessor(bufferView: bvPos, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC3", min: posMin, max: posMax)
        let accNrm = appendAccessor(bufferView: bvNrm, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC3", min: nil, max: nil)
        let accUv = appendAccessor(bufferView: bvUv, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC2", min: nil, max: nil)

        let matIndex: Int
        if let tex = textureRelativePath {
            let imgIndex = images.count
            images.append(["uri": tex])
            let texIndex = textures.count
            textures.append(["source": imgIndex])
            matIndex = materials.count
            materials.append([
                "name": "mat_tex_\(name)",
                "pbrMetallicRoughness": [
                    "baseColorTexture": ["index": texIndex],
                    "metallicFactor": 0,
                    "roughnessFactor": 0.92
                ],
                "alphaMode": alphaMode,
                "doubleSided": true
            ])
        } else {
            matIndex = materials.count
            var pbr: [String: Any] = [
                "baseColorFactor": [Double(baseColor.x), Double(baseColor.y), Double(baseColor.z), Double(baseColor.w)],
                "metallicFactor": 0,
                "roughnessFactor": 0.9
            ]
            materials.append([
                "name": "mat_\(name)",
                "pbrMetallicRoughness": pbr,
                "alphaMode": alphaMode,
                "doubleSided": true
            ])
        }

        let meshIndex = meshes.count
        meshes.append([
            "name": name,
            "primitives": [[
                "attributes": [
                    "POSITION": accPos,
                    "NORMAL": accNrm,
                    "TEXCOORD_0": accUv
                ],
                "indices": try appendTriangleIndices(vertexCount: vCount),
                "material": matIndex
            ]]
        ])

        let nodeIndex = nodes.count
        nodes.append([
            "name": name,
            "mesh": meshIndex
        ])
        nodeChildren.append(nodeIndex)
    }

    mutating func addTexturedVerticalPlane(
        name: String,
        worldMatrix: simd_float4x4,
        width: Float,
        height: Float,
        textureRelativePath: String,
        tint: SIMD4<Float>
    ) throws {
        // Two triangles in X-Y plane (local), normal +Z, then transform to world
        let hx = width * 0.5
        let hy = height * 0.5
        var positions: [Float] = [
            -hx, -hy, 0,  hx, -hy, 0,  hx, hy, 0,
            -hx, -hy, 0,  hx, hy, 0, -hx, hy, 0
        ]
        var normals: [Float] = [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]
        var uvs: [Float] = [0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0]
        let T = worldMatrix
        for i in stride(from: 0, to: positions.count, by: 3) {
            let p = SIMD4<Float>(positions[i], positions[i + 1], positions[i + 2], 1)
            let pw = T * p
            positions[i] = pw.x
            positions[i + 1] = pw.y
            positions[i + 2] = pw.z
            let n = SIMD4<Float>(normals[i], normals[i + 1], normals[i + 2], 0)
            let nw = normalize((T * n).xyz)
            normals[i] = nw.x
            normals[i + 1] = nw.y
            normals[i + 2] = nw.z
        }

        let vCount = 6
        let posMin = minVec(positions)
        let posMax = maxVec(positions)

        alignBin(4)
        let posOffset = bin.count
        positions.withUnsafeBytes { bin.append(contentsOf: $0) }
        alignBin(4)
        let nrmOffset = bin.count
        normals.withUnsafeBytes { bin.append(contentsOf: $0) }
        alignBin(4)
        let uvOffset = bin.count
        uvs.withUnsafeBytes { bin.append(contentsOf: $0) }

        let bvPos = appendBufferView(byteOffset: posOffset, byteLength: positions.count * 4, target: 34962)
        let bvNrm = appendBufferView(byteOffset: nrmOffset, byteLength: normals.count * 4, target: 34962)
        let bvUv = appendBufferView(byteOffset: uvOffset, byteLength: uvs.count * 4, target: 34962)

        let accPos = appendAccessor(bufferView: bvPos, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC3", min: posMin, max: posMax)
        let accNrm = appendAccessor(bufferView: bvNrm, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC3", min: nil, max: nil)
        let accUv = appendAccessor(bufferView: bvUv, byteOffset: 0, componentType: 5126, count: vCount, type: "VEC2", min: nil, max: nil)

        let imgIndex = images.count
        images.append(["uri": textureRelativePath])
        let texIndex = textures.count
        textures.append(["source": imgIndex])
        let matIndex = materials.count
        materials.append([
            "name": "mat_\(name)",
            "pbrMetallicRoughness": [
                "baseColorTexture": ["index": texIndex],
                "baseColorFactor": [Double(tint.x), Double(tint.y), Double(tint.z), Double(tint.w)],
                "metallicFactor": 0,
                "roughnessFactor": 0.85
            ],
            "alphaMode": "OPAQUE",
            "doubleSided": true
        ])

        let meshIndex = meshes.count
        meshes.append([
            "name": name,
            "primitives": [[
                "attributes": [
                    "POSITION": accPos,
                    "NORMAL": accNrm,
                    "TEXCOORD_0": accUv
                ],
                "indices": try appendTriangleIndices(vertexCount: vCount),
                "material": matIndex
            ]]
        ])

        let nodeIndex = nodes.count
        nodes.append(["name": name, "mesh": meshIndex])
        nodeChildren.append(nodeIndex)
    }

    private mutating func alignBin(_ a: Int) {
        while bin.count % a != 0 { bin.append(0) }
    }

    private mutating func appendBufferView(byteOffset: Int, byteLength: Int, target: Int) -> Int {
        let i = bufferViews.count
        bufferViews.append([
            "buffer": 0,
            "byteOffset": byteOffset,
            "byteLength": byteLength,
            "target": target
        ])
        return i
    }

    private mutating func appendAccessor(
        bufferView: Int,
        byteOffset: Int,
        componentType: Int,
        count: Int,
        type: String,
        min: [Float]?,
        max: [Float]?
    ) -> Int {
        let i = accessors.count
        var dict: [String: Any] = [
            "bufferView": bufferView,
            "byteOffset": byteOffset,
            "componentType": componentType,
            "count": count,
            "type": type
        ]
        if let min = min { dict["min"] = min.map { Double($0) } }
        if let max = max { dict["max"] = max.map { Double($0) } }
        accessors.append(dict)
        return i
    }

    private mutating func appendTriangleIndices(vertexCount: Int) throws -> Int {
        guard vertexCount % 3 == 0 else { throw ExportError.invalidMesh }
        var indices: [UInt16] = []
        indices.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            indices.append(UInt16(i))
        }
        alignBin(4)
        let off = bin.count
        indices.withUnsafeBytes { bin.append(contentsOf: $0) }
        let bv = appendBufferView(byteOffset: off, byteLength: indices.count * 2, target: 34963)
        let acc = accessors.count
        accessors.append([
            "bufferView": bv,
            "byteOffset": 0,
            "componentType": 5123,
            "count": indices.count,
            "type": "SCALAR"
        ])
        return acc
    }

    mutating func build(rootName: String) throws -> ([String: Any], Data) {
        alignBin(4)
        let binFinal = bin
        let rootIdx = nodes.count
        nodes.append([
            "name": rootName,
            "children": nodeChildren
        ])
        let gltf: [String: Any] = [
            "asset": ["version": "2.0", "generator": "RoomScanTest"],
            "scene": 0,
            "scenes": [["nodes": [rootIdx]]],
            "nodes": nodes,
            "meshes": meshes,
            "materials": materials,
            "textures": textures,
            "images": images,
            "accessors": accessors,
            "bufferViews": bufferViews,
            "buffers": [[
                "byteLength": binFinal.count,
                "uri": "room_scene.bin"
            ]]
        ]
        return (gltf, binFinal)
    }
}

private enum ExportError: Error {
    case invalidMesh
    case zipFailed
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

private func gltfMatrixArray(_ m: simd_float4x4) -> [Double] {
    let c0 = m.columns.0, c1 = m.columns.1, c2 = m.columns.2, c3 = m.columns.3
    return [
        Double(c0.x), Double(c0.y), Double(c0.z), Double(c0.w),
        Double(c1.x), Double(c1.y), Double(c1.z), Double(c1.w),
        Double(c2.x), Double(c2.y), Double(c2.z), Double(c2.w),
        Double(c3.x), Double(c3.y), Double(c3.z), Double(c3.w)
    ]
}

private func minVec(_ p: [Float]) -> [Float] {
    var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    for i in stride(from: 0, to: p.count, by: 3) {
        mn = min(mn, SIMD3<Float>(p[i], p[i + 1], p[i + 2]))
    }
    return [mn.x, mn.y, mn.z]
}

private func maxVec(_ p: [Float]) -> [Float] {
    var mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for i in stride(from: 0, to: p.count, by: 3) {
        mx = max(mx, SIMD3<Float>(p[i], p[i + 1], p[i + 2]))
    }
    return [mx.x, mx.y, mx.z]
}

/// One box face: outward normal `n`, quad center `c`, tangent half-span `u`, bitangent half-span `v`.
private struct ExportBoxFace {
    let n: SIMD3<Float>
    let c: SIMD3<Float>
    let u: SIMD3<Float>
    let v: SIMD3<Float>
}

/// Generates a triangulated axis-aligned box (36 verts) in world space.
private func appendUnitCubeFaces(
    halfExtents h: SIMD3<Float>,
    transform T: simd_float4x4,
    positions: inout [Float],
    normals: inout [Float],
    uvs: inout [Float]
) {
    let hx = h.x
    let hy = h.y
    let hz = h.z
    let faces: [ExportBoxFace] = [
        ExportBoxFace(n: SIMD3<Float>(1, 0, 0), c: SIMD3<Float>(hx, 0, 0), u: SIMD3<Float>(0, hy, 0), v: SIMD3<Float>(0, 0, hz)),
        ExportBoxFace(n: SIMD3<Float>(-1, 0, 0), c: SIMD3<Float>(-hx, 0, 0), u: SIMD3<Float>(0, hy, 0), v: SIMD3<Float>(0, 0, hz)),
        ExportBoxFace(n: SIMD3<Float>(0, 1, 0), c: SIMD3<Float>(0, hy, 0), u: SIMD3<Float>(hx, 0, 0), v: SIMD3<Float>(0, 0, hz)),
        ExportBoxFace(n: SIMD3<Float>(0, -1, 0), c: SIMD3<Float>(0, -hy, 0), u: SIMD3<Float>(hx, 0, 0), v: SIMD3<Float>(0, 0, hz)),
        ExportBoxFace(n: SIMD3<Float>(0, 0, 1), c: SIMD3<Float>(0, 0, hz), u: SIMD3<Float>(hx, 0, 0), v: SIMD3<Float>(0, hy, 0)),
        ExportBoxFace(n: SIMD3<Float>(0, 0, -1), c: SIMD3<Float>(0, 0, -hz), u: SIMD3<Float>(hx, 0, 0), v: SIMD3<Float>(0, hy, 0))
    ]
    let uvCorners: [(Float, Float)] = [(0, 0), (1, 0), (1, 1), (0, 1)]
    let tris: [(Int, Int, Int)] = [(0, 1, 2), (0, 2, 3)]

    for f in faces {
        let c = f.c
        let u = f.u
        let v = f.v
        let n = f.n
        let p0: SIMD3<Float> = c - u - v
        let p1: SIMD3<Float> = c + u - v
        let p2: SIMD3<Float> = c + u + v
        let p3: SIMD3<Float> = c - u + v
        let corners: [SIMD3<Float>] = [p0, p1, p2, p3]

        let n4 = SIMD4<Float>(n.x, n.y, n.z, 0)
        let nwBase = (T * n4).xyz
        let nw = normalize(nwBase)

        for tri in tris {
            let idx0 = tri.0
            let idx1 = tri.1
            let idx2 = tri.2
            for idx in [idx0, idx1, idx2] {
                let pl = corners[idx]
                let p4 = SIMD4<Float>(pl.x, pl.y, pl.z, 1)
                let pw = (T * p4).xyz
                let uv = uvCorners[idx]
                positions.append(contentsOf: [pw.x, pw.y, pw.z])
                normals.append(contentsOf: [nw.x, nw.y, nw.z])
                uvs.append(contentsOf: [uv.0, uv.1])
            }
        }
    }
}

// MARK: - ZIP (stored / no compression)

private enum ZipStoreArchive {

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let idx = UInt8(truncatingIfNeeded: crc) ^ byte
            crc = crcTable[Int(idx)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func zip(directory root: URL, stripPrefix: String) throws -> Data {
        var entries: [(path: String, data: Data)] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { throw ExportError.zipFailed }

        let base = stripPrefix.hasSuffix("/") ? stripPrefix : stripPrefix + "/"
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            let path = fileURL.path
            guard path.hasPrefix(base) else { continue }
            let rel = String(path.dropFirst(base.count))
            let data = try Data(contentsOf: fileURL)
            entries.append((rel, data))
        }
        return try buildZip(entries: entries)
    }

    private static func buildZip(entries: [(path: String, data: Data)]) throws -> Data {
        var out = Data()
        var central = Data()
        var entryCount: UInt16 = 0

        for entry in entries {
            let pathForZip = entry.path.replacingOccurrences(of: "\\", with: "/")
            guard let nameData = pathForZip.data(using: .utf8), nameData.count < 65_000 else { continue }
            let crc = ZipStoreArchive.crc32(entry.data)
            let localStart = UInt32(out.count)

            // Local file header (30 bytes + name) — version 2.0, store (no compression)
            var lh = Data()
            lh.appendLE(UInt32(0x0403_4B50))
            lh.appendLE(UInt16(20))
            lh.appendLE(UInt16(0))
            lh.appendLE(UInt16(0))
            lh.appendLE(UInt16(0))
            lh.appendLE(UInt16(0))
            lh.appendLE(crc)
            lh.appendLE(UInt32(entry.data.count))
            lh.appendLE(UInt32(entry.data.count))
            lh.appendLE(UInt16(truncatingIfNeeded: nameData.count))
            lh.appendLE(UInt16(0))
            lh.append(nameData)

            out.append(lh)
            out.append(entry.data)

            // Central directory file header (46 bytes + name) — PKZIP 4.4.7
            var ch = Data()
            ch.appendLE(UInt32(0x0201_4B50))
            ch.appendLE(UInt16(0x0314))   // version made by (UNIX, 2.0)
            ch.appendLE(UInt16(20))      // version needed to extract
            ch.appendLE(UInt16(0))       // general purpose bit flag
            ch.appendLE(UInt16(0))       // compression method = store
            ch.appendLE(UInt16(0))       // last mod time
            ch.appendLE(UInt16(0))       // last mod date
            ch.appendLE(crc)
            ch.appendLE(UInt32(entry.data.count))
            ch.appendLE(UInt32(entry.data.count))
            ch.appendLE(UInt16(truncatingIfNeeded: nameData.count))
            ch.appendLE(UInt16(0))       // extra field length
            ch.appendLE(UInt16(0))       // file comment length
            ch.appendLE(UInt16(0))       // disk number start
            ch.appendLE(UInt16(0))       // internal file attributes
            ch.appendLE(UInt32(0))       // external file attributes
            ch.appendLE(localStart)      // relative offset of local file header
            ch.append(nameData)
            central.append(ch)
            entryCount &+= 1
        }

        let centralOffset = UInt32(out.count)
        let centralSize = UInt32(central.count)
        out.append(central)

        // End of central directory record
        var end = Data()
        end.appendLE(UInt32(0x0605_4B50))
        end.appendLE(UInt16(0))        // number of this disk
        end.appendLE(UInt16(0))        // disk where central directory starts
        end.appendLE(entryCount)       // entries on this disk
        end.appendLE(entryCount)       // total entries
        end.appendLE(centralSize)
        end.appendLE(centralOffset)
        end.appendLE(UInt16(0))        // .zip file comment length
        out.append(end)
        return out
    }
}

private extension Data {
    mutating func appendLE(_ v: UInt16) {
        var le = v.littleEndian
        append(Data(bytes: &le, count: 2))
    }
    mutating func appendLE(_ v: UInt32) {
        var le = v.littleEndian
        append(Data(bytes: &le, count: 4))
    }
}
