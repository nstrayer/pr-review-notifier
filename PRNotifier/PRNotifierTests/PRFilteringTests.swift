import XCTest
@testable import PRNotifier

final class PRFilteringTests: XCTestCase {

    private func makePR(id: Int) -> PR {
        PR(id: id, number: id, title: "PR #\(id)",
           htmlURL: "https://github.com/test/repo/pull/\(id)",
           repo: "test/repo", authorLogin: nil)
    }

    // MARK: - partitionPRs

    func testPartitionSplitsCorrectly() {
        let prs = [makePR(id: 1), makePR(id: 2), makePR(id: 3)]

        let result = partitionPRs(prs, dismissedIDs: [2])

        XCTAssertEqual(result.active.map(\.id), [1, 3])
        XCTAssertEqual(result.dismissed.map(\.id), [2])
    }

    func testPartitionWithEmptyDismissedReturnsAllActive() {
        let prs = [makePR(id: 1), makePR(id: 2)]

        let result = partitionPRs(prs, dismissedIDs: [])

        XCTAssertEqual(result.active.count, 2)
        XCTAssertEqual(result.dismissed.count, 0)
    }

    func testPartitionWithAllDismissedReturnsNoneActive() {
        let prs = [makePR(id: 1), makePR(id: 2)]

        let result = partitionPRs(prs, dismissedIDs: [1, 2])

        XCTAssertEqual(result.active.count, 0)
        XCTAssertEqual(result.dismissed.count, 2)
    }

    // MARK: - cleanStaleDismissedIDs

    func testCleanStaleRemovesInvalidIDs() {
        let result = cleanStaleDismissedIDs(validIDs: [1, 2, 3], current: [2, 3, 99])

        XCTAssertEqual(result, [2, 3])
    }

    func testCleanStaleWithNoOverlapReturnsEmpty() {
        let result = cleanStaleDismissedIDs(validIDs: [1, 2], current: [99, 100])

        XCTAssertEqual(result, [])
    }

    func testCleanStaleWithAllValidReturnsAll() {
        let result = cleanStaleDismissedIDs(validIDs: [1, 2, 3], current: [1, 2])

        XCTAssertEqual(result, [1, 2])
    }
}
