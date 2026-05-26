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
    private let coordinator = PRCheckCoordinator()
    private let dismissals = DismissalManager()
    private let persistence = PersistenceManager.shared

    // MARK: - Init

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Computed

    var authoredAwaitingReview: [PR] {
        authoredPRs.filter { pr in
            guard let reviews = pr.reviews else { return true }
            return reviews.isEmpty || reviews.allSatisfy { $0.state == .pending }
        }
    }

    var authoredReceivedReview: [PR] {
        authoredPRs.filter { pr in
            guard let reviews = pr.reviews else { return false }
            return reviews.contains { $0.state != .pending }
        }
    }

    var readyToMergePRs: [PR] {
        authoredPRs.filter { $0.isReadyToMerge }
    }

    var menuBarTitle: String {
        if hasErrors { return "!" }
        if !settings.isConfigured && !settings.devShowSamplePRs { return "Setup" }
        let readyCount = readyToMergePRs.count
        if readyCount > 0 {
            return "\(readyCount) ready to merge"
        }
        if !activePRs.isEmpty {
            return "\(activePRs.count) \(activePRs.count == 1 ? "review" : "reviews")"
        }
        let reviewedCount = authoredReceivedReview.count
        if reviewedCount > 0 {
            return "\(reviewedCount) reviewed"
        }
        return "No reviews!"
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
            errors = []
            hasErrors = false
            await persistence.update { cache in
                cache.lastQueryTime = lastCheckTime
                cache.lastCheckHadErrors = false
                cache.lastCheckErrors = []
            }
            return
        }

        guard settings.isConfigured else {
            let configErrors = buildConfigErrors()
            errors = configErrors
            hasErrors = !configErrors.isEmpty
            await persistence.update { cache in
                cache.lastCheckHadErrors = !configErrors.isEmpty
                cache.lastCheckErrors = configErrors
            }
            return
        }

        guard let token = KeychainService.getActiveToken() else { return }

        let outcome = await coordinator.check(config: CheckConfig(
            token: token,
            repos: settings.repos,
            username: settings.effectiveUsername,
            enableNotifications: settings.enableNotifications
        ))

        activePRs = outcome.activePRs
        dismissedPRs = outcome.dismissedPRs
        authoredPRs = outcome.authoredPRs
        errors = outcome.errors
        hasErrors = outcome.hasErrors
        lastCheckTime = outcome.checkTime
    }

    // MARK: - Config Validation

    private func buildConfigErrors() -> [CheckError] {
        var configErrors: [CheckError] = []
        let token = KeychainService.getActiveToken()
        if token == nil || token!.isEmpty {
            configErrors.append(CheckError(
                type: .auth,
                message: "Not authenticated. Sign in with GitHub or add a token in settings."
            ))
        }
        if settings.effectiveUsername.isEmpty {
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
        return configErrors
    }

    // MARK: - Dismiss / Undismiss

    func dismiss(_ prID: Int) {
        guard let index = activePRs.firstIndex(where: { $0.id == prID }) else { return }
        let pr = activePRs.remove(at: index)
        dismissedPRs.append(pr)

        let updatedPRs = activePRs
        Task { await dismissals.dismiss(prID, pendingPRs: updatedPRs) }
    }

    func undismiss(_ prID: Int) {
        guard let index = dismissedPRs.firstIndex(where: { $0.id == prID }) else { return }
        let pr = dismissedPRs.remove(at: index)
        activePRs.append(pr)

        let updatedPRs = activePRs
        Task { await dismissals.restore(prID, pendingPRs: updatedPRs) }
    }

    // MARK: - Sample PRs (matches github.ts sample data)

    private func loadSamplePRs() async {
        let sampleActive: [PR] = [
            PR(id: 9876543210, number: 123, title: "[SAMPLE] Add new dashboard feature",
               htmlURL: "https://github.com/sample/repo/pull/123", repo: "sample/repo",
               authorLogin: "alice-dev"),
            PR(id: 9876543211, number: 456, title: "[SAMPLE] Fix login bug on Safari",
               htmlURL: "https://github.com/sample/repo/pull/456", repo: "another/project",
               authorLogin: "bob-eng"),
            PR(id: 9876543212, number: 789, title: "[SAMPLE] Update README with new installation instructions",
               htmlURL: "https://github.com/sample/repo/pull/789", repo: "docs/documentation",
               authorLogin: "charlie-docs"),
        ]

        let sampleAlwaysDismissed: [PR] = [
            PR(id: 9876543213, number: 101, title: "[SAMPLE-DISMISSED] Improve test coverage",
               htmlURL: "https://github.com/sample/repo/pull/101", repo: "sample/repo",
               authorLogin: "alice-dev"),
            PR(id: 9876543214, number: 202, title: "[SAMPLE-DISMISSED] Update API documentation",
               htmlURL: "https://github.com/sample/repo/pull/202", repo: "docs/api-docs",
               authorLogin: "bob-eng"),
        ]

        let sampleAuthored: [PR] = [
            PR(id: 9876543220, number: 301, title: "[SAMPLE-AUTHORED] Implement user profile page",
               htmlURL: "https://github.com/sample/repo/pull/301", repo: "sample/repo",
               authorLogin: "you", reviews: [
                   ReviewInfo(reviewerLogin: "reviewer1", reviewerName: "Alice Smith", state: .approved),
                   ReviewInfo(reviewerLogin: "reviewer2", reviewerName: "Bob Johnson", state: .pending),
               ], isAuthored: true, ciInfo: CIInfo(checks: [
                   CheckRunInfo(name: "build", status: .passing),
                   CheckRunInfo(name: "test-suite", status: .passing),
                   CheckRunInfo(name: "lint", status: .passing),
               ], overallStatus: .passing)),
            PR(id: 9876543221, number: 302, title: "[SAMPLE-AUTHORED] Fix navigation bug",
               htmlURL: "https://github.com/sample/repo/pull/302", repo: "another/project",
               authorLogin: "you", reviews: [
                   ReviewInfo(reviewerLogin: "reviewer3", reviewerName: "Charlie Davis", state: .changesRequested),
               ], isAuthored: true, ciInfo: CIInfo(checks: [
                   CheckRunInfo(name: "build", status: .passing),
                   CheckRunInfo(name: "test-suite", status: .failing),
                   CheckRunInfo(name: "lint", status: .passing),
               ], overallStatus: .failing)),
            PR(id: 9876543222, number: 303, title: "[SAMPLE-AUTHORED] Add API documentation",
               htmlURL: "https://github.com/sample/repo/pull/303", repo: "docs/documentation",
               authorLogin: "you", reviews: [], isAuthored: true),
        ]

        let allValid = sampleActive + sampleAlwaysDismissed

        let storedDismissedIDs = await dismissals.dismissedIDs()
        let validIDs = Set(allValid.map(\.id))
        let cleanedDismissedIDs = dismissals.cleanStale(
            validIDs: validIDs, current: storedDismissedIDs
        )

        let filtered = dismissals.filterActive(from: sampleActive, dismissed: cleanedDismissedIDs)
        self.activePRs = filtered.active
        self.dismissedPRs = sampleAlwaysDismissed + filtered.dismissed
        self.authoredPRs = sampleAuthored

        await persistence.update { cache in
            if cleanedDismissedIDs != storedDismissedIDs {
                cache.dismissedPRIDs = cleanedDismissedIDs
            }
            cache.pendingPRs = self.activePRs
            cache.authoredPRs = sampleAuthored
        }
    }
}
