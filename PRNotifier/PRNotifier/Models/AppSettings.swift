import Foundation

enum AuthMethod: String {
    case oauth
    case pat
}

@MainActor @Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let repos = "repos"
        static let username = "username"
        static let checkInterval = "checkInterval"
        static let enableNotifications = "enableNotifications"
        static let autoLaunch = "autoLaunch"
        static let settingsPrompted = "settingsPrompted"
        static let devShowSamplePRs = "devShowSamplePRs"
        static let authMethod = "authMethod"
        static let oauthUsername = "oauthUsername"
        static let repoColors = "repoColors"
    }

    var repos: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(repos) {
                defaults.set(data, forKey: Keys.repos)
            }
            // Remove color entries for repos no longer in the list
            let repoSet = Set(repos)
            repoColors = repoColors.filter { repoSet.contains($0.key) }
        }
    }

    var username: String {
        didSet { defaults.set(username, forKey: Keys.username) }
    }

    var checkInterval: Int {
        didSet { defaults.set(checkInterval, forKey: Keys.checkInterval) }
    }

    var enableNotifications: Bool {
        didSet { defaults.set(enableNotifications, forKey: Keys.enableNotifications) }
    }

    var autoLaunch: Bool {
        didSet { defaults.set(autoLaunch, forKey: Keys.autoLaunch) }
    }

    var settingsPrompted: Bool {
        didSet { defaults.set(settingsPrompted, forKey: Keys.settingsPrompted) }
    }

    var devShowSamplePRs: Bool {
        didSet { defaults.set(devShowSamplePRs, forKey: Keys.devShowSamplePRs) }
    }

    var authMethod: AuthMethod {
        didSet { defaults.set(authMethod.rawValue, forKey: Keys.authMethod) }
    }

    var oauthUsername: String {
        didSet { defaults.set(oauthUsername, forKey: Keys.oauthUsername) }
    }

    var repoColors: [String: RepoColor] {
        didSet {
            if let data = try? JSONEncoder().encode(repoColors) {
                defaults.set(data, forKey: Keys.repoColors)
            }
        }
    }

    /// The effective username -- OAuth auto-populates, PAT requires manual entry.
    var effectiveUsername: String {
        switch authMethod {
        case .oauth: return oauthUsername.isEmpty ? username : oauthUsername
        case .pat: return username
        }
    }

    var isConfigured: Bool {
        // Check cheap conditions first to avoid unnecessary keychain access
        guard !effectiveUsername.isEmpty && !repos.isEmpty else { return false }
        guard let token = KeychainService.getActiveToken(), !token.isEmpty else {
            return false
        }
        return true
    }

    /// Returns the color for a repo without mutating state. Safe to call from view body.
    func colorForRepo(_ repo: String) -> RepoColor {
        if let existing = repoColors[repo] {
            return existing
        }
        // Deterministic fallback: first unused palette color
        let usedColors = Set(repoColors.values)
        return RepoColor.allCases.first { !usedColors.contains($0) }
            ?? RepoColor.allCases[repoColors.count % RepoColor.allCases.count]
    }

    /// Assigns and persists a color for a repo. Call at mutation points (addRepo, init).
    @discardableResult
    func assignColorForRepo(_ repo: String) -> RepoColor {
        if let existing = repoColors[repo] {
            return existing
        }
        let color = colorForRepo(repo)
        repoColors[repo] = color
        return color
    }

    init() {
        // Load stored values (must set all stored properties before didSet can fire)
        let loadedRepos: [String]
        if let data = defaults.data(forKey: Keys.repos),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.repos = decoded
            loadedRepos = decoded
        } else {
            self.repos = []
            loadedRepos = []
        }
        self.username = defaults.string(forKey: Keys.username) ?? ""
        let interval = defaults.integer(forKey: Keys.checkInterval)
        self.checkInterval = interval > 0 ? interval : 15
        self.enableNotifications = defaults.object(forKey: Keys.enableNotifications) == nil ? true : defaults.bool(forKey: Keys.enableNotifications)
        self.autoLaunch = defaults.object(forKey: Keys.autoLaunch) == nil ? true : defaults.bool(forKey: Keys.autoLaunch)
        self.settingsPrompted = defaults.bool(forKey: Keys.settingsPrompted)
        self.devShowSamplePRs = defaults.bool(forKey: Keys.devShowSamplePRs)
        self.oauthUsername = defaults.string(forKey: Keys.oauthUsername) ?? ""
        if let data = defaults.data(forKey: Keys.repoColors),
           let decoded = try? JSONDecoder().decode([String: RepoColor].self, from: data) {
            // Filter stale entries and keep only configured repos
            let repoSet = Set(loadedRepos)
            self.repoColors = decoded.filter { repoSet.contains($0.key) }
        } else {
            self.repoColors = [:]
        }

        // Determine auth method: check stored preference, then infer from existing tokens.
        // Only probe the keychain for legacy migration (user has config but no stored
        // authMethod). New users get the default without any keychain access, avoiding
        // macOS keychain permission prompts on first launch.
        if let stored = defaults.string(forKey: Keys.authMethod),
           let method = AuthMethod(rawValue: stored) {
            self.authMethod = method
        } else if defaults.string(forKey: Keys.username) != nil
                    || defaults.string(forKey: Keys.oauthUsername) != nil {
            // Legacy migration: user has config from before authMethod was persisted.
            // Probe keychain to infer which method they were using.
            // Falls back to .oauth if tokens were deleted -- user must re-authenticate anyway.
            if KeychainService.getOAuthToken() != nil {
                self.authMethod = .oauth
            } else if KeychainService.getToken() != nil {
                self.authMethod = .pat
            } else {
                self.authMethod = .oauth
            }
        } else {
            self.authMethod = .oauth
        }

        // Eagerly assign colors for any repos that don't have one yet
        for repo in loadedRepos {
            assignColorForRepo(repo)
        }
    }
}
