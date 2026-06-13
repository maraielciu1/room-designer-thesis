//
//  FurnitureReplacement.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import Foundation
import simd
import RoomPlan

struct FurnitureReplacement: Identifiable, Codable {
    let id: UUID
    var objectId: UUID // Reference to the original scanned object
    var originalCategory: String // e.g., "chair", "table", "wallArt", "lighting"
    var replacedWithUSDZ: String // USDZ filename (or placeholder for decor items)
    var replacedAt: Date
    var transform: [Double] // Serialized transform matrix (16 values)
    
    // Interior-design manipulation data (persisted across sessions)
    var positionOffset: [Double]?  // [x, y, z] world-space offset from original position
    var yRotation: Double?         // Rotation around Y axis in radians
    var customScale: Double?       // Additional scale multiplier (1.0 = fit to original size)

    // Wall Art metadata (only when originalCategory == "wallArt")
    var wallArtImageFile: String?   // JPEG file saved in DecorManager.wallArtDirectory
    var wallArtFrameSize: String?   // FrameSize rawValue
    var wallArtFrameStyle: String?  // FrameStyle rawValue

    // Lighting metadata (only when originalCategory == "lighting")
    var lightFixtureType: String?   // LightFixtureType rawValue
    var lightColorRGB: [Double]?    // [r, g, b] 0…1
    var lightIntensity: Double?     // lumens

    // Carpet metadata (only when originalCategory == "carpet")
    var carpetSize: String?          // CarpetSize rawValue
    var carpetPattern: String?       // CarpetPattern rawValue
    var carpetColorRGB: [Double]?    // [r, g, b] 0…1
    var carpetCustomWidthCm: Double? // only when carpetSize == "Custom"
    var carpetCustomDepthCm: Double? // only when carpetSize == "Custom"
    
    init(id: UUID = UUID(),
         objectId: UUID,
         originalCategory: String,
         replacedWithUSDZ: String,
         replacedAt: Date = Date(),
         transform: [Double],
         positionOffset: [Double]? = nil,
         yRotation: Double? = nil,
         customScale: Double? = nil,
         wallArtImageFile: String? = nil,
         wallArtFrameSize: String? = nil,
         wallArtFrameStyle: String? = nil,
         lightFixtureType: String? = nil,
         lightColorRGB: [Double]? = nil,
         lightIntensity: Double? = nil,
         carpetSize: String? = nil,
         carpetPattern: String? = nil,
         carpetColorRGB: [Double]? = nil,
         carpetCustomWidthCm: Double? = nil,
         carpetCustomDepthCm: Double? = nil)
    {
        self.id = id
        self.objectId = objectId
        self.originalCategory = originalCategory
        self.replacedWithUSDZ = replacedWithUSDZ
        self.replacedAt = replacedAt
        self.transform = transform
        self.positionOffset = positionOffset
        self.yRotation = yRotation
        self.customScale = customScale
        self.wallArtImageFile = wallArtImageFile
        self.wallArtFrameSize = wallArtFrameSize
        self.wallArtFrameStyle = wallArtFrameStyle
        self.lightFixtureType = lightFixtureType
        self.lightColorRGB = lightColorRGB
        self.lightIntensity = lightIntensity
        self.carpetSize = carpetSize
        self.carpetPattern = carpetPattern
        self.carpetColorRGB = carpetColorRGB
        self.carpetCustomWidthCm = carpetCustomWidthCm
        self.carpetCustomDepthCm = carpetCustomDepthCm
    }

    // Convenience helpers

    var isWallArt: Bool { originalCategory == "wallArt" }
    var isLighting: Bool { originalCategory == "lighting" }
    var isCarpet: Bool { originalCategory == "carpet" }
    var isDecor: Bool { isWallArt || isLighting || isCarpet }
}

// Helper to work with transforms
extension FurnitureReplacement {
    func getTransformMatrix() -> simd_float4x4? {
        guard transform.count == 16 else { return nil }
        return simd_float4x4(
            SIMD4<Float>(Float(transform[0]), Float(transform[1]), Float(transform[2]), Float(transform[3])),
            SIMD4<Float>(Float(transform[4]), Float(transform[5]), Float(transform[6]), Float(transform[7])),
            SIMD4<Float>(Float(transform[8]), Float(transform[9]), Float(transform[10]), Float(transform[11])),
            SIMD4<Float>(Float(transform[12]), Float(transform[13]), Float(transform[14]), Float(transform[15]))
        )
    }
    
    static func fromTransform(_ matrix: simd_float4x4) -> [Double] {
        return [
            Double(matrix.columns.0.x), Double(matrix.columns.0.y), Double(matrix.columns.0.z), Double(matrix.columns.0.w),
            Double(matrix.columns.1.x), Double(matrix.columns.1.y), Double(matrix.columns.1.z), Double(matrix.columns.1.w),
            Double(matrix.columns.2.x), Double(matrix.columns.2.y), Double(matrix.columns.2.z), Double(matrix.columns.2.w),
            Double(matrix.columns.3.x), Double(matrix.columns.3.y), Double(matrix.columns.3.z), Double(matrix.columns.3.w)
        ]
    }
}
