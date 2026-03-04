//
//  LightingPickerView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//
//  Lets the user choose a light fixture type, colour and
//  intensity before placing it in the 3D room.
//

import SwiftUI

struct LightingPickerView: View {
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: LightFixtureType = .pendantGlobe
    @State private var lightColor: Color = .white
    @State private var intensity: Double = 3000   // lumens

    /// Called when the user confirms — passes chosen fixture, UIColor and intensity.
    let onAdd: (LightFixtureType, UIColor, Float) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Fixture Type ──
                        VStack(spacing: 10) {
                            ThemeSectionHeader(title: "Fixture Type",
                                               icon: "lightbulb.fill")

                            LazyVGrid(columns: [
                                GridItem(.flexible()), GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(LightFixtureType.allCases) { fixture in
                                    Button {
                                        selectedType = fixture
                                    } label: {
                                        fixtureCard(fixture)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Light Colour ──
                        VStack(spacing: 10) {
                            ThemeSectionHeader(title: "Light Colour",
                                               icon: "paintpalette.fill")

                            HStack(spacing: 14) {
                                // Quick presets
                                ForEach(colorPresets, id: \.name) { preset in
                                    Button {
                                        lightColor = preset.color
                                    } label: {
                                        Circle()
                                            .fill(preset.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(lightColor == preset.color
                                                            ? AppTheme.glowCyan
                                                            : Color.white.opacity(0.15),
                                                            lineWidth: 2))
                                    }
                                }

                                Spacer()

                                ColorPicker("", selection: $lightColor, supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Intensity ──
                        VStack(spacing: 8) {
                            ThemeSectionHeader(title: "Intensity",
                                               icon: "sun.max.fill")

                            HStack(spacing: 12) {
                                Image(systemName: "sun.min.fill")
                                    .foregroundColor(AppTheme.secondaryText)
                                    .font(.caption)

                                Slider(value: $intensity, in: 500...8000, step: 250)
                                    .tint(AppTheme.glowCyan)

                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }

                            Text("\(Int(intensity)) lm")
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.horizontal, 16)

                        // ── Preview ──
                        fixturePreview
                            .padding(.horizontal, 16)

                        // ── Add Button ──
                        Button {
                            onAdd(selectedType,
                                  UIColor(lightColor),
                                  Float(intensity))
                            dismiss()
                        } label: {
                            Label("Place Light", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Lighting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // ── Fixture card ──

    @ViewBuilder
    private func fixtureCard(_ fixture: LightFixtureType) -> some View {
        let isSelected = selectedType == fixture
        let iconStyle: AnyShapeStyle = isSelected
            ? AnyShapeStyle(AppTheme.accentGradientInline)
            : AnyShapeStyle(Color.white.opacity(0.7))

        VStack(spacing: 8) {
            fixtureCardIcon(fixture, isSelected: isSelected, iconStyle: iconStyle)

            Text(fixture.label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(fixture.subtitle)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(fixtureCardBackground(isSelected: isSelected))
        .overlay(fixtureCardBorder(isSelected: isSelected))
    }

    private func fixtureCardIcon(_ fixture: LightFixtureType,
                                 isSelected: Bool,
                                 iconStyle: AnyShapeStyle) -> some View {
        ZStack {
            Circle()
                .fill(isSelected
                      ? AppTheme.glowCyan.opacity(0.15)
                      : Color.white.opacity(0.06))
                .frame(width: 50, height: 50)

            Image(systemName: fixture.icon)
                .font(.system(size: 22))
                .foregroundStyle(iconStyle)
        }
    }

    private func fixtureCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected
                  ? AppTheme.glowCyan.opacity(0.10)
                  : Color.white.opacity(0.04))
    }

    private func fixtureCardBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected
                    ? AppTheme.glowCyan.opacity(0.4)
                    : Color.white.opacity(0.08), lineWidth: 1)
    }

    // ── Visual preview ──

    private var fixturePreview: some View {
        VStack(spacing: 8) {
            ThemeSectionHeader(title: "Preview", icon: "eye.fill")

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 130)

                VStack(spacing: 4) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 40))
                        .foregroundColor(lightColor)
                        .shadow(color: lightColor.opacity(0.6), radius: 12)

                    Text(selectedType.label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)

                    Text("\(Int(intensity)) lm • \(selectedType.placement.rawValue)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }

    // ── Colour presets ──

    private var colorPresets: [(name: String, color: Color)] {
        [
            ("Warm", Color(red: 1.0, green: 0.87, blue: 0.68)),
            ("Daylight", Color.white),
            ("Cool", Color(red: 0.82, green: 0.90, blue: 1.0)),
            ("Amber", Color(red: 1.0, green: 0.75, blue: 0.35)),
        ]
    }
}
