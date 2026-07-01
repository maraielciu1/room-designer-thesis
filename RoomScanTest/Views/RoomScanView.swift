//
//  RoomScanView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import RoomPlan
import SwiftData

struct RoomScanView: View {
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @Environment(\.dismiss) var dismiss

    let roomName: String

    /// Called after a successful scan and room creation.
    var onComplete: ((Room) -> Void)? = nil

    @State private var isScanning = false
    @State private var createdRoom: Room? = nil
    @State private var isProcessing = false
    @State private var roomCaptureView: RoomCaptureView?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasProcessedRoom = false
    @State private var instructionsExpanded = true

    /// Captures ARKit camera frames during the scan to extract wall/floor colours
    @State private var colorCaptureService = RoomColorCaptureService()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if createdRoom != nil {
                //  Scan complete => brief success state
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.glowGreen.opacity(0.12))
                            .frame(width: 100, height: 100)
                            .blur(radius: 25)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(AppTheme.glowGreen)
                    }
                    Text("Room Scanned!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(roomName)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)

                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppTheme.glowCyan)
                        Text("Opening designer…")
                            .font(.footnote)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.top, 6)
                }
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if let room = createdRoom {
                            onComplete?(room)
                        }
                    }
                }

            } else if isScanning {
                //  Scanning: Live Camera Feed 
                if let captureView = roomCaptureView {
                    RoomCaptureViewWrapper(
                        captureView: captureView,
                        onCompletion: { capturedRoom in
                            DispatchQueue.main.async {
                                guard !self.hasProcessedRoom else { return }
                                self.hasProcessedRoom = true
                                self.isProcessing = false

                                // Stop colour capture and collect the results
                                let materials = self.colorCaptureService.stopCapturing()

                                #if DEBUG
                                let transitionDelay: TimeInterval = 1.0
                                #else
                                let transitionDelay: TimeInterval = 0.5
                                #endif

                                DispatchQueue.main.asyncAfter(deadline: .now() + transitionDelay) {
                                    self.roomCaptureView?.captureSession.stop()
                                    self.createdRoom = self.createRoomFromScan(capturedRoom, materials: materials)
                                }
                            }
                        },
                        onError: { error in
                            DispatchQueue.main.async {
                                _ = self.colorCaptureService.stopCapturing()
                                self.isProcessing = false
                                self.isScanning = false
                                self.errorMessage = "Scanning error: \(error.localizedDescription)"
                                self.showError = true
                            }
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.glowCyan)
                        Text("Initializing camera…")
                            .font(.footnote)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                // Overlay: bottom controls
                VStack {
                    Spacer()

                    if isProcessing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Building 3D Model…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .glassCard(cornerRadius: 16)
                        .padding(.bottom, 50)
                    } else {
                        Button(action: {
                            isProcessing = true
                            roomCaptureView?.captureSession.stop()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done Scanning")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.glowGreen)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                            .shadow(color: AppTheme.glowGreen.opacity(0.35), radius: 10, y: 4)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 50)
                    }
                }

            } else {
                //  Instructions (expandable) 
                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppTheme.glowCyan.opacity(0.10))
                            .frame(width: 110, height: 110)
                            .blur(radius: 28)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.accentGradientInline)
                            .frame(width: 80, height: 80)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }

                    Text("Ready to Scan")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)

                    // Collapsible instructions card
                    VStack(spacing: 0) {
                        //  Header / drag handle 
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                instructionsExpanded.toggle()
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 36, height: 4)

                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(AppTheme.accentGradientInline)
                                    Text("Scanning Tips")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .rotationEffect(.degrees(instructionsExpanded ? 0 : -180))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, instructionsExpanded ? 4 : 14)
                        }
                        .buttonStyle(.plain)

                        //  Expandable content 
                        if instructionsExpanded {
                            VStack(alignment: .leading, spacing: 14) {
                                InstructionRow(icon: "1.circle.fill", text: "Move slowly around the room")
                                InstructionRow(icon: "2.circle.fill", text: "Point camera at furniture")
                                InstructionRow(icon: "3.circle.fill", text: "Ensure good lighting")
                                InstructionRow(icon: "4.circle.fill", text: "Tap 'Start Scan' when ready")
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .glassCard(cornerRadius: AppTheme.cornerRadius)
                    .padding(.horizontal, 24)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if value.translation.height > 30 {
                                        instructionsExpanded = false
                                    } else if value.translation.height < -30 {
                                        instructionsExpanded = true
                                    }
                                }
                            }
                    )

                    Button(action: {
                        finalizePreScan()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                            Text("Start Scan")
                        }
                    }
                    .buttonStyle(GradientButtonStyle())

                    Spacer()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            DispatchQueue.main.async {
                _ = colorCaptureService.stopCapturing()
                roomCaptureView?.captureSession.stop()
                roomCaptureView = nil
            }
        }
    }

    // MARK: - Helpers

    private func finalizePreScan() {
        createdRoom = nil
        hasProcessedRoom = false
        isProcessing = false
        let newCaptureView = RoomCaptureView()
        roomCaptureView = newCaptureView

        #if DEBUG
        let scanStartDelay: TimeInterval = 0.3
        #else
        let scanStartDelay: TimeInterval = 0.1
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + scanStartDelay) {
            isScanning = true
        }

        // Start colour capture once the ARSession has had time to initialise.
        // We add a longer delay so RoomPlan has begun producing frames.
        DispatchQueue.main.asyncAfter(deadline: .now() + scanStartDelay + 1.5) {
            colorCaptureService.startCapturing(session: newCaptureView.captureSession)
        }
    }

    private func createRoomFromScan(_ capturedRoom: CapturedRoom, materials: RoomMaterials? = nil) -> Room {
        let room = roomManager.createRoom(name: roomName, capturedRoom: capturedRoom, roomMaterials: materials)
        roomManager.removeDuplicateRooms()
        return room
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accentGradientInline)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText.opacity(0.9))
        }
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
    let roomManager = RoomManager(userManager: userManager, modelContext: container.mainContext)
    return RoomScanView(roomName: "Living Room")
        .environmentObject(roomManager)
        .environmentObject(userManager)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
