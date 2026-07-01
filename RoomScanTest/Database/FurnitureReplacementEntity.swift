//
//  FurnitureReplacementEntity.swift
//  RoomScanTest
//
//  SwiftData record for FurnitureReplacement. [Double] arrays are stored as
//  compact JSON strings so they are visible in the SQLite inspector.
//

import Foundation
import SwiftData

@Model
final class FurnitureReplacementEntity {
    @Attribute(.unique) var id: UUID
    var objectId: UUID
    var originalCategory: String
    var replacedWithUSDZ: String
    var replacedAt: Date

    // [Double] arrays serialized as JSON strings
    var transformJSON: String
    var positionOffsetJSON: String?
    var yRotation: Double?
    var customScale: Double?

    // Wall art
    var wallArtImageFile: String?
    var wallArtFrameSize: String?
    var wallArtFrameStyle: String?

    // Lighting
    var lightFixtureType: String?
    var lightColorJSON: String?
    var lightIntensity: Double?

    // Carpet
    var carpetSize: String?
    var carpetPattern: String?
    var carpetColorJSON: String?
    var carpetCustomWidthCm: Double?
    var carpetCustomDepthCm: Double?

    // Back-reference for cascade delete
    var room: RoomEntity?

    init(from r: FurnitureReplacement) {
        self.id = r.id
        self.objectId = r.objectId
        self.originalCategory = r.originalCategory
        self.replacedWithUSDZ = r.replacedWithUSDZ
        self.replacedAt = r.replacedAt
        self.transformJSON = Self.encodeDoubles(r.transform)
        self.positionOffsetJSON = r.positionOffset.map { Self.encodeDoubles($0) }
        self.yRotation = r.yRotation
        self.customScale = r.customScale
        self.wallArtImageFile = r.wallArtImageFile
        self.wallArtFrameSize = r.wallArtFrameSize
        self.wallArtFrameStyle = r.wallArtFrameStyle
        self.lightFixtureType = r.lightFixtureType
        self.lightColorJSON = r.lightColorRGB.map { Self.encodeDoubles($0) }
        self.lightIntensity = r.lightIntensity
        self.carpetSize = r.carpetSize
        self.carpetPattern = r.carpetPattern
        self.carpetColorJSON = r.carpetColorRGB.map { Self.encodeDoubles($0) }
        self.carpetCustomWidthCm = r.carpetCustomWidthCm
        self.carpetCustomDepthCm = r.carpetCustomDepthCm
    }

    func update(from r: FurnitureReplacement) {
        objectId = r.objectId
        originalCategory = r.originalCategory
        replacedWithUSDZ = r.replacedWithUSDZ
        replacedAt = r.replacedAt
        transformJSON = Self.encodeDoubles(r.transform)
        positionOffsetJSON = r.positionOffset.map { Self.encodeDoubles($0) }
        yRotation = r.yRotation
        customScale = r.customScale
        wallArtImageFile = r.wallArtImageFile
        wallArtFrameSize = r.wallArtFrameSize
        wallArtFrameStyle = r.wallArtFrameStyle
        lightFixtureType = r.lightFixtureType
        lightColorJSON = r.lightColorRGB.map { Self.encodeDoubles($0) }
        lightIntensity = r.lightIntensity
        carpetSize = r.carpetSize
        carpetPattern = r.carpetPattern
        carpetColorJSON = r.carpetColorRGB.map { Self.encodeDoubles($0) }
        carpetCustomWidthCm = r.carpetCustomWidthCm
        carpetCustomDepthCm = r.carpetCustomDepthCm
    }

    func toReplacement() -> FurnitureReplacement {
        FurnitureReplacement(
            id: id,
            objectId: objectId,
            originalCategory: originalCategory,
            replacedWithUSDZ: replacedWithUSDZ,
            replacedAt: replacedAt,
            transform: Self.decodeDoubles(transformJSON),
            positionOffset: positionOffsetJSON.map { Self.decodeDoubles($0) },
            yRotation: yRotation,
            customScale: customScale,
            wallArtImageFile: wallArtImageFile,
            wallArtFrameSize: wallArtFrameSize,
            wallArtFrameStyle: wallArtFrameStyle,
            lightFixtureType: lightFixtureType,
            lightColorRGB: lightColorJSON.map { Self.decodeDoubles($0) },
            lightIntensity: lightIntensity,
            carpetSize: carpetSize,
            carpetPattern: carpetPattern,
            carpetColorRGB: carpetColorJSON.map { Self.decodeDoubles($0) },
            carpetCustomWidthCm: carpetCustomWidthCm,
            carpetCustomDepthCm: carpetCustomDepthCm
        )
    }

    // MARK: - JSON helpers

    private static func encodeDoubles(_ values: [Double]) -> String {
        (try? String(data: JSONEncoder().encode(values), encoding: .utf8)) ?? "[]"
    }

    private static func decodeDoubles(_ json: String) -> [Double] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return values
    }
}
