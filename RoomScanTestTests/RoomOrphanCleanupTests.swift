//
//  RoomOrphanCleanupTests.swift
//  RoomScanTestTests
//

import XCTest
@testable import RoomScanTest

final class RoomOrphanCleanupTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoomScanTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    func testCleanOrphanedScanFilesRemovesOnlyUnknownUUIDs() throws {
        let keptId = UUID()
        let orphanId = UUID()
        let notUUIDName = "notes.txt"

        try writeStubScan(id: keptId)
        try writeStubScan(id: orphanId)
        let stray = tempRoot.appendingPathComponent(notUUIDName)
        try Data("{}".utf8).write(to: stray)

        Room.cleanOrphanedScanFiles(in: [tempRoot], existingRoomIds: [keptId])

        XCTAssertTrue(FileManager.default.fileExists(atPath: scanPath(for: keptId).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: scanPath(for: orphanId).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stray.path))
    }

    func testCleanOrphanedScanFilesIgnoresNonJSON() throws {
        let orphanId = UUID()
        let ply = tempRoot.appendingPathComponent("\(orphanId.uuidString).ply")
        try Data("ply".utf8).write(to: ply)

        Room.cleanOrphanedScanFiles(in: [tempRoot], existingRoomIds: [])

        XCTAssertTrue(FileManager.default.fileExists(atPath: ply.path))
    }

    // MARK: - Helpers

    private func scanPath(for id: UUID) -> URL {
        tempRoot.appendingPathComponent("\(id.uuidString).json")
    }

    private func writeStubScan(id: UUID) throws {
        try Data("{}".utf8).write(to: scanPath(for: id))
    }
}
