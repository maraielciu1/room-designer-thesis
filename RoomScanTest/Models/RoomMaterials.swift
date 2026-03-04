//
//  RoomMaterials.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 02.03.2026.
//
//  Stores the dominant wall and floor colors extracted from ARKit
//  camera frames captured during a RoomPlan scan.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - CodableColor

/// A simple RGB(A) color representation that conforms to Codable,
/// allowing persistence alongside the Room model.
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red   = Double(r)
        self.green = Double(g)
        self.blue  = Double(b)
        self.alpha = Double(a)
    }

    /// Convert back to UIColor for use in RealityKit materials.
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// A lighter tint of this color (for wireframe overlays).
    var lighterTint: UIColor {
        UIColor(
            red:   min(red   + 0.15, 1.0),
            green: min(green + 0.15, 1.0),
            blue:  min(blue  + 0.15, 1.0),
            alpha: alpha
        )
    }

    /// SwiftUI Color representation.
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// Initialize from a SwiftUI Color.
    init(from color: Color) {
        let ui = UIColor(color)
        self.init(uiColor: ui)
    }
}

// MARK: - SurfacePattern

/// Visual pattern / texture applied to a room surface.
enum SurfacePattern: String, Codable, CaseIterable, Identifiable, Equatable {
    case none
    case woodPlanks
    case ceramicTiles
    case brick
    case herringbone
    case concrete
    case marble

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:          return "Solid"
        case .woodPlanks:    return "Wood"
        case .ceramicTiles:  return "Tiles"
        case .brick:         return "Brick"
        case .herringbone:   return "Parquet"
        case .concrete:      return "Concrete"
        case .marble:        return "Marble"
        }
    }

    var icon: String {
        switch self {
        case .none:          return "square.fill"
        case .woodPlanks:    return "line.3.horizontal"
        case .ceramicTiles:  return "square.grid.3x3"
        case .brick:         return "rectangle.split.2x2"
        case .herringbone:   return "chevron.up"
        case .concrete:      return "circle.dashed"
        case .marble:        return "drop.fill"
        }
    }
}

// MARK: - RoomMaterials

/// Holds the captured material information for a scanned room.
/// Persisted as part of the Room model via Codable.
struct RoomMaterials: Codable, Equatable {
    /// Dominant wall color extracted from camera frames
    var wallColor: CodableColor

    /// Dominant floor color extracted from camera frames
    var floorColor: CodableColor

    /// Number of wall color samples captured (for debugging / quality indication)
    var wallSampleCount: Int

    /// Number of floor color samples captured
    var floorSampleCount: Int

    /// Pattern / texture for walls
    var wallPattern: SurfacePattern

    /// Pattern / texture for floors
    var floorPattern: SurfacePattern

    init(wallColor: CodableColor, floorColor: CodableColor,
         wallSampleCount: Int = 0, floorSampleCount: Int = 0,
         wallPattern: SurfacePattern = .none, floorPattern: SurfacePattern = .none) {
        self.wallColor = wallColor
        self.floorColor = floorColor
        self.wallSampleCount = wallSampleCount
        self.floorSampleCount = floorSampleCount
        self.wallPattern = wallPattern
        self.floorPattern = floorPattern
    }

    /// Backward-compatible decoding (rooms saved before patterns existed).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wallColor        = try c.decode(CodableColor.self, forKey: .wallColor)
        floorColor       = try c.decode(CodableColor.self, forKey: .floorColor)
        wallSampleCount  = try c.decodeIfPresent(Int.self, forKey: .wallSampleCount)  ?? 0
        floorSampleCount = try c.decodeIfPresent(Int.self, forKey: .floorSampleCount) ?? 0
        wallPattern      = try c.decodeIfPresent(SurfacePattern.self, forKey: .wallPattern)  ?? .none
        floorPattern     = try c.decodeIfPresent(SurfacePattern.self, forKey: .floorPattern) ?? .none
    }
}
