//
//  GaussianSplatView.swift
//  RoomScanTest
//
//  SwiftUI wrapper for the Metal-based Gaussian Splatting renderer.
//  Provides orbit camera controls (drag to rotate, pinch to zoom)
//  and a loading/error state overlay.
//

import SwiftUI
import MetalKit

// MARK: - SwiftUI View

struct GaussianSplatView: View {
    let plyURL: URL

    @State private var renderer: GaussianSplatRenderer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var gaussianCount: Int = 0
    @State private var fps: Int = 0
    @State private var fpsTimer: Timer?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let renderer {
                GaussianSplatMetalView(renderer: renderer)
                    .ignoresSafeArea()

                //  HUD overlay 
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppTheme.glowGreen)
                                    .frame(width: 8, height: 8)
                                Text("\(gaussianCount.formatted()) splats")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                            Text("\(fps) FPS")
                                .font(.caption2.monospaced())
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassCard(cornerRadius: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    //  Controls hint 
                    HStack(spacing: 16) {
                        Label("Drag to orbit", systemImage: "hand.draw")
                        Label("Pinch to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.bottom, 12)
                }

            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.glowOrange)
                    Text("Failed to Load")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(AppTheme.glowCyan)
                        .scaleEffect(1.3)
                    Text("Loading Gaussian Splats…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
        .task {
            await loadPLY()
        }
        .onAppear {
            // FPS counter
            fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if let r = renderer, r.lastFrameTime > 0 {
                    fps = Int(1.0 / r.lastFrameTime)
                }
            }
        }
        .onDisappear {
            fpsTimer?.invalidate()
            fpsTimer = nil
        }
    }

    private func loadPLY() async {
        isLoading = true
        errorMessage = nil

        do {
            // Parse on background thread
            let scene = try await Task.detached(priority: .userInitiated) {
                try PLYParser.parse(url: plyURL)
            }.value

            guard let r = GaussianSplatRenderer() else {
                errorMessage = "Metal is not available on this device."
                isLoading = false
                return
            }

            r.loadScene(scene)
            renderer = r
            gaussianCount = scene.gaussians.count
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Metal View (UIViewRepresentable)

struct GaussianSplatMetalView: UIViewRepresentable {
    let renderer: GaussianSplatRenderer

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = 60
        mtkView.isOpaque = true

        // Gesture recognizers
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        mtkView.addGestureRecognizer(pinch)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer = renderer
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }

    // MARK: - Coordinator (MTKViewDelegate + Gestures)

    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: GaussianSplatRenderer

        init(renderer: GaussianSplatRenderer) {
            self.renderer = renderer
            super.init()
        }

        //  MTKViewDelegate 

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

        nonisolated func draw(in view: MTKView) {
            MainActor.assumeIsolated {
                renderer.render(in: view)
            }
        }

        //  Gesture Handlers 

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let sensitivity: Float = 0.005

            renderer.orbitTheta -= Float(translation.x) * sensitivity
            renderer.orbitPhi += Float(translation.y) * sensitivity

            // Clamp elevation to avoid gimbal lock
            renderer.orbitPhi = max(-Float.pi / 2 + 0.05, min(Float.pi / 2 - 0.05, renderer.orbitPhi))

            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                renderer.orbitDistance /= Float(gesture.scale)
                renderer.orbitDistance = max(0.1, min(50, renderer.orbitDistance))
                gesture.scale = 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Will show "File not found" without a real .ply file
    GaussianSplatView(plyURL: URL(fileURLWithPath: "/tmp/test.ply"))
        .preferredColorScheme(.dark)
}
