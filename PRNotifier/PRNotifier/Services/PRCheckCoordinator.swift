import Foundation

struct CheckConfig {
    let token: String
    let repos: [String]
    let username: String
    let enableNotifications: Bool
}

struct CheckOutcome {
    var activePRs: [PR]
    var dismissedPRs: [PR]
    var authoredPRs: [PR]
    var errors: [CheckError]
    var hasErrors: Bool
    var checkTime: Date
    var isTotalFailure: Bool
}

struct PRCheckCoordinator {
    private let github = GitHubService()
    private let persistence = PersistenceManager.shared

    func check(config: CheckConfig) async -> CheckOutcome {
        let cache = await persistence.getCache()
        let dismissedIDs = cache.dismissedPRIDs

        do {
            let result = try await github.checkForPRs(
                token: config.token,
                repos: config.repos,
                username: config.username
            )

            let cleanedDismissedIDs = cleanStaleDismissedIDs(
                validIDs: result.validPRIDs, current: dismissedIDs
            )
            let filtered = partitionPRs(result.pendingPRs, dismissedIDs: cleanedDismissedIDs)

            let checkTime = Date()
            let readyToMergePRs = result.authoredPRs.filter { $0.isReadyToMerge }

            // Notifications for new PRs
            let notifiedIDs = cache.notifiedPRIDs
            let newPRs = filtered.active.filter { !notifiedIDs.contains($0.id) }

            if config.enableNotifications && !newPRs.isEmpty {
                for pr in newPRs {
                    await NotificationService.shared.sendNewPRNotification(pr: pr)
                }
                if newPRs.count > 1 {
                    await NotificationService.shared.sendSummaryNotification(count: filtered.active.count)
                }
            }

            // Notifications for ready-to-merge
            let readyMergeNotifiedIDs = cache.readyMergeNotifiedPRIDs
            let newlyReady = readyToMergePRs.filter { !readyMergeNotifiedIDs.contains($0.id) }

            if config.enableNotifications && !newlyReady.isEmpty {
                for pr in newlyReady {
                    await NotificationService.shared.sendReadyToMergeNotification(pr: pr)
                }
            }

            let allReposFailed = result.reposSucceeded == 0 && result.hasErrors

            if allReposFailed {
                await persistence.recordCheckErrors(result.errors)
            } else {
                let authoredPRIDs = Set(result.authoredPRs.map(\.id))
                await persistence.saveCheckResult(
                    dismissedPRIDs: cleanedDismissedIDs,
                    pendingPRs: filtered.active,
                    authoredPRs: result.authoredPRs,
                    checkTime: checkTime,
                    hasErrors: result.hasErrors,
                    errors: result.errors,
                    notifiedPRIDs: notifiedIDs.union(Set(newPRs.map(\.id)))
                        .intersection(result.validPRIDs),
                    readyMergeNotifiedPRIDs: readyMergeNotifiedIDs
                        .union(Set(newlyReady.map(\.id)))
                        .intersection(authoredPRIDs)
                )
            }

            return CheckOutcome(
                activePRs: filtered.active,
                dismissedPRs: filtered.dismissed,
                authoredPRs: result.authoredPRs,
                errors: result.errors,
                hasErrors: result.hasErrors,
                checkTime: checkTime,
                isTotalFailure: allReposFailed
            )
        } catch {
            let checkError = CheckError(
                type: .unknown,
                message: error.localizedDescription,
                details: "An unexpected error occurred."
            )
            await persistence.recordCheckErrors([checkError])
            return CheckOutcome(
                activePRs: [],
                dismissedPRs: [],
                authoredPRs: [],
                errors: [checkError],
                hasErrors: true,
                checkTime: Date(),
                isTotalFailure: true
            )
        }
    }
}
