//
//  RoomDesignerView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//
//  Interior Design Mode — 3D Room Scene Editor
//
//  After scanning with RoomPlan, the room's walls, floors, doors, windows,
//  and furniture are reconstructed in a fully virtual 3D scene (non-AR).
//  The user orbits the camera around the room, selects furniture objects,
//  drags them to reposition, and replaces them with USDZ models.
//
//  Camera controls:
//    • Two-finger drag  → orbit around the room
//    • Pinch            → zoom in / out
//  Object controls:
//    • Tap              → select / deselect
//    • Long press       → open full catalog
//    • One-finger drag  → move selected on floor plane
//    • Two-finger twist → rotate selected around Y axis
//

import SwiftUI
import simd
import RoomPlan
import RealityKit
import QuickLookThumbnailing

// MARK: - ScannedObject

struct ScannedObject: Identifiable {
    let id: UUID
    let stableId: String
    let object: CapturedRoom.Object?     // nil for user-added objects
    let transform: simd_float4x4
    let objectIndex: Int
    let isAdded: Bool
    let addedModelName: String?
    let dimensions: SIMD3<Float>

    /// Standard init for RoomPlan-detected objects
    init(id: UUID = UUID(), stableId: String, object: CapturedRoom.Object,
         transform: simd_float4x4, objectIndex: Int) {
        self.id = id
        self.stableId = stableId
        self.object = object
        self.transform = transform
        self.objectIndex = objectIndex
        self.isAdded = false
        self.addedModelName = nil
        self.dimensions = object.dimensions
    }

    /// Init for user-added (free-placed) objects
    init(id: UUID = UUID(), stableId: String, transform: simd_float4x4,
         addedModelName: String, dimensions: SIMD3<Float> = SIMD3<Float>(0.5, 0.5, 0.5)) {
        self.id = id
        self.stableId = stableId
        self.object = nil
        self.transform = transform
        self.objectIndex = -1
        self.isAdded = true
        self.addedModelName = addedModelName
        self.dimensions = dimensions
    }

    var categoryDescription: String {
        if isAdded {
            if addedModelName == "wallArt" { return "Wall Art" }
            if addedModelName == "lighting" { return "Light Fixture" }
            if addedModelName == "carpet" { return "Carpet / Rug" }
            return addedModelName?.replacingOccurrences(of: "_", with: " ").capitalized
                ?? "Added Furniture"
        }
        return object?.category.description ?? "Object"
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Helpers
// ═══════════════════════════════════════════════════════════════════

/// Extracts the `FurnitureReplacement.id` UUID embedded in a scene key.
/// Decor / added keys use the format "prefix_<UUID>", e.g. "wallArt_XXXXXXXX-…".
/// Returns `nil` for position-keyed objects like "obj_0_1.20_0.00_-0.50".
private func extractReplacementId(from key: String) -> UUID? {
    for prefix in ["wallArt_", "lighting_", "carpet_", "added_"] {
        if key.hasPrefix(prefix) {
            return UUID(uuidString: String(key.dropFirst(prefix.count)))
        }
    }
    return nil
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - RoomDesignerView
// ═══════════════════════════════════════════════════════════════════

struct RoomDesignerView: View {
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedObject: ScannedObject? = nil
    @State private var showFullCatalog = false
    @State private var arView: ARView?
    @State private var showDebugView = false
    @State private var showExportSheet = false
    @State private var exportImage: UIImage? = nil
    @State private var isManipulating = false
    @State private var resetSignal = false
    @State private var heightSignal: Int = 0
    @State private var heightDeltaValue: Float = 0
    @State private var showAddFurnitureCatalog = false
    @State private var showWallArtPicker = false
    @State private var showLightingPicker = false
    @State private var showCarpetPicker = false
    @State private var isFirstPersonCamera = false
    @State private var editorHintsExpanded = true
    @State private var wallColor: Color
    @State private var floorColor: Color
    @State private var wallPattern: SurfacePattern
    @State private var floorPattern: SurfacePattern
    @State private var colorChangeCount: Int = 0

    @State var room: Room

    init(room: Room) {
        _room = State(initialValue: room)
        if let mats = room.roomMaterials {
            _wallColor    = State(initialValue: mats.wallColor.color)
            _floorColor   = State(initialValue: mats.floorColor.color)
            _wallPattern  = State(initialValue: mats.wallPattern)
            _floorPattern = State(initialValue: mats.floorPattern)
        } else {
            _wallColor    = State(initialValue: Color(red: 0.7, green: 0.75, blue: 0.85))
            _floorColor   = State(initialValue: Color(red: 0.5, green: 0.5, blue: 0.5))
            _wallPattern  = State(initialValue: .none)
            _floorPattern = State(initialValue: .none)
        }
    }

    /// Whether the currently selected scanned object already has a replacement
    private var selectedReplacement: FurnitureReplacement? {
        guard let sel = selectedObject else { return nil }
        // Decor / added items embed their replacement UUID in the key — use it directly
        if let repId = extractReplacementId(from: sel.stableId) {
            return room.furnitureReplacements.first { $0.id == repId }
        }
        // Scanned furniture: fall back to position matching
        return room.furnitureReplacements.first { rep in
            guard let t = rep.getTransformMatrix() else { return false }
            let d = t.columns.3 - sel.transform.columns.3
            return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
        }
    }

    private var isSelectedObjectReplaced: Bool { selectedReplacement != nil }

    /// Resolves a display-friendly name for a model key.
    /// For scanned objects (`scanned_<uuid>`) it returns the user-given name
    /// from ScannedFurnitureManager; for built-in models it humanises the filename.
    private func friendlyModelName(_ key: String) -> String {
        if catalogManager.isScannedModel(key) {
            let uuidString = String(key.dropFirst("scanned_".count))
            if let uuid = UUID(uuidString: uuidString),
               let item = scannedFurnitureManager.items.first(where: { $0.id == uuid }) {
                return item.name
            }
        }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        ZStack {
            if let capturedRoom = room.getCapturedRoom() {
                RoomModelSceneView(
                    capturedRoom: capturedRoom,
                    room: $room,
                    selectedObject: $selectedObject,
                    showFullCatalog: $showFullCatalog,
                    arView: $arView,
                    isManipulating: $isManipulating,
                    resetSignal: $resetSignal,
                    heightSignal: heightSignal,
                    heightDelta: heightDeltaValue,
                    catalogManager: catalogManager,
                    roomManager: roomManager,
                    wallColor: wallColor,
                    floorColor: floorColor,
                    wallPattern: wallPattern,
                    floorPattern: floorPattern,
                    colorTrigger: colorChangeCount,
                    refreshTrigger: room.furnitureReplacements
                        .map { $0.id.hashValue &+ $0.replacedWithUSDZ.hashValue }
                        .reduce(room.furnitureReplacements.count, &+)
                )
                .edgesIgnoringSafeArea(.all)

                // ── Overlay UI ──
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal)
                        .padding(.top, 50)

                    Spacer()

                    bottomPanel(capturedRoom: capturedRoom)
                        .padding(.bottom, 20)

                    if showDebugView {
                        DebugObjectsView(room: room, capturedRoom: capturedRoom)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                            .padding(.bottom, 10)
                    }
                }
            } else {
                // No captured room data
                ZStack {
                    Color(hex: 0x0B0D17).ignoresSafeArea()

                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.glowOrange.opacity(0.12))
                                .frame(width: 110, height: 110)
                                .blur(radius: 25)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.glowOrange)
                        }
                        Text("Room Data Not Available")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                        Text("This room hasn't been scanned yet.\nGo back and scan it to get started.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)

                        Button(action: { dismiss() }) {
                            Label("Go Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(GradientButtonStyle())
                        .padding(.top, 6)
                    }
                    .padding(32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showFullCatalog) {
            if let selectedObject = selectedObject {
                FurniturePickerView(selectedObject: selectedObject, room: $room)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let image = exportImage {
                ShareSheet(activityItems: [image])
            }
        }
        .sheet(isPresented: $showAddFurnitureCatalog) {
            AddFurniturePickerView { modelName in
                addNewFurniture(modelName: modelName)
            }
        }
        .sheet(isPresented: $showWallArtPicker) {
            WallArtPickerView { image, frameSize, frameStyle in
                addWallArt(image: image, frameSize: frameSize, frameStyle: frameStyle)
            }
        }
        .sheet(isPresented: $showLightingPicker) {
            LightingPickerView { fixtureType, color, intensity in
                addLightFixture(type: fixtureType, color: color, intensity: intensity)
            }
        }
        .sheet(isPresented: $showCarpetPicker) {
            CarpetPickerView { size, widthM, depthM, color, pattern in
                addCarpet(size: size, widthM: widthM, depthM: depthM,
                          color: color, pattern: pattern)
            }
        }
        .onChange(of: room.id) { _, _ in roomManager.updateRoom(room) }
        .onChange(of: room.furnitureReplacements.count) { _, _ in roomManager.updateRoom(room) }
        .onChange(of: wallColor) { _, _ in
            saveRoomMaterials()
            colorChangeCount += 1
        }
        .onChange(of: floorColor) { _, _ in
            saveRoomMaterials()
            colorChangeCount += 1
        }
        .onChange(of: wallPattern) { _, _ in
            saveRoomMaterials()
            colorChangeCount += 1
        }
        .onChange(of: floorPattern) { _, _ in
            saveRoomMaterials()
            colorChangeCount += 1
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .tintedIcon()
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "view.3d")
                    .foregroundStyle(AppTheme.accentGradientInline)
                    .font(.system(size: 14))
                Text(room.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 12)

            Spacer()

            Button(action: {
                isFirstPersonCamera.toggle()
                switchCameraMode(firstPerson: isFirstPersonCamera)
            }) {
                Image(systemName: isFirstPersonCamera
                      ? "eye.fill" : "eye")
                    .tintedIcon(isFirstPersonCamera
                                ? AppTheme.glowGreen : AppTheme.glowCyan)
            }
            .help(isFirstPersonCamera ? "Orbit View" : "Room View")

            Button(action: takeScreenshot) {
                Image(systemName: "camera.fill")
                    .tintedIcon()
            }

            Button(action: { showDebugView.toggle() }) {
                Image(systemName: "info.circle")
                    .tintedIcon(AppTheme.glowViolet)
            }
        }
    }

    // MARK: Bottom Panel

    @ViewBuilder
    private func bottomPanel(capturedRoom: CapturedRoom) -> some View {
        if let selected = selectedObject {
            VStack(spacing: 0) {
                if isSelectedObjectReplaced || selected.isAdded {
                    manipulationBar(for: selected)
                } else {
                    objectInfoBar(for: selected)
                }
                FurnitureCatalogTray(
                    category: selected.object?.category,
                    onSelectModel: { replaceSelected(with: $0) },
                    onBrowseAll: { showFullCatalog = true }
                )
            }
            .glassCard(cornerRadius: AppTheme.cornerRadius)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedObject?.stableId)
        } else {
            VStack(spacing: 0) {
                // ── Collapsible header ──
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        editorHintsExpanded.toggle()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 36, height: 4)

                        HStack(spacing: 8) {
                            Image(systemName: "cube.transparent.fill")
                                .foregroundStyle(AppTheme.accentGradientInline)
                            Text("3D Room Editor")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AppTheme.secondaryText)
                                .rotationEffect(.degrees(editorHintsExpanded ? 0 : -180))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, editorHintsExpanded ? 4 : 14)
                }
                .buttonStyle(.plain)

                // ── Expandable content ──
                if editorHintsExpanded {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            hintRow(icon: "arrow.triangle.2.circlepath", text: "Two-finger drag to orbit")
                            hintRow(icon: "arrow.up.left.and.arrow.down.right", text: "Pinch to zoom")
                            hintRow(icon: "hand.tap", text: "Tap furniture to select")
                            hintRow(icon: "arrow.up.and.down.and.arrow.left.and.right", text: "Drag axis arrows to move")
                            hintRow(icon: "rotate.right", text: "Twist to rotate selected")
                        }

                        // ── Room Materials ──
                        VStack(spacing: 0) {
                            Divider().background(Color.white.opacity(0.1))
                                .padding(.bottom, 10)

                            HStack(spacing: 6) {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(AppTheme.accentGradientInline)
                                    .font(.system(size: 12))
                                Text("Room Materials")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.bottom, 8)

                            // ── Walls ──
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(wallColor)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    Text("Walls")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(AppTheme.secondaryText)
                                    ColorPicker("", selection: $wallColor, supportsOpacity: false)
                                        .labelsHidden()
                                        .scaleEffect(0.85)
                                }

                                patternRow(selection: $wallPattern, baseColor: wallColor)
                            }
                            .padding(.bottom, 10)

                            // ── Floors ──
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(floorColor)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    Text("Floor")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(AppTheme.secondaryText)
                                    ColorPicker("", selection: $floorColor, supportsOpacity: false)
                                        .labelsHidden()
                                        .scaleEffect(0.85)
                                }

                                patternRow(selection: $floorPattern, baseColor: floorColor)
                            }
                        }

                        // ── Add Buttons ──
                        VStack(spacing: 8) {
                            Button(action: { showAddFurnitureCatalog = true }) {
                                Label("Add Furniture", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(GradientButtonStyle())

                            HStack(spacing: 8) {
                                Button(action: { showWallArtPicker = true }) {
                                    Label("Wall Art", systemImage: "photo.artframe")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                .fill(Color.white.opacity(0.10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                        .stroke(AppTheme.glowCyan.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }

                                Button(action: { showLightingPicker = true }) {
                                    Label("Lighting", systemImage: "lightbulb.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                .fill(Color.white.opacity(0.10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                        .stroke(AppTheme.glowOrange.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }

                                Button(action: { showCarpetPicker = true }) {
                                    Label("Carpet", systemImage: "square.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                .fill(Color.white.opacity(0.10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                                        .stroke(AppTheme.glowGreen.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .glassCard(cornerRadius: AppTheme.cornerRadius)
            .padding(.horizontal, 12)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.height > 30 {
                                editorHintsExpanded = false
                            } else if value.translation.height < -30 {
                                editorHintsExpanded = true
                            }
                        }
                    }
            )
        }
    }

    private func hintRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundColor(AppTheme.secondaryText)
    }

    // MARK: Object Info Bar (unreplaced)

    private func objectInfoBar(for object: ScannedObject) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(object.categoryDescription)
                    .font(.subheadline.weight(.bold)).foregroundColor(.white)
                Text("Select a replacement below or drag to reposition")
                    .font(.caption2).foregroundColor(AppTheme.secondaryText)
            }
            Spacer()
            if isManipulating {
                Text("Moving…")
                    .font(.caption2.weight(.semibold)).foregroundColor(AppTheme.glowCyan)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(AppTheme.glowCyan.opacity(0.15)).cornerRadius(8)
            }
            Button { selectedObject = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.tertiaryText).font(.title3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Manipulation Bar (replaced)

    private func manipulationBar(for object: ScannedObject) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(friendlyModelName(selectedReplacement?.replacedWithUSDZ ?? "Furniture"))
                        .font(.subheadline.weight(.bold)).foregroundColor(.white)
                    Text("Drag an axis arrow to move / Twist to rotate")
                        .font(.caption2).foregroundColor(AppTheme.secondaryText)
                }
                Spacer()
                if isManipulating {
                    Text("Adjusting…")
                        .font(.caption2.weight(.semibold)).foregroundColor(AppTheme.glowGreen)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.glowGreen.opacity(0.15)).cornerRadius(8)
                }
                Button { selectedObject = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.tertiaryText).font(.title3)
                }
            }

            // ── Axis legend + actions ──
            HStack(spacing: 10) {
                // Axis colour key
                HStack(spacing: 8) {
                    axisLabel(color: .red,   text: "X")
                    axisLabel(color: .green, text: "Y ↕")
                    axisLabel(color: .blue,  text: "Z")
                }

                Spacer()

                Button(action: resetPosition) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(AppTheme.glowOrange.opacity(0.85))
                        .clipShape(Capsule())
                }
                Button(action: removeReplacement) {
                    Label("Remove", systemImage: "trash")
                        .font(.caption.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(AppTheme.glowRed.opacity(0.85))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Small coloured dot + label for the axis legend.
    private func axisLabel(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2.weight(.semibold)).foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: Material Persistence

    private func saveRoomMaterials() {
        let wc = CodableColor(from: wallColor)
        let fc = CodableColor(from: floorColor)
        if room.roomMaterials != nil {
            room.roomMaterials?.wallColor    = wc
            room.roomMaterials?.floorColor   = fc
            room.roomMaterials?.wallPattern  = wallPattern
            room.roomMaterials?.floorPattern = floorPattern
        } else {
            room.roomMaterials = RoomMaterials(
                wallColor: wc, floorColor: fc,
                wallPattern: wallPattern, floorPattern: floorPattern
            )
        }
        roomManager.updateRoom(room)
    }

    // MARK: Pattern Picker Row

    @ViewBuilder
    private func patternRow(selection: Binding<SurfacePattern>, baseColor: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SurfacePattern.allCases) { pattern in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection.wrappedValue = pattern
                        }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                if pattern == .none {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(baseColor)
                                        .frame(width: 38, height: 38)
                                } else {
                                    Image(uiImage: TextureGenerator.thumbnail(
                                        for: pattern,
                                        color: UIColor(baseColor)
                                    ))
                                    .resizable()
                                    .interpolation(.medium)
                                    .frame(width: 38, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        selection.wrappedValue == pattern
                                            ? Color.cyan : Color.white.opacity(0.15),
                                        lineWidth: selection.wrappedValue == pattern ? 2 : 1
                                    )
                            )

                            Text(pattern.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(
                                    selection.wrappedValue == pattern
                                        ? .white : .white.opacity(0.55)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Actions

    private func replaceSelected(with usdzFileName: String) {
        guard let selected = selectedObject else { return }
        if let repId = extractReplacementId(from: selected.stableId) {
            room.furnitureReplacements.removeAll { $0.id == repId }
        } else {
            room.furnitureReplacements.removeAll { rep in
                guard let t = rep.getTransformMatrix() else { return false }
                let d = t.columns.3 - selected.transform.columns.3
                return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
            }
        }
        let catDesc = selected.object?.category.description ?? "added"
        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: selected.isAdded ? "added" : "\(selected.object!.category)",
            replacedWithUSDZ: usdzFileName,
            transform: FurnitureReplacement.fromTransform(selected.transform)
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)
        historyManager.addHistoryEntry(
            roomId: room.id, replacementId: replacement.id, action: .replaced,
            details: "Replaced \(catDesc) with \(friendlyModelName(usdzFileName))"
        )
    }

    private func resetPosition() {
        guard let selected = selectedObject else { return }
        // Decor / added items: match by UUID; scanned furniture: match by position
        let idx: Int?
        if let repId = extractReplacementId(from: selected.stableId) {
            idx = room.furnitureReplacements.firstIndex { $0.id == repId }
        } else {
            let objPos = selected.transform.columns.3
            idx = room.furnitureReplacements.firstIndex(where: { rep in
                guard let t = rep.getTransformMatrix() else { return false }
                let d = t.columns.3 - objPos
                return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
            })
        }
        if let idx = idx {
            room.furnitureReplacements[idx].positionOffset = nil
            room.furnitureReplacements[idx].yRotation = nil
            room.furnitureReplacements[idx].customScale = nil
            roomManager.updateRoom(room)
        }
        resetSignal.toggle()
    }

    private func removeReplacement() {
        guard let selected = selectedObject else { return }

        if let repId = extractReplacementId(from: selected.stableId) {
            // Decor / added item — match by UUID
            if let rep = room.furnitureReplacements.first(where: { $0.id == repId }),
               rep.isWallArt, let imgFile = rep.wallArtImageFile {
                DecorManager.deleteImage(named: imgFile)
            }
            room.furnitureReplacements.removeAll { $0.id == repId }
        } else {
            // Scanned furniture — match by position
            let objPos = selected.transform.columns.3
            for rep in room.furnitureReplacements {
                guard let t = rep.getTransformMatrix() else { continue }
                let d = t.columns.3 - objPos
                let isMatch = abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
                if isMatch, rep.isWallArt, let imgFile = rep.wallArtImageFile {
                    DecorManager.deleteImage(named: imgFile)
                }
            }
            room.furnitureReplacements.removeAll { rep in
                guard let t = rep.getTransformMatrix() else { return false }
                let d = t.columns.3 - objPos
                return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
            }
        }
        roomManager.updateRoom(room)
        selectedObject = nil
    }

    // MARK: Add New Furniture (free-placed, not replacing anything)

    private func addNewFurniture(modelName: String) {
        // Place the new object at the centre of the room, on the floor
        guard let capturedRoom = room.getCapturedRoom() else { return }

        // Compute room centre
        var minB = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxB = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for wall in capturedRoom.walls {
            let p = SIMD3<Float>(wall.transform.columns.3.x,
                                 wall.transform.columns.3.y,
                                 wall.transform.columns.3.z)
            minB = min(minB, p - wall.dimensions * 0.5)
            maxB = max(maxB, p + wall.dimensions * 0.5)
        }
        for floor in capturedRoom.floors {
            let p = SIMD3<Float>(floor.transform.columns.3.x,
                                 floor.transform.columns.3.y,
                                 floor.transform.columns.3.z)
            minB = min(minB, p - floor.dimensions * 0.5)
            maxB = max(maxB, p + floor.dimensions * 0.5)
        }
        let center = (minB + maxB) * 0.5

        // Floor Y — the floor surface's center Y (= actual floor level)
        var floorY = minB.y
        if let firstFloor = capturedRoom.floors.first {
            floorY = firstFloor.transform.columns.3.y
        }

        // Build an identity transform positioned at the room centre, on the floor
        var xform = matrix_identity_float4x4
        xform.columns.3 = SIMD4<Float>(center.x, floorY + 0.25, center.z, 1)

        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: "added",
            replacedWithUSDZ: modelName,
            transform: FurnitureReplacement.fromTransform(xform)
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)

        historyManager.addHistoryEntry(
            roomId: room.id,
            replacementId: replacement.id,
            action: .replaced,
            details: "Added \(friendlyModelName(modelName)) to room"
        )
    }

    // MARK: Add Wall Art

    private func addWallArt(image: UIImage, frameSize: FrameSize, frameStyle: FrameStyle) {
        guard let capturedRoom = room.getCapturedRoom() else { return }
        guard let imageFile = DecorManager.saveImage(image) else { return }

        // Find the largest wall
        let sortedWalls = capturedRoom.walls.sorted {
            ($0.dimensions.x * $0.dimensions.y) > ($1.dimensions.x * $1.dimensions.y)
        }
        guard let wall = sortedWalls.first else { return }

        // Position the art at the wall's centre, offset slightly outward
        let wallNormal = simd_normalize(SIMD3<Float>(
            wall.transform.columns.2.x,
            wall.transform.columns.2.y,
            wall.transform.columns.2.z))
        let surfaceOffset = wall.dimensions.z / 2 + frameStyle.frameDepthM / 2 + 0.005
        var xform = wall.transform
        xform.columns.3 = SIMD4<Float>(
            SIMD3<Float>(wall.transform.columns.3.x,
                         wall.transform.columns.3.y,
                         wall.transform.columns.3.z) + wallNormal * surfaceOffset,
            1)

        let rgb = UIColor(Color.white)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: nil)

        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: "wallArt",
            replacedWithUSDZ: "wallArt",
            transform: FurnitureReplacement.fromTransform(xform),
            wallArtImageFile: imageFile,
            wallArtFrameSize: frameSize.rawValue,
            wallArtFrameStyle: frameStyle.rawValue
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)

        historyManager.addHistoryEntry(
            roomId: room.id, replacementId: replacement.id, action: .replaced,
            details: "Added wall art (\(frameSize.label), \(frameStyle.rawValue))")
    }

    // MARK: Add Light Fixture

    private func addLightFixture(type: LightFixtureType, color: UIColor, intensity: Float) {
        guard let capturedRoom = room.getCapturedRoom() else { return }

        // Room bounds for placement
        var minB = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxB = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for wall in capturedRoom.walls {
            let p = SIMD3<Float>(wall.transform.columns.3.x,
                                 wall.transform.columns.3.y,
                                 wall.transform.columns.3.z)
            minB = min(minB, p - wall.dimensions * 0.5)
            maxB = max(maxB, p + wall.dimensions * 0.5)
        }
        let center = (minB + maxB) * 0.5

        // Floor & ceiling Y
        var floorY = minB.y
        if let f = capturedRoom.floors.first {
            floorY = f.transform.columns.3.y
        }
        let ceilingY = maxB.y

        var xform = matrix_identity_float4x4
        switch type.placement {
        case .ceiling:
            xform.columns.3 = SIMD4<Float>(center.x, ceilingY, center.z, 1)
        case .floor:
            xform.columns.3 = SIMD4<Float>(center.x, floorY, center.z, 1)
        case .wall:
            // Attach to the largest wall, at mid-height
            if let wall = capturedRoom.walls.max(by: {
                $0.dimensions.x * $0.dimensions.y < $1.dimensions.x * $1.dimensions.y
            }) {
                let wallNormal = simd_normalize(SIMD3<Float>(
                    wall.transform.columns.2.x,
                    wall.transform.columns.2.y,
                    wall.transform.columns.2.z))
                let surfaceOffset = wall.dimensions.z / 2 + 0.02
                xform = wall.transform
                xform.columns.3 = SIMD4<Float>(
                    SIMD3<Float>(wall.transform.columns.3.x,
                                 wall.transform.columns.3.y,
                                 wall.transform.columns.3.z) + wallNormal * surfaceOffset,
                    1)
            } else {
                xform.columns.3 = SIMD4<Float>(center.x, (floorY + ceilingY) * 0.5, center.z, 1)
            }
        }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: "lighting",
            replacedWithUSDZ: "lighting",
            transform: FurnitureReplacement.fromTransform(xform),
            lightFixtureType: type.rawValue,
            lightColorRGB: [Double(r), Double(g), Double(b)],
            lightIntensity: Double(intensity)
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)

        historyManager.addHistoryEntry(
            roomId: room.id, replacementId: replacement.id, action: .replaced,
            details: "Added \(type.label) light fixture")
    }

    // MARK: Add Carpet

    private func addCarpet(size: CarpetSize, widthM: Float, depthM: Float,
                           color: UIColor, pattern: CarpetPattern) {
        guard let capturedRoom = room.getCapturedRoom() else { return }

        // Place at the floor centre
        var minB = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxB = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for wall in capturedRoom.walls {
            let p = SIMD3<Float>(wall.transform.columns.3.x,
                                 wall.transform.columns.3.y,
                                 wall.transform.columns.3.z)
            minB = min(minB, p - wall.dimensions * 0.5)
            maxB = max(maxB, p + wall.dimensions * 0.5)
        }
        let center = (minB + maxB) * 0.5

        var floorY = minB.y
        if let f = capturedRoom.floors.first {
            floorY = f.transform.columns.3.y
        }

        var xform = matrix_identity_float4x4
        xform.columns.3 = SIMD4<Float>(center.x, floorY, center.z, 1)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: "carpet",
            replacedWithUSDZ: "carpet",
            transform: FurnitureReplacement.fromTransform(xform),
            carpetSize: size.rawValue,
            carpetPattern: pattern.rawValue,
            carpetColorRGB: [Double(r), Double(g), Double(b)],
            carpetCustomWidthCm: size == .custom ? Double(widthM * 100) : nil,
            carpetCustomDepthCm: size == .custom ? Double(depthM * 100) : nil
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)

        let wCm = Int(widthM * 100)
        let dCm = Int(depthM * 100)
        historyManager.addHistoryEntry(
            roomId: room.id, replacementId: replacement.id, action: .replaced,
            details: "Added \(pattern.label) carpet (\(wCm)×\(dCm) cm)")
    }

    // MARK: Camera Mode Switch

    private func switchCameraMode(firstPerson: Bool) {
        NotificationCenter.default.post(
            name: .switchCameraMode,
            object: nil,
            userInfo: ["firstPerson": firstPerson])
    }

    private func takeScreenshot() {
        arView?.snapshot(saveToHDR: false) { image in
            DispatchQueue.main.async {
                if let img = image {
                    exportImage = img
                    showExportSheet = true
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - RoomModelSceneView (Non-AR 3D Room Scene)
// ═══════════════════════════════════════════════════════════════════

struct RoomModelSceneView: UIViewRepresentable {
    let capturedRoom: CapturedRoom
    @Binding var room: Room
    @Binding var selectedObject: ScannedObject?
    @Binding var showFullCatalog: Bool
    @Binding var arView: ARView?
    @Binding var isManipulating: Bool
    @Binding var resetSignal: Bool
    let heightSignal: Int
    let heightDelta: Float
    let catalogManager: FurnitureCatalogManager
    let roomManager: RoomManager
    let wallColor: Color
    let floorColor: Color
    let wallPattern: SurfacePattern
    let floorPattern: SurfacePattern
    let colorTrigger: Int
    let refreshTrigger: Int

    // ── makeUIView ────────────────────────────────────────────────

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.init(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))

        let coord = context.coordinator
        coord.catalogManager = catalogManager
        coord.roomManager = roomManager
        coord.view = view
        coord.roomBinding = $room

        // Compute room bounding box (used for camera + lighting + ground)
        computeRoomBounds(context: context)

        // Build 3D scene: lighting, room structure, furniture
        buildScene(in: view, context: context)

        // Setup orbit camera
        setupCamera(in: view, context: context)

        // Setup gestures (camera orbit + object manipulation)
        setupGestures(on: view, coordinator: coord)

        DispatchQueue.main.async { self.arView = view }
        return view
    }

    // ── updateUIView ──────────────────────────────────────────────

    func updateUIView(_ uiView: ARView, context: Context) {
        let coord = context.coordinator
        coord.roomBinding = $room

        // Sync selection state
        if selectedObject == nil && coord.selectedKey != nil {
            coord.selectedKey = nil
            coord.updateSelectionHighlight()
        } else if let sel = selectedObject, coord.selectedKey != sel.stableId {
            coord.selectedKey = sel.stableId
            coord.updateSelectionHighlight()
        }

        // Handle reset signal
        if resetSignal != coord.lastResetSignal {
            coord.lastResetSignal = resetSignal
            coord.resetSelectedEntity()
        }

        // Handle height adjustment signal
        if heightSignal != coord.lastHeightSignal {
            coord.lastHeightSignal = heightSignal
            coord.adjustHeight(by: heightDelta)
        }

        // Handle structure colour changes (wall / floor picker)
        if colorTrigger != coord.lastColorTrigger {
            coord.lastColorTrigger = colorTrigger
            updateStructureColors(in: uiView)
        }

        // Rebuild furniture when replacements change
        guard refreshTrigger != coord.lastRefreshTrigger else { return }
        coord.lastRefreshTrigger = refreshTrigger
        rebuildFurniture(in: uiView, context: context)
    }

    // ── computeRoomBounds ─────────────────────────────────────────

    private func computeRoomBounds(context: Context) {
        var mn = SIMD3<Float>(repeating:  Float.greatestFiniteMagnitude)
        var mx = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)

        // Helper: compute world-space AABB from a local bounding box + transform.
        // Surfaces are rotated, so we must transform all 8 local corners to world
        // space and take the min/max — simply adding ±half to the center is WRONG
        // for any rotated surface.
        func expandBounds(transform: simd_float4x4, dimensions: SIMD3<Float>) {
            let h = dimensions / 2
            let corners: [SIMD3<Float>] = [
                [-h.x, -h.y, -h.z], [ h.x, -h.y, -h.z],
                [-h.x,  h.y, -h.z], [ h.x,  h.y, -h.z],
                [-h.x, -h.y,  h.z], [ h.x, -h.y,  h.z],
                [-h.x,  h.y,  h.z], [ h.x,  h.y,  h.z]
            ]
            for c in corners {
                let w = transform * SIMD4<Float>(c.x, c.y, c.z, 1)
                let wp = SIMD3<Float>(w.x, w.y, w.z)
                mn = simd_min(mn, wp)
                mx = simd_max(mx, wp)
            }
        }

        // Include walls (properly transformed)
        for wall in capturedRoom.walls {
            expandBounds(transform: wall.transform, dimensions: wall.dimensions)
        }

        // Include floors (properly transformed)
        for floor in capturedRoom.floors {
            expandBounds(transform: floor.transform, dimensions: floor.dimensions)
        }

        // Include furniture center positions
        for obj in capturedRoom.objects {
            let p = SIMD3<Float>(obj.transform.columns.3.x,
                                 obj.transform.columns.3.y,
                                 obj.transform.columns.3.z)
            mn = simd_min(mn, p)
            mx = simd_max(mx, p)
        }

        let isEmpty = capturedRoom.walls.isEmpty
                   && capturedRoom.floors.isEmpty
                   && capturedRoom.objects.isEmpty
        if isEmpty { mn = .zero; mx = .one }

        // Floor Y = the floor surface's world-space center Y position.
        // We intentionally do NOT add/subtract dimensions.y because RoomPlan's
        // local dimensions.y may represent the floor's LENGTH, not its thickness.
        // The transform's translation Y is the actual floor level in world space.
        var floorY = mn.y
        if let firstFloor = capturedRoom.floors.first {
            floorY = firstFloor.transform.columns.3.y
        }

        let coord = context.coordinator
        coord.roomBoundsMin = mn
        coord.roomBoundsMax = mx
        coord.floorY = floorY
        coord.orbitCenter = (mn + mx) / 2
    }

    // ── buildScene — full scene construction ──────────────────────

    private func buildScene(in view: ARView, context: Context) {
        // Remove everything except the camera anchor
        view.scene.anchors
            .filter { $0.name != "__camera__" }
            .forEach { view.scene.removeAnchor($0) }

        let coord = context.coordinator
        coord.allObjectMap.removeAll()
        coord.anchorMap.removeAll()
        coord.moverMap.removeAll()
        coord.replacedContentMap.removeAll()
        coord.wireframeContentMap.removeAll()
        coord.initialScaleMap.removeAll()
        coord.selectionHighlight?.removeFromParent()
        coord.selectionHighlight = nil

        addLighting(to: view, context: context)
        addGroundPlane(to: view, context: context)
        addRoomStructure(to: view)
        addFurniture(to: view, context: context)
    }

    /// Rebuild furniture only (when replacements change) — room structure stays
    private func rebuildFurniture(in view: ARView, context: Context) {
        let coord = context.coordinator
        // Remove only furniture anchors
        for (_, anchor) in coord.anchorMap {
            view.scene.removeAnchor(anchor)
        }
        coord.allObjectMap.removeAll()
        coord.anchorMap.removeAll()
        coord.moverMap.removeAll()
        coord.replacedContentMap.removeAll()
        coord.wireframeContentMap.removeAll()
        coord.initialScaleMap.removeAll()
        coord.selectionHighlight?.removeFromParent()
        coord.selectionHighlight = nil

        addFurniture(to: view, context: context)
        coord.updateSelectionHighlight()
    }

    // ── addLighting ───────────────────────────────────────────────

    private func addLighting(to view: ARView, context: Context) {
        let c = context.coordinator.orbitCenter
        let anchor = AnchorEntity(world: .zero)
        anchor.name = "__lights__"

        // Overhead key light
        let keyLight = PointLight()
        keyLight.light.color = .white
        keyLight.light.intensity = 12_000
        keyLight.light.attenuationRadius = 30
        keyLight.position = [c.x, c.y + 6, c.z]
        anchor.addChild(keyLight)

        // Fill from the side
        let fillLight = PointLight()
        fillLight.light.color = UIColor(white: 0.9, alpha: 1)
        fillLight.light.intensity = 6_000
        fillLight.light.attenuationRadius = 25
        fillLight.position = [c.x + 4, c.y + 3, c.z + 4]
        anchor.addChild(fillLight)

        // Back fill
        let backLight = PointLight()
        backLight.light.color = UIColor(white: 0.85, alpha: 1)
        backLight.light.intensity = 4_000
        backLight.light.attenuationRadius = 25
        backLight.position = [c.x - 3, c.y + 2, c.z - 3]
        anchor.addChild(backLight)

        view.scene.addAnchor(anchor)
    }

    // ── addGroundPlane ────────────────────────────────────────────

    private func addGroundPlane(to view: ARView, context: Context) {
        let coord = context.coordinator

        // Place the ground plane just below the lowest room bound so it never
        // covers furniture.  We use roomBoundsMin.y (from expandBounds, always
        // correct regardless of dimension conventions).
        let groundY = min(coord.roomBoundsMin.y, coord.floorY) - 0.02

        let c = coord.orbitCenter
        let diag = simd_length(coord.roomBoundsMax - coord.roomBoundsMin)
        let groundSize = max(diag * 2, 12.0)

        let mesh = MeshResource.generateBox(size: [groundSize, 0.002, groundSize])
        let ground = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(white: 0.13, alpha: 1.0), isMetallic: false)]
        )
        ground.position = [c.x, groundY, c.z]

        let anchor = AnchorEntity(world: .zero)
        anchor.name = "__ground__"
        anchor.addChild(ground)
        view.scene.addAnchor(anchor)
    }

    // ── addRoomStructure — walls, floors, doors, windows ──────────

    private func addRoomStructure(to view: ARView) {
        // Use the user-chosen colours (from colour picker / captured scan)
        let wallPanelColor  = UIColor(wallColor)
        let floorPanelColor = UIColor(floorColor)

        func lighterTint(of color: UIColor) -> UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: min(r + 0.15, 1), green: min(g + 0.15, 1), blue: min(b + 0.15, 1), alpha: a)
        }

        let wallWireColor  = lighterTint(of: wallPanelColor)
        let floorWireColor = lighterTint(of: floorPanelColor)

        // Fully opaque — solid walls and floors
        let wallOpacity:  Float = 1.0
        let floorOpacity: Float = 1.0

        // ── Walls ──
        for wall in capturedRoom.walls {
            addStructuralElement(
                to: view,
                transform: wall.transform,
                dimensions: wall.dimensions,
                panelColor: wallPanelColor,
                panelOpacity: wallOpacity,
                wireColor: wallWireColor,
                name: "__wall__",
                pattern: wallPattern
            )
        }

        // ── Floors ──
        for floor in capturedRoom.floors {
            addStructuralElement(
                to: view,
                transform: floor.transform,
                dimensions: floor.dimensions,
                panelColor: floorPanelColor,
                panelOpacity: floorOpacity,
                wireColor: floorWireColor,
                name: "__floor__",
                pattern: floorPattern
            )
        }

        // ── Doors ──
        for door in capturedRoom.doors {
            addStructuralElement(
                to: view,
                transform: door.transform,
                dimensions: door.dimensions,
                panelColor: UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0),
                panelOpacity: 0.10,
                wireColor: UIColor(red: 0.35, green: 0.55, blue: 0.9, alpha: 1.0),
                name: "__door__"
            )
        }

        // ── Windows ──
        for window in capturedRoom.windows {
            addStructuralElement(
                to: view,
                transform: window.transform,
                dimensions: window.dimensions,
                panelColor: UIColor(red: 0.3, green: 0.8, blue: 0.95, alpha: 1.0),
                panelOpacity: 0.08,
                wireColor: UIColor(red: 0.35, green: 0.8, blue: 0.95, alpha: 1.0),
                name: "__window__"
            )
        }
    }

    /// Updates wall and floor materials in-place (no rebuild, no flicker).
    /// Handles both solid-colour and textured (patterned) surfaces.
    private func updateStructureColors(in view: ARView) {
        let wallUI  = UIColor(wallColor)
        let floorUI = UIColor(floorColor)

        func lighterTint(of color: UIColor) -> UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: min(r + 0.15, 1), green: min(g + 0.15, 1), blue: min(b + 0.15, 1), alpha: a)
        }

        let wallWire  = lighterTint(of: wallUI)
        let floorWire = lighterTint(of: floorUI)

        for anchor in view.scene.anchors {
            let isWall  = anchor.name == "__wall__"
            let isFloor = anchor.name == "__floor__"
            guard isWall || isFloor else { continue }

            let panelColor: UIColor      = isWall ? wallUI  : floorUI
            let wireColor: UIColor       = isWall ? wallWire : floorWire
            let pattern: SurfacePattern  = isWall ? wallPattern : floorPattern

            for child in anchor.children {
                if let panel = child as? ModelEntity, panel.model != nil {
                    // Rebuild material — textured or solid
                    var mat = SimpleMaterial(color: panelColor, isMetallic: false)
                    if pattern != .none, let mesh = panel.model?.mesh {
                        let ext = mesh.bounds.extents
                        let texW: Float = isFloor ? ext.x : max(ext.x, ext.z)
                        let texH: Float = isFloor ? ext.z : ext.y
                        if let cg = TextureGenerator.texture(
                               for: pattern, color: panelColor,
                               widthM: texW, heightM: texH),
                           let tr = try? TextureResource(
                               image: cg, options: .init(semantic: .color)) {
                            mat.color = .init(tint: .white, texture: .init(tr))
                        }
                    }
                    panel.model?.materials = [mat]
                    panel.components.set(OpacityComponent(opacity: 1.0))
                } else {
                    // Wireframe container — update each edge
                    for edge in child.children {
                        if let edgeModel = edge as? ModelEntity {
                            edgeModel.model?.materials = [UnlitMaterial(color: wireColor)]
                        }
                    }
                }
            }
        }
    }

    /// Adds a panel (solid or textured) + wireframe edges for a room surface
    private func addStructuralElement(
        to view: ARView,
        transform: simd_float4x4,
        dimensions: SIMD3<Float>,
        panelColor: UIColor,
        panelOpacity: Float,
        wireColor: UIColor,
        name: String,
        pattern: SurfacePattern = .none
    ) {
        let d = SIMD3<Float>(
            max(dimensions.x, 0.01),
            max(dimensions.y, 0.01),
            max(dimensions.z, 0.01)
        )

        let anchor = AnchorEntity(world: transform)
        anchor.name = name

        let panelMesh = MeshResource.generateBox(size: d)

        // Build material — textured or solid colour
        var panelMaterial = SimpleMaterial(color: panelColor, isMetallic: false)
        if pattern != .none {
            let texW: Float = name.contains("floor") ? d.x : max(d.x, d.z)
            let texH: Float = name.contains("floor") ? d.z : d.y
            if let cgImage = TextureGenerator.texture(
                   for: pattern, color: panelColor,
                   widthM: texW, heightM: texH),
               let tr = try? TextureResource(
                   image: cgImage, options: .init(semantic: .color)) {
                panelMaterial.color = .init(tint: .white, texture: .init(tr))
            }
        }

        let panel = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
        panel.components.set(OpacityComponent(opacity: panelOpacity))
        anchor.addChild(panel)

        // Wireframe edges on top
        let wireframe = Self.createWireframeBox(size: d, color: wireColor, thickness: 0.004)
        anchor.addChild(wireframe)

        view.scene.addAnchor(anchor)
    }

    // ── addFurniture ──────────────────────────────────────────────

    private func addFurniture(to view: ARView, context: Context) {
        let coord = context.coordinator
        guard let catMgr = coord.catalogManager else { return }

        for (index, object) in capturedRoom.objects.enumerated() {
            let cat = "\(object.category)".replacingOccurrences(of: ".", with: "")
            let isFurniture = FurnitureCatalogManager.categoryMappings.keys.contains(cat)
                || cat.contains("chair") || cat.contains("table")
                || cat.contains("sofa") || cat.contains("storage") || cat.contains("bed")
            guard isFurniture else { continue }

            let key = String(format: "obj_%d_%.2f_%.2f_%.2f", index,
                             object.transform.columns.3.x,
                             object.transform.columns.3.y,
                             object.transform.columns.3.z)

            let scannedObj = ScannedObject(
                stableId: key, object: object,
                transform: object.transform, objectIndex: index
            )
            coord.allObjectMap[key] = scannedObj

            // Only match non-decor replacements — wall art, lighting and
            // carpets are rendered by their own dedicated sections below.
            let replacement = room.furnitureReplacements.first { rep in
                guard !rep.isDecor,
                      let t = rep.getTransformMatrix() else { return false }
                let d = t.columns.3 - object.transform.columns.3
                return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
            }

            if let replacement = replacement {
                // ═══ REPLACED OBJECT ═══
                // Anchor stays at the ORIGINAL scan position (never moves).
                let anchor = AnchorEntity(world: object.transform)
                anchor.name = key + "_anchor"

                // Mover entity: this is what handleObjectPan moves.
                let mover = Entity()
                mover.name = key
                anchor.addChild(mover)

                let dims = object.dimensions
                let target = SIMD3<Float>(
                    max(dims.x, 0.1), max(dims.y, 0.1), max(dims.z, 0.1)
                )

                // ── Choose loading strategy ──
                // Scanned & marketplace models are at real-world scale (1 unit = 1 m).
                // Built-in catalogue models need to be scaled to fit the target box.
                let modelName = replacement.replacedWithUSDZ
                let useRealScale = catMgr.isScannedModel(modelName)
                                || catMgr.isMarketplaceModel(modelName)
                let model: Entity? = useRealScale
                    ? catMgr.loadAtRealWorldScale(named: modelName, targetDimensions: target)
                    : catMgr.loadAndScaleModel(named: modelName, targetDimensions: target)

                if let model = model {
                    if let yRot = replacement.yRotation {
                        model.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
                    }
                    let baseScale = model.scale.x
                    if let cs = replacement.customScale {
                        model.scale *= Float(cs)
                    }

                    let modelLight = PointLight()
                    modelLight.light.intensity = 2000
                    modelLight.light.color = .white
                    modelLight.light.attenuationRadius = 8
                    modelLight.position = [0, max(dims.y, 0.5), 0]
                    mover.addChild(modelLight)

                    mover.addChild(model)
                    coord.replacedContentMap[key] = model
                    coord.initialScaleMap[key] = baseScale
                }

                // Invisible collision shape for selection (no mesh → won't occlude walls)
                let bs = SIMD3<Float>(max(dims.x, 0.1), max(dims.y, 0.1), max(dims.z, 0.1))
                let hitBox = Entity()
                hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: bs)]))
                hitBox.name = key
                mover.addChild(hitBox)

                // ★ Add anchor to scene FIRST — setPosition(relativeTo: nil)
                //   requires the entity to be in the scene hierarchy so
                //   RealityKit can resolve world-space coordinates.
                view.scene.addAnchor(anchor)
                coord.anchorMap[key] = anchor
                coord.moverMap[key] = mover

                // Apply any saved position offset AFTER the entity is in-scene
                if let off = replacement.positionOffset, off.count >= 3 {
                    let origPos = SIMD3<Float>(object.transform.columns.3.x,
                                               object.transform.columns.3.y,
                                               object.transform.columns.3.z)
                    let targetPos = origPos + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                    mover.setPosition(targetPos, relativeTo: nil)
                }

            } else {
                // ═══ UNREPLACED: category-coloured wireframe ═══
                let anchor = AnchorEntity(world: object.transform)
                anchor.name = key + "_anchor"

                let mover = Entity()
                mover.name = key
                anchor.addChild(mover)

                let dims = object.dimensions
                let bs = SIMD3<Float>(max(dims.x, 0.1), max(dims.y, 0.1), max(dims.z, 0.1))

                let color = Self.wireframeColor(for: cat)
                let wireframe = Self.createWireframeBox(size: bs, color: color, thickness: 0.008)
                wireframe.name = key
                mover.addChild(wireframe)
                coord.wireframeContentMap[key] = wireframe

                // Invisible collision shape for selection (no mesh → won't occlude walls)
                let hitBox = Entity()
                hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: bs)]))
                hitBox.name = key
                mover.addChild(hitBox)

                view.scene.addAnchor(anchor)
                coord.anchorMap[key] = anchor
                coord.moverMap[key] = mover
            }
        }

        // ═══ FREE-PLACED OBJECTS (added without replacing anything) ═══
        let addedReplacements = room.furnitureReplacements.filter {
            $0.originalCategory == "added"
        }
        for rep in addedReplacements {
            guard let xform = rep.getTransformMatrix() else { continue }

            let key = "added_\(rep.id.uuidString)"

            // Skip if already rendered (rebuild handles removal first)
            guard coord.anchorMap[key] == nil else { continue }

            // Anchor stays at the BASE transform (never moves)
            let anchor = AnchorEntity(world: xform)
            anchor.name = key + "_anchor"

            // Mover entity: this is what gets repositioned
            let mover = Entity()
            mover.name = key
            anchor.addChild(mover)

            // Create a ScannedObject entry for selection & manipulation
            let addedObj = ScannedObject(
                stableId: key,
                transform: xform,
                addedModelName: rep.replacedWithUSDZ,
                dimensions: SIMD3<Float>(0.5, 0.5, 0.5)
            )
            coord.allObjectMap[key] = addedObj

            // ── Load model ──
            let modelName = rep.replacedWithUSDZ
            let defaultDims = SIMD3<Float>(0.5, 0.5, 0.5)
            let useRealScale = catMgr.isScannedModel(modelName)
                            || catMgr.isMarketplaceModel(modelName)
            let model: Entity? = useRealScale
                ? catMgr.loadAtRealWorldScale(named: modelName, targetDimensions: defaultDims)
                : catMgr.loadAndScaleModel(
                    named: modelName,
                    targetDimensions: FurnitureCatalogManager.knownBuiltInDimensions[modelName]
                        ?? defaultDims
                  )

            if let model = model {
                if let yRot = rep.yRotation {
                    model.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
                }
                let baseScale = model.scale.x
                if let cs = rep.customScale {
                    model.scale *= Float(cs)
                }

                let modelLight = PointLight()
                modelLight.light.intensity = 2000
                modelLight.light.color = .white
                modelLight.light.attenuationRadius = 8
                modelLight.position = [0, 0.5, 0]
                mover.addChild(modelLight)

                mover.addChild(model)
                coord.replacedContentMap[key] = model
                coord.initialScaleMap[key] = baseScale
            }

            // Invisible collision shape for selection (no mesh → won't occlude walls)
            let hitDims: SIMD3<Float>
            if let model = model {
                let b = model.visualBounds(relativeTo: mover)
                let ext = b.extents
                hitDims = SIMD3<Float>(max(ext.x, 0.1), max(ext.y, 0.1), max(ext.z, 0.1))
            } else {
                hitDims = defaultDims
            }
            let hitBox = Entity()
            hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: hitDims)]))
            hitBox.name = key
            mover.addChild(hitBox)

            // ★ Add anchor to scene FIRST so setPosition(relativeTo: nil) works
            view.scene.addAnchor(anchor)
            coord.anchorMap[key] = anchor
            coord.moverMap[key] = mover

            // Apply saved offset AFTER entity is in-scene
            if let off = rep.positionOffset, off.count >= 3 {
                let origPos = SIMD3<Float>(xform.columns.3.x,
                                           xform.columns.3.y,
                                           xform.columns.3.z)
                let targetPos = origPos + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                mover.setPosition(targetPos, relativeTo: nil)
            }
        }

        // ═══ WALL ART ═══
        let wallArtReplacements = room.furnitureReplacements.filter { $0.isWallArt }
        for rep in wallArtReplacements {
            guard let xform = rep.getTransformMatrix(),
                  let imageFile = rep.wallArtImageFile,
                  let frameSizeRaw = rep.wallArtFrameSize,
                  let frameStyleRaw = rep.wallArtFrameStyle,
                  let fSize = FrameSize(rawValue: frameSizeRaw),
                  let fStyle = FrameStyle(rawValue: frameStyleRaw)
            else { continue }

            let key = "wallArt_\(rep.id.uuidString)"
            guard coord.anchorMap[key] == nil else { continue }

            let anchor = AnchorEntity(world: xform)
            anchor.name = key + "_anchor"

            let mover = Entity()
            mover.name = key
            anchor.addChild(mover)

            // Create a selectable ScannedObject entry
            let artObj = ScannedObject(
                stableId: key, transform: xform,
                addedModelName: "wallArt",
                dimensions: SIMD3<Float>(fSize.widthM, fSize.heightM, 0.05)
            )
            coord.allObjectMap[key] = artObj

            // Build the wall art entity
            if let entity = DecorManager.createWallArtEntity(
                imageFileName: imageFile, frameSize: fSize, frameStyle: fStyle
            ) {
                if let yRot = rep.yRotation {
                    entity.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
                }
                mover.addChild(entity)
                coord.replacedContentMap[key] = entity
            }

            // Collision for selection
            let hitDims = SIMD3<Float>(fSize.widthM + 0.04, fSize.heightM + 0.04, 0.06)
            let hitBox = Entity()
            hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: hitDims)]))
            hitBox.name = key
            mover.addChild(hitBox)

            view.scene.addAnchor(anchor)
            coord.anchorMap[key] = anchor
            coord.moverMap[key] = mover

            if let off = rep.positionOffset, off.count >= 3 {
                let origPos = SIMD3<Float>(xform.columns.3.x,
                                           xform.columns.3.y,
                                           xform.columns.3.z)
                let targetPos = origPos + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                mover.setPosition(targetPos, relativeTo: nil)
            }
        }

        // ═══ LIGHTING FIXTURES ═══
        let lightReplacements = room.furnitureReplacements.filter { $0.isLighting }
        for rep in lightReplacements {
            guard let xform = rep.getTransformMatrix(),
                  let fixtureRaw = rep.lightFixtureType,
                  let fixtureType = LightFixtureType(rawValue: fixtureRaw)
            else { continue }

            let key = "lighting_\(rep.id.uuidString)"
            guard coord.anchorMap[key] == nil else { continue }

            let anchor = AnchorEntity(world: xform)
            anchor.name = key + "_anchor"

            let mover = Entity()
            mover.name = key
            anchor.addChild(mover)

            // Create a selectable ScannedObject entry
            let lightObj = ScannedObject(
                stableId: key, transform: xform,
                addedModelName: "lighting",
                dimensions: SIMD3<Float>(0.4, 0.5, 0.4)
            )
            coord.allObjectMap[key] = lightObj

            // Build the light fixture entity
            let lightColor: UIColor
            if let rgb = rep.lightColorRGB, rgb.count >= 3 {
                lightColor = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]),
                                     blue: CGFloat(rgb[2]), alpha: 1)
            } else {
                lightColor = .white
            }
            let intensity = Float(rep.lightIntensity ?? 3000)

            let entity = DecorManager.createLightFixture(
                type: fixtureType, color: lightColor, intensity: intensity
            )
            if let yRot = rep.yRotation {
                entity.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
            }
            mover.addChild(entity)
            coord.replacedContentMap[key] = entity

            // Collision for selection
            let bounds = entity.visualBounds(relativeTo: mover)
            let ext = bounds.extents
            let hitDims = SIMD3<Float>(max(ext.x, 0.15), max(ext.y, 0.15), max(ext.z, 0.15))
            let hitBox = Entity()
            hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: hitDims)]))
            hitBox.name = key
            mover.addChild(hitBox)

            view.scene.addAnchor(anchor)
            coord.anchorMap[key] = anchor
            coord.moverMap[key] = mover

            if let off = rep.positionOffset, off.count >= 3 {
                let origPos = SIMD3<Float>(xform.columns.3.x,
                                           xform.columns.3.y,
                                           xform.columns.3.z)
                let targetPos = origPos + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                mover.setPosition(targetPos, relativeTo: nil)
            }
        }

        // ═══ CARPETS ═══
        let carpetReplacements = room.furnitureReplacements.filter { $0.isCarpet }
        for rep in carpetReplacements {
            guard let xform = rep.getTransformMatrix(),
                  let sizeRaw = rep.carpetSize,
                  let patternRaw = rep.carpetPattern,
                  let carpetPattern = CarpetPattern(rawValue: patternRaw)
            else { continue }

            let key = "carpet_\(rep.id.uuidString)"
            guard coord.anchorMap[key] == nil else { continue }

            let anchor = AnchorEntity(world: xform)
            anchor.name = key + "_anchor"

            let mover = Entity()
            mover.name = key
            anchor.addChild(mover)

            // Resolve actual dimensions
            let carpetSize = CarpetSize(rawValue: sizeRaw)
            let widthM: Float
            let depthM: Float
            if carpetSize == .custom,
               let cw = rep.carpetCustomWidthCm,
               let cd = rep.carpetCustomDepthCm {
                widthM = Float(cw) / 100
                depthM = Float(cd) / 100
            } else {
                widthM = carpetSize?.widthM ?? 1.5
                depthM = carpetSize?.depthM ?? 2.0
            }

            let isRound = carpetSize?.isRound ?? false

            // Resolve colour
            let carpetColor: UIColor
            if let rgb = rep.carpetColorRGB, rgb.count >= 3 {
                carpetColor = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]),
                                      blue: CGFloat(rgb[2]), alpha: 1)
            } else {
                carpetColor = UIColor(red: 0.55, green: 0.40, blue: 0.30, alpha: 1)
            }

            // Build the carpet entity
            let entity = DecorManager.createCarpetEntity(
                widthM: widthM, depthM: depthM,
                isRound: isRound, color: carpetColor,
                pattern: carpetPattern
            )
            if let yRot = rep.yRotation {
                entity.orientation = simd_quatf(angle: Float(yRot), axis: [0, 1, 0])
            }
            mover.addChild(entity)
            coord.replacedContentMap[key] = entity

            // Use actual visual bounds for accurate hit-testing & highlight
            let bounds = entity.visualBounds(relativeTo: mover)
            let ext = bounds.extents
            let actualDims = SIMD3<Float>(
                max(ext.x, widthM), max(ext.y, 0.015), max(ext.z, depthM)
            )

            // Create selectable ScannedObject entry with measured dimensions
            let carpetObj = ScannedObject(
                stableId: key, transform: xform,
                addedModelName: "carpet",
                dimensions: actualDims
            )
            coord.allObjectMap[key] = carpetObj

            // Collision for selection — use measured extents
            let hitDims = SIMD3<Float>(actualDims.x + 0.04, 0.06, actualDims.z + 0.04)
            let hitBox = Entity()
            hitBox.components.set(CollisionComponent(shapes: [.generateBox(size: hitDims)]))
            hitBox.position.y = bounds.center.y   // align with carpet body centre
            hitBox.name = key
            mover.addChild(hitBox)

            view.scene.addAnchor(anchor)
            coord.anchorMap[key] = anchor
            coord.moverMap[key] = mover

            if let off = rep.positionOffset, off.count >= 3 {
                let origPos = SIMD3<Float>(xform.columns.3.x,
                                           xform.columns.3.y,
                                           xform.columns.3.z)
                let targetPos = origPos + SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                mover.setPosition(targetPos, relativeTo: nil)
            }
        }
    }

    // ── setupCamera ───────────────────────────────────────────────

    private func setupCamera(in view: ARView, context: Context) {
        let coord = context.coordinator
        let diag = simd_length(coord.roomBoundsMax - coord.roomBoundsMin)
        coord.orbitDistance  = max(diag * 1.3, 3.0)
        coord.orbitAzimuth  = .pi / 4      // 45°
        coord.orbitElevation = .pi / 5     // 36°

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 60

        let camAnchor = AnchorEntity(world: .zero)
        camAnchor.name = "__camera__"
        camAnchor.addChild(camera)
        view.scene.addAnchor(camAnchor)

        coord.cameraEntity = camera
        coord.cameraAnchor = camAnchor
        coord.updateCameraTransform()
    }

    // ── setupGestures ─────────────────────────────────────────────

    private func setupGestures(on view: ARView, coordinator: Coordinator) {
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }

        // Tap → select / deselect
        let tap = UITapGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleTap(_:)))

        // Long press → open full catalog
        let longPress = UILongPressGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5

        // One-finger pan → move selected object
        let objectPan = UIPanGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleObjectPan(_:)))
        objectPan.maximumNumberOfTouches = 1

        // Two-finger pan → orbit camera
        let cameraPan = UIPanGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleCameraOrbit(_:)))
        cameraPan.minimumNumberOfTouches = 2
        cameraPan.maximumNumberOfTouches = 2

        // Pinch → zoom camera
        let pinch = UIPinchGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleZoom(_:)))

        // Two-finger rotation → rotate selected object
        let rotation = UIRotationGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handleRotation(_:)))

        // Ordering
        tap.require(toFail: longPress)
        // Note: objectPan uses gestureRecognizerShouldBegin to block
        // when no object is selected, so tap no longer needs to
        // wait for it to fail → faster, more responsive taps.

        // Allow simultaneous two-finger gestures
        objectPan.delegate  = coordinator   // enables shouldBegin gating
        cameraPan.delegate  = coordinator
        pinch.delegate      = coordinator
        rotation.delegate   = coordinator

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(objectPan)
        view.addGestureRecognizer(cameraPan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(rotation)
    }

    // ── Helpers ───────────────────────────────────────────────────

    static func wireframeColor(for category: String) -> UIColor {
        if category.contains("chair")   { return .systemTeal }
        if category.contains("table")   { return .systemYellow }
        if category.contains("sofa")    { return .systemGreen }
        if category.contains("storage") || category.contains("shelf") { return .systemOrange }
        if category.contains("bed")     { return .systemPurple }
        return .systemCyan
    }

    static func createWireframeBox(size: SIMD3<Float>, color: UIColor, thickness: Float = 0.006) -> Entity {
        let container = Entity()
        let t = thickness
        let material = UnlitMaterial(color: color)
        let hw = size.x / 2, hh = size.y / 2, hd = size.z / 2

        // Horizontal edges (along X)
        for yS: Float in [-1, 1] { for zS: Float in [-1, 1] {
            let e = ModelEntity(mesh: .generateBox(size: [size.x, t, t]), materials: [material])
            e.position = [0, yS * hh, zS * hd]; container.addChild(e)
        }}
        // Vertical edges (along Y)
        for xS: Float in [-1, 1] { for zS: Float in [-1, 1] {
            let e = ModelEntity(mesh: .generateBox(size: [t, size.y, t]), materials: [material])
            e.position = [xS * hw, 0, zS * hd]; container.addChild(e)
        }}
        // Depth edges (along Z)
        for xS: Float in [-1, 1] { for yS: Float in [-1, 1] {
            let e = ModelEntity(mesh: .generateBox(size: [t, t, size.z]), materials: [material])
            e.position = [xS * hw, yS * hh, 0]; container.addChild(e)
        }}
        return container
    }

    // ── makeCoordinator ───────────────────────────────────────────

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedObject: $selectedObject,
            showFullCatalog: $showFullCatalog,
            room: $room,
            isManipulating: $isManipulating,
            capturedRoom: capturedRoom
        )
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Coordinator
    // ═══════════════════════════════════════════════════════════════

    class Coordinator: NSObject, UIGestureRecognizerDelegate {

        // ── SwiftUI bindings ──
        @Binding var selectedObject: ScannedObject?
        @Binding var showFullCatalog: Bool
        @Binding var isManipulating: Bool
        var roomBinding: Binding<Room>
        let capturedRoom: CapturedRoom

        // ── External references ──
        var view: ARView?
        var catalogManager: FurnitureCatalogManager?
        var roomManager: RoomManager?
        var lastRefreshTrigger: Int = 0
        var lastResetSignal: Bool = false
        var lastColorTrigger: Int = 0

        // ── Camera state (orbit) ──
        var cameraEntity: PerspectiveCamera?
        var cameraAnchor: AnchorEntity?
        var orbitCenter: SIMD3<Float> = .zero
        var orbitDistance: Float = 5
        var orbitAzimuth: Float = .pi / 4
        var orbitElevation: Float = .pi / 5
        var roomBoundsMin: SIMD3<Float> = .zero
        var roomBoundsMax: SIMD3<Float> = .one
        var floorY: Float = 0
        var lastHeightSignal: Int = 0

        // ── Camera state (first-person / in-room) ──
        var isFirstPerson: Bool = false
        var fpYaw: Float = 0            // horizontal look angle (radians)
        var fpPitch: Float = 0          // vertical look angle (clamped)
        var fpPosition: SIMD3<Float> = .zero   // eye position in world space
        private var cameraModeObserver: NSObjectProtocol?

        // ── Object maps ──
        var allObjectMap:        [String: ScannedObject] = [:]
        var anchorMap:           [String: AnchorEntity]  = [:]   // scene-level anchors (fixed)
        var moverMap:            [String: Entity]        = [:]   // movable containers (moved by drag)
        var replacedContentMap:  [String: Entity]        = [:]
        var wireframeContentMap: [String: Entity]        = [:]
        var initialScaleMap:     [String: Float]         = [:]

        // ── Selection ──
        var selectedKey: String?
        var selectionHighlight: Entity?

        // ── Gizmo (axis arrows) ──
        var gizmoAnchor: AnchorEntity?

        enum DragMode {
            case axisX, axisY, axisZ
            case freeXZ
        }
        var activeDragMode: DragMode?

        // ── Gesture state ──
        var panRightDir: SIMD3<Float> = .zero     // locked at pan start (freeXZ)
        var panForwardDir: SIMD3<Float> = .zero   // locked at pan start (freeXZ)
        var panMetersPerPixel: Float = 0           // locked at pan start
        var dragStartPos: SIMD3<Float> = .zero     // object position when drag began
        var rotationStart: simd_quatf?

        // Locked at .began for axis-constrained drags (prevents jitter)
        var lockedAxisScreenDir: SIMD2<Float>?     // unit screen direction of the axis
        var lockedAxisMetersPerPx: Float = 0       // world meters per screen pixel

        // Target-chase: the finger updates this target; the object lerps
        // toward it each frame.  Inherently stable — can never overshoot.
        var targetDragPos: SIMD3<Float> = .zero

        init(selectedObject: Binding<ScannedObject?>,
             showFullCatalog: Binding<Bool>,
             room: Binding<Room>,
             isManipulating: Binding<Bool>,
             capturedRoom: CapturedRoom) {
            _selectedObject  = selectedObject
            _showFullCatalog = showFullCatalog
            _isManipulating  = isManipulating
            self.roomBinding = room
            self.capturedRoom = capturedRoom
            super.init()

            // Listen for camera-mode switch from the SwiftUI overlay
            cameraModeObserver = NotificationCenter.default.addObserver(
                forName: .switchCameraMode, object: nil, queue: .main
            ) { [weak self] note in
                guard let self = self,
                      let fp = note.userInfo?["firstPerson"] as? Bool else { return }
                self.setFirstPerson(fp)
            }
        }

        deinit {
            if let obs = cameraModeObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }

        // ── First-Person Mode Toggle ────────────────────────────────

        func setFirstPerson(_ enabled: Bool) {
            isFirstPerson = enabled
            if enabled {
                // Place the camera at room center, at eye height (1.6 m above floor)
                let center = (roomBoundsMin + roomBoundsMax) / 2
                fpPosition = SIMD3<Float>(center.x, floorY + 1.6, center.z)
                fpYaw = orbitAzimuth    // face the same direction the orbit was pointing
                fpPitch = 0
                cameraEntity?.camera.fieldOfViewInDegrees = 75   // wider for immersion
            } else {
                cameraEntity?.camera.fieldOfViewInDegrees = 60   // restore orbit FOV
            }
            updateCameraTransform()
        }

        // ── Camera Transform ─────────────────────────────────────

        func updateCameraTransform() {
            guard let cam = cameraEntity else { return }

            if isFirstPerson {
                // First-person: position at fpPosition, look direction from yaw/pitch
                let lookX = cos(fpPitch) * sin(fpYaw)
                let lookY = sin(fpPitch)
                let lookZ = cos(fpPitch) * cos(fpYaw)
                let lookAt = fpPosition + SIMD3<Float>(lookX, lookY, lookZ)
                cam.look(at: lookAt, from: fpPosition, upVector: [0, 1, 0], relativeTo: nil)
            } else {
                let x = orbitCenter.x + orbitDistance * cos(orbitElevation) * sin(orbitAzimuth)
                let y = orbitCenter.y + orbitDistance * sin(orbitElevation)
                let z = orbitCenter.z + orbitDistance * cos(orbitElevation) * cos(orbitAzimuth)
                cam.look(at: orbitCenter, from: [x, y, z], upVector: [0, 1, 0], relativeTo: nil)
            }
        }

        // ── Hit Testing ──────────────────────────────────────────

        private func findClosestObjectKey(at point: CGPoint) -> String? {
            guard let view = view else { return nil }
            var bestKey: String?
            var bestDist: Float = 200

            for (key, mover) in moverMap {
                guard allObjectMap[key] != nil else { continue }
                let worldPos = mover.position(relativeTo: nil)
                guard let screenPt = view.project(worldPos) else { continue }
                let dx = Float(screenPt.x - point.x)
                let dy = Float(screenPt.y - point.y)
                let dist = sqrtf(dx * dx + dy * dy)
                if dist < bestDist {
                    bestDist = dist
                    bestKey = key
                }
            }
            return bestKey
        }

        // ── Tap → select / deselect ──────────────────────────────

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let loc = gesture.location(in: view)
            if let key = findClosestObjectKey(at: loc), let obj = allObjectMap[key] {
                if selectedKey == key {
                    selectedKey = nil; selectedObject = nil
                } else {
                    selectedKey = key; selectedObject = obj
                }
            } else {
                selectedKey = nil; selectedObject = nil
            }
            updateSelectionHighlight()
        }

        // ── Long Press → full catalog ────────────────────────────

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            let loc = gesture.location(in: view)
            if let key = findClosestObjectKey(at: loc), let obj = allObjectMap[key] {
                selectedKey = key; selectedObject = obj
                showFullCatalog = true
                updateSelectionHighlight()
            }
        }

        // ── Camera Orbit (two-finger pan) ────────────────────────

        @objc func handleCameraOrbit(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .changed else { return }
            let t = gesture.translation(in: view)

            if isFirstPerson {
                // Look around (two-finger pan)
                fpYaw   -= Float(t.x) * 0.005
                fpPitch  = max(-.pi / 3, min(.pi / 3,
                               fpPitch + Float(t.y) * 0.005))
            } else {
                orbitAzimuth  -= Float(t.x) * 0.005
                orbitElevation = max(0.05, min(Float.pi / 2 - 0.05,
                                                orbitElevation + Float(t.y) * 0.005))
            }
            gesture.setTranslation(.zero, in: view)
            updateCameraTransform()
        }

        // ── Zoom (pinch) ─────────────────────────────────────────

        @objc func handleZoom(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .changed else { return }

            if isFirstPerson {
                // Pinch to walk forward / backward
                let delta = Float(gesture.scale) - 1.0
                let forward = SIMD3<Float>(sin(fpYaw), 0, cos(fpYaw))
                fpPosition += forward * delta * 2.0

                // Keep inside room bounds (10 cm inset from walls)
                let inset: Float = 0.10
                fpPosition.x = max(roomBoundsMin.x + inset,
                                   min(roomBoundsMax.x - inset, fpPosition.x))
                fpPosition.z = max(roomBoundsMin.z + inset,
                                   min(roomBoundsMax.z - inset, fpPosition.z))
                // Lock Y at eye height
                fpPosition.y = floorY + 1.6
            } else {
                orbitDistance = max(0.5, min(40, orbitDistance / Float(gesture.scale)))
            }
            gesture.scale = 1
            updateCameraTransform()
        }

        // ── Object Move (one-finger pan — gizmo or free XZ) ──────

        @objc func handleObjectPan(_ gesture: UIPanGestureRecognizer) {
            guard let key = selectedKey,
                  let mover = moverMap[key] else { return }

            // ── Chase speed ──
            // How fast the object catches the target each frame.
            // 0.18 = silky smooth, 0.4 = responsive, 1.0 = instant.
            let chase: Float = 0.18

            switch gesture.state {
            case .began:
                let touchPt = gesture.location(in: view)
                activeDragMode = detectDragMode(at: touchPt)
                guard activeDragMode != nil else { return }
                isManipulating = true

                let curPos = mover.position(relativeTo: nil)
                dragStartPos  = curPos
                targetDragPos = curPos          // target starts where object is

                // ★ Zero translation so first .changed gets a tiny delta.
                gesture.setTranslation(.zero, in: view)

                // For freeXZ: lock camera-relative directions and scale
                if activeDragMode == .freeXZ, let cam = cameraEntity {
                    panMetersPerPixel = min(orbitDistance * 0.0004, 0.0008)
                    let camXform = cam.transformMatrix(relativeTo: nil)
                    let rightRaw   = SIMD3<Float>(camXform.columns.0.x, 0, camXform.columns.0.z)
                    let forwardRaw = SIMD3<Float>(-camXform.columns.2.x, 0, -camXform.columns.2.z)
                    let rl = simd_length(rightRaw)
                    let fl = simd_length(forwardRaw)
                    panRightDir   = rl > 0.001 ? rightRaw / rl : SIMD3<Float>(1, 0, 0)
                    panForwardDir = fl > 0.001 ? forwardRaw / fl : SIMD3<Float>(0, 0, -1)
                }

                // For axis mode: lock the screen projection once.
                if let mode = activeDragMode,
                   mode == .axisX || mode == .axisY || mode == .axisZ,
                   let arView = view {
                    let worldDir: SIMD3<Float> = {
                        switch mode {
                        case .axisX: return [1, 0, 0]
                        case .axisY: return [0, 1, 0]
                        case .axisZ: return [0, 0, 1]
                        default:     return .zero
                        }
                    }()
                    let pos = mover.position(relativeTo: nil)
                    if let p1 = arView.project(pos),
                       let p2 = arView.project(pos + worldDir * 0.1) {
                        let sAxis = SIMD2<Float>(Float(p2.x - p1.x),
                                                 Float(p2.y - p1.y))
                        let sLen = simd_length(sAxis)
                        if sLen > 3.0 {
                            lockedAxisScreenDir   = sAxis / sLen
                            lockedAxisMetersPerPx = min(0.1 / sLen, 0.0008)
                        } else {
                            lockedAxisScreenDir   = nil
                            lockedAxisMetersPerPx = 0
                        }
                    }
                }

            case .changed:
                guard let mode = activeDragMode else { return }
                let translation = gesture.translation(in: view)
                gesture.setTranslation(.zero, in: view)

                // ── 1. Compute raw delta from finger movement ──
                var rawDelta: SIMD3<Float> = .zero

                switch mode {
                case .axisX, .axisY, .axisZ:
                    guard let screenAxis = lockedAxisScreenDir else { break }
                    let worldDir: SIMD3<Float> = {
                        switch mode {
                        case .axisX: return [1, 0, 0]
                        case .axisY: return [0, 1, 0]
                        case .axisZ: return [0, 0, 1]
                        default:     return .zero
                        }
                    }()
                    let screenDelta = SIMD2<Float>(Float(translation.x),
                                                   Float(translation.y))
                    let projectedPx = simd_dot(screenDelta, screenAxis)
                    let worldMove   = projectedPx * lockedAxisMetersPerPx
                    rawDelta = worldDir * worldMove

                case .freeXZ:
                    let d = panRightDir   * Float(translation.x)  * panMetersPerPixel
                          + panForwardDir * Float(-translation.y) * panMetersPerPixel
                    rawDelta = SIMD3<Float>(d.x, 0, d.z)
                }

                // ── 2. Advance the TARGET by raw delta ──
                targetDragPos += rawDelta

                // ── 3. Clamp TARGET to room bounds (5 cm inset) ──
                let inset: Float = 0.05
                targetDragPos.x = max(roomBoundsMin.x + inset,
                                      min(roomBoundsMax.x - inset, targetDragPos.x))
                targetDragPos.z = max(roomBoundsMin.z + inset,
                                      min(roomBoundsMax.z - inset, targetDragPos.z))
                targetDragPos.y = max(floorY,
                                      min(roomBoundsMax.y, targetDragPos.y))

                // ── 4. Clamp TARGET total distance from start (2.5 m) ──
                let fromStart = targetDragPos - dragStartPos
                let totalDist = simd_length(fromStart)
                if totalDist > 2.5 {
                    targetDragPos = dragStartPos + simd_normalize(fromStart) * 2.5
                }

                // ── 5. Smoothly chase the target (lerp — can NEVER overshoot) ──
                let curPos = mover.position(relativeTo: nil)
                let newPos = simd_mix(curPos, targetDragPos,
                                      SIMD3<Float>(repeating: chase))

                mover.setPosition(newPos, relativeTo: nil)
                gizmoAnchor?.setPosition(newPos, relativeTo: nil)

            case .ended, .cancelled:
                // If .began returned early (no valid drag mode detected),
                // skip snap & save to avoid using a stale targetDragPos.
                guard activeDragMode != nil else {
                    return
                }

                // Snap to the final target so the object rests exactly
                // where the finger intended, not partway through a lerp.
                mover.setPosition(targetDragPos, relativeTo: nil)
                gizmoAnchor?.setPosition(targetDragPos, relativeTo: nil)

                activeDragMode = nil
                lockedAxisScreenDir = nil
                isManipulating = false
                if replacedContentMap[key] != nil {
                    saveManipulation(for: key)
                }

            default: break
            }
        }

        // ── Object Rotation (two-finger twist) ───────────────────

        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let key = selectedKey else { return }
            let entity = replacedContentMap[key] ?? wireframeContentMap[key]
            guard let entity = entity else { return }

            switch gesture.state {
            case .began:
                rotationStart = entity.orientation
                isManipulating = true

            case .changed:
                guard let startOri = rotationStart else { return }
                entity.orientation = startOri * simd_quatf(angle: -Float(gesture.rotation), axis: [0, 1, 0])

            case .ended, .cancelled:
                isManipulating = false
                if replacedContentMap[key] != nil {
                    saveManipulation(for: key)
                }

            default: break
            }
        }

        // ── Persist Manipulation ─────────────────────────────────

        func saveManipulation(for key: String) {
            guard let obj = allObjectMap[key],
                  let mover = moverMap[key] else { return }

            let origPos = obj.transform.columns.3

            // Decor / added items embed their replacement UUID in the key — match directly.
            // Scanned furniture falls back to position-based matching.
            let idx: Int?
            if let repId = extractReplacementId(from: key) {
                idx = roomBinding.wrappedValue.furnitureReplacements.firstIndex { $0.id == repId }
            } else {
                idx = roomBinding.wrappedValue.furnitureReplacements.firstIndex(where: { rep in
                    guard let t = rep.getTransformMatrix() else { return false }
                    let d = t.columns.3 - origPos
                    return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
                })
            }
            guard let idx = idx else { return }

            // Position offset from original
            let curPos = mover.position(relativeTo: nil)
            let offset = curPos - SIMD3<Float>(origPos.x, origPos.y, origPos.z)
            roomBinding.wrappedValue.furnitureReplacements[idx].positionOffset =
                [Double(offset.x), Double(offset.y), Double(offset.z)]

            // Y rotation and custom scale
            if let content = replacedContentMap[key] {
                let q = content.orientation
                let siny = 2.0 * (q.real * q.imag.y + q.imag.z * q.imag.x)
                let cosy = 1.0 - 2.0 * (q.imag.x * q.imag.x + q.imag.y * q.imag.y)
                roomBinding.wrappedValue.furnitureReplacements[idx].yRotation =
                    Double(atan2(siny, cosy))

                if let initScale = initialScaleMap[key], initScale > 0.0001 {
                    roomBinding.wrappedValue.furnitureReplacements[idx].customScale =
                        Double(content.scale.x / initScale)
                }
            }

            roomManager?.updateRoom(roomBinding.wrappedValue)
        }

        // ── Reset ────────────────────────────────────────────────

        func resetSelectedEntity() {
            guard let key = selectedKey,
                  let mover = moverMap[key],
                  let obj = allObjectMap[key] else { return }

            let origPos = SIMD3<Float>(
                obj.transform.columns.3.x,
                obj.transform.columns.3.y,
                obj.transform.columns.3.z
            )
            mover.setPosition(origPos, relativeTo: nil)
            gizmoAnchor?.setPosition(origPos, relativeTo: nil)

            if let content = replacedContentMap[key] {
                content.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                if let initScale = initialScaleMap[key] {
                    content.scale = SIMD3<Float>(repeating: initScale)
                }
            }

            rotationStart = nil
        }

        // ── Height adjustment (Y-axis) — kept as programmatic API ──

        func adjustHeight(by delta: Float) {
            guard let key = selectedKey,
                  let mover = moverMap[key] else { return }

            var pos = mover.position(relativeTo: nil)
            pos.y += delta
            // floorY is now the TOP of the floor surface (where objects rest).
            pos.y = max(floorY, pos.y)
            pos.y = min(roomBoundsMax.y, pos.y)
            mover.setPosition(pos, relativeTo: nil)
            gizmoAnchor?.setPosition(pos, relativeTo: nil)

            if replacedContentMap[key] != nil {
                saveManipulation(for: key)
            }
        }

        // ── Gizmo: create axis arrows ────────────────────────────

        /// Builds the 3-axis gizmo (red=X, green=Y, blue=Z) at a world position.
        func showGizmo(at worldPos: SIMD3<Float>) {
            removeGizmo()
            guard let view = view else { return }

            let anchor = AnchorEntity(world: .init(diagonal: [1, 1, 1, 1]))
            anchor.name = "__gizmo__"
            anchor.setPosition(worldPos, relativeTo: nil)

            let shaftLen:  Float = 0.30
            let shaftR:    Float = 0.008
            let tipR:      Float = 0.025
            let tipH:      Float = 0.06

            func makeArrow(dir: SIMD3<Float>, color: UIColor, tag: String) -> Entity {
                let container = Entity()
                container.name = tag
                let mat = UnlitMaterial(color: color)

                // Shaft (cylinder default axis = Y)
                let shaft = ModelEntity(
                    mesh: .generateCylinder(height: shaftLen, radius: shaftR),
                    materials: [mat])
                shaft.position = [0, shaftLen / 2, 0]
                container.addChild(shaft)

                // Tip — small sphere (arrow-head substitute)
                let tip = ModelEntity(
                    mesh: .generateSphere(radius: tipR),
                    materials: [mat])
                tip.position = [0, shaftLen + tipR, 0]
                container.addChild(tip)

                // Collision for the entire arrow (generous hit area)
                let hitBox = ModelEntity(
                    mesh: .generateBox(size: [tipR * 4, shaftLen + tipH, tipR * 4]),
                    materials: [SimpleMaterial(color: .white, isMetallic: false)])
                hitBox.components.set(OpacityComponent(opacity: 0.001))
                hitBox.components.set(CollisionComponent(shapes: [
                    .generateBox(size: [tipR * 4, shaftLen + tipH, tipR * 4])
                ]))
                hitBox.position = [0, (shaftLen + tipH) / 2, 0]
                hitBox.name = tag
                container.addChild(hitBox)

                // Orient: default is along +Y; rotate for X and Z
                if abs(dir.x) > 0.5 {
                    container.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
                } else if abs(dir.z) > 0.5 {
                    container.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                }
                return container
            }

            // Origin dot
            let originDot = ModelEntity(
                mesh: .generateSphere(radius: 0.018),
                materials: [UnlitMaterial(color: .white)])
            anchor.addChild(originDot)

            anchor.addChild(makeArrow(dir: [1, 0, 0], color: .systemRed,   tag: "__gizmo_x__"))
            anchor.addChild(makeArrow(dir: [0, 1, 0], color: .systemGreen, tag: "__gizmo_y__"))
            anchor.addChild(makeArrow(dir: [0, 0, 1], color: .systemBlue,  tag: "__gizmo_z__"))

            view.scene.addAnchor(anchor)
            gizmoAnchor = anchor
        }

        func removeGizmo() {
            gizmoAnchor?.removeFromParent()
            gizmoAnchor = nil
        }

        /// Determines which gizmo arrow (or the center) the screen point is near.
        func detectDragMode(at point: CGPoint) -> DragMode? {
            guard let key = selectedKey,
                  let mover = moverMap[key],
                  let view = view else { return nil }

            let center = mover.position(relativeTo: nil)
            let arrowLen: Float = 0.33   // slightly past tip

            // Sample points along each arrow for hit detection
            let axes: [(DragMode, SIMD3<Float>)] = [
                (.axisX, [1, 0, 0]),
                (.axisY, [0, 1, 0]),
                (.axisZ, [0, 0, 1])
            ]

            var bestMode: DragMode? = nil
            var bestDist: Float = 55      // max screen-pixel threshold

            for (mode, dir) in axes {
                // Check several sample points along the arrow shaft + tip
                for t: Float in stride(from: 0.04, through: arrowLen, by: 0.04) {
                    let worldPt = center + dir * t
                    guard let screenPt = view.project(worldPt) else { continue }
                    let dx = Float(screenPt.x - point.x)
                    let dy = Float(screenPt.y - point.y)
                    let dist = sqrtf(dx * dx + dy * dy)
                    if dist < bestDist {
                        bestDist = dist
                        bestMode = mode
                    }
                }
            }

            // If no arrow matched, check if near the center → free XZ drag
            if bestMode == nil {
                if let screenCenter = view.project(center) {
                    let dx = Float(screenCenter.x - point.x)
                    let dy = Float(screenCenter.y - point.y)
                    let dist = sqrtf(dx * dx + dy * dy)
                    if dist < 90 { bestMode = .freeXZ }
                }
            }

            return bestMode
        }

        // ── Selection Highlight + Gizmo ─────────────────────────────

        func updateSelectionHighlight() {
            selectionHighlight?.removeFromParent()
            selectionHighlight = nil
            removeGizmo()

            guard let key = selectedKey,
                  let mover = moverMap[key],
                  let obj = allObjectMap[key] else { return }

            let dims = obj.dimensions
            let pad: Float = 0.04
            // For very flat items (e.g. carpets) don't inflate the Y to 10 cm;
            // keep the highlight snug around the actual geometry.
            let minY: Float = dims.y < 0.05 ? dims.y + 0.01 : 0.1
            let boxSize = SIMD3<Float>(
                max(dims.x, 0.1) + pad,
                max(dims.y, minY) + pad,
                max(dims.z, 0.1) + pad
            )
            let color: UIColor = replacedContentMap[key] != nil ? .systemGreen : .systemYellow
            let highlight = RoomModelSceneView.createWireframeBox(
                size: boxSize, color: color, thickness: 0.012
            )
            highlight.name = "__highlight__"
            mover.addChild(highlight)
            selectionHighlight = highlight

            // Show axis arrows at the mover's world position
            let worldPos = mover.position(relativeTo: nil)
            showGizmo(at: worldPos)
        }

        // ── UIGestureRecognizerDelegate ──────────────────────────

        /// Only allow the one-finger pan when the touch starts on a
        /// gizmo arrow or near the selected object's center.
        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            if let pan = gestureRecognizer as? UIPanGestureRecognizer,
               pan.maximumNumberOfTouches == 1 {
                guard selectedKey != nil else { return false }
                let loc = pan.location(in: view)
                return detectDragMode(at: loc) != nil
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Allow all two-finger gestures (orbit, zoom, rotate) to coexist
            let isTwoFinger: (UIGestureRecognizer) -> Bool = { g in
                g is UIPinchGestureRecognizer
                || g is UIRotationGestureRecognizer
                || (g as? UIPanGestureRecognizer).map { $0.minimumNumberOfTouches >= 2 } ?? false
            }
            return isTwoFinger(gestureRecognizer) && isTwoFinger(otherGestureRecognizer)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FurnitureCatalogTray
// ═══════════════════════════════════════════════════════════════════

struct FurnitureCatalogTray: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    let category: CapturedRoom.Object.Category?
    let onSelectModel: (String) -> Void
    let onBrowseAll: () -> Void

    private var builtInModels: [String] {
        var result: [String] = []
        if let cat = category {
            result = catalogManager.getModelsForCategory(cat)
        }
        for m in catalogManager.getAllAvailableModels() where !result.contains(m) {
            result.append(m)
        }
        return result
    }

    private var userScans: [ScannedFurniture] {
        scannedFurnitureManager.getFurnitureForCurrentUser()
    }

    /// Marketplace models cached on-device.
    private var marketplaceDownloads: [DownloadedMarketplaceModel] {
        DownloadedMarketplaceModel.loadAll().filter {
            catalogManager.marketplaceModelURL(for: $0.catalogKey) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Built-in models
                    ForEach(builtInModels, id: \.self) { model in
                        Button { onSelectModel(model) } label: {
                            VStack(spacing: 4) {
                                USDZThumbnailView(
                                    url: catalogManager.modelFileURL(for: model),
                                    size: CGSize(width: 48, height: 48)
                                )
                                Text(model.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 76, height: 76)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    // User-scanned models
                    ForEach(userScans) { scan in
                        Button { onSelectModel(scan.catalogKey) } label: {
                            VStack(spacing: 4) {
                                USDZThumbnailView(
                                    url: scan.usdzURL,
                                    size: CGSize(width: 48, height: 48)
                                )
                                Text(scan.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 76, height: 76)
                            .background(AppTheme.glowGreen.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.glowGreen.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }

                    // Downloaded marketplace models
                    ForEach(marketplaceDownloads) { dl in
                        Button { onSelectModel(dl.catalogKey) } label: {
                            VStack(spacing: 4) {
                                USDZThumbnailView(
                                    url: catalogManager.modelFileURL(for: dl.catalogKey),
                                    size: CGSize(width: 48, height: 48)
                                )
                                Text(dl.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 76, height: 76)
                            .background(AppTheme.glowCyan.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.glowCyan.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }

                    Button(action: onBrowseAll) {
                        VStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.accentGradientInline)
                            Text("All")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .frame(width: 76, height: 76)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FurniturePickerView (full catalog — "Browse All")
// ═══════════════════════════════════════════════════════════════════

struct FurniturePickerView: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    @Environment(\.dismiss) var dismiss

    let selectedObject: ScannedObject
    @Binding var room: Room

    var availableModels: [String] {
        var result: [String] = []
        if let cat = selectedObject.object?.category {
            result = catalogManager.getModelsForCategory(cat)
        }
        let allModels = catalogManager.getAllAvailableModels()
        for m in allModels where !result.contains(m) { result.append(m) }
        return result
    }

    var userScans: [ScannedFurniture] {
        scannedFurnitureManager.getFurnitureForCurrentUser()
    }

    /// Marketplace models that have been downloaded to the device.
    private var downloadedMarketplace: [DownloadedMarketplaceModel] {
        DownloadedMarketplaceModel.loadAll().filter { model in
            catalogManager.marketplaceModelURL(for: model.catalogKey) != nil
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    // Built-in models
                    if !availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "Built-in Models", icon: "cube.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(availableModels, id: \.self) { name in
                                    FurnitureCard(modelName: name) { replaceObject(with: name) }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // User-scanned models
                    if !userScans.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "My Scanned Furniture", icon: "person.crop.rectangle.stack.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(userScans) { scan in
                                    ScannedFurnitureCard(item: scan) {
                                        replaceObject(with: scan.catalogKey)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Downloaded marketplace models
                    if !downloadedMarketplace.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "Downloaded from Marketplace", icon: "arrow.down.circle.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(downloadedMarketplace) { item in
                                    MarketplaceModelCard(item: item, catalogManager: catalogManager) {
                                        replaceObject(with: item.catalogKey)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .navigationTitle("Select Furniture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
    }

    /// Resolves a display-friendly name for a model key.
    private func friendlyModelName(_ key: String) -> String {
        if catalogManager.isScannedModel(key) {
            let uuidStr = String(key.dropFirst("scanned_".count))
            if let uuid = UUID(uuidString: uuidStr),
               let item = scannedFurnitureManager.items.first(where: { $0.id == uuid }) {
                return item.name
            }
        }
        if catalogManager.isMarketplaceModel(key) {
            let itemId = String(key.dropFirst("marketplace_".count))
            if let meta = DownloadedMarketplaceModel.loadAll().first(where: { $0.id == itemId }) {
                return meta.name
            }
        }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func replaceObject(with usdzFileName: String) {
        if let repId = extractReplacementId(from: selectedObject.stableId) {
            room.furnitureReplacements.removeAll { $0.id == repId }
        } else {
            room.furnitureReplacements.removeAll { rep in
                guard let t = rep.getTransformMatrix() else { return false }
                let d = t.columns.3 - selectedObject.transform.columns.3
                return abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05
            }
        }

        let catDesc = selectedObject.object?.category.description ?? "added"
        let replacement = FurnitureReplacement(
            objectId: UUID(),
            originalCategory: selectedObject.isAdded ? "added" : "\(selectedObject.object!.category)",
            replacedWithUSDZ: usdzFileName,
            transform: FurnitureReplacement.fromTransform(selectedObject.transform)
        )
        room.furnitureReplacements.append(replacement)
        roomManager.updateRoom(room)

        historyManager.addHistoryEntry(
            roomId: room.id,
            replacementId: replacement.id,
            action: .replaced,
            details: "Replaced \(catDesc) with \(friendlyModelName(usdzFileName))"
        )
        dismiss()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - AddFurniturePickerView (add new furniture to scene)
// ═══════════════════════════════════════════════════════════════════

struct AddFurniturePickerView: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var scannedFurnitureManager: ScannedFurnitureManager
    @Environment(\.dismiss) var dismiss

    let onSelect: (String) -> Void

    private var builtInModels: [String] {
        catalogManager.getAllAvailableModels()
    }

    private var userScans: [ScannedFurniture] {
        scannedFurnitureManager.getFurnitureForCurrentUser()
    }

    /// Marketplace models that have been downloaded to the device.
    private var downloadedMarketplace: [DownloadedMarketplaceModel] {
        DownloadedMarketplaceModel.loadAll().filter { model in
            // Only show if the cached USDZ file still exists on disk
            catalogManager.marketplaceModelURL(for: model.catalogKey) != nil
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                ScrollView {
                    if !builtInModels.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "Built-in Models", icon: "cube.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(builtInModels, id: \.self) { name in
                                    FurnitureCard(modelName: name) {
                                        onSelect(name)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !userScans.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "My Scanned Furniture", icon: "person.crop.rectangle.stack.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(userScans) { scan in
                                    ScannedFurnitureCard(item: scan) {
                                        onSelect(scan.catalogKey)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !downloadedMarketplace.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemeSectionHeader(title: "Downloaded from Marketplace", icon: "arrow.down.circle.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(downloadedMarketplace) { item in
                                    MarketplaceModelCard(item: item, catalogManager: catalogManager) {
                                        onSelect(item.catalogKey)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .navigationTitle("Add Furniture to Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - DebugObjectsView
// ═══════════════════════════════════════════════════════════════════

struct DebugObjectsView: View {
    let room: Room
    let capturedRoom: CapturedRoom

    private var furnitureObjects: [(index: Int, object: CapturedRoom.Object,
                                    pos: SIMD3<Float>, dims: SIMD3<Float>,
                                    category: String, hasReplacement: Bool,
                                    replacementName: String?,
                                    offset: SIMD3<Float>?, yRot: Double?, customScale: Double?)] {
        var objects: [(Int, CapturedRoom.Object, SIMD3<Float>, SIMD3<Float>,
                       String, Bool, String?, SIMD3<Float>?, Double?, Double?)] = []

        for (index, object) in capturedRoom.objects.enumerated() {
            let cat = "\(object.category)".replacingOccurrences(of: ".", with: "")
            let isFurniture = FurnitureCatalogManager.categoryMappings.keys.contains(cat)
                || cat.contains("chair") || cat.contains("table")
                || cat.contains("sofa") || cat.contains("storage") || cat.contains("bed")
            guard isFurniture else { continue }

            let pos4 = object.transform.columns.3
            let pos3 = SIMD3<Float>(pos4.x, pos4.y, pos4.z)
            let dims = object.dimensions

            var hasRep = false
            var repName: String?
            var offset: SIMD3<Float>?
            var yRot: Double?
            var cScale: Double?

            for rep in room.furnitureReplacements {
                if let t = rep.getTransformMatrix() {
                    let d = t.columns.3 - pos4
                    if abs(d.x) < 0.05 && abs(d.y) < 0.05 && abs(d.z) < 0.05 {
                        hasRep = true
                        repName = rep.replacedWithUSDZ
                        if let off = rep.positionOffset, off.count >= 3 {
                            offset = SIMD3<Float>(Float(off[0]), Float(off[1]), Float(off[2]))
                        }
                        yRot = rep.yRotation
                        cScale = rep.customScale
                        break
                    }
                }
            }
            objects.append((index, object, pos3, dims, cat, hasRep, repName, offset, yRot, cScale))
        }
        return objects
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Debug: \(furnitureObjects.count) Objects")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)

                HStack(spacing: 15) {
                    debugBadge("Walls", count: capturedRoom.walls.count, color: .gray)
                    debugBadge("Floors", count: capturedRoom.floors.count, color: .brown)
                    debugBadge("Doors", count: capturedRoom.doors.count, color: .blue)
                    debugBadge("Windows", count: capturedRoom.windows.count, color: .cyan)
                }
                .padding(.bottom, 5)

                if furnitureObjects.isEmpty {
                    Text("No furniture objects detected")
                        .font(.caption).foregroundColor(.gray).padding()
                } else {
                    ForEach(Array(furnitureObjects.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color(RoomModelSceneView.wireframeColor(for: item.category)))
                                    .frame(width: 10, height: 10)
                                Text("\(item.index): \(item.category)")
                                    .font(.subheadline).foregroundColor(.white)
                                Spacer()
                                Text(item.hasReplacement ? "REPLACED" : "SELECTABLE")
                                    .font(.caption)
                                    .foregroundColor(item.hasReplacement ? .green : .red)
                            }
                            Text(String(format: "Pos: (%.2f, %.2f, %.2f)", item.pos.x, item.pos.y, item.pos.z))
                                .font(.caption).foregroundColor(.gray)
                            Text(String(format: "Size: %.2f x %.2f x %.2f m", item.dims.x, item.dims.y, item.dims.z))
                                .font(.caption).foregroundColor(.gray)

                            if let name = item.replacementName {
                                Text("→ \(name)")
                                    .font(.caption).foregroundColor(.green)
                            }
                            if let off = item.offset {
                                Text(String(format: "Offset: (%.2f, %.2f, %.2f)", off.x, off.y, off.z))
                                    .font(.caption).foregroundColor(.cyan)
                            }
                            if let yr = item.yRot {
                                Text(String(format: "Y Rotation: %.1f°", yr * 180.0 / .pi))
                                    .font(.caption).foregroundColor(.cyan)
                            }
                            if let cs = item.customScale {
                                Text(String(format: "Custom Scale: %.2fx", cs))
                                    .font(.caption).foregroundColor(.cyan)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func debugBadge(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline).foregroundColor(color)
            Text(label)
                .font(.caption2).foregroundColor(.gray)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FurnitureCard
// ═══════════════════════════════════════════════════════════════════

struct FurnitureCard: View {
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    let modelName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                USDZThumbnailView(
                    url: catalogManager.modelFileURL(for: modelName),
                    size: CGSize(width: 80, height: 80)
                )
                Text(modelName.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassCard()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - ScannedFurnitureCard
// ═══════════════════════════════════════════════════════════════════

struct ScannedFurnitureCard: View {
    let item: ScannedFurniture
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                USDZThumbnailView(
                    url: item.usdzURL,
                    size: CGSize(width: 80, height: 80)
                )
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(2)
                Text(item.category.capitalized)
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassCard()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - MarketplaceModelCard
// ═══════════════════════════════════════════════════════════════════

/// Card for a marketplace model that has been downloaded to the device.
struct MarketplaceModelCard: View {
    let item: DownloadedMarketplaceModel
    let catalogManager: FurnitureCatalogManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                USDZThumbnailView(
                    url: catalogManager.modelFileURL(for: item.catalogKey),
                    size: CGSize(width: 80, height: 80)
                )
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 8))
                    Text(item.category.capitalized)
                        .font(.caption2)
                }
                .foregroundColor(AppTheme.glowCyan.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassCard()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - ShareSheet
// ═══════════════════════════════════════════════════════════════════

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Category description extension
// ═══════════════════════════════════════════════════════════════════

extension CapturedRoom.Object.Category {
    var description: String {
        "\(self)".replacingOccurrences(of: ".", with: "").capitalized
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - USDZ Thumbnail Cache & View
// ═══════════════════════════════════════════════════════════════════

/// Thread-safe in-memory cache for generated USDZ thumbnails.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 80 // keep at most 80 thumbnails in memory
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Renders a 3D thumbnail preview of a USDZ/USDC file using
/// Apple's `QLThumbnailGenerator`.  Displays a loading spinner while
/// the thumbnail is being generated and falls back to a system icon
/// if the file is missing or generation fails.
struct USDZThumbnailView: View {
    let url: URL?
    let size: CGSize

    @State private var thumbnail: UIImage? = nil
    @State private var isLoading = true

    init(url: URL?, size: CGSize = CGSize(width: 120, height: 120)) {
        self.url = url
        self.size = size
    }

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .tint(.gray)
            } else {
                // Fallback icon when no thumbnail could be generated
                Image(systemName: "cube.fill")
                    .font(.system(size: min(size.width, size.height) * 0.4))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        guard let url else {
            isLoading = false
            return
        }

        let cacheKey = url.lastPathComponent
        if let cached = ThumbnailCache.shared.image(forKey: cacheKey) {
            self.thumbnail = cached
            self.isLoading = false
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size.width * 2, height: size.height * 2),
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateRepresentations(for: request) { representation, _, error in
            DispatchQueue.main.async {
                if let representation {
                    let img = representation.uiImage
                    ThumbnailCache.shared.setImage(img, forKey: cacheKey)
                    self.thumbnail = img
                }
                self.isLoading = false
            }
        }
    }
}
