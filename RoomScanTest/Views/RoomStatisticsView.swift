//
//  RoomStatisticsView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Displays room measurements, object counts, material estimates,
//  and smart design suggestions in a modern bottom-sheet style.
//

import SwiftUI
import RoomPlan

struct RoomStatisticsView: View {
    @Environment(\.dismiss) var dismiss

    let room: Room

    // Computed once on init
    private let measurements: RoomMeasurements?
    private let statistics: RoomStatistics?
    private let suggestions: [RoomSuggestion]
    private let materialEstimates: MaterialEstimates?

    @State private var selectedTab: StatTab = .measurements

    enum StatTab: String, CaseIterable {
        case measurements = "Measurements"
        case objects      = "Objects"
        case materials    = "Materials"
        case tips         = "Smart Tips"

        var icon: String {
            switch self {
            case .measurements: return "ruler"
            case .objects:      return "cube"
            case .materials:    return "paintbrush"
            case .tips:         return "lightbulb"
            }
        }
    }

    init(room: Room) {
        self.room = room
        if let captured = room.getCapturedRoom() {
            let m = MeasurementService.measure(captured)
            self.measurements = m
            let stats = SmartSuggestionsService.computeStatistics(
                capturedRoom: captured,
                replacements: room.furnitureReplacements,
                measurements: m
            )
            self.statistics = stats
            self.suggestions = SmartSuggestionsService.generateSuggestions(
                capturedRoom: captured,
                replacements: room.furnitureReplacements,
                measurements: m,
                statistics: stats
            )
            self.materialEstimates = MeasurementService.estimateMaterials(
                from: m,
                doorCount: captured.doors.count,
                windowCount: captured.windows.count
            )
        } else {
            self.measurements = nil
            self.statistics = nil
            self.suggestions = []
            self.materialEstimates = nil
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                if measurements != nil {
                    VStack(spacing: 0) {
                        tabBar
                        ScrollView {
                            VStack(spacing: 20) {
                                switch selectedTab {
                                case .measurements:
                                    measurementsSection
                                case .objects:
                                    objectsSection
                                case .materials:
                                    materialsSection
                                case .tips:
                                    tipsSection
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 32)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Room Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatTab.allCases, id: \.rawValue) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func tabButton(_ tab: StatTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption.weight(.semibold))
                Text(tab.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isSelected ? .white : AppTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(AppTheme.accentGradientInline)
                    : AnyShapeStyle(Color.white.opacity(0.06))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : Color.white.opacity(0.1),
                    lineWidth: 1
                )
            )
        }
    }

    // MARK: - Measurements Tab

    private var measurementsSection: some View {
        VStack(spacing: 16) {
            if let m = measurements {
                // Hero card — dimensions
                heroCard(
                    icon: "cube.transparent",
                    title: "Room Dimensions",
                    value: m.formattedDimensions,
                    subtitle: "Width × Depth × Height"
                )

                // Grid of key metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricCard(icon: "square.dashed", label: "Floor Area", value: m.formattedFloorArea)
                    metricCard(icon: "rectangle.3.group", label: "Wall Area", value: m.formattedWallArea)
                    metricCard(icon: "arrow.triangle.2.circlepath", label: "Perimeter", value: m.formattedPerimeter)
                    metricCard(icon: "cube", label: "Volume", value: m.formattedVolume)
                    metricCard(icon: "rectangle.portrait", label: "Walls", value: "\(m.wallCount)")
                    metricCard(icon: "rectangle.bottomhalf.filled", label: "Floors", value: "\(m.floorCount)")
                    metricCard(icon: "door.left.hand.open", label: "Doors", value: "\(m.doorCount)")
                    metricCard(icon: "window.horizontal", label: "Windows", value: "\(m.windowCount)")
                }
            }
        }
    }

    // MARK: - Objects Tab

    private var objectsSection: some View {
        VStack(spacing: 16) {
            if let stats = statistics {
                heroCard(
                    icon: "shippingbox",
                    title: "Total Items",
                    value: "\(stats.totalFurniture)",
                    subtitle: "\(stats.scannedObjectCount) scanned + \(stats.replacedCount) replaced + \(stats.addedCount) added"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricCard(icon: "photo.artframe", label: "Wall Art", value: "\(stats.wallArtCount)")
                    metricCard(icon: "light.recessed", label: "Lighting", value: "\(stats.lightingCount)")
                    metricCard(icon: "square.fill", label: "Carpets", value: "\(stats.carpetCount)")
                    metricCard(icon: "arrow.left.arrow.right", label: "Replaced", value: "\(stats.replacedCount)")
                }

                // Density & lighting adequacy
                VStack(spacing: 12) {
                    ThemeSectionHeader(title: "Room Analysis", icon: "chart.bar.xaxis")
                        .padding(.top, 4)

                    infoRow(label: "Furniture Density",
                            value: String(format: "%.1f items/m²", stats.furnitureDensity),
                            icon: densityIcon(stats.furnitureDensity))
                    infoRow(label: "Carpet Coverage",
                            value: String(format: "%.0f%%", stats.carpetCoverage),
                            icon: "square.grid.3x3.fill")
                    infoRow(label: "Lighting Adequacy",
                            value: stats.lightingAdequacy.rawValue,
                            icon: lightingIcon(stats.lightingAdequacy))
                }
                .padding(16)
                .glassCard()
            }
        }
    }

    // MARK: - Materials Tab

    private var materialsSection: some View {
        VStack(spacing: 16) {
            if let est = materialEstimates, let m = measurements {
                heroCard(
                    icon: "paintbrush.fill",
                    title: "Material Estimates",
                    value: "",
                    subtitle: "Based on your room's measurements"
                )

                VStack(spacing: 12) {
                    materialRow(
                        icon: "paintbrush.pointed",
                        label: "Wall Paint (2 coats)",
                        value: est.formattedPaint,
                        detail: "Based on ~10 m²/L coverage"
                    )
                    Divider().background(Color.white.opacity(0.1))

                    materialRow(
                        icon: "square.grid.3x3.fill",
                        label: "Flooring Material",
                        value: est.formattedFlooring,
                        detail: "Includes 10% waste allowance"
                    )
                    Divider().background(Color.white.opacity(0.1))

                    materialRow(
                        icon: "ruler",
                        label: "Skirting / Baseboard",
                        value: est.formattedSkirting,
                        detail: "Perimeter minus door openings"
                    )
                }
                .padding(16)
                .glassCard()

                // Raw data card
                VStack(spacing: 12) {
                    ThemeSectionHeader(title: "Raw Values", icon: "tablecells")
                        .padding(.top, 4)

                    infoRow(label: "Paintable Wall Area",
                            value: String(format: "%.1f m²", m.wallArea - Float(m.doorCount) * 1.9 - Float(m.windowCount) * 1.5),
                            icon: "paintbrush")
                    infoRow(label: "Floor Area",
                            value: m.formattedFloorArea,
                            icon: "square.dashed")
                    infoRow(label: "Perimeter",
                            value: m.formattedPerimeter,
                            icon: "arrow.triangle.2.circlepath")
                }
                .padding(16)
                .glassCard()
            }
        }
    }

    // MARK: - Smart Tips Tab

    private var tipsSection: some View {
        VStack(spacing: 12) {
            if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.glowGreen)
                    Text("Looking Good!")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                    Text("No suggestions at this time. Your room design looks well balanced.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .glassCard()
            } else {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    // MARK: - Component Views

    private func heroCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.accentGradientInline)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            if !value.isEmpty {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.accentGradientInline)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.accentGradientInline)

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard()
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accentGradientInline)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(.white)
        }
    }

    private func materialRow(icon: String, label: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accentGradientInline)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }

            Spacer()

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(AppTheme.accentGradientInline)
        }
    }

    private func suggestionCard(_ suggestion: RoomSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title3)
                .foregroundColor(priorityColor(suggestion.priority))
                .frame(width: 32, height: 32)
                .background(priorityColor(suggestion.priority).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(suggestion.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }

                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentGradientInline)
            Text("No Scan Data")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text("Scan the room first to see measurements and statistics.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Helpers

    private func priorityColor(_ priority: RoomSuggestion.SuggestionPriority) -> Color {
        switch priority {
        case .high:   return AppTheme.glowRed
        case .medium: return AppTheme.glowOrange
        case .low:    return AppTheme.glowGreen
        }
    }

    private func densityIcon(_ density: Float) -> String {
        if density > 2.5 { return "exclamationmark.triangle" }
        if density < 0.3 { return "rectangle.3.group" }
        return "checkmark.circle"
    }

    private func lightingIcon(_ adequacy: RoomStatistics.LightingAdequacy) -> String {
        switch adequacy {
        case .insufficient: return "lightbulb.slash"
        case .adequate:     return "lightbulb"
        case .wellLit:      return "lightbulb.fill"
        case .overLit:      return "lightbulb.max"
        }
    }
}
