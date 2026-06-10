//
//  USDFurnitureFitScale.swift
//  RoomScanTest
//
//  Uniform scale heuristic for fitting a USDZ model into a target bounding box.
//  Used by in-app catalogue loading and Blender export alignment (margin may differ).
//

import simd

enum USDFurnitureFitScale {
    /// `min(targetᵢ / modelᵢ) × margin`, clamped to at least `minimumScale`.
    /// Returns `1` when any model axis extent is non-positive (caller may apply a fallback).
    static func uniformScale(
        targetSize: SIMD3<Float>,
        modelSize: SIMD3<Float>,
        margin: Float,
        minimumScale: Float = 0.0001
    ) -> Float {
        guard modelSize.x > 1e-5, modelSize.y > 1e-5, modelSize.z > 1e-5 else {
            return 1
        }
        let scaleX = targetSize.x / modelSize.x
        let scaleY = targetSize.y / modelSize.y
        let scaleZ = targetSize.z / modelSize.z
        let uniform = min(scaleX, scaleY, scaleZ) * margin
        return max(uniform, minimumScale)
    }
}
