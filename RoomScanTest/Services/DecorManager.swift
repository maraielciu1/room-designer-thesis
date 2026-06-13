//
//  DecorManager.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//
//  Manages wall-art image persistence on disk
//  and builds RealityKit entities for wall art & lighting fixtures.
//

import Foundation
import UIKit
import RealityKit

enum DecorManager {

    // MARK: - Wall Art — Image I/O

    static var wallArtDirectory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WallArt", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    static func saveImage(_ image: UIImage, id: UUID = UUID()) -> String? {
        // Normalise orientation before encoding so the saved JPEG
        // pixels are always in the correct visual order (no EXIF rotation).
        let normalised: UIImage
        if image.imageOrientation != .up {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: image.size, format: fmt)
            normalised = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        } else {
            normalised = image
        }

        let fileName = "\(id.uuidString).jpg"
        let url = wallArtDirectory.appendingPathComponent(fileName)
        guard let data = normalised.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            print("[DecorManager] save image error: \(error)")
            return nil
        }
    }

    static func loadImage(named fileName: String) -> UIImage? {
        let url = wallArtDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func deleteImage(named fileName: String) {
        let url = wallArtDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Wall Art — Entity Builder

    /// Returns a RealityKit entity tree: frame (box) + canvas (plane with photo).
    static func createWallArtEntity(
        imageFileName: String,
        frameSize: FrameSize,
        frameStyle: FrameStyle
    ) -> Entity? {
        guard let rawImage = loadImage(named: imageFileName) else { return nil }

        // Normalise EXIF orientation so the CGImage pixels match
        // what the user sees — prevents portrait photos appearing rotated.
        let image: UIImage
        if rawImage.imageOrientation != .up {
            // Force scale 1.0 so the bitmap keeps the original pixel
            // dimensions instead of multiplying by screen-scale (2×/3×),
            // which would exceed GPU texture limits and silently fail.
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: rawImage.size, format: fmt)
            image = renderer.image { _ in
                rawImage.draw(in: CGRect(origin: .zero, size: rawImage.size))
            }
        } else {
            image = rawImage
        }
        guard let cgImage = image.cgImage else { return nil }

        let container = Entity()
        container.name = "__wallArt__"

        let artW  = frameSize.widthM
        let artH  = frameSize.heightM
        let border = frameStyle.borderWidthM
        let depth  = frameStyle.frameDepthM

        // ── Frame panel ──
        if frameStyle != .noFrame {
            let fw = artW + border * 2
            let fh = artH + border * 2
            let frameMesh = MeshResource.generateBox(
                width: fw, height: fh, depth: depth, cornerRadius: 0)

            let frameMat = SimpleMaterial(
                color: frameStyle.frameColor,
                isMetallic: frameStyle.isMetallic)

            let frameEntity = ModelEntity(
                mesh: frameMesh, materials: [frameMat])
            frameEntity.name = "frame"
            container.addChild(frameEntity)
        }

        // Canvas (photo texture on a vertical plane)
        let canvasMesh = MeshResource.generatePlane(
            width: artW, height: artH)

        if let texture = try? TextureResource(
            image: cgImage, options: .init(semantic: .color)) {
            var mat = UnlitMaterial()
            mat.color = .init(tint: .white, texture: .init(texture))

            let canvas = ModelEntity(mesh: canvasMesh, materials: [mat])
            canvas.name = "canvas"
            // Place slightly in front of the frame back panel
            canvas.position.z = depth / 2 + 0.001
            container.addChild(canvas)
        }

        return container
    }

    // MARK: - Lighting — Entity Builder

    static func createLightFixture(
        type: LightFixtureType,
        color: UIColor = .white,
        intensity: Float = 3000
    ) -> Entity {
        switch type {
        case .pendantGlobe:  return pendantGlobe(color: color, intensity: intensity)
        case .pendantDrum:   return pendantDrum(color: color, intensity: intensity)
        case .chandelier:    return chandelier(color: color, intensity: intensity)
        case .ceilingFlush:  return ceilingFlush(color: color, intensity: intensity)
        case .wallSconce:    return wallSconce(color: color, intensity: intensity)
        case .floorLamp:     return floorLamp(color: color, intensity: intensity)
        }
    }

    // Pendant Globe

    private static func pendantGlobe(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"
        let metalMat = SimpleMaterial(color: .darkGray, isMetallic: true)

        // Canopy (ceiling mount plate)
        let canopy = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.06),
            materials: [metalMat])
        canopy.position.y = 0
        root.addChild(canopy)

        // Rod
        let rod = ModelEntity(
            mesh: .generateCylinder(height: 0.35, radius: 0.004),
            materials: [metalMat])
        rod.position.y = -0.175 - 0.01   // hanging below canopy
        root.addChild(rod)

        // Globe
        let globe = ModelEntity(
            mesh: .generateSphere(radius: 0.10),
            materials: [UnlitMaterial(color: color.withAlphaComponent(0.92))])
        globe.name = "bulb"
        globe.position.y = -0.35 - 0.01
        root.addChild(globe)

        // PointLight
        let light = pointLight(color: color, intensity: intensity)
        light.position.y = -0.36
        root.addChild(light)

        return root
    }

    // Pendant Drum

    private static func pendantDrum(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"
        let metalMat = SimpleMaterial(color: .darkGray, isMetallic: true)

        // Canopy
        let canopy = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.06),
            materials: [metalMat])
        root.addChild(canopy)

        // Rod
        let rod = ModelEntity(
            mesh: .generateCylinder(height: 0.25, radius: 0.004),
            materials: [metalMat])
        rod.position.y = -0.135
        root.addChild(rod)

        // Drum shade (short cylinder)
        let shadeMat = SimpleMaterial(
            color: color.withAlphaComponent(0.85), isMetallic: false)
        let shade = ModelEntity(
            mesh: .generateCylinder(height: 0.18, radius: 0.14),
            materials: [shadeMat])
        shade.name = "bulb"
        shade.position.y = -0.35
        root.addChild(shade)

        // PointLight
        let light = pointLight(color: color, intensity: intensity)
        light.position.y = -0.38
        root.addChild(light)

        return root
    }

    // Chandelier

    private static func chandelier(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"
        let metalMat = SimpleMaterial(color: UIColor(white: 0.25, alpha: 1), isMetallic: true)
        let goldMat  = SimpleMaterial(
            color: UIColor(red: 0.76, green: 0.60, blue: 0.32, alpha: 1), isMetallic: true)

        // Canopy
        let canopy = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.05),
            materials: [metalMat])
        root.addChild(canopy)

        // Central rod
        let rod = ModelEntity(
            mesh: .generateCylinder(height: 0.25, radius: 0.008),
            materials: [goldMat])
        rod.position.y = -0.135
        root.addChild(rod)

        // Hub
        let hub = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [goldMat])
        hub.position.y = -0.27
        root.addChild(hub)

        // Arms + bulbs (6 arms)
        let armCount = 6
        let armLength: Float = 0.18
        let bulbMat = UnlitMaterial(color: color.withAlphaComponent(0.9))

        for i in 0..<armCount {
            let angle = Float(i) * (.pi * 2 / Float(armCount))
            let dx = cos(angle) * armLength / 2
            let dz = sin(angle) * armLength / 2

            // Arm
            let arm = ModelEntity(
                mesh: .generateCylinder(height: armLength, radius: 0.005),
                materials: [goldMat])
            arm.position = [dx, -0.27, dz]
            arm.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                * simd_quatf(angle: angle, axis: [0, 1, 0])
            root.addChild(arm)

            // Bulb at tip
            let bulb = ModelEntity(
                mesh: .generateSphere(radius: 0.025),
                materials: [bulbMat])
            bulb.name = "bulb"
            bulb.position = [cos(angle) * armLength, -0.27, sin(angle) * armLength]
            root.addChild(bulb)
        }

        // PointLight at center
        let light = pointLight(color: color, intensity: intensity * 1.5)
        light.position.y = -0.30
        root.addChild(light)

        return root
    }

    //  Ceiling Flush

    private static func ceilingFlush(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"

        // Flat disc
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.04, radius: 0.18),
            materials: [UnlitMaterial(color: color.withAlphaComponent(0.88))])
        disc.name = "bulb"
        disc.position.y = -0.02
        root.addChild(disc)

        // Thin rim
        let rim = ModelEntity(
            mesh: .generateCylinder(height: 0.05, radius: 0.19),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: true)])
        rim.position.y = -0.025
        root.addChild(rim)

        let light = pointLight(color: color, intensity: intensity)
        light.position.y = -0.06
        root.addChild(light)

        return root
    }

    // Wall Sconce

    private static func wallSconce(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"
        let metalMat = SimpleMaterial(color: .darkGray, isMetallic: true)

        // Mounting plate
        let plate = ModelEntity(
            mesh: .generateBox(width: 0.06, height: 0.10, depth: 0.02),
            materials: [metalMat])
        root.addChild(plate)

        // Arm
        let arm = ModelEntity(
            mesh: .generateCylinder(height: 0.08, radius: 0.006),
            materials: [metalMat])
        arm.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        arm.position.z = 0.05
        root.addChild(arm)

        // Globe
        let globe = ModelEntity(
            mesh: .generateSphere(radius: 0.06),
            materials: [UnlitMaterial(color: color.withAlphaComponent(0.90))])
        globe.name = "bulb"
        globe.position.z = 0.10
        root.addChild(globe)

        let light = pointLight(color: color, intensity: intensity * 0.6)
        light.position.z = 0.11
        root.addChild(light)

        return root
    }

    // Floor Lamp

    private static func floorLamp(color: UIColor, intensity: Float) -> Entity {
        let root = Entity(); root.name = "__lighting__"
        let metalMat = SimpleMaterial(color: UIColor(white: 0.20, alpha: 1), isMetallic: true)

        // Base
        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.14),
            materials: [metalMat])
        base.position.y = 0.01
        root.addChild(base)

        // Pole
        let pole = ModelEntity(
            mesh: .generateCylinder(height: 1.50, radius: 0.012),
            materials: [metalMat])
        pole.position.y = 0.77
        root.addChild(pole)

        // Shade (drum)
        let shadeMat = SimpleMaterial(
            color: color.withAlphaComponent(0.80), isMetallic: false)
        let shade = ModelEntity(
            mesh: .generateCylinder(height: 0.22, radius: 0.16),
            materials: [shadeMat])
        shade.name = "bulb"
        shade.position.y = 1.56
        root.addChild(shade)

        // PointLight
        let light = pointLight(color: color, intensity: intensity)
        light.position.y = 1.55
        root.addChild(light)

        return root
    }

    // MARK: - Carpet / Rug — Entity Builder

    /// Returns a carpet entity: a flat box (or cylinder for round) textured with the chosen colour & pattern.
    static func createCarpetEntity(
        widthM: Float,
        depthM: Float,
        isRound: Bool,
        color: UIColor,
        pattern: CarpetPattern
    ) -> Entity {
        let container = Entity()
        container.name = "__carpet__"

        // Carpet pile thickness
        let thickness: Float = 0.012

        // Material — slightly rough, never metallic
        var baseMat = SimpleMaterial(
            color: color, isMetallic: false)
        baseMat.roughness = .float(0.85)

        if isRound {
            let radius = widthM / 2
            let mesh = MeshResource.generateCylinder(
                height: thickness, radius: radius)
            let carpet = ModelEntity(mesh: mesh, materials: [baseMat])
            carpet.name = "carpetBody"
            carpet.position.y = thickness / 2
            container.addChild(carpet)
        } else {
            let mesh = MeshResource.generateBox(
                width: widthM, height: thickness, depth: depthM,
                cornerRadius: 0.005)
            let carpet = ModelEntity(mesh: mesh, materials: [baseMat])
            carpet.name = "carpetBody"
            carpet.position.y = thickness / 2
            container.addChild(carpet)
        }

        // Add a subtle pattern overlay stripe / detail via additional geometry
        addPatternDetail(to: container, width: widthM, depth: depthM,
                         isRound: isRound, color: color, pattern: pattern,
                         thickness: thickness)

        return container
    }

    /// Adds simple geometric detail on top of the carpet body to suggest a pattern.
    private static func addPatternDetail(
        to container: Entity,
        width: Float, depth: Float,
        isRound: Bool, color: UIColor,
        pattern: CarpetPattern, thickness: Float
    ) {
        let detailY: Float = thickness + 0.001
        // Slightly darker accent of the base colour
        let accentColor = color.withAlphaComponent(0.5)
        let accentMat = SimpleMaterial(color: accentColor, isMetallic: false)

        switch pattern {
        case .solid:
            break  // no extra detail

        case .striped:
            // A few thin stripe bars
            let stripeCount = 5
            let stripeW: Float = width * 0.06
            let spacing = depth / Float(stripeCount + 1)
            for i in 1...stripeCount {
                let stripe = ModelEntity(
                    mesh: .generateBox(width: width * 0.85, height: 0.002, depth: stripeW),
                    materials: [accentMat])
                stripe.position = [0, detailY,
                                   -depth / 2 + spacing * Float(i)]
                container.addChild(stripe)
            }

        case .geometric:
            // Diamond shape in centre
            let dimSize = min(width, depth) * 0.35
            let diamond = ModelEntity(
                mesh: .generateBox(width: dimSize, height: 0.002, depth: dimSize),
                materials: [accentMat])
            diamond.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
            diamond.position.y = detailY
            container.addChild(diamond)

        case .shaggy:
            // Concentric ring/border
            let borderW: Float = 0.03
            let inner = ModelEntity(
                mesh: .generateBox(width: width - borderW * 4,
                                   height: 0.003,
                                   depth: depth - borderW * 4),
                materials: [accentMat])
            inner.position.y = detailY
            container.addChild(inner)

        case .oriental:
            // Border frame + central medallion (small disc)
            let borderFrame = ModelEntity(
                mesh: .generateBox(width: width * 0.92, height: 0.002,
                                   depth: depth * 0.92),
                materials: [accentMat])
            borderFrame.position.y = detailY
            container.addChild(borderFrame)

            let centerMat = SimpleMaterial(color: color, isMetallic: false)
            let center = ModelEntity(
                mesh: .generateBox(width: width * 0.82, height: 0.003,
                                   depth: depth * 0.82),
                materials: [centerMat])
            center.position.y = detailY + 0.001
            container.addChild(center)

            let medallion = ModelEntity(
                mesh: .generateCylinder(height: 0.003,
                                        radius: min(width, depth) * 0.15),
                materials: [accentMat])
            medallion.position.y = detailY + 0.002
            container.addChild(medallion)

        case .herringbone:
            // Diagonal stripes both ways
            let barCount = 4
            let barW: Float = 0.02
            let span = min(width, depth) * 0.7
            let spacing = span / Float(barCount)
            for i in 0..<barCount {
                let offset = -span / 2 + spacing * (Float(i) + 0.5)
                let barA = ModelEntity(
                    mesh: .generateBox(width: span * 0.6, height: 0.002, depth: barW),
                    materials: [accentMat])
                barA.orientation = simd_quatf(angle: .pi / 6, axis: [0, 1, 0])
                barA.position = [offset * 0.4, detailY, offset * 0.4]
                container.addChild(barA)

                let barB = ModelEntity(
                    mesh: .generateBox(width: span * 0.6, height: 0.002, depth: barW),
                    materials: [accentMat])
                barB.orientation = simd_quatf(angle: -.pi / 6, axis: [0, 1, 0])
                barB.position = [-offset * 0.4, detailY, offset * 0.4]
                container.addChild(barB)
            }
        }
    }

    // PointLight helper 

    private static func pointLight(
        color: UIColor, intensity: Float
    ) -> PointLight {
        let light = PointLight()
        light.light.intensity = intensity
        light.light.color = color
        light.light.attenuationRadius = 6
        return light
    }
}
