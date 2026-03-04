//
//  WallArtPickerView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 04.03.2026.
//
//  Presents a photo picker, frame-size selector, and frame-style
//  selector so the user can hang custom wall art in the 3D room.
//

import SwiftUI
import PhotosUI

struct WallArtPickerView: View {
    @Environment(\.dismiss) var dismiss

    // ── Photo selection ──
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // ── Frame options ──
    @State private var frameSize: FrameSize   = .a4
    @State private var frameStyle: FrameStyle = .thinBlack

    /// Called when the user confirms — passes the chosen image, size and style.
    let onAdd: (UIImage, FrameSize, FrameStyle) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Photo Picker ──
                        VStack(spacing: 10) {
                            ThemeSectionHeader(title: "Choose Artwork",
                                               icon: "photo.on.rectangle.angled")

                            if let img = selectedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 160)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 36))
                                                .foregroundStyle(AppTheme.accentGradientInline)
                                            Text("Tap to select a photo")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                    )
                            }

                            PhotosPicker(selection: $pickerItem,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                Label(selectedImage == nil ? "Select Photo" : "Change Photo",
                                      systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                        .padding(.horizontal, 16)

                        // ── Frame Size ──
                        VStack(spacing: 10) {
                            ThemeSectionHeader(title: "Frame Size",
                                               icon: "aspectratio")

                            LazyVGrid(columns: [
                                GridItem(.flexible()), GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(FrameSize.allCases) { size in
                                    Button {
                                        frameSize = size
                                    } label: {
                                        HStack(spacing: 6) {
                                            // Aspect-ratio thumbnail
                                            let aspect = CGFloat(size.widthM / size.heightM)
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                                .frame(width: 22 * aspect, height: 22)

                                            Text(size.label)
                                                .font(.caption2.weight(.medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(frameSize == size
                                                      ? AppTheme.glowCyan.opacity(0.18)
                                                      : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(frameSize == size
                                                        ? AppTheme.glowCyan.opacity(0.5)
                                                        : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Frame Style ──
                        VStack(spacing: 10) {
                            ThemeSectionHeader(title: "Frame Style",
                                               icon: "square.on.square")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(FrameStyle.allCases) { style in
                                        Button {
                                            frameStyle = style
                                        } label: {
                                            VStack(spacing: 6) {
                                                // Preview swatch
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(style == .noFrame
                                                              ? Color.white.opacity(0.1)
                                                              : style.previewColor)
                                                        .frame(width: 38, height: 38)

                                                    if style != .noFrame {
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(Color.white.opacity(0.85))
                                                            .frame(width: 22, height: 22)
                                                    } else {
                                                        Image(systemName: "xmark")
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                    }
                                                }

                                                Text(style.rawValue)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                            .padding(6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(frameStyle == style
                                                          ? AppTheme.glowCyan.opacity(0.18)
                                                          : Color.clear)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(frameStyle == style
                                                            ? AppTheme.glowCyan.opacity(0.5)
                                                            : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Live Preview ──
                        if let img = selectedImage {
                            VStack(spacing: 8) {
                                ThemeSectionHeader(title: "Preview", icon: "eye.fill")
                                artPreview(image: img)
                            }
                            .padding(.horizontal, 16)
                        }

                        // ── Add Button ──
                        Button {
                            if let img = selectedImage {
                                onAdd(img, frameSize, frameStyle)
                                dismiss()
                            }
                        } label: {
                            Label("Hang on Wall", systemImage: "photo.artframe")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .disabled(selectedImage == nil)
                        .opacity(selectedImage == nil ? 0.5 : 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Wall Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // ── Preview card with frame + image ──

    @ViewBuilder
    private func artPreview(image: UIImage) -> some View {
        let aspect = CGFloat(frameSize.widthM / frameSize.heightM)
        let previewH: CGFloat = 140
        let previewW = previewH * aspect

        ZStack {
            if frameStyle != .noFrame {
                RoundedRectangle(cornerRadius: 4)
                    .fill(frameStyle.previewColor)
                    .frame(width: previewW + 12, height: previewH + 12)
            }

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: previewW, height: previewH)
                .clipped()
        }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }
}
