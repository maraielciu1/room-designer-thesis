//
//  RoomScanView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI
import RoomPlan

struct RoomScanView: View {
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var catalogManager: FurnitureCatalogManager
    @Environment(\.dismiss) var dismiss

    let roomName: String

    /// Called after a successful scan and room creation.
    /// The parent chain (CreateRoomView → RoomListView) uses this to dismiss the
    /// sheet and navigate to the designer.
    var onComplete: ((Room) -> Void)? = nil

    @State private var isScanning = false
    @State private var createdRoom: Room? = nil
    @State private var isProcessing = false
    @State private var roomCaptureView: RoomCaptureView?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasProcessedRoom = false

    var body: some View {
        ZStack {
            if createdRoom != nil {
                // ── Scan complete — brief success state ──
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("Room Scanned!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(roomName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView("Opening designer…")
                        .padding(.top, 10)
                }
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    // Give the user a moment to see the success state, then
                    // signal the parent to dismiss the sheet & navigate.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if let room = createdRoom {
                            onComplete?(room)
                        }
                    }
                }

            } else if isScanning {
                // ── Scanning: Live Camera Feed ──
                if let captureView = roomCaptureView {
                    RoomCaptureViewWrapper(
                        captureView: captureView,
                        onCompletion: { capturedRoom in
                            DispatchQueue.main.async {
                                guard !self.hasProcessedRoom else { return }
                                self.hasProcessedRoom = true
                                self.isProcessing = false

                                #if DEBUG
                                let transitionDelay: TimeInterval = 1.0
                                #else
                                let transitionDelay: TimeInterval = 0.5
                                #endif

                                DispatchQueue.main.asyncAfter(deadline: .now() + transitionDelay) {
                                    self.roomCaptureView?.captureSession.stop()
                                    self.createdRoom = self.createRoomFromScan(capturedRoom)
                                }
                            }
                        },
                        onError: { error in
                            DispatchQueue.main.async {
                                self.isProcessing = false
                                self.isScanning = false
                                self.errorMessage = "Scanning error: \(error.localizedDescription)"
                                self.showError = true
                            }
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                } else {
                    ProgressView("Initializing camera...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                }

                VStack {
                    Spacer()

                    if isProcessing {
                        ProgressView("Building 3D Model...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    } else {
                        Button(action: {
                            isProcessing = true
                            roomCaptureView?.captureSession.stop()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done Scanning")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 50)
                    }
                }

            } else {
                // ── Instructions ──
                VStack(spacing: 30) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Ready to Scan")
                        .font(.title)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 15) {
                        InstructionRow(icon: "1.circle.fill", text: "Move slowly around the room")
                        InstructionRow(icon: "2.circle.fill", text: "Point camera at furniture")
                        InstructionRow(icon: "3.circle.fill", text: "Ensure good lighting")
                        InstructionRow(icon: "4.circle.fill", text: "Tap 'Start Scan' when ready")
                    }
                    .padding()

                    Button(action: {
                        finalizePreScan()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Scan")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            DispatchQueue.main.async {
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
        roomCaptureView = RoomCaptureView()

        #if DEBUG
        let scanStartDelay: TimeInterval = 0.3
        #else
        let scanStartDelay: TimeInterval = 0.1
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + scanStartDelay) {
            isScanning = true
        }
    }

    private func createRoomFromScan(_ capturedRoom: CapturedRoom) -> Room {
        let room = roomManager.createRoom(name: roomName, capturedRoom: capturedRoom)
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
                .foregroundColor(.blue)
                .font(.title3)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    RoomScanView(roomName: "Living Room")
        .environmentObject(RoomManager(userManager: UserManager()))
        .environmentObject(UserManager())
}
