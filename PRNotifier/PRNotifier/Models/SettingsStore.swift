import Foundation

struct SettingsSnapshot: Codable {
    var repos: [String] = []
    var username: String = ""
    var checkInterval: Int = 15
    var enableNotifications: Bool = true
    var autoLaunch: Bool = true
    var settingsPrompted: Bool = false
    var devShowSamplePRs: Bool = false
    var authMethod: String = AuthMethod.oauth.rawValue
    var oauthUsername: String = ""
    var repoColors: [String: RepoColor] = [:]
}

protocol SettingsStore {
    func load() -> SettingsSnapshot
    func save(_ snapshot: SettingsSnapshot)
}

struct UserDefaultsSettingsStore: SettingsStore {
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

    func load() -> SettingsSnapshot {
        var snapshot = SettingsSnapshot()

        if let data = defaults.data(forKey: Keys.repos),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            snapshot.repos = decoded
        }
        snapshot.username = defaults.string(forKey: Keys.username) ?? ""
        let interval = defaults.integer(forKey: Keys.checkInterval)
        snapshot.checkInterval = interval > 0 ? interval : 15
        snapshot.enableNotifications = defaults.object(forKey: Keys.enableNotifications) == nil
            ? true : defaults.bool(forKey: Keys.enableNotifications)
        snapshot.autoLaunch = defaults.object(forKey: Keys.autoLaunch) == nil
            ? true : defaults.bool(forKey: Keys.autoLaunch)
        snapshot.settingsPrompted = defaults.bool(forKey: Keys.settingsPrompted)
        snapshot.devShowSamplePRs = defaults.bool(forKey: Keys.devShowSamplePRs)
        snapshot.oauthUsername = defaults.string(forKey: Keys.oauthUsername) ?? ""
        snapshot.authMethod = defaults.string(forKey: Keys.authMethod) ?? AuthMethod.oauth.rawValue

        if let data = defaults.data(forKey: Keys.repoColors),
           let decoded = try? JSONDecoder().decode([String: RepoColor].self, from: data) {
            let repoSet = Set(snapshot.repos)
            snapshot.repoColors = decoded.filter { repoSet.contains($0.key) }
        }

        return snapshot
    }

    func save(_ snapshot: SettingsSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot.repos) {
            defaults.set(data, forKey: Keys.repos)
        }
        defaults.set(snapshot.username, forKey: Keys.username)
        defaults.set(snapshot.checkInterval, forKey: Keys.checkInterval)
        defaults.set(snapshot.enableNotifications, forKey: Keys.enableNotifications)
        defaults.set(snapshot.autoLaunch, forKey: Keys.autoLaunch)
        defaults.set(snapshot.settingsPrompted, forKey: Keys.settingsPrompted)
        defaults.set(snapshot.devShowSamplePRs, forKey: Keys.devShowSamplePRs)
        defaults.set(snapshot.authMethod, forKey: Keys.authMethod)
        defaults.set(snapshot.oauthUsername, forKey: Keys.oauthUsername)
        if let data = try? JSONEncoder().encode(snapshot.repoColors) {
            defaults.set(data, forKey: Keys.repoColors)
        }
    }
}

struct InMemorySettingsStore: SettingsStore {
    var snapshot = SettingsSnapshot()

    func load() -> SettingsSnapshot { snapshot }
    func save(_ snapshot: SettingsSnapshot) {}
}
