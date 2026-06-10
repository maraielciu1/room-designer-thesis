//
//  USDFurnitureFitScaleTests.swift
//  RoomScanTestTests
//

import XCTest
@testable import RoomScanTest

final class USDFurnitureFitScaleTests: XCTestCase {

    func testUniformScaleUsesMinimumAxisRatio() {
        let target = SIMD3<Float>(2, 1, 4)
        let model = SIMD3<Float>(1, 0.5, 8)
        let scale = USDFurnitureFitScale.uniformScale(
            targetSize: target,
            modelSize: model,
            margin: 1.0
        )
        // Ratios: 2, 2, 0.5 → min = 0.5
        XCTAssertEqual(scale, 0.5, accuracy: 1e-5)
    }

    func testUniformScaleAppliesMargin() {
        let target = SIMD3<Float>(1, 1, 1)
        let model = SIMD3<Float>(2, 4, 8)
        let scale = USDFurnitureFitScale.uniformScale(
            targetSize: target,
            modelSize: model,
            margin: 0.90
        )
        // min(0.5, 0.25, 0.125) = 0.125 × 0.9
        XCTAssertEqual(scale, 0.1125, accuracy: 1e-5)
    }

    func testBlenderExportMarginMatchesFormula() {
        let marker = SIMD3<Float>(1.2, 0.8, 0.6)
        let imported = SIMD3<Float>(0.4, 0.2, 0.3)
        let scale = USDFurnitureFitScale.uniformScale(
            targetSize: marker,
            modelSize: imported,
            margin: 0.92
        )
        // min(1.2/0.4, 0.8/0.2, 0.6/0.3) = min(3, 4, 2) = 2 → 2 × 0.92
        XCTAssertEqual(scale, 1.84, accuracy: 1e-5)
    }

    func testZeroModelExtentReturnsOne() {
        let scale = USDFurnitureFitScale.uniformScale(
            targetSize: SIMD3<Float>(1, 1, 1),
            modelSize: SIMD3<Float>(0, 1, 1),
            margin: 0.9
        )
        XCTAssertEqual(scale, 1)
    }
}
