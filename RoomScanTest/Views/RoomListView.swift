//
//  RoomListView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct RoomListView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.presentAccount) private var presentAccount
    @State private var showCreateRoom = false
    @State private var showRoom3DGSCapture = false
    @State private var showSHARPCapture = false

    // Programmatic navigation after scanning
    @State private var pendingRoom: Room? = nil
    @State private var navigateToNewRoom = false
    @State private var showHistory = false
    @State private var showBlenderExportShare = false
    @State private var blenderExportURL: URL?
    @State private var showBlenderExportError = false
    @State private var blenderExportErrorMessage = ""
    @State private var isBlenderExporting = false
    @State private var roomPendingDeletion: Room?
    @State private var showDeleteConfirmation = false
    @State private var showDemoSplat = false

    private var demoSplatURL: URL? {
        // First try app bundle, then Documents folder
        if let bundleURL = Bundle.main.url(forResource: "demo_splat", withExtension: "ply") {
            return bundleURL
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsURL = docs.appendingPathComponent("demo_splat.ply")
        return FileManager.default.fileExists(atPath: docsURL.path) ? docsURL : nil
    }

    private var roomScanMenuItems: [AppScreenHeaderMenuItem] {
        [
            AppScreenHeaderMenuItem(title: "Room Scan (RoomPlan)", systemImage: "viewfinder") {
                showCreateRoom = true
            },
            AppScreenHeaderMenuItem(title: "3D Gaussian Splat", systemImage: "sparkles") {
                showRoom3DGSCapture = true
            },
            AppScreenHeaderMenuItem(title: "SHARP ML", systemImage: "camera.viewfinder") {
                showSHARPCapture = true
            },
        ]
    }

    var userRooms: [Room] {
        roomManager.getRoomsForCurrentUser()
    }

    var body: some View {
        mainContent
            .background(hiddenNavigationLinks.hidden())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { screenHeader }
            .fullScreenCover(isPresented: $showRoom3DGSCapture) { room3DGSCaptureCover }
            .fullScreenCover(isPresented: $showSHARPCapture) { sharpCaptureCover }
            .sheet(isPresented: $showCreateRoom, onDismiss: handleCreateRoomDismiss) { createRoomSheet }
            .onChange(of: navigateToNewRoom) { _, active in
                if !active { pendingRoom = nil }
            }
            .sheet(isPresented: $showBlenderExportShare, onDismiss: handleBlenderExportShareDismiss) {
                blenderExportShareSheet
            }
            .alert("Could not export", isPresented: $showBlenderExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(blenderExportErrorMessage)
            }
            .alert("Delete Room?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    roomPendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    if let room = roomPendingDeletion {
                        deleteRoom(room)
                    }
                    roomPendingDeletion = nil
                }
            } message: {
                deleteConfirmationMessage
            }
            .overlay { blenderExportOverlay }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if userRooms.isEmpty {
                VStack(spacing: 0) {
                    demoSplatCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    Spacer()
                    emptyStateView
                    Spacer()
                }
            } else {
                roomsList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowViolet.opacity(0.10))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                Image(systemName: "house.lodge.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.accentGradientInline)
            }
            Text("No Rooms Yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Scan your first room to get started")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)

            Menu {
                roomScanMenuButtons
            } label: {
                Label("Scan a Room", systemImage: "plus.viewfinder")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.top, 8)
        }
    }

    private var roomsList: some View {
        List {
            Section {
                demoSplatCard
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(userRooms) { room in
                roomRow(for: room)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var demoSplatCard: some View {
        Button {
            if demoSplatURL != nil {
                showDemoSplat = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.glowViolet.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.glowViolet, AppTheme.glowCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Demo 3D Gaussian Splat")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("DEMO")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(AppTheme.glowViolet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.glowViolet.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    Text(demoSplatURL != nil ? "Tap to view best result" : "Add demo_splat.ply to bundle or Documents")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()

                Image(systemName: demoSplatURL != nil ? "chevron.right" : "exclamationmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(demoSplatURL != nil ? AppTheme.tertiaryText : AppTheme.glowOrange)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(AppTheme.glowViolet.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.glowViolet.opacity(0.5), AppTheme.glowCyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(demoSplatURL == nil)
        .fullScreenCover(isPresented: $showDemoSplat) {
            NavigationStack {
                if let url = demoSplatURL {
                    GaussianSplatView(plyURL: url)
                        .navigationTitle("Demo 3DGS")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { showDemoSplat = false }
                            }
                        }
                }
            }
            .appSheetBackground()
        }
    }

    @ViewBuilder
    private func roomRow(for room: Room) -> some View {
        ZStack {
            NavigationLink(destination: RoomDesignerView(room: room)) {
                Color.clear
            }
            .opacity(0)
            RoomRowView(room: room)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contextMenu {
            Button {
                exportRoomForBlender(room)
            } label: {
                Label("Export for Blender…", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(!room.hasScanData)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                roomPendingDeletion = room
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(AppTheme.glowRed)
        }
    }

    @ViewBuilder
    private var hiddenNavigationLinks: some View {
        NavigationLink(
            destination: Group {
                if let room = pendingRoom {
                    RoomDesignerView(room: room)
                }
            },
            isActive: $navigateToNewRoom,
            label: { EmptyView() }
        )
        NavigationLink(
            destination: HistoryView(),
            isActive: $showHistory,
            label: { EmptyView() }
        )
    }

    private var screenHeader: some View {
        AppScreenHeader(
            title: "My Rooms",
            leading: .leading("clock.arrow.circlepath", accessibilityLabel: "History") {
                showHistory = true
            },
            trailingMenu: roomScanMenuItems,
            profileInitial: userManager.currentUser.map { String($0.name.prefix(1)).uppercased() },
            onProfileTap: presentAccount
        )
    }

    private var room3DGSCaptureCover: some View {
        NavigationStack {
            Room3DGSCaptureView()
        }
        .appSheetBackground()
    }

    private var sharpCaptureCover: some View {
        NavigationStack {
            SHARPCaptureView()
        }
        .appSheetBackground()
    }

    private var createRoomSheet: some View {
        CreateRoomView { createdRoom in
            pendingRoom = createdRoom
            showCreateRoom = false
        }
    }

    @ViewBuilder
    private var blenderExportShareSheet: some View {
        if let url = blenderExportURL {
            ShareSheet(activityItems: [url])
        }
    }

    @ViewBuilder
    private var deleteConfirmationMessage: some View {
        if let room = roomPendingDeletion {
            Text("“\(room.name)” and its scan data will be permanently deleted. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var blenderExportOverlay: some View {
        if isBlenderExporting {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView("Preparing export…")
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.surfacePrimary))
            }
        }
    }

    private func handleCreateRoomDismiss() {
        if pendingRoom != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                navigateToNewRoom = true
            }
        }
    }

    private func handleBlenderExportShareDismiss() {
        if let url = blenderExportURL {
            try? FileManager.default.removeItem(at: url)
        }
        blenderExportURL = nil
    }

    @ViewBuilder
    private var roomScanMenuButtons: some View {
        ForEach(roomScanMenuItems) { item in
            Button(action: item.action) {
                if let icon = item.systemImage {
                    Label(item.title, systemImage: icon)
                } else {
                    Text(item.title)
                }
            }
        }
    }

    private func deleteRoom(_ room: Room) {
        if pendingRoom?.id == room.id {
            pendingRoom = nil
            navigateToNewRoom = false
        }
        projectManager.removeRoomReferences(for: room.id)
        roomManager.deleteRoom(room)
    }

    private func exportRoomForBlender(_ room: Room) {
        guard let captured = room.getCapturedRoom() else {
            blenderExportErrorMessage = "This room has no scan data to export."
            showBlenderExportError = true
            return
        }
        isBlenderExporting = true
        Task { @MainActor in
            defer { isBlenderExporting = false }
            let mats = RoomBlenderExportService.materialsForListExport(room: room)
            do {
                let url = try RoomBlenderExportService.makeExportZip(
                    room: room,
                    capturedRoom: captured,
                    wallColor: mats.wall,
                    floorColor: mats.floor,
                    wallPattern: mats.wallPattern,
                    floorPattern: mats.floorPattern,
                    catalog: catalogManager
                )
                blenderExportURL = url
                showBlenderExportShare = true
            } catch {
                blenderExportErrorMessage = error.localizedDescription
                showBlenderExportError = true
            }
        }
    }
}

struct RoomRowView: View {
    let room: Room

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(room.hasScanData
                          ? AppTheme.glowCyan.opacity(0.12)
                          : AppTheme.secondaryTint.opacity(0.35))
                    .frame(width: 50, height: 50)
                Image(systemName: room.hasScanData ? "view.3d" : "cube.transparent")
                    .font(.system(size: 22))
                    .foregroundStyle(room.hasScanData
                                     ? AppTheme.accentGradientInline
                                     : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Updated \(room.updatedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)

                HStack(spacing: 8) {
                    if !room.furnitureReplacements.isEmpty {
                        Label("\(room.furnitureReplacements.count)", systemImage: "cube.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.warmAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.glowCyan.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if room.hasScanData {
                        Label("3D", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppTheme.glowGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.glowGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.tertiaryText)
        }
        .padding(14)
        .glassCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

#Preview {
    let container = try! ModelContainer(for:
        RoomEntity.self, FurnitureReplacementEntity.self,
        ProjectEntity.self, ScannedFurnitureEntity.self,
        ReplacementHistoryEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let userManager = UserManager()
    let roomManager = RoomManager(userManager: userManager, modelContext: ctx)
    return NavigationView {
        RoomListView()
            .environmentObject(userManager)
            .environmentObject(roomManager)
            .environmentObject(FurnitureCatalogManager())
            .environmentObject(ProjectManager(userManager: userManager, roomManager: roomManager, modelContext: ctx))
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
