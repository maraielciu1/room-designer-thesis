//
//  SmartSuggestionsService.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Analyses a room's current state and produces actionable
//  interior-design suggestions and statistics.
//

import Foundation
import RoomPlan
import simd

// MARK: - Suggestion Model

struct RoomSuggestion: Identifiable {
    let id = UUID()
    let icon: String       // SF Symbol name
    let title: String
    let detail: String
    let category: SuggestionCategory
    let priority: SuggestionPriority

    enum SuggestionCategory: String, CaseIterable {
        case lighting  = "Lighting"
        case furniture = "Furniture"
        case decor     = "Decor"
        case space     = "Space"
        case material  = "Material"
    }

    enum SuggestionPriority: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2

        static func < (lhs: SuggestionPriority, rhs: SuggestionPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Room Statistics

struct RoomStatistics {
    /// Total number of furniture items placed
    let totalFurniture: Int
    /// Number of wall art pieces
    let wallArtCount: Int
    /// Number of light fixtures
    let lightingCount: Int
    /// Number of carpets/rugs
    let carpetCount: Int
    /// Number of original scanned objects
    let scannedObjectCount: Int
    /// Number of replaced objects
    let replacedCount: Int
    /// Number of user-added (free-placed) items
    let addedCount: Int
    /// Floor coverage by carpets (percentage 0…100)
    let carpetCoverage: Float
    /// Furniture density (items per m²)
    let furnitureDensity: Float
    /// Is the room well-lit (based on fixture count relative to floor area)
    let lightingAdequacy: LightingAdequacy

    enum LightingAdequacy: String {
        case insufficient = "Insufficient"
        case adequate     = "Adequate"
        case wellLit      = "Well Lit"
        case overLit      = "Over-Lit"
    }
}

// MARK: - SmartSuggestionsService

enum SmartSuggestionsService {

    /// Analyse a room and produce statistics.
    static func computeStatistics(
        capturedRoom: CapturedRoom,
        replacements: [FurnitureReplacement],
        measurements: RoomMeasurements
    ) -> RoomStatistics {

        let wallArtCount   = replacements.filter { $0.isWallArt }.count
        let lightingCount  = replacements.filter { $0.isLighting }.count
        let carpetCount    = replacements.filter { $0.isCarpet }.count
        let decorCount     = wallArtCount + lightingCount + carpetCount
        let replacedCount  = replacements.filter { !$0.isDecor }.count
        let addedCount     = replacements.filter { $0.originalCategory == "added" }.count

        // Carpet coverage
        let carpetArea: Float = replacements.filter { $0.isCarpet }.reduce(0) { sum, rep in
            guard let sizeStr = rep.carpetSize,
                  let size = CarpetSize(rawValue: sizeStr) else { return sum }
            var w = size.widthM
            var d = size.depthM
            if size == .custom {
                if let cw = rep.carpetCustomWidthCm { w = Float(cw / 100) }
                if let cd = rep.carpetCustomDepthCm { d = Float(cd / 100) }
            }
            if size.isRound {
                let r = w / 2
                return sum + Float.pi * r * r
            }
            return sum + w * d
        }
        let carpetCoverage = measurements.floorArea > 0
            ? (carpetArea / measurements.floorArea) * 100
            : 0

        // Furniture density
        let totalFurniture = capturedRoom.objects.count + decorCount + addedCount
        let density = measurements.floorArea > 0
            ? Float(totalFurniture) / measurements.floorArea
            : 0

        // Lighting adequacy (rule of thumb: ~1 fixture per 8 m^2)
        let recommendedLights = max(1, Int(measurements.floorArea / 8))
        let adequacy: RoomStatistics.LightingAdequacy
        if lightingCount == 0 {
            adequacy = .insufficient
        } else if lightingCount < recommendedLights {
            adequacy = .adequate
        } else if lightingCount <= recommendedLights * 2 {
            adequacy = .wellLit
        } else {
            adequacy = .overLit
        }

        return RoomStatistics(
            totalFurniture: totalFurniture,
            wallArtCount: wallArtCount,
            lightingCount: lightingCount,
            carpetCount: carpetCount,
            scannedObjectCount: capturedRoom.objects.count,
            replacedCount: replacedCount,
            addedCount: addedCount,
            carpetCoverage: carpetCoverage,
            furnitureDensity: density,
            lightingAdequacy: adequacy
        )
    }

    /// Generate smart suggestions based on room analysis.
    static func generateSuggestions(
        capturedRoom: CapturedRoom,
        replacements: [FurnitureReplacement],
        measurements: RoomMeasurements,
        statistics: RoomStatistics
    ) -> [RoomSuggestion] {
        var suggestions: [RoomSuggestion] = []

        //  Lighting suggestions

        if statistics.lightingCount == 0 {
            suggestions.append(RoomSuggestion(
                icon: "lightbulb.fill",
                title: "Add Lighting",
                detail: "Your room has no light fixtures. Consider adding at least \(max(1, Int(measurements.floorArea / 4))) lights for a \(measurements.formattedFloorArea) room.",
                category: .lighting,
                priority: .high
            ))
        } else if statistics.lightingAdequacy == .adequate {
            let recommended = max(1, Int(measurements.floorArea / 4))
            let deficit = recommended - statistics.lightingCount
            if deficit > 0 {
                suggestions.append(RoomSuggestion(
                    icon: "lightbulb.fill",
                    title: "More Light Recommended",
                    detail: "Consider adding \(deficit) more fixture\(deficit == 1 ? "" : "s") for optimal illumination of your \(measurements.formattedFloorArea) space.",
                    category: .lighting,
                    priority: .medium
                ))
            }
        } else if statistics.lightingAdequacy == .overLit {
            suggestions.append(RoomSuggestion(
                icon: "lightbulb.slash",
                title: "Lighting Density High",
                detail: "You have \(statistics.lightingCount) fixtures in \(measurements.formattedFloorArea). Consider reducing for a cozier ambiance.",
                category: .lighting,
                priority: .low
            ))
        }

        // Wall art suggestions

        if statistics.wallArtCount == 0 && measurements.wallArea > 8 {
            suggestions.append(RoomSuggestion(
                icon: "photo.artframe",
                title: "Add Wall Decor",
                detail: "Your \(measurements.formattedWallArea) of wall space is bare. Wall art or photos can add personality.",
                category: .decor,
                priority: .medium
            ))
        }

        let wallArtDensity = measurements.wallArea > 0
            ? Float(statistics.wallArtCount) / measurements.wallArea
            : 0
        if wallArtDensity > 0.5 {
            suggestions.append(RoomSuggestion(
                icon: "photo.on.rectangle.angled",
                title: "Wall Art Density",
                detail: "You have many pieces on the walls. A gallery wall looks great, but ensure spacing for visual balance.",
                category: .decor,
                priority: .low
            ))
        }

        // Carpet / rug suggestions

        if statistics.carpetCount == 0 && measurements.floorArea > 6 {
            suggestions.append(RoomSuggestion(
                icon: "square.fill",
                title: "Add a Rug",
                detail: "A carpet or rug can define zones, add warmth, and reduce echo in your \(measurements.formattedFloorArea) room.",
                category: .decor,
                priority: .medium
            ))
        }

        if statistics.carpetCoverage > 80 {
            suggestions.append(RoomSuggestion(
                icon: "square.stack",
                title: "Heavy Floor Coverage",
                detail: "Carpets cover \(Int(statistics.carpetCoverage))% of the floor. Consider reducing for a more balanced look.",
                category: .decor,
                priority: .low
            ))
        }

        // Furniture / space suggestions

        if statistics.furnitureDensity > 2.5 {
            suggestions.append(RoomSuggestion(
                icon: "exclamationmark.triangle",
                title: "Room May Be Overcrowded",
                detail: "Furniture density is \(String(format: "%.1f", statistics.furnitureDensity)) items/m². Consider removing items for better flow.",
                category: .space,
                priority: .high
            ))
        } else if statistics.furnitureDensity < 0.3 && measurements.floorArea > 8 {
            suggestions.append(RoomSuggestion(
                icon: "rectangle.3.group",
                title: "Room Feels Sparse",
                detail: "Only \(String(format: "%.1f", statistics.furnitureDensity)) items/m². Adding furniture or decor could make the space feel more inviting.",
                category: .space,
                priority: .medium
            ))
        }

        // Material / planning suggestions 

        let estimates = MeasurementService.estimateMaterials(
            from: measurements,
            doorCount: capturedRoom.doors.count,
            windowCount: capturedRoom.windows.count
        )

        suggestions.append(RoomSuggestion(
            icon: "paintbrush.fill",
            title: "Paint Estimate",
            detail: "You'd need approximately \(estimates.formattedPaint) of paint (2 coats) for the walls.",
            category: .material,
            priority: .low
        ))

        suggestions.append(RoomSuggestion(
            icon: "square.grid.3x3.fill",
            title: "Flooring Estimate",
            detail: "Flooring material needed: \(estimates.formattedFlooring) (includes 10% waste allowance).",
            category: .material,
            priority: .low
        ))

        if estimates.skirtingLength > 0 {
            suggestions.append(RoomSuggestion(
                icon: "ruler",
                title: "Skirting Board",
                detail: "Approx. \(estimates.formattedSkirting) of skirting / baseboard needed.",
                category: .material,
                priority: .low
            ))
        }

        // Sort by priority (high first)
        return suggestions.sorted { $0.priority > $1.priority }
    }
}
