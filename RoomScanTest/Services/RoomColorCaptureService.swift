//
//  RoomColorCaptureService.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 02.03.2026.
//
//  During a RoomPlan scan this service periodically samples the
//  live camera feed (via RoomCaptureSession → ARSession → ARFrame)
//  and computes the average colour of the centre region.
//
//  Based on the device's pitch angle it classifies each sample as
//  either a "wall" sample (camera roughly horizontal) or a "floor"
//  sample (camera tilted downward).  After scanning, the samples
//  are averaged to produce a RoomMaterials struct that stores the
//  dominant wall and floor colours.
//

import Foundation
import ARKit
import RoomPlan
import CoreImage

// MARK: - RoomColorCaptureService

class RoomColorCaptureService {

    // ── Configuration ────────────────────────────────────────────
    /// Seconds between frame samples (lower = more samples but more CPU)
    private let samplingInterval: TimeInterval = 1.5

    /// Pitch threshold (radians). Values below this classify as "floor".
    /// −0.45 rad ≈ −26°  (device tilted ~26° below horizontal)
    private let floorPitchThreshold: Float = -0.45

    // ── Internal state ───────────────────────────────────────────
    private var timer: Timer?
    private var wallSamples:  [(r: Double, g: Double, b: Double)] = []
    private var floorSamples: [(r: Double, g: Double, b: Double)] = []
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Weak capture session reference so we don't retain the view
    private weak var captureSession: RoomCaptureSession?

    // ── Public API ───────────────────────────────────────────────

    /// Begin sampling frames from the given RoomCaptureSession.
    /// Call this shortly after the session starts running.
    func startCapturing(session: RoomCaptureSession) {
        self.captureSession = session
        wallSamples.removeAll()
        floorSamples.removeAll()

        // Schedule on main run-loop (ARSession currentFrame is main-thread-safe)
        timer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            self?.sampleCurrentFrame()
        }
        print("[ColorCapture] Started sampling every \(samplingInterval)s")
    }

    /// Stop sampling and return the computed RoomMaterials (or nil if
    /// no usable samples were collected).
    func stopCapturing() -> RoomMaterials? {
        timer?.invalidate()
        timer = nil
        captureSession = nil

        let materials = computeMaterials()
        let wc = wallSamples.count
        let fc = floorSamples.count
        print("[ColorCapture] Stopped — \(wc) wall samples, \(fc) floor samples")
        return materials
    }

    // ── Frame Sampling ───────────────────────────────────────────

    private func sampleCurrentFrame() {
        guard let session = captureSession else { return }

        // Access the underlying ARSession's latest frame
        guard let frame = session.arSession.currentFrame else { return }

        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Determine device pitch from the camera's Euler angles
        // eulerAngles.x = pitch:  negative → looking down,  positive → looking up
        let pitch = frame.camera.eulerAngles.x
        let isLookingAtFloor = pitch < floorPitchThreshold

        // Sample from the centre 50 % of the image (avoids edges / UI overlays)
        let ext = ciImage.extent
        let sampleRect = CGRect(
            x: ext.origin.x + ext.width  * 0.25,
            y: ext.origin.y + ext.height * 0.25,
            width:  ext.width  * 0.5,
            height: ext.height * 0.5
        )

        guard let avg = averageColor(of: ciImage, in: sampleRect) else { return }

        // Ignore very dark frames (camera may be obstructed / initialising)
        let brightness = avg.r * 0.299 + avg.g * 0.587 + avg.b * 0.114
        guard brightness > 0.05 else { return }

        if isLookingAtFloor {
            floorSamples.append(avg)
        } else {
            wallSamples.append(avg)
        }
    }

    // ── Colour Computation ───────────────────────────────────────

    /// Uses CIAreaAverage to compute the mean colour of a region.
    private func averageColor(of image: CIImage, in rect: CGRect) -> (r: Double, g: Double, b: Double)? {
        let cropped = image.cropped(to: rect)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: cropped,
            kCIInputExtentKey: CIVector(cgRect: rect)
        ]),
        let output = filter.outputImage else { return nil }

        // Render the 1×1 result into a 4-byte RGBA bitmap
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return (
            r: Double(bitmap[0]) / 255.0,
            g: Double(bitmap[1]) / 255.0,
            b: Double(bitmap[2]) / 255.0
        )
    }

    /// Average all collected samples into a final RoomMaterials.
    private func computeMaterials() -> RoomMaterials? {
        // Need at least some samples to produce meaningful results
        guard !wallSamples.isEmpty || !floorSamples.isEmpty else { return nil }

        let wallColor  = averageSamples(wallSamples,  fallback: (0.82, 0.84, 0.88))
        let floorColor = averageSamples(floorSamples, fallback: (0.50, 0.46, 0.42))

        return RoomMaterials(
            wallColor:  wallColor,
            floorColor: floorColor,
            wallSampleCount:  wallSamples.count,
            floorSampleCount: floorSamples.count
        )
    }

    /// Average an array of (r, g, b) tuples.  Returns `fallback` if array is empty.
    private func averageSamples(
        _ samples: [(r: Double, g: Double, b: Double)],
        fallback: (Double, Double, Double)
    ) -> CodableColor {
        guard !samples.isEmpty else {
            return CodableColor(red: fallback.0, green: fallback.1, blue: fallback.2)
        }

        let n = Double(samples.count)
        let r = samples.map(\.r).reduce(0, +) / n
        let g = samples.map(\.g).reduce(0, +) / n
        let b = samples.map(\.b).reduce(0, +) / n

        return CodableColor(red: r, green: g, blue: b)
    }
}
