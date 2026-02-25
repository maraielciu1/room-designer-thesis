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
        VStack(spacing: 0) {
            // Tab picker
            Picker("Library", selection: $selectedTab) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .scanned:
                scannedSection
            case .builtIn:
                builtInSection
            }
        }
        .navigationTitle("My Furniture")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showObjectScan = true }) {
                    Label("Scan Object", systemImage: "cube.transparent")
                }
            }
        }
        .fullScreenCover(isPresented: $showObjectScan) {
            // No NavigationView wrapper here — ObjectScanView manages its own
            // navigation per phase. During capture, ObjectCaptureView MUST be
            // the root view with zero overlays to show its built-in UI controls.
            ObjectScanView(onDismiss: { showObjectScan = false })
        }
    }

    // MARK: - Scanned objects tab

    private var scannedSection: some View {
        Group {
            if userScans.isEmpty {
                scannedEmptyState
            } else {
                List {
                    ForEach(userScans) { item in
                        ScannedFurnitureRow(item: item)
                    }
                    .onDelete(perform: deleteScanned)
                }
            }
        }
    }

    private var scannedEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Scanned Objects")
                .font(.title2).fontWeight(.semibold)

            Text("Scan real-world furniture to create 3D models you can place in any room.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showObjectScan = true }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Scan Your First Object")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func deleteScanned(at offsets: IndexSet) {
        for index in offsets {
            scannedFurnitureManager.deleteFurniture(userScans[index])
        }
    }

    // MARK: - Built-in models tab

    private var builtInSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(catalogManager.getAllAvailableModels(), id: \.self) { name in
                    BuiltInModelCard(name: name)
                }
            }
            .padding()
        }
    }
}

// MARK: - Row Views

struct ScannedFurnitureRow: View {
    let item: ScannedFurniture

    var body: some View {
        HStack(spacing: 14) {
            // 3D thumbnail of the scanned model
            USDZThumbnailView(
                url: item.usdzURL,
                size: CGSize(width: 56, height: 56)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(item.category.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)

                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BuiltInModelCard: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    let name: String

    var body: some View {
        VStack(spacing: 8) {
            USDZThumbnailView(
                url: catalogManager.modelFileURL(for: name),
                size: CGSize(width: 80, height: 80)
            )

            Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        FurnitureLibraryView()
            .environmentObject(FurnitureCatalogManager())
            .environmentObject(ScannedFurnitureManager(userManager: UserManager()))
    }
}
