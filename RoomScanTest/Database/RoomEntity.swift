//
//  RoomEntity.swift
//  RoomScanTest
//
//  SwiftData record for Room. RoomMaterials is flattened into nullable
//  scalar columns. Scan geometry (CapturedRoom JSON) stays on disk.
//

import Foundation
import SwiftData

@Model
final class RoomEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var userId: UUID
    var createdAt: Date
    var updatedAt: Date
    var capturedRoomExportURL: String?
    var projectId: UUID?

    // RoomMaterials flattened
    var wallColorRed: Double?
    var wallColorGreen: Double?
    var wallColorBlue: Double?
    var wallColorAlpha: Double?
    var floorColorRed: Double?
    var floorColorGreen: Double?
    var floorColorBlue: Double?
    var floorColorAlpha: Double?
    var wallSampleCount: Int?
    var floorSampleCount: Int?
    var wallPatternRaw: String?
    var floorPatternRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \FurnitureReplacementEntity.room)
    var furnitureReplacements: [FurnitureReplacementEntity] = []

    init(from room: Room) {
        self.id = room.id
        self.name = room.name
        self.userId = room.userId
        self.createdAt = room.createdAt
        self.updatedAt = room.updatedAt
        self.capturedRoomExportURL = room.capturedRoomExportURL
        self.projectId = room.projectId
        applyMaterials(room.roomMaterials)
    }

    func update(from room: Room, context: ModelContext) {
        name = room.name
        userId = room.userId
        createdAt = room.createdAt
        updatedAt = room.updatedAt
        capturedRoomExportURL = room.capturedRoomExportURL
        projectId = room.projectId
        applyMaterials(room.roomMaterials)

        // Sync replacements: remove deleted ones, upsert existing/new ones
        let incomingIds = Set(room.furnitureReplacements.map(\.id))
        for existing in furnitureReplacements where !incomingIds.contains(existing.id) {
            context.delete(existing)
        }
        for replacement in room.furnitureReplacements {
            if let entity = furnitureReplacements.first(where: { $0.id == replacement.id }) {
                entity.update(from: replacement)
            } else {
                let entity = FurnitureReplacementEntity(from: replacement)
                entity.room = self
                furnitureReplacements.append(entity)
            }
        }
    }

    func toRoom() -> Room {
        Room(
            id: id,
            name: name,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            capturedRoomExportURL: capturedRoomExportURL,
            furnitureReplacements: furnitureReplacements.map { $0.toReplacement() },
            roomMaterials: extractMaterials(),
            projectId: projectId
        )
    }

    // MARK: - Materials helpers

    private func applyMaterials(_ m: RoomMaterials?) {
        guard let m else {
            wallColorRed = nil; wallColorGreen = nil; wallColorBlue = nil; wallColorAlpha = nil
            floorColorRed = nil; floorColorGreen = nil; floorColorBlue = nil; floorColorAlpha = nil
            wallSampleCount = nil; floorSampleCount = nil
            wallPatternRaw = nil; floorPatternRaw = nil
            return
        }
        wallColorRed = m.wallColor.red; wallColorGreen = m.wallColor.green
        wallColorBlue = m.wallColor.blue; wallColorAlpha = m.wallColor.alpha
        floorColorRed = m.floorColor.red; floorColorGreen = m.floorColor.green
        floorColorBlue = m.floorColor.blue; floorColorAlpha = m.floorColor.alpha
        wallSampleCount = m.wallSampleCount; floorSampleCount = m.floorSampleCount
        wallPatternRaw = m.wallPattern.rawValue; floorPatternRaw = m.floorPattern.rawValue
    }

    private func extractMaterials() -> RoomMaterials? {
        guard let wr = wallColorRed, let wg = wallColorGreen,
              let wb = wallColorBlue, let wa = wallColorAlpha,
              let fr = floorColorRed, let fg = floorColorGreen,
              let fb = floorColorBlue, let fa = floorColorAlpha else { return nil }
        return RoomMaterials(
            wallColor: CodableColor(red: wr, green: wg, blue: wb, alpha: wa),
            floorColor: CodableColor(red: fr, green: fg, blue: fb, alpha: fa),
            wallSampleCount: wallSampleCount ?? 0,
            floorSampleCount: floorSampleCount ?? 0,
            wallPattern: SurfacePattern(rawValue: wallPatternRaw ?? "") ?? .none,
            floorPattern: SurfacePattern(rawValue: floorPatternRaw ?? "") ?? .none
        )
    }
}
