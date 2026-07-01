//
//  CreateRoomView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import SwiftData

struct CreateRoomView: View {
    @EnvironmentObject var roomManager: RoomManager
    @Environment(\.dismiss) var dismiss
    @State private var roomName = ""

    /// Called when a room has been successfully scanned and created.
    var onRoomCreated: ((Room) -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.warmAccent.opacity(0.14))
                            .frame(width: 100, height: 100)
                            .blur(radius: 25)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 72, height: 72)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(AppTheme.warmAccent.opacity(0.35), lineWidth: 1)
                            )
                    }

                    Text("Create New Room")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)

                    // Name input card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ROOM NAME")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                            .tracking(0.8)

                        TextField("e.g. Living Room, Bedroom", text: $roomName)
                            .textInputAutocapitalization(.words)
                            .padding(14)
                            .background(AppTheme.secondaryTint.opacity(0.35))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        roomName.isEmpty
                                        ? AppTheme.warmAccent.opacity(0.2)
                                        : AppTheme.warmAccent.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(AppTheme.primaryText)
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
                        .foregroundStyle(
                            roomName.isEmpty
                            ? AppTheme.secondaryText
                            : AppTheme.primaryDark
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            roomName.isEmpty
                            ? AnyShapeStyle(AppTheme.secondaryTint.opacity(0.5))
                            : AnyShapeStyle(AppTheme.warmAccent)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius)
                                .strokeBorder(AppTheme.lightNeutral.opacity(roomName.isEmpty ? 0.15 : 0.35), lineWidth: 1)
                        )
                        .shadow(color: roomName.isEmpty ? .clear : AppTheme.glowAccent,
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
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.warmAccent)
                }
            }
        }
        .appSheetBackground()
    }
}

#Preview {
    let container = try! ModelContainer(for:
        RoomEntity.self, FurnitureReplacementEntity.self,
        ProjectEntity.self, ScannedFurnitureEntity.self,
        ReplacementHistoryEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let userManager = UserManager()
    return CreateRoomView()
        .environmentObject(RoomManager(userManager: userManager, modelContext: container.mainContext))
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
