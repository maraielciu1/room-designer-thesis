//
//  RoomPlanView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//
//  This file contains the RoomCaptureViewWrapper and Coordinator
//  used for room scanning functionality
//

import SwiftUI
import RoomPlan
import RealityKit

// COORDINATOR: Handles the end of the scan
//
// IMPORTANT: With SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor in this project,
// every type is implicitly @MainActor. However, RoomCaptureViewDelegate methods
// may be called by the RoomPlan framework from internal threads.
// We mark delegate methods as `nonisolated` and properties as `nonisolated(unsafe)`
// to prevent actor-isolation crashes that occur ONLY when the Xcode debugger is attached
// (the debugger enables stricter concurrency and Metal API validation).
//
@objc class RoomCaptureCoordinator: NSObject, RoomCaptureViewDelegate {
    // nonisolated(unsafe) because these are accessed from nonisolated delegate methods
    // that RoomPlan may call from any thread
    nonisolated(unsafe) var onCompletion: (@Sendable (CapturedRoom) -> Void)?
    nonisolated(unsafe) var onError: (@Sendable (Error) -> Void)?
    private nonisolated(unsafe) var hasCalledCompletion = false
    
    init(onCompletion: @escaping @Sendable (CapturedRoom) -> Void, onError: @escaping @Sendable (Error) -> Void) {
        self.onCompletion = onCompletion
        self.onError = onError
        super.init()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    func encode(with coder: NSCoder) {}

    // Mark as nonisolated — RoomPlan may call this from a background thread
    // and it returns a synchronous Bool, so it CANNOT be dispatched to MainActor
    nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        if let error = error {
            // Dispatch error callback to main thread for UI safety
            DispatchQueue.main.async { [self] in
                self.onError?(error)
            }
            return false
        }
        return true
    }

    // Mark as nonisolated — RoomPlan may call this from a background thread
    nonisolated func captureView(didPresent room: CapturedRoom, error: (any Error)?) {
        if let error = error {
            DispatchQueue.main.async { [self] in
                self.onError?(error)
            }
            return
        }
        
        // Only call completion once - prevent duplicate processing
        guard !hasCalledCompletion else { return }
        hasCalledCompletion = true
        
        // Dispatch to main thread for UI safety
        DispatchQueue.main.async { [self] in
            self.onCompletion?(room)
        }
    }
}

// Helper Wrapper for the Scanner
struct RoomCaptureViewWrapper: UIViewRepresentable {
    let captureView: RoomCaptureView
    var onCompletion: @Sendable (CapturedRoom) -> Void
    var onError: @Sendable (Error) -> Void
    
    func makeUIView(context: Context) -> RoomCaptureView {
        // makeUIView is called on main thread
        // Set delegate first - this is critical and must happen before starting session
        captureView.delegate = context.coordinator
        
        // Use a longer delay in DEBUG builds (when Xcode debugger may be attached)
        // The debugger adds overhead to Metal and ARKit initialization, so we need
        // more time before starting the RoomPlan session
        #if DEBUG
        let startDelay: TimeInterval = 0.8
        #else
        let startDelay: TimeInterval = 0.2
        #endif
        
        // Delay session start to ensure view is fully initialized
        // This prevents Metal rendering conflicts, especially with debugger attached
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            // Only start if delegate is still set (view hasn't been deallocated)
            if captureView.delegate === context.coordinator {
                let configuration = RoomCaptureSession.Configuration()
                captureView.captureSession.run(configuration: configuration)
            }
        }
        
        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // Ensure delegate is always set (SwiftUI might recreate coordinator)
        if uiView.delegate !== context.coordinator {
            uiView.delegate = context.coordinator
        }
    }
    
    func makeCoordinator() -> RoomCaptureCoordinator {
        RoomCaptureCoordinator(onCompletion: onCompletion, onError: onError)
    }
}
