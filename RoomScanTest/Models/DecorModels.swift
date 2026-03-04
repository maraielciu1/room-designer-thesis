//
//  DecorModels.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//
//  Data models for wall art frames and lighting fixtures.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Wall Art Frame Sizes

enum FrameSize: String, CaseIterable, Identifiable, Codable {
    case a5        = "A5"
    case a4        = "A4"
    case a3        = "A3"
    case medium    = "50×70"
    case large     = "60×90"
    case square40  = "40×40"
    case square60  = "60×60"
    case panoramic = "100×40"

    var id: String { rawValue }

    /// Width in metres
    var widthM: Float {
        switch self {
        case .a5:        return 0.148
        case .a4:        return 0.210
        case .a3:        return 0.297
        case .medium:    return 0.50
        case .large:     return 0.60
        case .square40:  return 0.40
        case .square60:  return 0.60
        case .panoramic: return 1.00
        }
    }

    /// Height in metres
    var heightM: Float {
        switch self {
        case .a5:        return 0.210
        case .a4:        return 0.297
        case .a3:        return 0.420
        case .medium:    return 0.70
        case .large:     return 0.90
        case .square40:  return 0.40
        case .square60:  return 0.60
        case .panoramic: return 0.40
        }
    }

    var label: String {
        switch self {
        case .a5:        return "A5 (15×21 cm)"
        case .a4:        return "A4 (21×30 cm)"
        case .a3:        return "A3 (30×42 cm)"
        case .medium:    return "Medium (50×70 cm)"
        case .large:     return "Large (60×90 cm)"
        case .square40:  return "Square (40×40 cm)"
        case .square60:  return "Square (60×60 cm)"
        case .panoramic: return "Panoramic (100×40 cm)"
        }
    }
}

// MARK: - Frame Styles

enum FrameStyle: String, CaseIterable, Identifiable, Codable {
    case thinBlack   = "Thin Black"
    case thinWhite   = "Thin White"
    case classicGold = "Classic Gold"
    case classicWood = "Classic Wood"
    case boldBlack   = "Bold Black"
    case floating    = "Floating"
    case noFrame     = "No Frame"

    var id: String { rawValue }

    var borderWidthM: Float {
        switch self {
        case .thinBlack, .thinWhite:     return 0.015
        case .classicGold, .classicWood: return 0.035
        case .boldBlack:                 return 0.050
        case .floating:                  return 0.005
        case .noFrame:                   return 0.0
        }
    }

    var frameColor: UIColor {
        switch self {
        case .thinBlack:   return UIColor(white: 0.10, alpha: 1)
        case .thinWhite:   return UIColor(white: 0.95, alpha: 1)
        case .classicGold: return UIColor(red: 0.76, green: 0.60, blue: 0.32, alpha: 1)
        case .classicWood: return UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)
        case .boldBlack:   return UIColor(white: 0.05, alpha: 1)
        case .floating:    return UIColor(white: 0.15, alpha: 1)
        case .noFrame:     return .clear
        }
    }

    var isMetallic: Bool { self == .classicGold }

    var frameDepthM: Float {
        switch self {
        case .thinBlack, .thinWhite:     return 0.020
        case .classicGold, .classicWood: return 0.030
        case .boldBlack:                 return 0.040
        case .floating:                  return 0.012
        case .noFrame:                   return 0.005
        }
    }

    /// SwiftUI preview color
    var previewColor: Color { Color(frameColor) }
}

// MARK: - Light Fixture Types

enum LightFixtureType: String, CaseIterable, Identifiable, Codable {
    case pendantGlobe  = "Pendant Globe"
    case pendantDrum   = "Pendant Drum"
    case chandelier    = "Chandelier"
    case ceilingFlush  = "Ceiling Flush"
    case wallSconce    = "Wall Sconce"
    case floorLamp     = "Floor Lamp"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pendantGlobe:  return "lightbulb.fill"
        case .pendantDrum:   return "light.max.fill"
        case .chandelier:    return "sparkles"
        case .ceilingFlush:  return "circle.fill"
        case .wallSconce:    return "lightbulb.2.fill"
        case .floorLamp:     return "lamp.floor.fill"
        }
    }

    var label: String { rawValue }

    var subtitle: String {
        switch self {
        case .pendantGlobe:  return "Globe on a thin rod"
        case .pendantDrum:   return "Cylindrical drum shade"
        case .chandelier:    return "Multi-arm classic chandelier"
        case .ceilingFlush:  return "Flat ceiling-mounted disc"
        case .wallSconce:    return "Wall-mounted bracket light"
        case .floorLamp:     return "Standing floor lamp"
        }
    }

    var placement: LightPlacement {
        switch self {
        case .pendantGlobe, .pendantDrum, .chandelier, .ceilingFlush:
            return .ceiling
        case .wallSconce:
            return .wall
        case .floorLamp:
            return .floor
        }
    }
}

enum LightPlacement: String, Codable {
    case ceiling, wall, floor
}

// MARK: - Carpet / Rug Sizes

enum CarpetSize: String, CaseIterable, Identifiable, Codable {
    case small80x150  = "80×150"
    case medium120x170 = "120×170"
    case medium160x230 = "160×230"
    case large200x300  = "200×300"
    case large250x350  = "250×350"
    case runner70x200  = "70×200"
    case round120     = "Round 120"
    case round200     = "Round 200"
    case custom       = "Custom"

    var id: String { rawValue }

    /// Width in metres (X-axis)
    var widthM: Float {
        switch self {
        case .small80x150:   return 0.80
        case .medium120x170: return 1.20
        case .medium160x230: return 1.60
        case .large200x300:  return 2.00
        case .large250x350:  return 2.50
        case .runner70x200:  return 0.70
        case .round120:      return 1.20
        case .round200:      return 2.00
        case .custom:        return 1.50     // default; overridden by user input
        }
    }

    /// Depth in metres (Z-axis)
    var depthM: Float {
        switch self {
        case .small80x150:   return 1.50
        case .medium120x170: return 1.70
        case .medium160x230: return 2.30
        case .large200x300:  return 3.00
        case .large250x350:  return 3.50
        case .runner70x200:  return 2.00
        case .round120:      return 1.20
        case .round200:      return 2.00
        case .custom:        return 2.00     // default; overridden by user input
        }
    }

    var isRound: Bool {
        self == .round120 || self == .round200
    }

    var label: String {
        switch self {
        case .small80x150:   return "Small (80×150 cm)"
        case .medium120x170: return "Medium (120×170 cm)"
        case .medium160x230: return "Medium (160×230 cm)"
        case .large200x300:  return "Large (200×300 cm)"
        case .large250x350:  return "XL (250×350 cm)"
        case .runner70x200:  return "Runner (70×200 cm)"
        case .round120:      return "Round Ø120 cm"
        case .round200:      return "Round Ø200 cm"
        case .custom:        return "Custom Size"
        }
    }

    var icon: String {
        switch self {
        case .runner70x200: return "rectangle"
        case .round120, .round200: return "circle"
        case .custom: return "ruler"
        default: return "rectangle.fill"
        }
    }
}

// MARK: - Carpet Patterns / Textures

enum CarpetPattern: String, CaseIterable, Identifiable, Codable {
    case solid       = "Solid"
    case striped     = "Striped"
    case geometric   = "Geometric"
    case shaggy      = "Shaggy"
    case oriental    = "Oriental"
    case herringbone = "Herringbone"

    var id: String { rawValue }

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .solid:       return "square.fill"
        case .striped:     return "line.3.horizontal"
        case .geometric:   return "diamond.fill"
        case .shaggy:      return "cloud.fill"
        case .oriental:    return "seal.fill"
        case .herringbone: return "chevron.up.chevron.down"
        }
    }

    var subtitle: String {
        switch self {
        case .solid:       return "Flat single colour"
        case .striped:     return "Classic parallel stripes"
        case .geometric:   return "Modern diamond / triangle motif"
        case .shaggy:      return "Deep-pile plush texture"
        case .oriental:    return "Traditional ornate design"
        case .herringbone: return "Woven V-shaped weave"
        }
    }
}
