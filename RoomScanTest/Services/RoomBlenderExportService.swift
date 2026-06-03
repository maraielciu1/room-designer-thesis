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

        let innerName = "\(room.name.sanitizedForPath())_\(room.id.uuidString.prefix(8))"
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
        var manifestItems: [FurnitureManifestItem] = []
        var lightManifestItems: [LightManifestItem] = []

        let arResolver = ExportPoseResolver(catalog: catalog)
        let markerColor = SIMD4<Float>(0.2, 0.92, 0.45, 0.12)

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
                textureRelativePath: texRel,
                unlit: true
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
                textureRelativePath: texRel,
                unlit: true
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
                    try appendFurniturePlacement(
                        destName: destName,
                        world: world,
                        targetDimensions: target,
                        useRealWorldScale: catalog.isScannedModel(rep.replacedWithUSDZ),
                        customScale: rep.customScale.map { Float($0) },
                        markerColor: markerColor,
                        builder: &builder,
                        manifestItems: &manifestItems
                    )
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
                try appendFurniturePlacement(
                    destName: destName,
                    world: world,
                    targetDimensions: defaultDims,
                    useRealWorldScale: catalog.isScannedModel(rep.replacedWithUSDZ),
                    customScale: rep.customScale.map { Float($0) },
                    markerColor: markerColor,
                    builder: &builder,
                    manifestItems: &manifestItems
                )
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

        // ── Lighting: placeholder box + manifest for Blender lights / simple fixture mesh ──
        for rep in room.furnitureReplacements where rep.isLighting {
            guard let xform = rep.getTransformMatrix(),
                  let fixtureRaw = rep.lightFixtureType,
                  let fixtureType = LightFixtureType(rawValue: fixtureRaw)
            else { continue }
            let color: UIColor
            if let rgb = rep.lightColorRGB, rgb.count >= 3 {
                color = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
            } else { color = .white }
            if let (world, half) = arResolver.worldMatrixAndHalfExtentsForDecor(
                transform: xform,
                replacement: rep,
                attach: {
                    DecorManager.createLightFixture(
                        type: fixtureType,
                        color: color,
                        intensity: Float(rep.lightIntensity ?? 3000)
                    )
                }
            ) {
                let placeholder = "lighting_\(rep.id.uuidString.prefix(8))"
                try builder.addBox(
                    name: placeholder,
                    transform: world,
                    halfExtents: half,
                    baseColor: rgbaFloats(color.withAlphaComponent(0.2)),
                    textureRelativePath: nil,
                    alphaMode: "BLEND",
                    unlit: true
                )
                lightManifestItems.append(
                    LightManifestItem(
                        id: String(rep.id.uuidString.prefix(8)),
                        placeholderName: placeholder,
                        fixtureType: fixtureRaw,
                        colorRGB: {
                            let c = rgbaFloats(color)
                            return [Double(c.x), Double(c.y), Double(c.z)]
                        }(),
                        intensity: rep.lightIntensity ?? 3000
                    )
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
            let carpetHalf = isRound
                ? SIMD3<Float>(widthM * 0.5, 0.006, widthM * 0.5)
                : SIMD3<Float>(widthM * 0.5, 0.006, depthM * 0.5)
            if let (world, half) = arResolver.worldMatrixAndHalfExtentsForDecor(
                transform: xform,
                replacement: rep,
                overrideHalfExtents: carpetHalf,
                attach: {
                    DecorManager.createCarpetEntity(
                        widthM: widthM, depthM: depthM,
                        isRound: isRound, color: carpetColor,
                        pattern: carpetPattern
                    )
                }
            ) {
                var carpetTex: String?
                if let png = carpetPatternPNG(
                    pattern: carpetPattern,
                    color: carpetColor,
                    widthM: widthM,
                    depthM: depthM,
                    isRound: isRound
                ) {
                    textureFileCounter += 1
                    let fn = "textures/carpet_\(rep.id.uuidString.prefix(8))_\(textureFileCounter).png"
                    try png.write(to: root.appendingPathComponent(fn))
                    carpetTex = fn
                }
                try builder.addBox(
                    name: "carpet_\(rep.id.uuidString.prefix(8))",
                    transform: world,
                    halfExtents: half,
                    baseColor: rgbaFloats(carpetColor),
                    textureRelativePath: carpetTex,
                    unlit: true
                )
            }
        }

        let manifest = FurnitureManifest(items: manifestItems)
        let manifestData = try JSONEncoder.pretty.encode(manifest)
        try manifestData.write(to: root.appendingPathComponent("furniture_manifest.json"), options: .atomic)

        let sceneManifest = SceneManifest(lights: lightManifestItems)
        let sceneData = try JSONEncoder.pretty.encode(sceneManifest)
        try sceneData.write(to: root.appendingPathComponent("scene_manifest.json"), options: .atomic)

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

        let zipBaseName = exportZipBaseName(roomName: room.name)
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(zipBaseName).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try zipBytes.write(to: zipURL, options: .atomic)
        return zipURL
    }

    private static func appendFurniturePlacement(
        destName: String,
        world: simd_float4x4,
        targetDimensions: SIMD3<Float>,
        useRealWorldScale: Bool,
        customScale: Float?,
        markerColor: SIMD4<Float>,
        builder: inout GltfMiniBuilder,
        manifestItems: inout [FurnitureManifestItem]
    ) throws {
        let id = (destName as NSString).deletingPathExtension
        let markerName = "marker_\(id)"
        try builder.addBox(
            name: markerName,
            transform: world,
            halfExtents: targetDimensions * 0.5,
            baseColor: markerColor,
            textureRelativePath: nil,
            alphaMode: "BLEND",
            unlit: true
        )
        manifestItems.append(
            FurnitureManifestItem(
                id: id,
                usdz: "furniture/\(destName)",
                markerName: markerName,
                targetDimensions: [
                    Double(targetDimensions.x),
                    Double(targetDimensions.y),
                    Double(targetDimensions.z)
                ],
                useRealWorldScale: useRealWorldScale,
                customScale: customScale.map { Double($0) }
            )
        )
    }

    private static let blenderApplyFurnitureScriptUTF8 = """
    # RoomScanTest — finalize Blender scene after importing room_scene.gltf
    #
    # 1) File -> Import -> glTF 2.0: room_scene.gltf
    # 2) Scripting -> open this file -> Run Script
    #
    # - Aligns USDZ furniture to green marker_* (bottom sits on marker floor)
    # - Replaces lighting_* placeholders with real lights + simple fixture meshes
    # - Fades marker_* / lighting_* guide meshes

    import json
    import os
    import bpy
    import bmesh
    from mathutils import Vector, Matrix

    MARKER_PREFIX = "marker_"

    def script_dir():
        txt = bpy.context.space_data.text if bpy.context.space_data else None
        if txt and txt.filepath:
            return os.path.dirname(bpy.path.abspath(txt.filepath))
        if bpy.data.filepath:
            return os.path.dirname(bpy.path.abspath(bpy.data.filepath))
        return os.getcwd()

    def resolve_path(base, rel):
        return os.path.normpath(os.path.join(base, rel))

    def find_object(name):
        obj = bpy.data.objects.get(name)
        if obj:
            return obj
        for o in bpy.data.objects:
            if o.name.split(".")[0] == name:
                return o
        return None

    def mesh_world_bounds(mesh_objects):
        corners = []
        for o in mesh_objects:
            if o.type != "MESH":
                continue
            for c in o.bound_box:
                corners.append(o.matrix_world @ Vector(c))
        if not corners:
            z = Vector((0, 0, 0))
            return z, Vector((1, 1, 1)), z, z
        xs = [c.x for c in corners]
        ys = [c.y for c in corners]
        zs = [c.z for c in corners]
        bmin = Vector((min(xs), min(ys), min(zs)))
        bmax = Vector((max(xs), max(ys), max(zs)))
        center = (bmin + bmax) * 0.5
        size = bmax - bmin
        return center, size, bmin, bmax

    def roots_of(objs):
        s = set(objs)
        return [o for o in objs if o.parent not in s]

    def import_usdz(filepath):
        if not hasattr(bpy.ops.wm, "usd_import"):
            raise RuntimeError("USD importer not available (enable USD add-on)")
        before = set(bpy.data.objects)
        bpy.ops.wm.usd_import(filepath=filepath)
        return [o for o in bpy.data.objects if o not in before]

    def parent_preserve_world(child, parent):
        mw = child.matrix_world.copy()
        child.parent = parent
        child.matrix_world = mw

    def align_to_marker(imported_roots, marker_obj, use_real_scale, custom_scale, align_mode):
        group = bpy.data.objects.new("FURN_" + marker_obj.name, None)
        bpy.context.scene.collection.objects.link(group)
        group.matrix_world = Matrix.Identity(4)

        for r in imported_roots:
            parent_preserve_world(r, group)

        bpy.context.view_layer.update()
        meshes = [o for o in group.children_recursive if o.type == "MESH"]
        _, g_size, _, _ = mesh_world_bounds(meshes)
        _, m_size, _, m_max = mesh_world_bounds([marker_obj])

        if not use_real_scale:
            sx = m_size.x / g_size.x if g_size.x > 1e-5 else 1.0
            sy = m_size.y / g_size.y if g_size.y > 1e-5 else 1.0
            sz = m_size.z / g_size.z if g_size.z > 1e-5 else 1.0
            uniform = min(sx, sy, sz) * 0.92
            if custom_scale:
                uniform *= float(custom_scale)
            group.scale = (group.scale.x * uniform, group.scale.y * uniform, group.scale.z * uniform)

        bpy.context.view_layer.update()
        meshes = [o for o in group.children_recursive if o.type == "MESH"]
        g_center, _, g_min, _ = mesh_world_bounds(meshes)
        m_center, _, m_min, _ = mesh_world_bounds([marker_obj])

        if align_mode == "bottom":
            delta = Vector((m_center.x - g_center.x, m_center.y - g_center.y, m_min.z - g_min.z))
        else:
            delta = m_center - g_center
        group.matrix_world = Matrix.Translation(delta) @ group.matrix_world

    def remove_objects_by_prefix(prefixes):
        to_remove = []
        for o in list(bpy.data.objects):
            base = o.name.split(".")[0]
            for p in prefixes:
                if base.startswith(p):
                    to_remove.append(o)
                    break
        for o in to_remove:
            bpy.data.objects.remove(o, do_unlink=True)

    def disable_viewport_bounds():
        for o in bpy.data.objects:
            o.show_bounds = False
            if o.display_type == "WIRE":
                o.display_type = "TEXTURED"

    def make_mat(name, rgba, emission=False):
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = rgba
            bsdf.inputs["Roughness"].default_value = 0.55
            if emission:
                bsdf.inputs["Emission Color"].default_value = rgba[:3] + (1.0,)
                bsdf.inputs["Emission Strength"].default_value = 2.5
        return mat

    def add_cylinder(name, radius, depth, location, mat):
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20,
                              radius1=radius, radius2=radius, depth=depth)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        if mat:
            obj.data.materials.append(mat)
        return obj

    def add_sphere(name, radius, location, mat):
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=radius)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        if mat:
            obj.data.materials.append(mat)
        return obj

    def intensity_to_watts(value):
        return max(8.0, float(value) * 0.2)

    def add_box(name, sx, sy, sz, location, mat):
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        if mat:
            obj.data.materials.append(mat)
        return obj

    def build_fixture_mesh(fixture_type, color, center, bmin, bmax, uid):
        import math
        cx, cy = center.x, center.y
        cz_top = bmax.z
        cz_floor = bmin.z
        pfx = "FIX_" + str(uid) + "_"
        metal = make_mat(pfx + "metal", (0.22, 0.22, 0.24, 1.0))
        gold = make_mat(pfx + "gold", (0.76, 0.60, 0.32, 1.0))
        bulb = make_mat(pfx + "bulb", (*color[:3], 1.0), emission=True)
        ft = (fixture_type or "").strip()

        if ft == "Floor Lamp":
            # Match DecorManager floorLamp: base at floor, pole 1.5m, shade on top
            add_cylinder(pfx + "base", 0.14, 0.02, (cx, cy, cz_floor + 0.01), metal)
            add_cylinder(pfx + "pole", 0.012, 1.50, (cx, cy, cz_floor + 0.77), metal)
            add_cylinder(pfx + "shade", 0.16, 0.22, (cx, cy, cz_floor + 1.56), bulb)
            return
        elif ft == "Wall Sconce":
            add_box(pfx + "plate", 0.06, 0.10, 0.02, (cx, cy, center.z), metal)
            add_cylinder(pfx + "arm", 0.006, 0.08, (cx, cy + 0.05, center.z), metal)
            add_sphere(pfx + "globe", 0.06, (cx, cy + 0.10, center.z), bulb)
        elif ft == "Ceiling Flush":
            add_cylinder(pfx + "rim", 0.19, 0.05, (cx, cy, cz_top - 0.025), metal)
            add_cylinder(pfx + "disc", 0.18, 0.04, (cx, cy, cz_top - 0.04), bulb)
        elif ft == "Chandelier":
            add_cylinder(pfx + "canopy", 0.05, 0.02, (cx, cy, cz_top - 0.01), metal)
            add_cylinder(pfx + "rod", 0.008, 0.25, (cx, cy, cz_top - 0.14), gold)
            add_sphere(pfx + "hub", 0.04, (cx, cy, cz_top - 0.28), gold)
            arm_len = 0.18
            hub_z = cz_top - 0.28
            for i in range(6):
                ang = i * (2.0 * math.pi / 6.0)
                bx = cx + math.cos(ang) * arm_len
                by = cy + math.sin(ang) * arm_len
                add_cylinder(pfx + "arm" + str(i), 0.005, arm_len, ((cx + bx) * 0.5, (cy + by) * 0.5, hub_z), gold)
                add_sphere(pfx + "bulb" + str(i), 0.025, (bx, by, hub_z), bulb)
        elif ft == "Pendant Drum":
            add_cylinder(pfx + "canopy", 0.06, 0.02, (cx, cy, cz_top - 0.01), metal)
            add_cylinder(pfx + "rod", 0.004, 0.25, (cx, cy, cz_top - 0.14), metal)
            add_cylinder(pfx + "shade", 0.14, 0.18, (cx, cy, cz_top - 0.35), bulb)
        else:
            # Pendant Globe (default)
            add_cylinder(pfx + "canopy", 0.06, 0.02, (cx, cy, cz_top - 0.01), metal)
            add_cylinder(pfx + "rod", 0.004, 0.35, (cx, cy, cz_top - 0.19), metal)
            add_sphere(pfx + "globe", 0.10, (cx, cy, cz_top - 0.36), bulb)

    def apply_scene_lights(base):
        path = resolve_path(base, "scene_manifest.json")
        if not os.path.isfile(path):
            print("No scene_manifest.json (skip lights).")
            return
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        lights = data.get("lights", [])
        for item in lights:
            ph = item.get("placeholderName", "")
            placeholder = find_object(ph)
            if placeholder is None:
                print("Skip light", item.get("id"), "-> placeholder not found:", ph)
                continue
            center, size, bmin, bmax = mesh_world_bounds([placeholder])
            rgb = item.get("colorRGB", [1.0, 1.0, 1.0])
            color = (float(rgb[0]), float(rgb[1]), float(rgb[2]))
            watts = intensity_to_watts(item.get("intensity", 3000))
            ft = item.get("fixtureType", "")

            loc = center.copy()
            if ft == "Floor Lamp":
                loc = Vector((center.x, center.y, bmin.z + 1.55))
            elif ft == "Wall Sconce":
                loc = center
            elif ft == "Ceiling Flush":
                loc.z = bmax.z - 0.06
            elif "Chandelier" in ft or "Pendant" in ft:
                loc.z = bmax.z - 0.36
            else:
                loc.z = bmax.z - size.z * 0.12

            light_data = bpy.data.lights.new(name="LT_" + str(item.get("id", ph)), type="POINT")
            light_data.color = color
            light_data.energy = watts
            light_data.shadow_soft_size = 0.15
            light_obj = bpy.data.objects.new(light_data.name, light_data)
            bpy.context.scene.collection.objects.link(light_obj)
            light_obj.location = loc

            build_fixture_mesh(ft, color, center, bmin, bmax, item.get("id", ph))
            bpy.data.objects.remove(placeholder, do_unlink=True)
            print("Light + fixture:", ph, "->", ft, watts, "W")

    def ensure_sun():
        for o in bpy.data.objects:
            if o.type == "LIGHT" and o.data.type == "SUN":
                return
        sun_data = bpy.data.lights.new(name="RoomScanTest_Sun", type="SUN")
        sun_data.energy = 2.5
        sun_obj = bpy.data.objects.new("RoomScanTest_Sun", sun_data)
        bpy.context.scene.collection.objects.link(sun_obj)
        sun_obj.rotation_euler = (0.9, 0.1, 0.6)

    def apply_furniture(base):
        manifest_path = resolve_path(base, "furniture_manifest.json")
        if not os.path.isfile(manifest_path):
            print("No furniture_manifest.json")
            return
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        items = manifest.get("items", [])
        for item in items:
            marker_name = item.get("markerName", "")
            marker = find_object(marker_name)
            if marker is None:
                print("Skip", item.get("id"), "-> marker not found:", marker_name)
                continue
            usdz_path = resolve_path(base, item.get("usdz", ""))
            if not os.path.isfile(usdz_path):
                print("Skip", item.get("id"), "-> missing", usdz_path)
                continue
            try:
                imported = import_usdz(usdz_path)
            except Exception as ex:
                print("Skip", item.get("id"), "->", ex)
                continue
            roots = roots_of(imported)
            if not roots:
                continue
            align_to_marker(
                roots, marker,
                bool(item.get("useRealWorldScale", False)),
                item.get("customScale"),
                item.get("alignMode", "bottom"),
            )
            print("Aligned", os.path.basename(usdz_path), "->", marker_name)

    def main():
        base = script_dir()
        if not any(o.type == "MESH" for o in bpy.data.objects):
            print("Import room_scene.gltf first, then run this script.")
            return
        ensure_sun()
        apply_furniture(base)
        apply_scene_lights(base)
        remove_objects_by_prefix([MARKER_PREFIX])
        disable_viewport_bounds()
        print("Done. Guide markers removed; fixtures and furniture kept.")

    main()
    """

    private static func readmeText(innerFolderName: String) -> String {
        """
        Room export for Blender / 3D tools
        ===================================

        1. Unzip this archive. Open the folder "\(innerFolderName)".

        2. Import the room: File → Import → glTF 2.0 — pick "room_scene.gltf".
           Keep "room_scene.bin", "textures/", and "wall_art/" beside it (same layout as this folder).

        3. Open Scripting and run "blender_apply_furniture.py" from this folder.
           • Imports each USDZ and places it on the bottom of the matching green marker_* box.
           • Replaces lighting_* placeholders with point lights + fixture meshes (pendant, floor lamp, etc.).
           • Deletes green marker_* guide boxes when finished (no black wireframes).
           • Wall/floor colours and patterns use glTF unlit materials.

        4. Switch viewport shading to Material Preview or Rendered to see colours/textures.
           USDZ furniture materials come from the USD importer (enable the USD add-on).

        5. Units are metres.

        Generated by RoomScanTest.
        """
    }

    // MARK: - Helpers

    /// e.g. `LivingRoom_BlenderExport_2026-05-15_14-30-00`
    private static func exportZipBaseName(roomName: String, date: Date = Date()) -> String {
        let roomPart = roomName.sanitizedForPath()
        return "\(roomPart)_BlenderExport_\(exportDateStamp(date))"
    }

    private static func exportDateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    private static func clampDims(_ d: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(max(d.x, 0.01), max(d.y, 0.01), max(d.z, 0.01))
    }

    /// Procedural carpet top-down texture for Blender (solid / stripes / geometric).
    private static func carpetPatternPNG(
        pattern: CarpetPattern,
        color: UIColor,
        widthM: Float,
        depthM: Float,
        isRound: Bool
    ) -> Data? {
        let ppm: CGFloat = 96
        let w = min(max(Int(CGFloat(widthM) * ppm), 64), 512)
        let h = min(max(Int(CGFloat(depthM) * ppm), 64), 512)
        let size = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let accent = color.withAlphaComponent(0.55)
        accent.setFill()
        switch pattern {
        case .solid:
            break
        case .striped:
            let stripeH = max(size.height / 7, 4)
            for i in 0..<6 where i % 2 == 0 {
                ctx.fill(CGRect(x: 0, y: CGFloat(i) * stripeH, width: size.width, height: stripeH))
            }
        case .geometric, .oriental, .herringbone:
            let inset = min(size.width, size.height) * 0.18
            ctx.fill(CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2))
        case .shaggy:
            let inset = min(size.width, size.height) * 0.1
            ctx.fill(CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2))
        }
        if isRound {
            ctx.setBlendMode(.destinationIn)
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img?.pngData()
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

// MARK: - Furniture manifest (Blender alignment)

private struct FurnitureManifest: Encodable {
    let version: Int
    let items: [FurnitureManifestItem]

    init(items: [FurnitureManifestItem]) {
        version = 1
        self.items = items
    }
}

private struct FurnitureManifestItem: Encodable {
    let id: String
    let usdz: String
    let markerName: String
    let targetDimensions: [Double]
    let useRealWorldScale: Bool
    let customScale: Double?
    let alignMode: String

    init(
        id: String,
        usdz: String,
        markerName: String,
        targetDimensions: [Double],
        useRealWorldScale: Bool,
        customScale: Double?
    ) {
        self.id = id
        self.usdz = usdz
        self.markerName = markerName
        self.targetDimensions = targetDimensions
        self.useRealWorldScale = useRealWorldScale
        self.customScale = customScale
        alignMode = "bottom"
    }
}

private struct SceneManifest: Encodable {
    let version: Int
    let lights: [LightManifestItem]

    init(lights: [LightManifestItem]) {
        version = 1
        self.lights = lights
    }
}

private struct LightManifestItem: Encodable {
    let id: String
    let placeholderName: String
    let fixtureType: String
    let colorRGB: [Double]
    let intensity: Double
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
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

    /// World matrix and half-extents for decor (lighting, carpet).
    /// Translation is taken from world-space `visualBounds.center` so floor-anchored items
    /// (carpet, floor lamp) are not shifted — the stored transform is often at floor level
    /// while the mesh extends upward.
    func worldMatrixAndHalfExtentsForDecor(
        transform: simd_float4x4,
        replacement: FurnitureReplacement,
        overrideHalfExtents: SIMD3<Float>? = nil,
        attach: () -> Entity?
    ) -> (simd_float4x4, SIMD3<Float>)? {
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

        let bounds = content.visualBounds(relativeTo: nil)
        var m = content.transformMatrix(relativeTo: nil)
        let c = bounds.center
        m.columns.3 = SIMD4<Float>(c.x, c.y, c.z, 1)

        let rawHalf = overrideHalfExtents ?? (bounds.extents * 0.5)
        let clamped = SIMD3<Float>(
            max(rawHalf.x, 0.02),
            max(rawHalf.y, 0.006),
            max(rawHalf.z, 0.02)
        )
        clearScene()
        return (m, clamped)
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
    private var usesUnlitExtension = false

    private mutating func markUnlit(_ enabled: Bool) {
        if enabled { usesUnlitExtension = true }
    }

    private func unlitExtensions(_ enabled: Bool) -> [String: Any]? {
        enabled ? ["KHR_materials_unlit": [:] as [String: Any]] : nil
    }

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
        alphaMode: String = "OPAQUE",
        unlit: Bool = false
    ) throws {
        markUnlit(unlit)
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
            var mat: [String: Any] = [
                "name": "mat_tex_\(name)",
                "pbrMetallicRoughness": [
                    "baseColorTexture": ["index": texIndex],
                    "baseColorFactor": [1.0, 1.0, 1.0, Double(baseColor.w)],
                    "metallicFactor": 0,
                    "roughnessFactor": 0.92
                ],
                "alphaMode": alphaMode,
                "doubleSided": true
            ]
            if let ext = unlitExtensions(unlit) { mat["extensions"] = ext }
            matIndex = materials.count
            materials.append(mat)
        } else {
            let pbr: [String: Any] = [
                "baseColorFactor": [Double(baseColor.x), Double(baseColor.y), Double(baseColor.z), Double(baseColor.w)],
                "metallicFactor": 0,
                "roughnessFactor": 0.9
            ]
            var mat: [String: Any] = [
                "name": "mat_\(name)",
                "pbrMetallicRoughness": pbr,
                "alphaMode": alphaMode,
                "doubleSided": true
            ]
            if let ext = unlitExtensions(unlit) { mat["extensions"] = ext }
            matIndex = materials.count
            materials.append(mat)
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
        tint: SIMD4<Float>,
        unlit: Bool = true
    ) throws {
        markUnlit(unlit)
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
        var mat: [String: Any] = [
            "name": "mat_\(name)",
            "pbrMetallicRoughness": [
                "baseColorTexture": ["index": texIndex],
                "baseColorFactor": [Double(tint.x), Double(tint.y), Double(tint.z), Double(tint.w)],
                "metallicFactor": 0,
                "roughnessFactor": 0.85
            ],
            "alphaMode": "OPAQUE",
            "doubleSided": true
        ]
        if let ext = unlitExtensions(unlit) { mat["extensions"] = ext }
        let matIndex = materials.count
        materials.append(mat)

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

        var samplers: [[String: Any]] = []
        if !textures.isEmpty {
            samplers.append([
                "magFilter": 9729,
                "minFilter": 9987,
                "wrapS": 10497,
                "wrapT": 10497
            ])
            textures = textures.map { tex in
                var t = tex
                t["sampler"] = 0
                return t
            }
        }

        var gltf: [String: Any] = [
            "asset": ["version": "2.0", "generator": "RoomScanTest"],
            "scene": 0,
            "scenes": [["nodes": [rootIdx]]],
            "nodes": nodes,
            "meshes": meshes,
            "materials": materials,
            "accessors": accessors,
            "bufferViews": bufferViews,
            "buffers": [[
                "byteLength": binFinal.count,
                "uri": "room_scene.bin"
            ]]
        ]
        if !textures.isEmpty {
            gltf["textures"] = textures
            gltf["images"] = images
            gltf["samplers"] = samplers
        }
        if usesUnlitExtension {
            gltf["extensionsUsed"] = ["KHR_materials_unlit"]
        }
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
