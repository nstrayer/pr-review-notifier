import Foundation

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

    var isConfigured: Bool {
        if let token = KeychainService.getToken(), !token.isEmpty {
            return !username.isEmpty && !repos.isEmpty
        }
        return false
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
    }
}
