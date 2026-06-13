//
//  MeasurementService.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Pure-function measurement engine.
//  Computes room dimensions, areas, volumes, perimeters, and
//  point-to-point distances from RoomPlan CapturedRoom data.
//

import Foundation
import simd
import RoomPlan

// MARK: - Measurement Results

/// Holds all computed measurements for a scanned room.
struct RoomMeasurements {
    /// Overall bounding-box dimensions in metres (W × H × D)
    let width: Float
    let height: Float
    let depth: Float

    /// Floor area in m² (sum of all floor surfaces)
    let floorArea: Float

    /// Total wall surface area in m² (sum of all walls)
    let wallArea: Float

    /// Room perimeter in metres (sum of wall widths at floor level)
    let perimeter: Float

    /// Approximate volume in m³ (floor area × height)
    let volume: Float

    /// Number of walls, floors, doors, windows, and objects detected
    let wallCount: Int
    let floorCount: Int
    let doorCount: Int
    let windowCount: Int
    let objectCount: Int

    // Formatted helpers

    var formattedWidth: String { String(format: "%.2f m", width) }
    var formattedHeight: String { String(format: "%.2f m", height) }
    var formattedDepth: String { String(format: "%.2f m", depth) }
    var formattedFloorArea: String { String(format: "%.1f m²", floorArea) }
    var formattedWallArea: String { String(format: "%.1f m²", wallArea) }
    var formattedPerimeter: String { String(format: "%.1f m", perimeter) }
    var formattedVolume: String { String(format: "%.1f m³", volume) }
    var formattedDimensions: String {
        String(format: "%.1f × %.1f × %.1f m", width, depth, height)
    }
}

/// Dimensions of a single object, formatted for display.
struct ObjectMeasurements {
    let width: Float   // X
    let height: Float  // Y
    let depth: Float   // Z
    let category: String

    var formattedDimensions: String {
        let wCm = Int(width * 100)
        let hCm = Int(height * 100)
        let dCm = Int(depth * 100)
        return "\(wCm) × \(hCm) × \(dCm) cm"
    }

    var formattedCompact: String {
        let wCm = Int(width * 100)
        let hCm = Int(height * 100)
        let dCm = Int(depth * 100)
        return "\(wCm)×\(hCm)×\(dCm)"
    }
}

// MARK: - Material Estimates

/// Estimated quantities for renovation / planning.
struct MaterialEstimates {
    /// Paint needed for walls (litres, assuming ~10 m²/L coverage)
    let paintLitres: Float

    /// Flooring material needed (m²), with 10 % waste allowance
    let flooringArea: Float

    /// Baseboard / skirting length in metres (≈ perimeter minus door openings)
    let skirtingLength: Float

    var formattedPaint: String { String(format: "%.1f L", paintLitres) }
    var formattedFlooring: String { String(format: "%.1f m²", flooringArea) }
    var formattedSkirting: String { String(format: "%.1f m", skirtingLength) }
}

// MARK: - MeasurementService

enum MeasurementService {

    /// Compute all room measurements from a CapturedRoom.
    static func measure(_ capturedRoom: CapturedRoom) -> RoomMeasurements {
        let (minB, maxB) = boundingBox(for: capturedRoom)

        let width  = maxB.x - minB.x
        let height = maxB.y - minB.y
        let depth  = maxB.z - minB.z

        // Floor area - sum each floor surface
        let floorArea: Float = capturedRoom.floors.reduce(0) { sum, floor in
            sum + floor.dimensions.x * floor.dimensions.z
        }

        // Wall area - sum each wall surface
        let wallArea: Float = capturedRoom.walls.reduce(0) { sum, wall in
            sum + wall.dimensions.x * wall.dimensions.y
        }

        // Perimeter - sum of wall widths
        let perimeter: Float = capturedRoom.walls.reduce(0) { $0 + $1.dimensions.x }

        // Volume - floor area × height (approximation for non-rectangular rooms)
        let effectiveFloorArea = floorArea > 0 ? floorArea : (width * depth)
        let volume = effectiveFloorArea * height

        return RoomMeasurements(
            width: width,
            height: height,
            depth: depth,
            floorArea: effectiveFloorArea,
            wallArea: wallArea,
            perimeter: perimeter,
            volume: volume,
            wallCount: capturedRoom.walls.count,
            floorCount: capturedRoom.floors.count,
            doorCount: capturedRoom.doors.count,
            windowCount: capturedRoom.windows.count,
            objectCount: capturedRoom.objects.count
        )
    }

    /// Measure dimensions of a specific object.
    static func measureObject(_ object: CapturedRoom.Object) -> ObjectMeasurements {
        ObjectMeasurements(
            width: object.dimensions.x,
            height: object.dimensions.y,
            depth: object.dimensions.z,
            category: object.category.description
        )
    }

    /// Measure dimensions from a ScannedObject's stored dimensions.
    static func measureScannedObject(dimensions: SIMD3<Float>, category: String) -> ObjectMeasurements {
        ObjectMeasurements(
            width: dimensions.x,
            height: dimensions.y,
            depth: dimensions.z,
            category: category
        )
    }

    /// Euclidean distance between two 3D points.
    static func distance(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float {
        simd_distance(a, b)
    }

    /// Formatted distance between two points.
    static func formattedDistance(from a: SIMD3<Float>, to b: SIMD3<Float>) -> String {
        let d = distance(from: a, to: b)
        if d >= 1.0 {
            return String(format: "%.2f m", d)
        } else {
            return String(format: "%.0f cm", d * 100)
        }
    }

    /// Compute material estimates from room measurements.
    static func estimateMaterials(from measurements: RoomMeasurements,
                                  doorCount: Int,
                                  windowCount: Int) -> MaterialEstimates {
        // Subtract approximate door/window area from wall area for paint
        let doorArea: Float = Float(doorCount) * 1.9    // ~0.8m × 2.0m standard door
        let windowArea: Float = Float(windowCount) * 1.5 // ~1.0m × 1.5m standard window
        let paintableWallArea = max(measurements.wallArea - doorArea - windowArea, 0)

        // Paint: ~10 m^2 per litre, two coats
        let paintLitres = (paintableWallArea / 10.0) * 2.0

        // Flooring: floor area + 10% waste
        let flooringArea = measurements.floorArea * 1.10

        // Skirting: perimeter minus door widths (~0.8m each)
        let skirtingLength = max(measurements.perimeter - Float(doorCount) * 0.8, 0)

        return MaterialEstimates(
            paintLitres: paintLitres,
            flooringArea: flooringArea,
            skirtingLength: skirtingLength
        )
    }

    // MARK: - Internal Helpers

    /// Compute the axis-aligned bounding box of the room.
    static func boundingBox(for capturedRoom: CapturedRoom) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minB = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxB = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for wall in capturedRoom.walls {
            let p = SIMD3<Float>(wall.transform.columns.3.x,
                                 wall.transform.columns.3.y,
                                 wall.transform.columns.3.z)
            minB = min(minB, p - wall.dimensions * 0.5)
            maxB = max(maxB, p + wall.dimensions * 0.5)
        }
        for floor in capturedRoom.floors {
            let p = SIMD3<Float>(floor.transform.columns.3.x,
                                 floor.transform.columns.3.y,
                                 floor.transform.columns.3.z)
            minB = min(minB, p - floor.dimensions * 0.5)
            maxB = max(maxB, p + floor.dimensions * 0.5)
        }

        // Fallback if there are no walls/floors
        if minB.x == .greatestFiniteMagnitude {
            return (.zero, .zero)
        }

        return (minB, maxB)
    }
}
