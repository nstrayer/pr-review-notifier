import XCTest
@testable import PRNotifier

final class CIStatusAggregatorTests: XCTestCase {

    // MARK: - Deduplication

    func testCheckRunOverridesCommitStatusBySameName() {
        let checkRuns = [CheckRunInfo(name: "CI", status: .passing)]
        let commitStatuses = [CheckRunInfo(name: "CI", status: .failing)]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: commitStatuses)

        let byName = Dictionary(uniqueKeysWithValues: result.checks.map { ($0.name, $0) })
        XCTAssertEqual(byName["CI"]?.status, .passing)
        XCTAssertEqual(result.checks.count, 1)
    }

    func testDeduplicationIsCaseInsensitive() {
        let checkRuns = [CheckRunInfo(name: "Build", status: .passing)]
        let commitStatuses = [CheckRunInfo(name: "build", status: .failing)]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: commitStatuses)

        XCTAssertEqual(result.checks.count, 1)
        XCTAssertEqual(result.checks[0].status, .passing)
    }

    func testNonOverlappingChecksAreMerged() {
        let checkRuns = [CheckRunInfo(name: "lint", status: .passing)]
        let commitStatuses = [CheckRunInfo(name: "deploy", status: .pending)]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: commitStatuses)

        XCTAssertEqual(result.checks.count, 2)
    }

    // MARK: - Overall status

    func testEmptyChecksProduceNoneStatus() {
        let result = CIStatusAggregator.aggregate(checkRuns: [], commitStatuses: [])

        XCTAssertEqual(result.overallStatus, .none)
        XCTAssertTrue(result.checks.isEmpty)
    }

    func testAnyFailingMeansOverallFailing() {
        let checkRuns = [
            CheckRunInfo(name: "test", status: .passing),
            CheckRunInfo(name: "lint", status: .failing),
        ]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: [])

        XCTAssertEqual(result.overallStatus, .failing)
    }

    func testAnyPendingWithNoFailingMeansOverallPending() {
        let checkRuns = [
            CheckRunInfo(name: "test", status: .passing),
            CheckRunInfo(name: "lint", status: .pending),
        ]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: [])

        XCTAssertEqual(result.overallStatus, .pending)
    }

    func testAllPassingMeansOverallPassing() {
        let checkRuns = [
            CheckRunInfo(name: "test", status: .passing),
            CheckRunInfo(name: "lint", status: .passing),
        ]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: [])

        XCTAssertEqual(result.overallStatus, .passing)
    }

    func testFailingTakesPriorityOverPending() {
        let checkRuns = [
            CheckRunInfo(name: "test", status: .failing),
            CheckRunInfo(name: "lint", status: .pending),
        ]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: [])

        XCTAssertEqual(result.overallStatus, .failing)
    }

    // MARK: - Preserves original names

    func testPreservesCheckRunNameCasing() {
        let checkRuns = [CheckRunInfo(name: "MyBuild", status: .passing)]

        let result = CIStatusAggregator.aggregate(checkRuns: checkRuns, commitStatuses: [])

        XCTAssertEqual(result.checks[0].name, "MyBuild")
    }
}
