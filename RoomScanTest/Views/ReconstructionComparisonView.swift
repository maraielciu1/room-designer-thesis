//
//  ReconstructionComparisonView.swift
//  RoomScanTest
//
//  Side-by-side comparison of Apple Object Capture (USDZ) vs
//  Gaussian Splatting (.ply) reconstruction of the same object.
//

import SwiftUI
import QuickLook
import RealityKit

// MARK: - Comparison View

struct ReconstructionComparisonView: View {
    let furniture: ScannedFurniture
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager

    enum ViewMode: String, CaseIterable {
        case objectCapture = "Object Capture"
        case gaussianSplat = "Gaussian Splat"
        case sideBySide    = "Side by Side"
    }

    @State private var viewMode: ViewMode = .sideBySide
    @State private var showImportSplat = false
    @State private var showExportImages = false
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var showGSGuide = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Mode Picker ──
                modePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // ── Content ──
                switch viewMode {
                case .objectCapture:
                    objectCapturePanel
                        .transition(.opacity)
                case .gaussianSplat:
                    gaussianSplatPanel
                        .transition(.opacity)
                case .sideBySide:
                    sideBySidePanel
                        .transition(.opacity)
                }

                // ── Stats Bar ──
                statsBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Compare Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !furniture.hasSplat {
                        Button(action: { showImportSplat = true }) {
                            Label("Import .ply Splat", systemImage: "square.and.arrow.down")
                        }
                    }
                    Button(action: exportImages) {
                        Label("Export Images for Training", systemImage: "photo.stack")
                    }
                    Divider()
                    Button(action: { showGSGuide = true }) {
                        Label("How to Train a Splat", systemImage: "questionmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .tintedIcon()
                }
            }
        }
        .fileImporter(
            isPresented: $showImportSplat,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleSplatImport(result)
        }
        .overlay {
            if isExporting {
                exportOverlay
            }
        }
        .sheet(isPresented: $showGSGuide) {
            GaussianSplattingGuideView()
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                let isDisabled = mode == .gaussianSplat && !furniture.hasSplat
                    || mode == .sideBySide && !furniture.hasSplat

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(viewMode == mode ? .white :
                                            isDisabled ? AppTheme.tertiaryText : AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewMode == mode
                            ? AnyShapeStyle(AppTheme.accentGradientInline)
                            : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                        .clipShape(Capsule())
                }
                .disabled(isDisabled)
            }
        }
    }

    // MARK: - Object Capture Panel

    private var objectCapturePanel: some View {
        VStack(spacing: 12) {
            // USDZ 3D preview
            USDZPreviewCard(url: furniture.usdzURL, title: "Apple Object Capture")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 16) {
                StatBadge(label: "Method", value: "Photogrammetry", icon: "cube.fill", color: .blue)
                StatBadge(label: "Format", value: "USDZ", icon: "doc.fill", color: .blue)
                StatBadge(label: "Size", value: furniture.formattedSize, icon: "internaldrive", color: .blue)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Gaussian Splat Panel

    @ViewBuilder
    private var gaussianSplatPanel: some View {
        if furniture.hasSplat, let splatURL = furniture.splatURL {
            VStack(spacing: 12) {
                GaussianSplatView(plyURL: splatURL)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .stroke(AppTheme.glowGreen.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 16) {
                    StatBadge(label: "Method", value: "3DGS", icon: "sparkles", color: AppTheme.glowGreen)
                    StatBadge(label: "Format", value: "PLY", icon: "doc.fill", color: AppTheme.glowGreen)
                    StatBadge(label: "Size", value: furniture.formattedSplatSize, icon: "internaldrive", color: AppTheme.glowGreen)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        } else {
            noSplatPlaceholder
        }
    }

    // MARK: - Side-by-Side Panel

    @ViewBuilder
    private var sideBySidePanel: some View {
        if furniture.hasSplat, let splatURL = furniture.splatURL {
            HStack(spacing: 8) {
                // Left: Object Capture
                VStack(spacing: 6) {
                    methodLabel("Object Capture", color: .blue)
                    USDZPreviewCard(url: furniture.usdzURL, title: nil)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Right: Gaussian Splat
                VStack(spacing: 6) {
                    methodLabel("Gaussian Splat", color: AppTheme.glowGreen)
                    GaussianSplatView(plyURL: splatURL)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.glowGreen.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            noSplatPlaceholder
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        VStack(spacing: 8) {
            Divider().background(Color.white.opacity(0.1))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("USDZ").font(.caption2.weight(.bold)).foregroundColor(.blue)
                    Text(furniture.formattedSize)
                        .font(.caption2).foregroundColor(AppTheme.secondaryText)
                }

                if furniture.hasSplat {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLY").font(.caption2.weight(.bold)).foregroundColor(AppTheme.glowGreen)
                        Text(furniture.formattedSplatSize)
                            .font(.caption2).foregroundColor(AppTheme.secondaryText)
                    }

                    if let count = furniture.splatGaussianCount {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gaussians").font(.caption2.weight(.bold)).foregroundColor(AppTheme.glowGreen)
                            Text(count.formatted())
                                .font(.caption2).foregroundColor(AppTheme.secondaryText)
                        }
                    }
                }

                Spacer()

                if let dims = furniture.realWorldSize {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Dimensions").font(.caption2.weight(.bold)).foregroundColor(AppTheme.secondaryText)
                        Text(String(format: "%.0f×%.0f×%.0f cm",
                                    dims.x * 100, dims.y * 100, dims.z * 100))
                            .font(.caption2).foregroundColor(AppTheme.tertiaryText)
                    }
                }
            }
        }
    }

    // MARK: - No Splat Placeholder

    private var noSplatPlaceholder: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.glowGreen.opacity(0.08))
                    .frame(width: 110, height: 110)
                    .blur(radius: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.glowGreen.opacity(0.5))
            }

            Text("No Gaussian Splat Available")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text("Export your scan images and train a\nGaussian Splat model externally, then\nimport the .ply file here.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: exportImages) {
                    Label("Export Images for Training", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GradientButtonStyle())

                Button(action: { showImportSplat = true }) {
                    Label("Import .ply File", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(GhostButtonStyle())

                Button(action: { showGSGuide = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("How to Train a Gaussian Splat")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.top, 4)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func methodLabel(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Export Images

    private func exportImages() {
        // Look for images in the capture session directory
        let captureDir = ScannedFurnitureManager.captureSessionDirectory
        let count = ImageExportService.imageCount(in: captureDir)

        if count == 0 {
            exportMessage = "No captured images found. Images are only available immediately after scanning an object."
            isExporting = false
            return
        }

        isExporting = true
        exportMessage = "Packaging \(count) images…"

        Task {
            do {
                let zipURL = try await ImageExportService.createZip(from: captureDir)
                await MainActor.run {
                    isExporting = false
                    ImageExportService.share(fileURL: zipURL)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Import Splat

    private func handleSplatImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            // Verify it's a .ply file
            guard sourceURL.pathExtension.lowercased() == "ply" else {
                exportMessage = "Please select a .ply file."
                return
            }

            // Start accessing security-scoped resource
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

            // Copy to model directory
            let splatName = "\(furniture.id.uuidString)_splat.ply"
            let destURL = ScannedFurnitureManager.modelDirectory
                .appendingPathComponent(splatName)

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                let fileSize = (try? FileManager.default.attributesOfItem(
                    atPath: destURL.path))?[.size] as? Int64

                // Parse to get Gaussian count
                var gaussianCount: Int? = nil
                if let scene = try? PLYParser.parse(url: destURL) {
                    gaussianCount = scene.gaussians.count
                }

                // Update metadata
                scannedFurnitureManager.attachSplat(
                    to: furniture,
                    splatFileName: splatName,
                    gaussianCount: gaussianCount,
                    fileSizeBytes: fileSize
                )

                // Switch to splat view
                withAnimation { viewMode = .sideBySide }

            } catch {
                exportMessage = "Import failed: \(error.localizedDescription)"
            }

        case .failure(let error):
            exportMessage = "File picker error: \(error.localizedDescription)"
        }
    }

    // MARK: - Export Overlay

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppTheme.glowCyan)
                    .scaleEffect(1.3)
                Text(exportMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .glassCard(cornerRadius: 20)
        }
    }
}

// MARK: - USDZ Preview Card

struct USDZPreviewCard: View {
    let url: URL
    let title: String?

    var body: some View {
        VStack(spacing: 6) {
            if let title {
                HStack(spacing: 5) {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            // 3D model preview
            Model3DPreview(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

// MARK: - Model3D Preview (RealityKit)

struct Model3DPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.init(white: 0.05, alpha: 1))

        // Basic lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.color = .white
        directionalLight.light.intensity = 1000
        directionalLight.look(at: .zero, from: [2, 4, 2], relativeTo: nil)

        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(directionalLight)
        arView.scene.addAnchor(lightAnchor)

        // Load model
        Task {
            do {
                let entity = try await Entity(contentsOf: url)
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)

                // Center and fit model
                let bounds = entity.visualBounds(relativeTo: anchor)
                let center = bounds.center
                entity.position = -center
                let maxExt = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxExt > 0.001 {
                    let scale = 0.5 / maxExt
                    entity.scale = [scale, scale, scale]
                }
            } catch {
                print("[Model3DPreview] Failed to load: \(error)")
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) { }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 10)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ReconstructionComparisonView(
            furniture: ScannedFurniture(
                name: "Test Chair",
                userId: UUID(),
                usdzFileName: "test.usdz"
            )
        )
        .environmentObject(ScannedFurnitureManager(userManager: UserManager()))
    }
    .preferredColorScheme(.dark)
}
