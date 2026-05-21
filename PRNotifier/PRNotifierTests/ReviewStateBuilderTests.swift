import XCTest
@testable import PRNotifier

final class ReviewStateBuilderTests: XCTestCase {

    // MARK: - Basic behavior

    func testLatestReviewWinsForSameReviewer() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "alice", name: "Alice", state: "APPROVED"),
            ReviewInput(login: "alice", name: "Alice", state: "CHANGES_REQUESTED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].reviewerLogin, "alice")
        XCTAssertEqual(result[0].state, .changesRequested)
    }

    func testCommentDoesNotDowngradeApproval() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "bob", name: "Bob", state: "APPROVED"),
            ReviewInput(login: "bob", name: "Bob", state: "COMMENTED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .approved)
    }

    func testCommentDoesNotDowngradeChangesRequested() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "carol", name: "Carol", state: "CHANGES_REQUESTED"),
            ReviewInput(login: "carol", name: "Carol", state: "COMMENTED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .changesRequested)
    }

    func testRequestedReviewerOverridesPriorState() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "dave", name: "Dave", state: "APPROVED"),
        ]
        let requested = [ReviewerInput(login: "dave", name: "Dave")]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: requested)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].state, .pending)
    }

    func testMultipleReviewersIndependent() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "alice", name: "Alice", state: "APPROVED"),
            ReviewInput(login: "bob", name: "Bob", state: "CHANGES_REQUESTED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        let byLogin = Dictionary(uniqueKeysWithValues: result.map { ($0.reviewerLogin, $0) })
        XCTAssertEqual(byLogin["alice"]?.state, .approved)
        XCTAssertEqual(byLogin["bob"]?.state, .changesRequested)
    }

    func testUnknownStateMapsToPending() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "eve", name: "Eve", state: "DISMISSED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result[0].state, .pending)
    }

    func testReviewWithNilUserIsSkipped() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: nil, name: nil, state: "APPROVED"),
            ReviewInput(login: "frank", name: "Frank", state: "APPROVED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].reviewerLogin, "frank")
    }

    func testRequestedReviewerWithNoReviewHistory() {
        let requested = [ReviewerInput(login: "grace", name: "Grace")]

        let result = ReviewStateBuilder.build(reviews: [], requestedReviewers: requested)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].reviewerLogin, "grace")
        XCTAssertEqual(result[0].state, .pending)
    }

    func testPreservesReviewerName() {
        let reviews: [ReviewInput] = [
            ReviewInput(login: "heidi", name: "Heidi Hacker", state: "APPROVED"),
        ]

        let result = ReviewStateBuilder.build(reviews: reviews, requestedReviewers: [])

        XCTAssertEqual(result[0].reviewerName, "Heidi Hacker")
    }
}
