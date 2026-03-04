//
//  ImageExportService.swift
//  RoomScanTest
//
//  Exports captured Object Capture images as a zip archive for
//  off-device Gaussian Splatting training (COLMAP → 3DGS pipeline).
//

import Foundation
import UIKit

enum ImageExportService {

    // MARK: - Public API

    /// Creates a zip archive from a directory of captured images.
    /// Returns the URL of the zip file in the temporary directory.
    static func createZip(from imagesDirectory: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordError: NSError?

            coordinator.coordinate(
                readingItemAt: imagesDirectory,
                options: .forUploading,
                error: &coordError
            ) { zipURL in
                // NSFileCoordinator creates a temp zip; copy it to our own temp location
                let destName = "GaussianSplatting_Images_\(dateStamp()).zip"
                let destURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(destName)

                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: zipURL, to: destURL)
                    continuation.resume(returning: destURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordError {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Counts the image files in a directory (HEIC/JPEG/PNG).
    static func imageCount(in directory: URL) -> Int {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return 0 }
        let exts: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]
        return contents.filter { exts.contains($0.pathExtension.lowercased()) }.count
    }

    /// Presents a share sheet for the given file URL.
    @MainActor
    static func share(fileURL: URL, from viewController: UIViewController? = nil) {
        let vc = viewController ?? topViewController()
        guard let vc else { return }

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        // iPad popover anchor
        activityVC.popoverPresentationController?.sourceView = vc.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0
        )
        vc.present(activityVC, animated: true)
    }

    // MARK: - Helpers

    private static func dateStamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        return fmt.string(from: Date())
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var vc = root
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }
}
