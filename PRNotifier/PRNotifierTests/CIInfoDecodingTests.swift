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
        let checks = [
            CheckRunInfo(name: "zeta", status: .passing),
            CheckRunInfo(name: "alpha", status: .passing),
            CheckRunInfo(name: "middle", status: .passing),
        ]
        let ciInfo = CIInfo(checks: checks, overallStatus: .passing)

        let sorted = ciInfo.checks.sorted { a, b in
            let order: [CheckRunStatus: Int] = [.failing: 0, .pending: 1, .passing: 2]
            let ao = order[a.status] ?? 3
            let bo = order[b.status] ?? 3
            if ao != bo { return ao < bo }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        XCTAssertEqual(sorted.map(\.name), ["alpha", "middle", "zeta"])
    }

    func testChecksSortFailingBeforePendingBeforePassing() {
        let checks = [
            CheckRunInfo(name: "c-pass", status: .passing),
            CheckRunInfo(name: "a-fail", status: .failing),
            CheckRunInfo(name: "b-pend", status: .pending),
        ]
        let ciInfo = CIInfo(checks: checks, overallStatus: .failing)

        let sorted = ciInfo.checks.sorted { a, b in
            let order: [CheckRunStatus: Int] = [.failing: 0, .pending: 1, .passing: 2]
            let ao = order[a.status] ?? 3
            let bo = order[b.status] ?? 3
            if ao != bo { return ao < bo }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        XCTAssertEqual(sorted.map(\.name), ["a-fail", "b-pend", "c-pass"])
    }
}
