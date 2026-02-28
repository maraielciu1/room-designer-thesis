//
//  RoomListView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct RoomListView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var roomManager: RoomManager
    @State private var showCreateRoom = false

    // Programmatic navigation after scanning
    @State private var pendingRoom: Room? = nil
    @State private var navigateToNewRoom = false
    @State private var showHistory = false

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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateRoom = true }) {
                    Image(systemName: "plus")
                        .tintedIconGradient()
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .tintedIcon(AppTheme.glowViolet)
                }
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
    }
    .preferredColorScheme(.dark)
}
