//
//  GaussianSplatCloudService.swift
//  RoomScanTest
//
//  Uploads captured images to a backend that runs the 3D Gaussian Splatting
//  pipeline (COLMAP + 3DGS). The backend can be your own GPU server or a
//  proxy to a service like Replicate. Google Colab cannot be triggered by
//  an external API — run the same pipeline on your server instead.
//

import Foundation

// MARK: - Configuration

/// Base URL of your Gaussian Splatting training backend (e.g. https://your-server.com/gs).
/// Set via UserDefaults key `GaussianSplatCloudService.serverBaseURLKey` or leave nil to hide cloud training.
enum GaussianSplatCloudConfig {
    static let serverBaseURLKey = "gs_cloud_server_base_url"

    /// User-configurable server base URL (no trailing slash). Example: "https://my-gs-backend.run.app"
    static var serverBaseURL: String? {
        get {
            UserDefaults.standard
                .string(forKey: serverBaseURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set { UserDefaults.standard.set(newValue, forKey: serverBaseURLKey) }
    }

    static var serverURL: URL? {
        guard let s = serverBaseURL, !s.isEmpty else { return nil }
        return URL(string: s.hasSuffix("/") ? String(s.dropLast()) : s)
    }
}

// MARK: - API Contract

/// Backend must implement:
/// - POST /jobs  (multipart/form-data: file = zip)  → { "jobId": "uuid" }
/// - GET  /jobs/{id}/status                        → { "status": "pending"|"processing"|"completed"|"failed", "progress": 0-100? }
/// - GET  /jobs/{id}/result                        → binary .ply (when status == completed)
struct GaussianSplatCloudService {

    // MARK: - Endpoint URLs (testable contract)

    static func jobsURL(serverBaseURL: URL) -> URL {
        serverBaseURL.appendingPathComponent("jobs")
    }

    static func jobStatusURL(serverBaseURL: URL, jobId: String) -> URL {
        jobsURL(serverBaseURL: serverBaseURL)
            .appendingPathComponent(jobId)
            .appendingPathComponent("status")
    }

    static func jobResultURL(serverBaseURL: URL, jobId: String) -> URL {
        jobsURL(serverBaseURL: serverBaseURL)
            .appendingPathComponent(jobId)
            .appendingPathComponent("result")
    }

    /// Training + .ply download can take many minutes; use 2h so the app never times out during poll/download.
    private static let requestTimeout: TimeInterval = 7200

    private static let longTimeoutSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        return URLSession(configuration: config)
    }()

    enum CloudJobStatus: String, Decodable {
        case pending
        case processing
        case completed
        case failed
    }

    struct StatusResponse: Decodable {
        let status: CloudJobStatus
        let progress: Int?
        let message: String?
    }

    enum Error: LocalizedError {
        case noServerURL
        case invalidURL
        case uploadFailed(underlying: Swift.Error?)
        case statusFailed(underlying: Swift.Error?)
        case downloadFailed(underlying: Swift.Error?)
        case jobFailed(message: String?)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .noServerURL: return "No cloud training server configured. Set the server URL in Settings."
            case .invalidURL: return "Invalid server URL."
            case .uploadFailed(let e): return "Upload failed: \(e?.localizedDescription ?? "unknown")"
            case .statusFailed(let e): return "Status check failed: \(e?.localizedDescription ?? "unknown")"
            case .downloadFailed(let e): return "Download failed: \(e?.localizedDescription ?? "unknown")"
            case .jobFailed(let msg): return msg ?? "Training failed on the server."
            case .invalidResponse: return "Invalid response from server."
            }
        }
    }

    /// Upload zip of images and start training. Returns job ID.
    static func uploadAndSubmit(zipURL: URL, serverBaseURL: URL) async throws -> String {
        let url = jobsURL(serverBaseURL: serverBaseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let zipData = try Data(contentsOf: zipURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(zipURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(zipData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = requestTimeout

        let (data, response) = try await longTimeoutSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Error.invalidResponse }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw Error.uploadFailed(underlying: nil)
        }
        struct JobResponse: Decodable { let jobId: String }
        let decoded = try JSONDecoder().decode(JobResponse.self, from: data)
        return decoded.jobId
    }

    /// Poll job status. Returns (status, progress 0–100, optional message).
    static func pollStatus(jobId: String, serverBaseURL: URL) async throws -> (CloudJobStatus, Int?, String?) {
        let url = jobStatusURL(serverBaseURL: serverBaseURL, jobId: jobId)
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        let (data, response) = try await longTimeoutSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw Error.statusFailed(underlying: nil)
        }
        let statusResp = try JSONDecoder().decode(StatusResponse.self, from: data)
        return (statusResp.status, statusResp.progress, statusResp.message)
    }

    /// Download the .ply result. Call only when status == .completed.
    static func downloadResult(jobId: String, serverBaseURL: URL) async throws -> Data {
        let url = jobResultURL(serverBaseURL: serverBaseURL, jobId: jobId)
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        let (data, response) = try await longTimeoutSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw Error.downloadFailed(underlying: nil)
        }
        return data
    }

    private static let pingSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 4
        cfg.timeoutIntervalForResource = 4
        return URLSession(configuration: cfg)
    }()

    /// Returns `true` if the backend responds (GET `/jobs` on Flask returns 405).
    static func ping(serverBaseURL: URL) async -> Bool {
        var request = URLRequest(url: jobsURL(serverBaseURL: serverBaseURL))
        request.httpMethod = "GET"
        do {
            let (_, response) = try await pingSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 405 || http.statusCode == 200
        } catch {
            return false
        }
    }

    /// Full flow: upload zip, poll until completed/failed, return .ply data.
    static func trainAndDownload(zipURL: URL, serverBaseURL: URL, pollInterval: TimeInterval = 3.0, onProgress: ((Int?, String?) -> Void)? = nil) async throws -> Data {
        let jobId = try await uploadAndSubmit(zipURL: zipURL, serverBaseURL: serverBaseURL)
        while true {
            let (status, progress, message) = try await pollStatus(jobId: jobId, serverBaseURL: serverBaseURL)
            await MainActor.run { onProgress?(progress, message) }
            switch status {
            case .completed:
                return try await downloadResult(jobId: jobId, serverBaseURL: serverBaseURL)
            case .failed:
                throw Error.jobFailed(message: message)
            case .pending, .processing:
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }
}
