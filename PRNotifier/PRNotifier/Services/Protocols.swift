import Foundation

protocol PRChecking: Sendable {
    func check(config: CheckConfig) async -> CheckOutcome
}

protocol Persisting: Sendable {
    func getPendingPRs() async -> [PR]
    func getAuthoredPRs() async -> [PR]
    func getNotifiedPRIDs() async -> Set<Int>
    func getDismissedPRIDs() async -> Set<Int>
    func getLastQueryTime() async -> Date?
    func getLastCheckHadErrors() async -> Bool
    func getLastCheckErrors() async -> [CheckError]
    func getCache() async -> PersistenceManager.CacheData
    func getReadyMergeNotifiedPRIDs() async -> Set<Int>

    func dismissPR(_ id: Int, updatedPendingPRs: [PR]) async
    func restorePR(_ id: Int, updatedPendingPRs: [PR]) async
    func saveCheckResult(
        dismissedPRIDs: Set<Int>,
        pendingPRs: [PR],
        authoredPRs: [PR],
        checkTime: Date,
        hasErrors: Bool,
        errors: [CheckError],
        notifiedPRIDs: Set<Int>,
        readyMergeNotifiedPRIDs: Set<Int>
    ) async
    func recordCheckErrors(_ errors: [CheckError]) async
    func saveSampleState(
        dismissedPRIDs: Set<Int>?,
        pendingPRs: [PR],
        authoredPRs: [PR],
        checkTime: Date?
    ) async
}

protocol GitHubFetching: Sendable {
    func checkForPRs(
        token: String,
        repos: [String],
        username: String
    ) async throws -> PRCheckResult
}

protocol NotificationSending: Sendable {
    func sendNewPRNotification(pr: PR) async
    func sendSummaryNotification(count: Int) async
    func sendReadyToMergeNotification(pr: PR) async
    func requestPermission() async
}
