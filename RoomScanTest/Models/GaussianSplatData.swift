//
//  GaussianSplatData.swift
//  RoomScanTest
//
//  Data model and PLY parser for 3D Gaussian Splatting scenes.
//  Handles the standard .ply output from 3DGS training pipelines.
//

import Foundation
import simd

// MARK: - Data Model

/// A single 3D Gaussian primitive loaded from a .ply file.
struct GaussianPrimitive: Sendable {
    var position: SIMD3<Float>
    var color: SIMD3<Float>       // Linear RGB [0,1]
    var opacity: Float            // [0,1]
    var scale: SIMD3<Float>       // 3D scale (already exp'd)
    var rotation: simd_quatf      // Unit quaternion
}

/// Container for a loaded Gaussian Splatting scene.
struct GaussianSplatScene: Sendable {
    var gaussians: [GaussianPrimitive]
    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)

    var center: SIMD3<Float> {
        (boundingBox.min + boundingBox.max) * 0.5
    }

    var extent: Float {
        simd_length(boundingBox.max - boundingBox.min)
    }
}

/// GPU-side Gaussian data. Layout must match the Metal shader struct exactly.
/// Total size: 56 bytes (14 × Float).
struct GaussianGPU {
    var px: Float; var py: Float; var pz: Float   // position  (12 B)
    var opacity: Float                             //           ( 4 B)
    var cr: Float; var cg: Float; var cb: Float   // color     (12 B)
    var sx: Float; var sy: Float; var sz: Float   // scale     (12 B)
    var rw: Float; var rx: Float; var ry: Float; var rz: Float // rotation (16 B)
}

/// GPU-side uniform data. Layout must match the Metal shader struct exactly.
struct GaussianUniforms {
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var viewport: SIMD2<Float>
    var _padding: SIMD2<Float> = .zero
}

// MARK: - PLY Parser

/// Parses .ply files output by 3D Gaussian Splatting training.
nonisolated enum PLYParser {

    enum PLYError: LocalizedError {
        case invalidHeader
        case unsupportedFormat
        case missingProperties
        case invalidData
        case fileNotFound

        nonisolated var errorDescription: String? {
            switch self {
            case .invalidHeader:      return "Invalid PLY file header"
            case .unsupportedFormat:  return "Only binary little-endian and ASCII PLY files are supported"
            case .missingProperties:  return "PLY file is missing required Gaussian properties (x, y, z)"
            case .invalidData:        return "Could not parse PLY vertex data"
            case .fileNotFound:       return "PLY file not found"
            }
        }
    }

    /// Parse a .ply file from the given URL.
    static func parse(url: URL) throws -> GaussianSplatScene {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PLYError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse PLY data from memory.
    static func parse(data: Data) throws -> GaussianSplatScene {
        // ── Locate header boundary ──
        guard let headerEndRange = data.range(of: Data("end_header\n".utf8)) else {
            throw PLYError.invalidHeader
        }

        let headerData = data[data.startIndex..<headerEndRange.lowerBound]
        guard let headerString = String(data: headerData, encoding: .ascii) else {
            throw PLYError.invalidHeader
        }

        let lines = headerString.components(separatedBy: "\n")
        guard lines.first == "ply" else { throw PLYError.invalidHeader }

        // ── Parse header ──
        var isBinaryLE = false
        var isAscii = false
        var vertexCount = 0
        var properties: [(name: String, type: String)] = []
        var inVertexElement = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "format binary_little_endian 1.0" {
                isBinaryLE = true
            } else if trimmed == "format ascii 1.0" {
                isAscii = true
            } else if trimmed.hasPrefix("element vertex") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 3, let count = Int(parts[2]) {
                    vertexCount = count
                    inVertexElement = true
                }
            } else if trimmed.hasPrefix("element ") {
                inVertexElement = false
            } else if trimmed.hasPrefix("property") && inVertexElement {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 3 {
                    properties.append((name: String(parts[2]), type: String(parts[1])))
                }
            }
        }

        guard isBinaryLE || isAscii else { throw PLYError.unsupportedFormat }
        guard vertexCount > 0 else { throw PLYError.invalidData }

        let propIndex = Dictionary(uniqueKeysWithValues:
            properties.enumerated().map { ($0.element.name, $0.offset) }
        )
        guard propIndex["x"] != nil, propIndex["y"] != nil, propIndex["z"] != nil else {
            throw PLYError.missingProperties
        }

        let bodyStart = headerEndRange.upperBound

        if isBinaryLE {
            return try parseBinary(data: data, bodyStart: bodyStart,
                                   vertexCount: vertexCount,
                                   properties: properties, propIndex: propIndex)
        } else {
            return try parseAscii(data: data, bodyStart: bodyStart,
                                  vertexCount: vertexCount,
                                  properties: properties, propIndex: propIndex)
        }
    }

    // MARK: - Binary Parsing

    private static func parseBinary(
        data: Data, bodyStart: Int, vertexCount: Int,
        properties: [(name: String, type: String)],
        propIndex: [String: Int]
    ) throws -> GaussianSplatScene {

        // Calculate per-vertex stride
        var stride = 0
        var offsets: [Int] = []
        for prop in properties {
            offsets.append(stride)
            stride += byteSize(for: prop.type)
        }

        guard data.count >= bodyStart + stride * vertexCount else {
            throw PLYError.invalidData
        }

        let SH_C0: Float = 0.28209479177387814

        var gaussians: [GaussianPrimitive] = []
        gaussians.reserveCapacity(vertexCount)

        var bbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var bbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for i in 0..<vertexCount {
            let base = bodyStart + i * stride

            // ── Position ──
            let x = readFloat(data: data, offset: base + offsets[propIndex["x"]!])
            let y = readFloat(data: data, offset: base + offsets[propIndex["y"]!])
            let z = readFloat(data: data, offset: base + offsets[propIndex["z"]!])
            let pos = SIMD3<Float>(x, y, z)

            // ── Color (SH DC or direct RGB) ──
            var color = SIMD3<Float>(0.5, 0.5, 0.5)
            if let i0 = propIndex["f_dc_0"],
               let i1 = propIndex["f_dc_1"],
               let i2 = propIndex["f_dc_2"] {
                let r = readFloat(data: data, offset: base + offsets[i0])
                let g = readFloat(data: data, offset: base + offsets[i1])
                let b = readFloat(data: data, offset: base + offsets[i2])
                color = SIMD3<Float>(
                    clamp01(r * SH_C0 + 0.5),
                    clamp01(g * SH_C0 + 0.5),
                    clamp01(b * SH_C0 + 0.5)
                )
            } else if let iR = propIndex["red"],
                      let iG = propIndex["green"],
                      let iB = propIndex["blue"] {
                let r = readUInt8(data: data, offset: base + offsets[iR])
                let g = readUInt8(data: data, offset: base + offsets[iG])
                let b = readUInt8(data: data, offset: base + offsets[iB])
                color = SIMD3<Float>(Float(r) / 255, Float(g) / 255, Float(b) / 255)
            }

            // ── Opacity (logit → sigmoid) ──
            var opacity: Float = 1.0
            if let iO = propIndex["opacity"] {
                let logit = readFloat(data: data, offset: base + offsets[iO])
                opacity = sigmoid(logit)
            }

            // ── Scale (log → exp) ──
            var scale = SIMD3<Float>(0.01, 0.01, 0.01)
            if let i0 = propIndex["scale_0"],
               let i1 = propIndex["scale_1"],
               let i2 = propIndex["scale_2"] {
                scale = SIMD3<Float>(
                    exp(readFloat(data: data, offset: base + offsets[i0])),
                    exp(readFloat(data: data, offset: base + offsets[i1])),
                    exp(readFloat(data: data, offset: base + offsets[i2]))
                )
            }

            // ── Rotation quaternion ──
            var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            if let i0 = propIndex["rot_0"],
               let i1 = propIndex["rot_1"],
               let i2 = propIndex["rot_2"],
               let i3 = propIndex["rot_3"] {
                let w  = readFloat(data: data, offset: base + offsets[i0])
                let qx = readFloat(data: data, offset: base + offsets[i1])
                let qy = readFloat(data: data, offset: base + offsets[i2])
                let qz = readFloat(data: data, offset: base + offsets[i3])
                rotation = simd_normalize(simd_quatf(ix: qx, iy: qy, iz: qz, r: w))
            }

            // Filter degenerate Gaussians
            guard opacity > 0.005,
                  scale.x > 1e-7, scale.y > 1e-7, scale.z > 1e-7 else { continue }

            gaussians.append(GaussianPrimitive(
                position: pos, color: color, opacity: opacity,
                scale: scale, rotation: rotation
            ))
            bbMin = min(bbMin, pos)
            bbMax = max(bbMax, pos)
        }

        if gaussians.isEmpty { bbMin = .zero; bbMax = .zero }
        return GaussianSplatScene(gaussians: gaussians, boundingBox: (bbMin, bbMax))
    }

    // MARK: - ASCII Parsing

    private static func parseAscii(
        data: Data, bodyStart: Int, vertexCount: Int,
        properties: [(name: String, type: String)],
        propIndex: [String: Int]
    ) throws -> GaussianSplatScene {

        guard let bodyString = String(data: data[bodyStart...], encoding: .ascii) else {
            throw PLYError.invalidData
        }

        let SH_C0: Float = 0.28209479177387814
        let lines = bodyString.components(separatedBy: "\n")

        var gaussians: [GaussianPrimitive] = []
        gaussians.reserveCapacity(vertexCount)

        var bbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var bbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for i in 0..<min(vertexCount, lines.count) {
            let values = lines[i].split(separator: " ").compactMap { Float($0) }
            guard values.count >= properties.count else { continue }

            let pos = SIMD3<Float>(
                values[propIndex["x"]!],
                values[propIndex["y"]!],
                values[propIndex["z"]!]
            )

            var color = SIMD3<Float>(0.5, 0.5, 0.5)
            if let i0 = propIndex["f_dc_0"],
               let i1 = propIndex["f_dc_1"],
               let i2 = propIndex["f_dc_2"] {
                color = SIMD3<Float>(
                    clamp01(values[i0] * SH_C0 + 0.5),
                    clamp01(values[i1] * SH_C0 + 0.5),
                    clamp01(values[i2] * SH_C0 + 0.5)
                )
            }

            var opacity: Float = 1.0
            if let iO = propIndex["opacity"] {
                opacity = sigmoid(values[iO])
            }

            var scale = SIMD3<Float>(0.01, 0.01, 0.01)
            if let i0 = propIndex["scale_0"],
               let i1 = propIndex["scale_1"],
               let i2 = propIndex["scale_2"] {
                scale = SIMD3<Float>(exp(values[i0]), exp(values[i1]), exp(values[i2]))
            }

            var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            if let i0 = propIndex["rot_0"],
               let i1 = propIndex["rot_1"],
               let i2 = propIndex["rot_2"],
               let i3 = propIndex["rot_3"] {
                rotation = simd_normalize(
                    simd_quatf(ix: values[i1], iy: values[i2], iz: values[i3], r: values[i0])
                )
            }

            guard opacity > 0.005 else { continue }

            gaussians.append(GaussianPrimitive(
                position: pos, color: color, opacity: opacity,
                scale: scale, rotation: rotation
            ))
            bbMin = min(bbMin, pos)
            bbMax = max(bbMax, pos)
        }

        if gaussians.isEmpty { bbMin = .zero; bbMax = .zero }
        return GaussianSplatScene(gaussians: gaussians, boundingBox: (bbMin, bbMax))
    }

    // MARK: - Helpers

    private static func sigmoid(_ x: Float) -> Float { 1.0 / (1.0 + exp(-x)) }
    private static func clamp01(_ x: Float) -> Float { max(0, min(1, x)) }

    private static func readFloat(data: Data, offset: Int) -> Float {
        data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
    }

    private static func readUInt8(data: Data, offset: Int) -> UInt8 {
        data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt8.self) }
    }

    private static func byteSize(for type: String) -> Int {
        switch type {
        case "float", "float32":  return 4
        case "double", "float64": return 8
        case "uchar", "uint8":   return 1
        case "char", "int8":     return 1
        case "ushort", "uint16": return 2
        case "short", "int16":   return 2
        case "uint", "uint32":   return 4
        case "int", "int32":     return 4
        default:                 return 4
        }
    }
}
