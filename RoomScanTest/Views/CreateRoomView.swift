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
    var onRoomCreated: ((Room) -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.glowCyan.opacity(0.10))
                            .frame(width: 100, height: 100)
                            .blur(radius: 25)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 72, height: 72)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }

                    Text("Create New Room")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    // Name input card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ROOM NAME")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                            .tracking(0.8)

                        TextField("e.g. Living Room, Bedroom", text: $roomName)
                            .textInputAutocapitalization(.words)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        roomName.isEmpty
                                        ? Color.white.opacity(0.08)
                                        : AppTheme.glowCyan.opacity(0.4),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)

                    // Scan Button
                    NavigationLink(
                        destination: RoomScanView(
                            roomName: roomName,
                            onComplete: { room in
                                onRoomCreated?(room)
                            }
                        )
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                            Text("Start Room Scan")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            roomName.isEmpty
                            ? AnyShapeStyle(Color.white.opacity(0.08))
                            : AnyShapeStyle(AppTheme.accentGradientInline)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                        .shadow(color: roomName.isEmpty ? .clear : AppTheme.glowCyan.opacity(0.3),
                                radius: 10, y: 4)
                    }
                    .disabled(roomName.isEmpty)
                    .padding(.horizontal, 28)

                    // Footer hint
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.tertiaryText)
                        Text("You'll scan the room using your camera to detect furniture and walls.")
                            .font(.caption)
                            .foregroundColor(AppTheme.tertiaryText)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
    }
}

#Preview {
    CreateRoomView()
        .environmentObject(RoomManager(userManager: UserManager()))
        .preferredColorScheme(.dark)
}
