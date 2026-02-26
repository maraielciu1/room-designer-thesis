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

struct FurnitureLibraryView: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    @State private var showObjectScan = false
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
                // ── Custom segmented picker ──
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
                .padding(.vertical, 12)

                switch selectedTab {
                case .scanned: scannedSection
                case .builtIn: builtInSection
                }
            }
        }
        .navigationTitle("My Furniture")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showObjectScan = true }) {
                    Image(systemName: "cube.transparent")
                        .tintedIcon()
                }
            }
        }
        .fullScreenCover(isPresented: $showObjectScan) {
            ObjectScanView(onDismiss: { showObjectScan = false })
        }
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
                            ScannedFurnitureRow(item: item, onDelete: {
                                scannedFurnitureManager.deleteFurniture(item)
                            })
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

    var body: some View {
        HStack(spacing: 14) {
            // 3D thumbnail
            USDZThumbnailView(
                url: item.usdzURL,
                size: CGSize(width: 56, height: 56)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.glowCyan.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

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

                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundColor(AppTheme.tertiaryText)
                }

                Text(item.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }

            Spacer()

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
