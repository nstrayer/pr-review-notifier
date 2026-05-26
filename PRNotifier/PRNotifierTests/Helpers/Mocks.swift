import Foundation
@testable import PRNotifier

final class MockGitHubService: GitHubFetching, @unchecked Sendable {
    var resultToReturn: PRCheckResult?
    var errorToThrow: Error?

    func checkForPRs(token: String, repos: [String], username: String) async throws -> PRCheckResult {
        if let error = errorToThrow { throw error }
        return resultToReturn ?? PRCheckResult(
            pendingPRs: [], authoredPRs: [], validPRIDs: [],
            errors: [], hasErrors: false, reposSucceeded: 0
        )
    }
}

actor MockPersistence: Persisting {
    var cache = PersistenceManager.CacheData()

    func getPendingPRs() -> [PR] { cache.pendingPRs }
    func getAuthoredPRs() -> [PR] { cache.authoredPRs }
    func getNotifiedPRIDs() -> Set<Int> { cache.notifiedPRIDs }
    func getDismissedPRIDs() -> Set<Int> { cache.dismissedPRIDs }
    func getLastQueryTime() -> Date? { cache.lastQueryTime }
    func getLastCheckHadErrors() -> Bool { cache.lastCheckHadErrors }
    func getLastCheckErrors() -> [CheckError] { cache.lastCheckErrors }
    func getCache() -> PersistenceManager.CacheData { cache }
    func getReadyMergeNotifiedPRIDs() -> Set<Int> { cache.readyMergeNotifiedPRIDs }

    func dismissPR(_ id: Int, updatedPendingPRs: [PR]) {
        cache.dismissedPRIDs.insert(id)
        cache.pendingPRs = updatedPendingPRs
    }

    func restorePR(_ id: Int, updatedPendingPRs: [PR]) {
        cache.dismissedPRIDs.remove(id)
        cache.pendingPRs = updatedPendingPRs
    }

    func saveCheckResult(
        dismissedPRIDs: Set<Int>,
        pendingPRs: [PR],
        authoredPRs: [PR],
        checkTime: Date,
        hasErrors: Bool,
        errors: [CheckError],
        notifiedPRIDs: Set<Int>,
        readyMergeNotifiedPRIDs: Set<Int>
    ) {
        cache.dismissedPRIDs = dismissedPRIDs
        cache.pendingPRs = pendingPRs
        cache.authoredPRs = authoredPRs
        cache.lastQueryTime = checkTime
        cache.lastCheckHadErrors = hasErrors
        cache.lastCheckErrors = errors
        cache.notifiedPRIDs = notifiedPRIDs
        cache.readyMergeNotifiedPRIDs = readyMergeNotifiedPRIDs
    }

    func recordCheckErrors(_ errors: [CheckError]) {
        cache.lastCheckHadErrors = !errors.isEmpty
        cache.lastCheckErrors = errors
    }

    func saveSampleState(
        dismissedPRIDs: Set<Int>?,
        pendingPRs: [PR],
        authoredPRs: [PR],
        checkTime: Date?
    ) {
        if let ids = dismissedPRIDs {
            cache.dismissedPRIDs = ids
        }
        cache.pendingPRs = pendingPRs
        cache.authoredPRs = authoredPRs
        if let time = checkTime {
            cache.lastQueryTime = time
        }
        cache.lastCheckHadErrors = false
        cache.lastCheckErrors = []
    }
}

final class MockNotificationService: NotificationSending, @unchecked Sendable {
    var sentPRNotifications: [PR] = []
    var sentSummaryCount: Int?
    var sentReadyToMerge: [PR] = []
    var permissionRequested = false

    func sendNewPRNotification(pr: PR) async {
        sentPRNotifications.append(pr)
    }

    func sendSummaryNotification(count: Int) async {
        sentSummaryCount = count
    }

    func sendReadyToMergeNotification(pr: PR) async {
        sentReadyToMerge.append(pr)
    }

    func requestPermission() async {
        permissionRequested = true
    }
}
