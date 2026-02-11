import Foundation

@Observable
@MainActor
final class PRViewModel {
    // MARK: - Public state

    var activePRs: [PR] = []
    var dismissedPRs: [PR] = []
    var authoredPRs: [PR] = []
    var isLoading = false
    var lastCheckTime: Date?
    var errors: [CheckError] = []
    var hasErrors = false

    let settings: AppSettings

    // MARK: - Private

    private var pollingTask: Task<Void, Never>?
    private var isCheckInFlight = false
    private let github = GitHubService()
    private let persistence = PersistenceManager.shared

    // MARK: - Init

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Computed

    var menuBarTitle: String {
        if hasErrors { return "!" }
        if !settings.isConfigured && !settings.devShowSamplePRs { return "Setup" }
        if activePRs.isEmpty { return "No reviews!" }
        return "\(activePRs.count) reviews"
    }

    // MARK: - Lifecycle

    func start() async {
        // Load cached state
        let cache = await persistence.getCache()
        activePRs = cache.pendingPRs
        authoredPRs = cache.authoredPRs
        lastCheckTime = cache.lastQueryTime
        hasErrors = cache.lastCheckHadErrors
        errors = cache.lastCheckErrors

        await NotificationService.shared.requestPermission()
        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        // Strong self capture is intentional: PRViewModel is a singleton owned by the
        // app root (@State in PRNotifierApp) and lives for the entire app lifetime.
        // Call stopPolling() to break the cycle if ownership model ever changes.
        pollingTask = Task {
            // Check immediately
            await checkNow()

            // Then loop on interval
            while !Task.isCancelled {
                let interval = settings.checkInterval
                try? await Task.sleep(for: .seconds(interval * 60))
                if Task.isCancelled { break }
                await checkNow()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func restartPolling() {
        startPolling()
    }

    // MARK: - Check

    func checkNow() async {
        guard !isCheckInFlight else { return }
        isCheckInFlight = true
        isLoading = true

        defer {
            isCheckInFlight = false
            isLoading = false
        }

        // Sample PR mode
        if settings.devShowSamplePRs {
            await loadSamplePRs()
            lastCheckTime = Date()
            await persistence.setLastQueryTime(lastCheckTime)
            errors = []
            hasErrors = false
            await persistence.setLastCheckErrors([])
            return
        }

        guard settings.isConfigured else {
            // Build config errors like the Electron version
            var configErrors: [CheckError] = []
            let token = KeychainService.getToken()
            if token == nil || token!.isEmpty {
                configErrors.append(CheckError(
                    type: .auth,
                    message: "GitHub token not configured. Please add your token in settings."
                ))
            }
            if settings.username.isEmpty {
                configErrors.append(CheckError(
                    type: .auth,
                    message: "GitHub username not configured. Please add your username in settings."
                ))
            }
            if settings.repos.isEmpty {
                configErrors.append(CheckError(
                    type: .auth,
                    message: "No repositories configured. Please add repositories to monitor in settings."
                ))
            }
            errors = configErrors
            hasErrors = !configErrors.isEmpty
            await persistence.setLastCheckErrors(configErrors)
            return
        }

        guard let token = KeychainService.getToken() else { return }
        let dismissedIDs = await persistence.getDismissedPRIDs()

        do {
            let result = try await github.checkForPRs(
                token: token,
                repos: settings.repos,
                username: settings.username,
                dismissedIDs: dismissedIDs
            )

            activePRs = result.activePRs
            dismissedPRs = result.dismissedPRs
            authoredPRs = result.authoredPRs
            errors = result.errors
            hasErrors = result.hasErrors
            lastCheckTime = Date()

            // Clean stale dismissed IDs
            let cleanedDismissedIDs = dismissedIDs.intersection(result.validPRIDs)
            await persistence.setDismissedPRIDs(cleanedDismissedIDs)
            await persistence.setPendingPRs(result.activePRs)
            await persistence.setAuthoredPRs(result.authoredPRs)
            await persistence.setLastQueryTime(lastCheckTime)
            await persistence.setLastCheckErrors(result.errors)

            // Send notifications for new PRs
            let notifiedIDs = await persistence.getNotifiedPRIDs()
            let newPRs = result.activePRs.filter { !notifiedIDs.contains($0.id) }

            if settings.enableNotifications && !newPRs.isEmpty {
                for pr in newPRs {
                    await NotificationService.shared.sendNewPRNotification(pr: pr)
                }
                if newPRs.count > 1 {
                    await NotificationService.shared.sendSummaryNotification(count: result.activePRs.count)
                }
            }

            // Update notified IDs: add new, remove stale
            let updatedNotifiedIDs = notifiedIDs.union(Set(newPRs.map(\.id)))
                .intersection(result.validPRIDs)
            await persistence.setNotifiedPRIDs(updatedNotifiedIDs)
        } catch {
            let checkError = CheckError(
                type: .unknown,
                message: error.localizedDescription,
                details: "An unexpected error occurred."
            )
            errors = [checkError]
            hasErrors = true
            await persistence.setLastCheckErrors([checkError])
        }
    }

    // MARK: - Dismiss / Undismiss

    func dismiss(_ prID: Int) {
        guard let index = activePRs.firstIndex(where: { $0.id == prID }) else { return }
        let pr = activePRs.remove(at: index)
        dismissedPRs.append(pr)

        Task {
            await persistence.addDismissedPRID(prID)
            await persistence.setPendingPRs(activePRs)
        }
    }

    func undismiss(_ prID: Int) {
        guard let index = dismissedPRs.firstIndex(where: { $0.id == prID }) else { return }
        let pr = dismissedPRs.remove(at: index)
        activePRs.append(pr)

        Task {
            await persistence.removeDismissedPRID(prID)
            await persistence.setPendingPRs(activePRs)
        }
    }

    // MARK: - Sample PRs (matches github.ts sample data)

    private func loadSamplePRs() async {
        let sampleActive: [PR] = [
            PR(id: 9876543210, number: 123, title: "[SAMPLE] Add new dashboard feature",
               htmlURL: "https://github.com/sample/repo/pull/123", repo: "sample/repo"),
            PR(id: 9876543211, number: 456, title: "[SAMPLE] Fix login bug on Safari",
               htmlURL: "https://github.com/sample/repo/pull/456", repo: "another/project"),
            PR(id: 9876543212, number: 789, title: "[SAMPLE] Update README with new installation instructions",
               htmlURL: "https://github.com/sample/repo/pull/789", repo: "docs/documentation"),
        ]

        let sampleAlwaysDismissed: [PR] = [
            PR(id: 9876543213, number: 101, title: "[SAMPLE-DISMISSED] Improve test coverage",
               htmlURL: "https://github.com/sample/repo/pull/101", repo: "sample/repo"),
            PR(id: 9876543214, number: 202, title: "[SAMPLE-DISMISSED] Update API documentation",
               htmlURL: "https://github.com/sample/repo/pull/202", repo: "docs/api-docs"),
        ]

        let sampleAuthored: [PR] = [
            PR(id: 9876543220, number: 301, title: "[SAMPLE-AUTHORED] Implement user profile page",
               htmlURL: "https://github.com/sample/repo/pull/301", repo: "sample/repo",
               reviews: [
                   ReviewInfo(reviewerLogin: "reviewer1", reviewerName: "Alice Smith", state: .approved),
                   ReviewInfo(reviewerLogin: "reviewer2", reviewerName: "Bob Johnson", state: .pending),
               ], isAuthored: true),
            PR(id: 9876543221, number: 302, title: "[SAMPLE-AUTHORED] Fix navigation bug",
               htmlURL: "https://github.com/sample/repo/pull/302", repo: "another/project",
               reviews: [
                   ReviewInfo(reviewerLogin: "reviewer3", reviewerName: "Charlie Davis", state: .changesRequested),
               ], isAuthored: true),
            PR(id: 9876543222, number: 303, title: "[SAMPLE-AUTHORED] Add API documentation",
               htmlURL: "https://github.com/sample/repo/pull/303", repo: "docs/documentation",
               reviews: [], isAuthored: true),
        ]

        let allValid = sampleActive + sampleAlwaysDismissed

        let storedDismissedIDs = await persistence.getDismissedPRIDs()
        let validIDs = Set(allValid.map(\.id))
        let cleanedDismissedIDs = storedDismissedIDs.intersection(validIDs)

        if cleanedDismissedIDs != storedDismissedIDs {
            await persistence.setDismissedPRIDs(cleanedDismissedIDs)
        }

        self.activePRs = sampleActive.filter { !cleanedDismissedIDs.contains($0.id) }
        let dismissedFromActive = sampleActive.filter { cleanedDismissedIDs.contains($0.id) }
        self.dismissedPRs = sampleAlwaysDismissed + dismissedFromActive
        self.authoredPRs = sampleAuthored

        await persistence.setPendingPRs(self.activePRs)
        await persistence.setAuthoredPRs(sampleAuthored)
    }
}
