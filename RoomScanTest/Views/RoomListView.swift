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

    var userRooms: [Room] {
        roomManager.getRoomsForCurrentUser()
    }

    var body: some View {
        // No NavigationView here — AppRootView already provides one
        ZStack {
            if userRooms.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "house.lodge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Rooms Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Create your first room to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(userRooms) { room in
                        NavigationLink(destination: RoomDesignerView(room: room)) {
                            RoomRowView(room: room)
                        }
                    }
                    .onDelete(perform: deleteRooms)
                }
            }
        }
        // Hidden link for programmatic navigation to a newly scanned room
        .background(
            NavigationLink(
                destination: Group {
                    if let room = pendingRoom {
                        RoomDesignerView(room: room)
                    }
                },
                isActive: $navigateToNewRoom,
                label: { EmptyView() }
            )
            .hidden()
        )
        .navigationTitle("My Rooms")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateRoom = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(destination: HistoryView()) {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showCreateRoom, onDismiss: {
            // After the sheet closes, auto-navigate if a room was just created
            if pendingRoom != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    navigateToNewRoom = true
                }
            }
        }) {
            CreateRoomView { createdRoom in
                // Called by RoomScanView after a successful scan
                pendingRoom = createdRoom
                showCreateRoom = false          // dismiss the sheet
            }
        }
        .onChange(of: navigateToNewRoom) { _, active in
            // Clear pending room when user navigates back
            if !active { pendingRoom = nil }
        }
    }

    private func deleteRooms(at offsets: IndexSet) {
        for index in offsets {
            roomManager.deleteRoom(userRooms[index])
        }
    }
}

struct RoomRowView: View {
    let room: Room

    var body: some View {
        HStack {
            // Scan data indicator
            Circle()
                .fill(room.hasScanData ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.headline)
                Text("Updated: \(room.updatedAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if !room.furnitureReplacements.isEmpty {
                        Label("\(room.furnitureReplacements.count) replacements", systemImage: "cube.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if room.hasScanData {
                        Label("3D scan", systemImage: "view.3d")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Scan data unavailable", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        RoomListView()
            .environmentObject(UserManager())
            .environmentObject(RoomManager(userManager: UserManager()))
    }
}
