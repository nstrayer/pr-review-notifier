import Foundation

enum AuthMethod: String {
    case oauth
    case pat
}

@MainActor @Observable
final class AppSettings {
    private let store: SettingsStore

    var repos: [String]
    var username: String
    var checkInterval: Int
    var enableNotifications: Bool
    var autoLaunch: Bool
    var settingsPrompted: Bool
    var devShowSamplePRs: Bool
    var authMethod: AuthMethod
    var oauthUsername: String
    var repoColors: [String: RepoColor]

    /// The effective username -- OAuth auto-populates, PAT requires manual entry.
    var effectiveUsername: String {
        switch authMethod {
        case .oauth: return oauthUsername.isEmpty ? username : oauthUsername
        case .pat: return username
        }
    }

    var isConfigured: Bool {
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
        save()
        return color
    }

    /// Remove color entries for repos no longer in the list and persist.
    func cleanRepoColors() {
        let repoSet = Set(repos)
        let cleaned = repoColors.filter { repoSet.contains($0.key) }
        if cleaned.count != repoColors.count {
            repoColors = cleaned
            save()
        }
    }

    /// Persist all current settings to the backing store.
    func save() {
        var snapshot = SettingsSnapshot()
        snapshot.repos = repos
        snapshot.username = username
        snapshot.checkInterval = checkInterval
        snapshot.enableNotifications = enableNotifications
        snapshot.autoLaunch = autoLaunch
        snapshot.settingsPrompted = settingsPrompted
        snapshot.devShowSamplePRs = devShowSamplePRs
        snapshot.authMethod = authMethod.rawValue
        snapshot.oauthUsername = oauthUsername
        snapshot.repoColors = repoColors
        store.save(snapshot)
    }

    /// Determine auth method from stored preference or infer from existing tokens.
    /// Only probes keychain for legacy migration (user has config but no stored authMethod).
    func resolveAuthMethod() {
        let snapshot = store.load()
        if AuthMethod(rawValue: snapshot.authMethod) != nil {
            return
        }
        // Legacy migration: infer from keychain state
        if !snapshot.username.isEmpty || !snapshot.oauthUsername.isEmpty {
            if KeychainService.getOAuthToken() != nil {
                authMethod = .oauth
            } else if KeychainService.getToken() != nil {
                authMethod = .pat
            } else {
                authMethod = .oauth
            }
            save()
        }
    }

    init(store: SettingsStore = UserDefaultsSettingsStore()) {
        self.store = store
        let snapshot = store.load()

        self.repos = snapshot.repos
        self.username = snapshot.username
        self.checkInterval = snapshot.checkInterval
        self.enableNotifications = snapshot.enableNotifications
        self.autoLaunch = snapshot.autoLaunch
        self.settingsPrompted = snapshot.settingsPrompted
        self.devShowSamplePRs = snapshot.devShowSamplePRs
        self.oauthUsername = snapshot.oauthUsername
        self.repoColors = snapshot.repoColors
        self.authMethod = AuthMethod(rawValue: snapshot.authMethod) ?? .oauth

        resolveAuthMethod()

        // Eagerly assign colors for any repos that don't have one yet
        for repo in snapshot.repos {
            assignColorForRepo(repo)
        }
    }
}
