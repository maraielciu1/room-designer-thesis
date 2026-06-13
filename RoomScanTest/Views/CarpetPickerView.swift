//
//  CarpetPickerView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//
//  Lets the user choose a carpet/rug with a standard or custom
//  size, colour and pattern before placing it on the floor.
//

import SwiftUI

struct CarpetPickerView: View {
    @Environment(\.dismiss) var dismiss

    // Size
    @State private var selectedSize: CarpetSize = .medium160x230
    @State private var customWidthCm: String = "150"
    @State private var customDepthCm: String = "200"

    // Colour
    @State private var carpetColor: Color = Color(red: 0.55, green: 0.40, blue: 0.30)

    // Pattern
    @State private var selectedPattern: CarpetPattern = .solid

    /// Called when the user confirms - passes size enum, actual width/depth in metres,
    /// colour, and pattern.
    let onAdd: (CarpetSize, Float, Float, UIColor, CarpetPattern) -> Void

    // Resolved dimensions (accounts for custom input) 
    private var resolvedWidthM: Float {
        if selectedSize == .custom,
           let cm = Float(customWidthCm), cm > 0 {
            return cm / 100
        }
        return selectedSize.widthM
    }

    private var resolvedDepthM: Float {
        if selectedSize == .custom,
           let cm = Float(customDepthCm), cm > 0 {
            return cm / 100
        }
        return selectedSize.depthM
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        sizeSection
                        patternSection
                        colourSection
                        previewSection

                        // ── Add Button ──
                        Button {
                            onAdd(selectedSize,
                                  resolvedWidthM,
                                  resolvedDepthM,
                                  UIColor(carpetColor),
                                  selectedPattern)
                            dismiss()
                        } label: {
                            Label("Place Carpet", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Carpet / Rug")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.warmAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .appSheetBackground()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Size Section
    // ═══════════════════════════════════════════════════════════════

    private var sizeSection: some View {
        VStack(spacing: 10) {
            ThemeSectionHeader(title: "Size", icon: "ruler")

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 8) {
                ForEach(CarpetSize.allCases) { size in
                    Button { selectedSize = size } label: {
                        sizeCardLabel(size)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom dimension inputs (visible when "Custom" is selected)
            if selectedSize == .custom {
                customDimensionFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: selectedSize)
    }

    private func sizeCardLabel(_ size: CarpetSize) -> some View {
        let isSel = selectedSize == size
        return HStack(spacing: 6) {
            Image(systemName: size.icon)
                .font(.caption)
                .foregroundColor(isSel ? AppTheme.glowGreen : .white.opacity(0.5))

            Text(size.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSel ? AppTheme.glowGreen.opacity(0.18)
                            : AppTheme.secondaryTint.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSel ? AppTheme.glowGreen.opacity(0.5)
                              : Color.clear, lineWidth: 1)
        )
    }

    private var customDimensionFields: some View {
        HStack(spacing: 12) {
            dimensionField(label: "Width (cm)", text: $customWidthCm)
            dimensionField(label: "Depth (cm)", text: $customDepthCm)
        }
        .padding(.top, 6)
    }

    private func dimensionField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.secondaryText)

            TextField("", text: text)
                .keyboardType(.decimalPad)
                .font(.body.monospacedDigit())
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.warmAccent.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.glowGreen.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Pattern Section
    // ═══════════════════════════════════════════════════════════════

    private var patternSection: some View {
        VStack(spacing: 10) {
            ThemeSectionHeader(title: "Pattern", icon: "square.grid.3x3.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 10) {
                ForEach(CarpetPattern.allCases) { pat in
                    Button { selectedPattern = pat } label: {
                        patternCard(pat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func patternCard(_ pat: CarpetPattern) -> some View {
        let isSel = selectedPattern == pat
        return VStack(spacing: 6) {
            patternCardIcon(pat, isSelected: isSel)

            Text(pat.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Text(pat.subtitle)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(patternCardBG(isSelected: isSel))
        .overlay(patternCardBorder(isSelected: isSel))
    }

    private func patternCardIcon(_ pat: CarpetPattern, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected
                      ? AppTheme.glowGreen.opacity(0.15)
                      : AppTheme.secondaryTint.opacity(0.35))
                .frame(width: 44, height: 44)

            Image(systemName: pat.icon)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? AppTheme.glowGreen : .white.opacity(0.6))
        }
    }

    private func patternCardBG(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected
                  ? AppTheme.glowGreen.opacity(0.10)
                  : AppTheme.lightNeutral.opacity(0.06))
    }

    private func patternCardBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected
                    ? AppTheme.glowGreen.opacity(0.4)
                    : AppTheme.warmAccent.opacity(0.2), lineWidth: 1)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Colour Section
    // ═══════════════════════════════════════════════════════════════

    private var colourSection: some View {
        VStack(spacing: 10) {
            ThemeSectionHeader(title: "Colour", icon: "paintpalette.fill")

            HStack(spacing: 14) {
                ForEach(carpetColorPresets, id: \.name) { preset in
                    Button { carpetColor = preset.color } label: {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(carpetColor == preset.color
                                            ? AppTheme.glowGreen
                                            : AppTheme.warmAccent.opacity(0.3),
                                            lineWidth: 2))
                    }
                }

                Spacer()

                ColorPicker("", selection: $carpetColor, supportsOpacity: false)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
    }

    private var carpetColorPresets: [(name: String, color: Color)] {
        [
            ("Beige",    Color(red: 0.83, green: 0.75, blue: 0.65)),
            ("Charcoal", Color(red: 0.25, green: 0.25, blue: 0.27)),
            ("Navy",     Color(red: 0.10, green: 0.15, blue: 0.35)),
            ("Rust",     Color(red: 0.65, green: 0.30, blue: 0.18)),
            ("Sage",     Color(red: 0.50, green: 0.60, blue: 0.48)),
        ]
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Preview Section
    // ═══════════════════════════════════════════════════════════════

    private var previewSection: some View {
        VStack(spacing: 8) {
            ThemeSectionHeader(title: "Preview", icon: "eye.fill")

            carpetPreviewCard
        }
        .padding(.horizontal, 16)
    }

    private var carpetPreviewCard: some View {
        let wCm = Int(resolvedWidthM * 100)
        let dCm = Int(resolvedDepthM * 100)

        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.lightNeutral.opacity(0.06))
                .frame(height: 130)

            VStack(spacing: 6) {
                carpetPreviewShape

                Text("\(selectedPattern.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("\(wCm)×\(dCm) cm" + (selectedSize.isRound ? " (round)" : ""))
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var carpetPreviewShape: some View {
        let aspect = CGFloat(resolvedWidthM / resolvedDepthM)
        let previewH: CGFloat = 60
        let previewW = previewH * aspect

        if selectedSize.isRound {
            Circle()
                .fill(carpetColor)
                .frame(width: previewH, height: previewH)
                .overlay(
                    Circle()
                        .stroke(AppTheme.warmAccent.opacity(0.3), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(carpetColor)
                .frame(width: max(previewW, 30), height: previewH)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.warmAccent.opacity(0.3), lineWidth: 1))
        }
    }
}
