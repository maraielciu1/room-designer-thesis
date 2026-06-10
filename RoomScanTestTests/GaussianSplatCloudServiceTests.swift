//
//  GaussianSplatCloudServiceTests.swift
//  RoomScanTestTests
//

import XCTest
@testable import RoomScanTest

final class GaussianSplatCloudServiceTests: XCTestCase {

    private let base = URL(string: "https://gs.example.com/api")!
    private let jobId = "job-abc-123"

    func testJobsURL() {
        XCTAssertEqual(
            GaussianSplatCloudService.jobsURL(serverBaseURL: base).absoluteString,
            "https://gs.example.com/api/jobs"
        )
    }

    func testJobStatusURL() {
        XCTAssertEqual(
            GaussianSplatCloudService.jobStatusURL(serverBaseURL: base, jobId: jobId).absoluteString,
            "https://gs.example.com/api/jobs/job-abc-123/status"
        )
    }

    func testJobResultURL() {
        XCTAssertEqual(
            GaussianSplatCloudService.jobResultURL(serverBaseURL: base, jobId: jobId).absoluteString,
            "https://gs.example.com/api/jobs/job-abc-123/result"
        )
    }

    func testStatusResponseDecoding() throws {
        let json = """
        {"status":"processing","progress":42,"message":"COLMAP"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GaussianSplatCloudService.StatusResponse.self, from: json)
        XCTAssertEqual(decoded.status, .processing)
        XCTAssertEqual(decoded.progress, 42)
        XCTAssertEqual(decoded.message, "COLMAP")
    }
}
