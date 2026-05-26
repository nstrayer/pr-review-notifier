import XCTest
@testable import PRNotifier

final class PRCheckCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        github: MockGitHubService = MockGitHubService(),
        persistence: MockPersistence = MockPersistence(),
        notifications: MockNotificationService = MockNotificationService()
    ) -> (PRCheckCoordinator, MockGitHubService, MockPersistence, MockNotificationService) {
        let coordinator = PRCheckCoordinator(
            github: github,
            persistence: persistence,
            notifications: notifications
        )
        return (coordinator, github, persistence, notifications)
    }

    private func makePR(id: Int, title: String = "Test PR") -> PR {
        PR(id: id, number: id, title: title,
           htmlURL: "https://github.com/test/repo/pull/\(id)",
           repo: "test/repo", authorLogin: "alice")
    }

    private var defaultConfig: CheckConfig {
        CheckConfig(token: "fake-token", repos: ["test/repo"],
                    username: "me", enableNotifications: true)
    }

    // MARK: - Success Path

    func testSuccessfulCheckReturnsActivePRs() async {
        let (coordinator, github, _, _) = makeCoordinator()
        let pr = makePR(id: 1)

        github.resultToReturn = PRCheckResult(
            pendingPRs: [pr], authoredPRs: [], validPRIDs: [1],
            errors: [], hasErrors: false, reposSucceeded: 1
        )

        let outcome = await coordinator.check(config: defaultConfig)

        XCTAssertEqual(outcome.activePRs.count, 1)
        XCTAssertEqual(outcome.activePRs.first?.id, 1)
        XCTAssertFalse(outcome.hasErrors)
        XCTAssertFalse(outcome.isTotalFailure)
    }

    func testNewPRsTriggersNotification() async {
        let (coordinator, github, _, notifications) = makeCoordinator()
        let pr = makePR(id: 1)

        github.resultToReturn = PRCheckResult(
            pendingPRs: [pr], authoredPRs: [], validPRIDs: [1],
            errors: [], hasErrors: false, reposSucceeded: 1
        )

        _ = await coordinator.check(config: defaultConfig)

        XCTAssertEqual(notifications.sentPRNotifications.count, 1)
        XCTAssertEqual(notifications.sentPRNotifications.first?.id, 1)
    }

    func testAlreadyNotifiedPRsDoNotRetrigger() async {
        let persistence = MockPersistence()
        await persistence.saveCheckResult(
            dismissedPRIDs: [], pendingPRs: [], authoredPRs: [],
            checkTime: Date(), hasErrors: false, errors: [],
            notifiedPRIDs: [1], readyMergeNotifiedPRIDs: []
        )

        let (coordinator, github, _, notifications) = makeCoordinator(persistence: persistence)
        let pr = makePR(id: 1)

        github.resultToReturn = PRCheckResult(
            pendingPRs: [pr], authoredPRs: [], validPRIDs: [1],
            errors: [], hasErrors: false, reposSucceeded: 1
        )

        _ = await coordinator.check(config: defaultConfig)

        XCTAssertEqual(notifications.sentPRNotifications.count, 0)
    }

    // MARK: - Dismissals

    func testDismissedPRsAreFilteredFromActive() async {
        let persistence = MockPersistence()
        await persistence.dismissPR(2, updatedPendingPRs: [])

        let (coordinator, github, _, _) = makeCoordinator(persistence: persistence)
        let pr1 = makePR(id: 1, title: "Active")
        let pr2 = makePR(id: 2, title: "Dismissed")

        github.resultToReturn = PRCheckResult(
            pendingPRs: [pr1, pr2], authoredPRs: [], validPRIDs: [1, 2],
            errors: [], hasErrors: false, reposSucceeded: 1
        )

        let outcome = await coordinator.check(config: defaultConfig)

        XCTAssertEqual(outcome.activePRs.map(\.id), [1])
        XCTAssertEqual(outcome.dismissedPRs.map(\.id), [2])
    }

    // MARK: - Error Paths

    func testNetworkErrorProducesTotalFailure() async {
        let (coordinator, github, persistence, _) = makeCoordinator()

        github.errorToThrow = URLError(.notConnectedToInternet)

        let outcome = await coordinator.check(config: defaultConfig)

        XCTAssertTrue(outcome.isTotalFailure)
        XCTAssertTrue(outcome.hasErrors)
        XCTAssertEqual(outcome.activePRs.count, 0)

        let hasErrors = await persistence.getLastCheckHadErrors()
        XCTAssertTrue(hasErrors)
    }

    func testAllReposFailedPreservesCachedPRData() async {
        let persistence = MockPersistence()
        let cachedPR = makePR(id: 99, title: "Previously Cached")
        await persistence.saveCheckResult(
            dismissedPRIDs: [], pendingPRs: [cachedPR], authoredPRs: [],
            checkTime: Date(), hasErrors: false, errors: [],
            notifiedPRIDs: [], readyMergeNotifiedPRIDs: []
        )

        let (coordinator, github, _, _) = makeCoordinator(persistence: persistence)

        github.resultToReturn = PRCheckResult(
            pendingPRs: [], authoredPRs: [], validPRIDs: [],
            errors: [CheckError(type: .network, message: "timeout")],
            hasErrors: true, reposSucceeded: 0
        )

        let outcome = await coordinator.check(config: defaultConfig)

        XCTAssertTrue(outcome.isTotalFailure)

        let persistedPRs = await persistence.getPendingPRs()
        XCTAssertEqual(persistedPRs.map(\.id), [99])
    }

    // MARK: - Notifications Disabled

    func testNotificationsDisabledSkipsSending() async {
        let (coordinator, github, _, notifications) = makeCoordinator()
        let pr = makePR(id: 1)

        github.resultToReturn = PRCheckResult(
            pendingPRs: [pr], authoredPRs: [], validPRIDs: [1],
            errors: [], hasErrors: false, reposSucceeded: 1
        )

        let config = CheckConfig(token: "fake", repos: ["test/repo"],
                                 username: "me", enableNotifications: false)
        _ = await coordinator.check(config: config)

        XCTAssertEqual(notifications.sentPRNotifications.count, 0)
    }
}
