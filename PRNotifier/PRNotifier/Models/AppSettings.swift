import Foundation

enum AuthMethod: String {
    case oauth
    case pat
}

@Observable
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
    }

    var repos: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(repos) {
                defaults.set(data, forKey: Keys.repos)
            }
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

    init() {
        // Load stored values (must set all stored properties before didSet can fire)
        if let data = defaults.data(forKey: Keys.repos),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.repos = decoded
        } else {
            self.repos = []
        }
        self.username = defaults.string(forKey: Keys.username) ?? ""
        let interval = defaults.integer(forKey: Keys.checkInterval)
        self.checkInterval = interval > 0 ? interval : 15
        self.enableNotifications = defaults.object(forKey: Keys.enableNotifications) == nil ? true : defaults.bool(forKey: Keys.enableNotifications)
        self.autoLaunch = defaults.object(forKey: Keys.autoLaunch) == nil ? true : defaults.bool(forKey: Keys.autoLaunch)
        self.settingsPrompted = defaults.bool(forKey: Keys.settingsPrompted)
        self.devShowSamplePRs = defaults.bool(forKey: Keys.devShowSamplePRs)
        self.oauthUsername = defaults.string(forKey: Keys.oauthUsername) ?? ""

        // Determine auth method: check stored preference, then infer from existing tokens.
        // Only probe the keychain for legacy migration (user has config but no stored
        // authMethod). New users get the default without any keychain access, avoiding
        // macOS keychain permission prompts on first launch.
        if let stored = defaults.string(forKey: Keys.authMethod),
           let method = AuthMethod(rawValue: stored) {
            self.authMethod = method
        } else if defaults.string(forKey: Keys.username) != nil
                    || defaults.data(forKey: Keys.repos) != nil
                    || defaults.string(forKey: Keys.oauthUsername) != nil {
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
    }
}
