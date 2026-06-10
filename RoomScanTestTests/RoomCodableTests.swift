//
//  RoomCodableTests.swift
//  RoomScanTestTests
//

import simd
import XCTest
@testable import RoomScanTest

final class RoomCodableTests: XCTestCase {

    func testFurnitureReplacementRoundTrip() throws {
        let original = FurnitureReplacement(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            objectId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            originalCategory: "chair",
            replacedWithUSDZ: "catalog-chair.usdz",
            replacedAt: Date(timeIntervalSinceReferenceDate: 800_000),
            transform: Array(0..<16).map { Double($0) * 0.1 },
            positionOffset: [0.1, 0.2, 0.3],
            yRotation: 1.57,
            customScale: 1.1,
            lightFixtureType: "pendant",
            lightColorRGB: [1, 0.9, 0.8],
            lightIntensity: 800
        )

        let decoded = try roundTrip(original)
        assertFurnitureReplacementEqual(original, decoded)
    }

    func testRoomRoundTrip() throws {
        let userId = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        let roomId = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        let projectId = UUID(uuidString: "44444444-5555-6666-7777-888888888888")!

        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: "table",
            replacedWithUSDZ: "table_modern.usdz",
            transform: FurnitureReplacement.fromTransform(matrix_identity_float4x4)
        )

        let original = Room(
            id: roomId,
            name: "Living Room",
            userId: userId,
            createdAt: Date(timeIntervalSinceReferenceDate: 700_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 700_100),
            capturedRoomExportURL: "/legacy/export.json",
            furnitureReplacements: [replacement],
            roomMaterials: RoomMaterials(
                wallColor: CodableColor(red: 0.9, green: 0.85, blue: 0.8),
                floorColor: CodableColor(red: 0.4, green: 0.35, blue: 0.3)
            ),
            projectId: projectId
        )

        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.createdAt.timeIntervalSinceReferenceDate, original.createdAt.timeIntervalSinceReferenceDate, accuracy: 0.001)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSinceReferenceDate, original.updatedAt.timeIntervalSinceReferenceDate, accuracy: 0.001)
        XCTAssertEqual(decoded.capturedRoomExportURL, original.capturedRoomExportURL)
        XCTAssertEqual(decoded.projectId, original.projectId)
        XCTAssertEqual(decoded.furnitureReplacements.count, 1)
        assertFurnitureReplacementEqual(original.furnitureReplacements[0], decoded.furnitureReplacements[0])
        XCTAssertEqual(decoded.roomMaterials, original.roomMaterials)
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func assertFurnitureReplacementEqual(_ a: FurnitureReplacement, _ b: FurnitureReplacement) {
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.objectId, b.objectId)
        XCTAssertEqual(a.originalCategory, b.originalCategory)
        XCTAssertEqual(a.replacedWithUSDZ, b.replacedWithUSDZ)
        XCTAssertEqual(a.replacedAt.timeIntervalSinceReferenceDate, b.replacedAt.timeIntervalSinceReferenceDate, accuracy: 0.001)
        XCTAssertEqual(a.transform, b.transform)
        XCTAssertEqual(a.positionOffset, b.positionOffset)
        XCTAssertEqual(a.yRotation, b.yRotation)
        XCTAssertEqual(a.customScale, b.customScale)
        XCTAssertEqual(a.wallArtImageFile, b.wallArtImageFile)
        XCTAssertEqual(a.wallArtFrameSize, b.wallArtFrameSize)
        XCTAssertEqual(a.wallArtFrameStyle, b.wallArtFrameStyle)
        XCTAssertEqual(a.lightFixtureType, b.lightFixtureType)
        XCTAssertEqual(a.lightColorRGB, b.lightColorRGB)
        XCTAssertEqual(a.lightIntensity, b.lightIntensity)
        XCTAssertEqual(a.carpetSize, b.carpetSize)
        XCTAssertEqual(a.carpetPattern, b.carpetPattern)
        XCTAssertEqual(a.carpetColorRGB, b.carpetColorRGB)
        XCTAssertEqual(a.carpetCustomWidthCm, b.carpetCustomWidthCm)
        XCTAssertEqual(a.carpetCustomDepthCm, b.carpetCustomDepthCm)
    }
}
