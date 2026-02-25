//
//  CreateRoomView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct CreateRoomView: View {
    @EnvironmentObject var roomManager: RoomManager
    @Environment(\.dismiss) var dismiss
    @State private var roomName = ""

    /// Called when a room has been successfully scanned and created.
    /// The parent (RoomListView) uses this to dismiss the sheet and navigate.
    var onRoomCreated: ((Room) -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Room Name", text: $roomName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Room Details")
                } footer: {
                    Text("Give your room a name (e.g., Living Room, Bedroom)")
                }

                Section {
                    NavigationLink(
                        destination: RoomScanView(
                            roomName: roomName,
                            onComplete: { room in
                                // Bubble up to RoomListView so the sheet is dismissed
                                onRoomCreated?(room)
                            }
                        )
                    ) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Room")
                        }
                    }
                    .disabled(roomName.isEmpty)
                } header: {
                    Text("Next Steps")
                } footer: {
                    Text("Scan your room to detect furniture and start designing")
                }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreateRoomView()
        .environmentObject(RoomManager(userManager: UserManager()))
}
