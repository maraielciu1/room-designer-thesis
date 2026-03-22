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
            Color(hex: 0x0B0D17).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Segmented picker (same top padding as Rooms page content) ──
                HStack(spacing: 6) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(selectedTab == tab ? .white : AppTheme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == tab
                                    ? AnyShapeStyle(AppTheme.accentGradientInline)
                                    : AnyShapeStyle(Color.white.opacity(0.06))
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                switch selectedTab {
                case .scanned: scannedSection
                case .builtIn: builtInSection
                }
            }
        }
        .navigationTitle("My Furniture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: 0x0B0D17).opacity(0.88), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showObjectScan = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                .accessibilityLabel("New scan")
            }
        }
        .fullScreenCover(isPresented: $showObjectScan) {
            ObjectScanView(onDismiss: { showObjectScan = false })
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
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.glowCyan.opacity(0.10))
                    .frame(width: 110, height: 110)
                    .blur(radius: 28)
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accentGradientInline)
            }

            Text("No Scanned Objects")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text("Scan real-world furniture to create\n3D models you can place in any room.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showObjectScan = true }) {
                Label("Scan Your First Object", systemImage: "camera.fill")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.top, 8)

            Spacer()
        }
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
                USDZThumbnailView(
                    url: item.usdzURL,
                    size: CGSize(width: 56, height: 56)
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.glowCyan.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Splat indicator badge
                if item.hasSplat {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(AppTheme.glowGreen)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(item.category.capitalized)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppTheme.glowCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.glowCyan.opacity(0.12))
                        .clipShape(Capsule())

                    // Reconstruction method badges
                    HStack(spacing: 3) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Text("OC")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())

                    if item.hasSplat {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.glowGreen)
                            Text("3DGS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppTheme.glowGreen)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.glowGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundColor(AppTheme.tertiaryText)

                    if item.hasSplat {
                        Text("• \(item.formattedSplatSize) splat")
                            .font(.caption2)
                            .foregroundColor(AppTheme.tertiaryText)
                    }

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(AppTheme.tertiaryText)

                    Text(item.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                // Import splat button (if no splat yet)
                if !item.hasSplat, let onImportSplat {
                    Button(action: onImportSplat) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(AppTheme.glowGreen.opacity(0.7))
                            .padding(8)
                            .background(AppTheme.glowGreen.opacity(0.10))
                            .clipShape(Circle())
                    }
                }

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(AppTheme.glowRed.opacity(0.7))
                            .padding(8)
                            .background(AppTheme.glowRed.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: AppTheme.cardCornerRadius)
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
        .glassCard(cornerRadius: AppTheme.cardCornerRadius)
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
