import XCTest
@testable import PRNotifier

final class CIInfoDecodingTests: XCTestCase {

    // MARK: - CheckRunStatus fallback decoding

    func testKnownCheckRunStatusDecodes() throws {
        let json = Data(#"{"name":"build","status":"passing"}"#.utf8)
        let info = try JSONDecoder().decode(CheckRunInfo.self, from: json)
        XCTAssertEqual(info.status, .passing)
    }

    func testUnknownCheckRunStatusFallsToPending() throws {
        let json = Data(#"{"name":"build","status":"queued"}"#.utf8)
        let info = try JSONDecoder().decode(CheckRunInfo.self, from: json)
        XCTAssertEqual(info.status, .pending)
    }

    // MARK: - CIStatus fallback decoding

    func testKnownCIStatusDecodes() throws {
        let json = Data(#""failing""#.utf8)
        let status = try JSONDecoder().decode(CIStatus.self, from: json)
        XCTAssertEqual(status, .failing)
    }

    func testUnknownCIStatusFallsToNone() throws {
        let json = Data(#""unknown_state""#.utf8)
        let status = try JSONDecoder().decode(CIStatus.self, from: json)
        XCTAssertEqual(status, .none)
    }

    // MARK: - CIInfo sort stability

    func testChecksWithSameStatusSortByName() {
        let ciInfo = CIInfo(checks: [
            CheckRunInfo(name: "zeta", status: .passing),
            CheckRunInfo(name: "alpha", status: .passing),
            CheckRunInfo(name: "middle", status: .passing),
        ], overallStatus: .passing)

        XCTAssertEqual(ciInfo.sortedChecks.map(\.name), ["alpha", "middle", "zeta"])
    }

    func testChecksSortFailingBeforePendingBeforePassing() {
        let ciInfo = CIInfo(checks: [
            CheckRunInfo(name: "c-pass", status: .passing),
            CheckRunInfo(name: "a-fail", status: .failing),
            CheckRunInfo(name: "b-pend", status: .pending),
        ], overallStatus: .failing)

        XCTAssertEqual(ciInfo.sortedChecks.map(\.name), ["a-fail", "b-pend", "c-pass"])
    }
}
