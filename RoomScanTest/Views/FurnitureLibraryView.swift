//
//  FurnitureLibraryView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 20.02.2026.
//
//  "My Furniture" — shows both built-in USDZ models and user-scanned objects.
//  The user can scan new objects (Object Capture) or browse/delete scanned ones.
//

import SwiftUI
import UniformTypeIdentifiers

struct FurnitureLibraryView: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    @State private var showObjectScan = false
    @State private var showSHARPCapture = false
    @State private var showImportSplat = false
    @State private var importTargetItem: ScannedFurniture?
    @State private var selectedTab: LibraryTab = .scanned

    enum LibraryTab: String, CaseIterable {
        case scanned = "My Scans"
        case builtIn = "Built-in"
    }

    private var userScans: [ScannedFurniture] {
        scannedFurnitureManager.getFurnitureForCurrentUser()
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Segmented picker ─────────────────────────────────────────
                HStack(spacing: 6) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.appCallout.weight(.semibold))
                                .foregroundColor(selectedTab == tab ? .white : AppTheme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == tab
                                    ? AnyShapeStyle(AppTheme.accentGradient)
                                    : AnyShapeStyle(AppTheme.surfaceTertiary)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        selectedTab == tab
                                        ? Color.clear
                                        : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(AppTheme.background)
                .overlay(alignment: .bottom) {
                    Divider().background(Color.white.opacity(0.07))
                }

                switch selectedTab {
                case .scanned: scannedSection
                case .builtIn: builtInSection
                }
            }
        }
        .navigationTitle("My Furniture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showObjectScan = true
                    } label: {
                        Label("Object Capture scan", systemImage: "cube.transparent")
                    }
                    Button {
                        showSHARPCapture = true
                    } label: {
                        Label("SHARP — one photo splat", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                .accessibilityLabel("New scan or SHARP capture")
            }
        }
        .fullScreenCover(isPresented: $showObjectScan) {
            ObjectScanView(onDismiss: { showObjectScan = false })
        }
        .fullScreenCover(isPresented: $showSHARPCapture) {
            NavigationStack {
                SHARPCaptureView()
            }
        }
        .fileImporter(
            isPresented: $showImportSplat,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleSplatImport(result)
        }
    }

    // MARK: - Splat Import

    private func handleSplatImport(_ result: Result<[URL], Error>) {
        guard let targetItem = importTargetItem else { return }

        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first,
                  sourceURL.pathExtension.lowercased() == "ply" else { return }

            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

            let splatName = "\(targetItem.id.uuidString)_splat.ply"
            let destURL = ScannedFurnitureManager.modelDirectory
                .appendingPathComponent(splatName)

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                let fileSize = (try? FileManager.default.attributesOfItem(
                    atPath: destURL.path))?[.size] as? Int64

                var gaussianCount: Int? = nil
                if let scene = try? PLYParser.parse(url: destURL) {
                    gaussianCount = scene.gaussians.count
                }

                scannedFurnitureManager.attachSplat(
                    to: targetItem,
                    splatFileName: splatName,
                    gaussianCount: gaussianCount,
                    fileSizeBytes: fileSize
                )
            } catch {
                print("[FurnitureLibrary] Splat import failed: \(error)")
            }

        case .failure(let error):
            print("[FurnitureLibrary] File picker error: \(error)")
        }
        importTargetItem = nil
    }

    // MARK: - Scanned objects tab

    private var scannedSection: some View {
        Group {
            if userScans.isEmpty {
                scannedEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(userScans) { item in
                            NavigationLink(destination:
                                ReconstructionComparisonView(furniture: item)
                            ) {
                                ScannedFurnitureRow(
                                    item: item,
                                    onDelete: {
                                        scannedFurnitureManager.deleteFurniture(item)
                                    },
                                    onImportSplat: {
                                        importTargetItem = item
                                        showImportSplat = true
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var scannedEmptyState: some View {
        AppEmptyState(
            icon: "cube.transparent",
            title: "No Scanned Objects",
            message: "Scan real-world furniture to create\n3D models you can place in any room.",
            ctaLabel: "Scan Your First Object",
            action: { showObjectScan = true }
        )
    }

    // MARK: - Built-in models tab

    private var builtInSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(catalogManager.getAllAvailableModels(), id: \.self) { name in
                    BuiltInModelCard(name: name)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Row Views

struct ScannedFurnitureRow: View {
    let item: ScannedFurniture
    var onDelete: (() -> Void)? = nil
    var onImportSplat: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            // 3D thumbnail
            ZStack(alignment: .bottomTrailing) {
                USDZThumbnailView(url: item.usdzURL, size: CGSize(width: 54, height: 54))
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                if item.hasSplat {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(AppTheme.glowGreen)
                        .clipShape(Circle())
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.appHeadline)
                    .foregroundColor(AppTheme.primaryText)

                HStack(spacing: 5) {
                    StatusChip(label: item.category.capitalized, color: AppTheme.accentLight)
                    StatusChip(label: "OC", color: AppTheme.accent)
                    if item.hasSplat {
                        StatusChip(label: "3DGS", color: AppTheme.glowGreen)
                    }
                }

                HStack(spacing: 4) {
                    Text(item.formattedSize)
                    if item.hasSplat { Text("· \(item.formattedSplatSize) splat") }
                    Text("· \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.appCaption2)
                .foregroundColor(AppTheme.tertiaryText)
            }

            Spacer()

            VStack(spacing: 8) {
                if !item.hasSplat, let onImportSplat {
                    Button(action: onImportSplat) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.glowGreen)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.glowGreen.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.glowRed)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.glowRed.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .classicCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

struct BuiltInModelCard: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    let name: String

    var body: some View {
        VStack(spacing: 8) {
            USDZThumbnailView(
                url: catalogManager.modelFileURL(for: name),
                size: CGSize(width: 72, height: 72)
            )

            Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .classicCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

#Preview {
    NavigationView {
        FurnitureLibraryView()
            .environmentObject(FurnitureCatalogManager())
            .environmentObject(ScannedFurnitureManager(userManager: UserManager()))
    }
    .preferredColorScheme(.dark)
}
