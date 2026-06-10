//
//  PLYParserTests.swift
//  RoomScanTestTests
//

import XCTest
@testable import RoomScanTest

final class PLYParserTests: XCTestCase {

    /// Minimal ASCII 3DGS-style PLY (two vertices) used across parser tests.
    private static let fixtureASCII = """
        ply
        format ascii 1.0
        element vertex 2
        property float x
        property float y
        property float z
        property float f_dc_0
        property float f_dc_1
        property float f_dc_2
        property float opacity
        property float scale_0
        property float scale_1
        property float scale_2
        property float rot_0
        property float rot_1
        property float rot_2
        property float rot_3
        end_header
        0 0 0 0 0 0 0 0 0 0 1 0 0 0
        1 2 3 0 0 0 2 0 0 0 1 0 0 0

        """

    private var fixtureData: Data {
        Data(Self.fixtureASCII.utf8)
    }

    func testParseFixtureGaussianCountAndPositions() throws {
        let scene = try PLYParser.parse(data: fixtureData)
        XCTAssertEqual(scene.gaussians.count, 2)

        XCTAssertEqual(scene.gaussians[0].position.x, 0, accuracy: 1e-5)
        XCTAssertEqual(scene.gaussians[0].position.y, 0, accuracy: 1e-5)
        XCTAssertEqual(scene.gaussians[0].position.z, 0, accuracy: 1e-5)

        // COLMAP Y-down Z-forward → Y-up Z-back
        XCTAssertEqual(scene.gaussians[1].position.x, 1, accuracy: 1e-5)
        XCTAssertEqual(scene.gaussians[1].position.y, -2, accuracy: 1e-5)
        XCTAssertEqual(scene.gaussians[1].position.z, -3, accuracy: 1e-5)
    }

    func testParseFixtureOpacityFromLogit() throws {
        let scene = try PLYParser.parse(data: fixtureData)
        XCTAssertEqual(scene.gaussians[0].opacity, 0.5, accuracy: 1e-4)
        let expected = 1.0 / (1.0 + exp(-2.0))
        XCTAssertEqual(scene.gaussians[1].opacity, Float(expected), accuracy: 1e-4)
    }

    func testParseURLRoundTripWritesTempFile() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("ply-\(UUID().uuidString).ply")
        defer { try? FileManager.default.removeItem(at: temp) }
        try fixtureData.write(to: temp)
        let fromURL = try PLYParser.parse(url: temp)
        let fromData = try PLYParser.parse(data: fixtureData)
        XCTAssertEqual(fromURL.gaussians.count, fromData.gaussians.count)
        XCTAssertEqual(fromURL.gaussians[1].position, fromData.gaussians[1].position)
    }

    func testMissingFileThrows() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("no-such.ply")
        XCTAssertThrowsError(try PLYParser.parse(url: missing)) { error in
            guard let plyError = error as? PLYParser.PLYError else {
                return XCTFail("Expected PLYParser.PLYError, got \(error)")
            }
            XCTAssertEqual(plyError, .fileNotFound)
        }
    }
}
