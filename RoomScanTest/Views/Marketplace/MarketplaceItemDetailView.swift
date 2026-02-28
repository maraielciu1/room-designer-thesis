//
//  MarketplaceItemDetailView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI
import RealityKit
import QuickLook
import FirebaseAuth

/// Detail view for a marketplace item — preview, description, download & like.
struct MarketplaceItemDetailView: View {
    let item: MarketplaceItem

    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var marketplaceManager: MarketplaceManager

    @Environment(\.dismiss) private var dismiss

    @State private var isDownloading = false
    @State private var downloadedURL: URL?
    @State private var isLiked = false
    @State private var showQLPreview = false

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ── Header ──
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .tintedIcon()
                        }
                        Spacer()
                        if item.uploaderUid == authManager.firebaseUser?.uid {
                            Button {
                                Task {
                                    await marketplaceManager.deleteItem(item)
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .tintedIcon(AppTheme.glowRed)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // ── 3D Preview Placeholder ──
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.glowViolet.opacity(0.15), AppTheme.glowCyan.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 240)

                        if downloadedURL != nil {
                            // Show a simple preview label (full QuickLook via button)
                            VStack(spacing: 8) {
                                Image(systemName: "cube.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(AppTheme.accentGradientInline)
                                Text("Model Ready")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppTheme.glowGreen)
                                Button("View in AR") { showQLPreview = true }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.accentGradientInline)
                                    .clipShape(Capsule())
                            }
                            .quickLookPreview($downloadedURL)
                        } else {
                            Image(systemName: item.furnitureCategory.icon)
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.accentGradientInline)
                        }
                    }
                    .padding(.horizontal, 16)

                    // ── Info Section ──
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(item.name)
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Spacer()
                            // Like button
                            Button {
                                Task {
                                    guard let uid = authManager.firebaseUser?.uid else { return }
                                    await marketplaceManager.toggleLike(item: item, userId: uid)
                                    isLiked.toggle()
                                }
                            } label: {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundColor(isLiked ? AppTheme.glowRed : AppTheme.secondaryText)
                            }
                        }

                        // Category + tags
                        HStack(spacing: 8) {
                            Text(item.category.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentGradientInline)
                                .clipShape(Capsule())

                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.secondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }

                        if !item.description.isEmpty {
                            Text(item.description)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider().overlay(Color.white.opacity(0.08))

                        // Metadata
                        HStack(spacing: 24) {
                            metadataItem(icon: "person.fill", label: item.uploaderName)
                            metadataItem(icon: "arrow.down.circle", label: "\(item.downloadCount) downloads")
                            metadataItem(icon: "heart", label: "\(item.likeCount) likes")
                        }

                        HStack(spacing: 24) {
                            metadataItem(icon: "doc.fill", label: item.formattedSize)
                            if let dims = item.dimensions, dims.count >= 3 {
                                metadataItem(
                                    icon: "ruler",
                                    label: String(format: "%.0f × %.0f × %.0f cm",
                                                  dims[0]*100, dims[1]*100, dims[2]*100)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)

                    // ── Download / Use Button ──
                    if marketplaceManager.isModelCached(item) || downloadedURL != nil {
                        VStack(spacing: 10) {
                            Button("View in AR") { showQLPreview = true }
                                .buttonStyle(GradientButtonStyle())

                            Text("Model downloaded ✓")
                                .font(.caption)
                                .foregroundColor(AppTheme.glowGreen)
                        }
                    } else {
                        Button {
                            Task {
                                isDownloading = true
                                downloadedURL = await marketplaceManager.downloadModel(item)
                                isDownloading = false
                            }
                        } label: {
                            Group {
                                if isDownloading {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Downloading...")
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Download Model")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GradientButtonStyle())
                        .disabled(isDownloading)
                        .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .task {
            // Check initial like state & cache
            if let uid = authManager.firebaseUser?.uid {
                isLiked = await marketplaceManager.isLikedByUser(itemId: item.id, userId: uid)
            }
            if let cached = marketplaceManager.cachedModelURL(for: item) {
                downloadedURL = cached
            }
        }
    }

    private func metadataItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(AppTheme.glowCyan)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.tertiaryText)
        }
    }
}
