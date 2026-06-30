//
//  SHARPService.swift
//  RoomScanTest
//
//  HTTP client for the local SHARP inference server (sharp_server.py).
//  SHARP takes a single JPEG image and returns a binary .ply file containing
//  a 3D Gaussian Splatting scene in under one second on a GPU.
//
//  Reference: Mescheder et al., "SHARP: Sharp Monocular View Synthesis", ICLR 2025
//  https://machinelearning.apple.com/research/sharp-monocular-view
//

import Foundation
import UIKit

enum SHARPService {

    // MARK: - Configuration

    static let modalURL: String? = "https://maraielciu26--sharp-server-web.modal.run"

    /// UserDefaults key where a manually-entered server URL is persisted (fallback).
    static let serverURLKey = "sharp_server_base_url"

    static var serverBaseURL: String? {
        get {
            if let modal = modalURL { return modal }
            return UserDefaults.standard
                .string(forKey: serverURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            guard modalURL == nil else { return }  // ignore saves when Modal URL is active
            UserDefaults.standard.set(newValue, forKey: serverURLKey)
        }
    }

    static var serverURL: URL? {
        guard let raw = serverBaseURL, !raw.isEmpty else { return nil }
        let trimmed = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        return URL(string: trimmed)
    }

    // MARK: - Errors

    enum SHARPError: LocalizedError {
        case noServerURL
        case imageEncodingFailed
        case serverError(statusCode: Int, body: String?)
        case networkError(Swift.Error)
        case saveFailed(Swift.Error)

        var errorDescription: String? {
            switch self {
            case .noServerURL:
                return "No SHARP server URL configured. Enter the URL of your Mac running sharp_server.py (e.g. http://192.168.1.x:8765) in the capture screen."
            case .imageEncodingFailed:
                return "Could not JPEG-encode the captured image."
            case .serverError(let code, let body):
                return "SHARP server returned HTTP \(code).\(body.map { " \($0)" } ?? "")"
            case .networkError(let e):
                return "Network error: \(e.localizedDescription)"
            case .saveFailed(let e):
                return "Could not save .ply to disk: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Custom session (URLSession.shared caps at 60 s regardless of URLRequest.timeoutInterval)

    private static let inferSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 360   // 6 min — first run compiles Metal shaders
        cfg.timeoutIntervalForResource = 600   // 10 min total (includes 66 MB download)
        return URLSession(configuration: cfg)
    }()

    // MARK: - Inference

    /// Send a single photo to the SHARP server.
    /// - Returns: Local `file://` URL of the saved `.ply`.
    static func infer(image: UIImage) async throws -> URL {
        guard let base = serverURL else { throw SHARPError.noServerURL }
        guard let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw SHARPError.imageEncodingFailed
        }

        var request = URLRequest(url: base.appendingPathComponent("sharp/infer"))
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpegData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await inferSession.data(for: request)
        } catch {
            throw SHARPError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8)
            throw SHARPError.serverError(statusCode: http.statusCode, body: body)
        }

        // Persist .ply to Documents so GaussianSplatView can read it
        let filename = "sharp_\(Int(Date().timeIntervalSince1970)).ply"
        let plyURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: plyURL, options: .atomic)
        } catch {
            throw SHARPError.saveFailed(error)
        }

        return plyURL
    }

    // MARK: - Health check

    private static let pingSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 4
        cfg.timeoutIntervalForResource = 4
        return URLSession(configuration: cfg)
    }()

    /// Returns `true` if the server `/health` endpoint responds 200 within 4 s.
    static func ping() async -> Bool {
        guard let base = serverURL else { return false }
        var request = URLRequest(url: base.appendingPathComponent("health"))
        request.httpMethod = "GET"
        do {
            let (_, response) = try await pingSession.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
