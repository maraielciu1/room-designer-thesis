//
//  RoomListView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import UIKit

struct RoomListView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @State private var showCreateRoom = false

    // Programmatic navigation after scanning
    @State private var pendingRoom: Room? = nil
    @State private var navigateToNewRoom = false
    @State private var showHistory = false
    @State private var showBlenderExportShare = false
    @State private var blenderExportURL: URL?
    @State private var showBlenderExportError = false
    @State private var blenderExportErrorMessage = ""
    @State private var isBlenderExporting = false

    var userRooms: [Room] {
        roomManager.getRoomsForCurrentUser()
    }

    var body: some View {
        ZStack {
            // Dark background
            Color(hex: 0x0B0D17).ignoresSafeArea()

            if userRooms.isEmpty {
                // ── Empty State ──
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
                        .foregroundColor(.white)
                    Text("Scan your first room to get started")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)

                    Button(action: { showCreateRoom = true }) {
                        Label("Scan a Room", systemImage: "plus.viewfinder")
                    }
                    .buttonStyle(GradientButtonStyle())
                    .padding(.top, 8)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(userRooms) { room in
                            NavigationLink(destination: RoomDesignerView(room: room)) {
                                RoomRowView(room: room)
                            }
                            .contextMenu {
                                Button {
                                    exportRoomForBlender(room)
                                } label: {
                                    Label("Export for Blender…", systemImage: "square.and.arrow.up.on.square")
                                }
                                .disabled(!room.hasScanData)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        // Hidden links for programmatic navigation
        .background(
            Group {
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
            .hidden()
        )
        .navigationTitle("My Rooms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: 0x0B0D17).opacity(0.88), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .accessibilityLabel("History")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateRoom = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                .accessibilityLabel("Scan a room")
            }
        }
        .sheet(isPresented: $showCreateRoom, onDismiss: {
            if pendingRoom != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    navigateToNewRoom = true
                }
            }
        }) {
            CreateRoomView { createdRoom in
                pendingRoom = createdRoom
                showCreateRoom = false
            }
        }
        .onChange(of: navigateToNewRoom) { _, active in
            if !active { pendingRoom = nil }
        }
        .sheet(isPresented: $showBlenderExportShare, onDismiss: {
            if let url = blenderExportURL {
                try? FileManager.default.removeItem(at: url)
            }
            blenderExportURL = nil
        }) {
            if let url = blenderExportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Could not export", isPresented: $showBlenderExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blenderExportErrorMessage)
        }
        .overlay {
            if isBlenderExporting {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView("Preparing export…")
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x1A1D2E)))
                }
            }
        }
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
                          : Color.white.opacity(0.06))
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
                    .foregroundColor(.white)

                Text("Updated \(room.updatedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)

                HStack(spacing: 8) {
                    if !room.furnitureReplacements.isEmpty {
                        Label("\(room.furnitureReplacements.count)", systemImage: "cube.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppTheme.glowCyan)
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
    NavigationView {
        RoomListView()
            .environmentObject(UserManager())
            .environmentObject(RoomManager(userManager: UserManager()))
            .environmentObject(FurnitureCatalogManager())
    }
    .preferredColorScheme(.dark)
}
