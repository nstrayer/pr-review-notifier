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
    private let dismissals = DismissalManager()
    private let persistence = PersistenceManager.shared

    func check(config: CheckConfig) async -> CheckOutcome {
        let cache = await persistence.getCache()
        let dismissedIDs = await dismissals.dismissedIDs()

        do {
            let result = try await github.checkForPRs(
                token: config.token,
                repos: config.repos,
                username: config.username
            )

            let cleanedDismissedIDs = dismissals.cleanStale(
                validIDs: result.validPRIDs, current: dismissedIDs
            )
            let filtered = dismissals.filterActive(
                from: result.pendingPRs, dismissed: cleanedDismissedIDs
            )

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

            // Single persistence write -- only update PR data on success
            if allReposFailed {
                await persistence.update { cache in
                    cache.lastCheckHadErrors = true
                    cache.lastCheckErrors = result.errors
                }
            } else {
                let authoredPRIDs = Set(result.authoredPRs.map(\.id))
                await persistence.update { cache in
                    cache.dismissedPRIDs = cleanedDismissedIDs
                    cache.pendingPRs = filtered.active
                    cache.authoredPRs = result.authoredPRs
                    cache.lastQueryTime = checkTime
                    cache.lastCheckHadErrors = result.hasErrors
                    cache.lastCheckErrors = result.errors
                    cache.notifiedPRIDs = notifiedIDs.union(Set(newPRs.map(\.id)))
                        .intersection(result.validPRIDs)
                    cache.readyMergeNotifiedPRIDs = readyMergeNotifiedIDs
                        .union(Set(newlyReady.map(\.id)))
                        .intersection(authoredPRIDs)
                }
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
            await persistence.update { cache in
                cache.lastCheckHadErrors = true
                cache.lastCheckErrors = [checkError]
            }
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
