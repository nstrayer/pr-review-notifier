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
        get {
            if let data = defaults.data(forKey: Keys.repos),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.repos)
            }
        }
    }

    var username: String {
        get { defaults.string(forKey: Keys.username) ?? "" }
        set { defaults.set(newValue, forKey: Keys.username) }
    }

    var checkInterval: Int {
        get {
            let val = defaults.integer(forKey: Keys.checkInterval)
            return val > 0 ? val : 15
        }
        set { defaults.set(newValue, forKey: Keys.checkInterval) }
    }

    var enableNotifications: Bool {
        get {
            if defaults.object(forKey: Keys.enableNotifications) == nil { return true }
            return defaults.bool(forKey: Keys.enableNotifications)
        }
        set { defaults.set(newValue, forKey: Keys.enableNotifications) }
    }

    var autoLaunch: Bool {
        get {
            if defaults.object(forKey: Keys.autoLaunch) == nil { return true }
            return defaults.bool(forKey: Keys.autoLaunch)
        }
        set { defaults.set(newValue, forKey: Keys.autoLaunch) }
    }

    var settingsPrompted: Bool {
        get { defaults.bool(forKey: Keys.settingsPrompted) }
        set { defaults.set(newValue, forKey: Keys.settingsPrompted) }
    }

    var devShowSamplePRs: Bool {
        get { defaults.bool(forKey: Keys.devShowSamplePRs) }
        set { defaults.set(newValue, forKey: Keys.devShowSamplePRs) }
    }

    var isConfigured: Bool {
        let token = KeychainService.getToken()
        return token != nil && !token!.isEmpty && !username.isEmpty && !repos.isEmpty
    }
}
