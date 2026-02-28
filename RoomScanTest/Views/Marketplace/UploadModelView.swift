//
//  UploadModelView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI

/// View to publish a scanned object from the local library to the community marketplace.
struct UploadModelView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var marketplaceManager: MarketplaceManager

    @Environment(\.dismiss) private var dismiss

    // MARK: - Local scanned furniture (read from on-device library)
    @State private var localItems: [ScannedFurniture] = []
    @State private var selectedItem: ScannedFurniture?

    // MARK: - Form fields
    @State private var name = ""
    @State private var description = ""
    @State private var selectedCategory = FurnitureCategory.other
    @State private var tagsText = ""       // comma-separated

    @State private var isUploading = false
    @State private var uploadSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                if uploadSuccess {
                    successView
                } else {
                    formContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .tintedIcon()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Upload to Marketplace")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear { loadLocalItems() }
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Select Local Model ──
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select a Scanned Model")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.secondaryText)

                    if localItems.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppTheme.glowOrange)
                            Text("No scanned models found. Scan an object first.")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(14)
                        .glassCard()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(localItems) { item in
                                    localItemCard(item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // ── Name & Description ──
                VStack(spacing: 14) {
                    AuthTextField(icon: "textformat", placeholder: "Model Name", text: $name)
                    AuthTextField(icon: "text.alignleft", placeholder: "Description (optional)", text: $description)
                }
                .padding(.horizontal, 16)

                // ── Category Picker ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.secondaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FurnitureCategory.allCases) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.caption)
                                        Text(cat.displayName)
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundColor(selectedCategory == cat ? .white : AppTheme.secondaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategory == cat
                                        ? AnyShapeStyle(AppTheme.accentGradientInline)
                                        : AnyShapeStyle(Color.white.opacity(0.06))
                                    )
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // ── Tags ──
                AuthTextField(icon: "tag", placeholder: "Tags (comma-separated)", text: $tagsText)
                    .padding(.horizontal, 16)

                // ── Selected model info ──
                if let sel = selectedItem {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill")
                            .foregroundStyle(AppTheme.accentGradientInline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sel.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Text(sel.formattedSize)
                                .font(.caption2)
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.glowGreen)
                    }
                    .padding(14)
                    .glassCard()
                    .padding(.horizontal, 16)
                }

                // ── Error ──
                if let err = marketplaceManager.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(AppTheme.glowRed)
                        .padding(.horizontal, 16)
                }

                // ── Upload Button ──
                Button {
                    Task { await performUpload() }
                } label: {
                    Group {
                        if isUploading {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Uploading…")
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("Publish to Marketplace")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(isUploading || !canUpload)
                .opacity(canUpload ? 1.0 : 0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.glowGreen)
            Text("Published!")
                .font(.title.weight(.bold))
                .foregroundColor(.white)
            Text("Your model is now live on the marketplace.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
            Button("Done") { dismiss() }
                .buttonStyle(GradientButtonStyle())
            Spacer()
        }
    }

    // MARK: - Helpers

    private var canUpload: Bool {
        selectedItem != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func localItemCard(_ item: ScannedFurniture) -> some View {
        Button {
            selectedItem = item
            if name.isEmpty { name = item.name }
            if let cat = FurnitureCategory(rawValue: item.category) {
                selectedCategory = cat
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: (FurnitureCategory(rawValue: item.category) ?? .other).icon)
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentGradientInline)
                    .frame(width: 56, height: 56)
                Text(item.name)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(
                        selectedItem?.id == item.id ? AppTheme.glowCyan : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }

    private func loadLocalItems() {
        // Load items directly from UserDefaults (same key as ScannedFurnitureManager)
        guard let data = UserDefaults.standard.data(forKey: "scanned_furniture_items"),
              let decoded = try? JSONDecoder().decode([ScannedFurniture].self, from: data) else { return }
        localItems = decoded
    }

    private func performUpload() async {
        guard let sel = selectedItem,
              let uploader = authManager.marketplaceUser else { return }

        isUploading = true
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let result = await marketplaceManager.uploadModel(
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: selectedCategory.rawValue,
            tags: tags,
            usdzFileURL: sel.usdzURL,
            dimensions: sel.realWorldDimensions,
            uploader: uploader
        )

        isUploading = false
        if result != nil {
            uploadSuccess = true
        }
    }
}
