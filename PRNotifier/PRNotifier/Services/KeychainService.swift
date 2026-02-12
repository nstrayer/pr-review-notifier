import Foundation
import KeychainAccess

@MainActor
enum KeychainService {
    private static let keychain = Keychain(service: "PR Notifier")
    private static let legacyKeychain = Keychain(service: "com.nickstrayer.prnotifier")
    private static let tokenKey = "github-token"
    private static let oauthTokenKey = "github-oauth-token"

    // In-memory cache so each key is only read from the keychain once per
    // app session, avoiding repeated macOS keychain permission prompts.
    private static var cache: [String: String?] = [:]
    private static var cacheLoaded = false

    private static func loadCacheIfNeeded() {
        guard !cacheLoaded else { return }
        cacheLoaded = true

        for key in [tokenKey, oauthTokenKey] {
            if let value = try? keychain.get(key) {
                cache[key] = value
            } else if let value = try? legacyKeychain.get(key) {
                // Migrate from legacy service name to the new human-readable one.
                // Only remove the legacy entry if the write to the new keychain succeeds.
                cache[key] = value
                do {
                    try keychain.set(value, key: key)
                    try? legacyKeychain.remove(key)
                } catch {
                    // Write failed; keep legacy entry intact
                }
            } else {
                cache[key] = nil
            }
        }
    }

    // MARK: - PAT (existing)

    static func getToken() -> String? {
        loadCacheIfNeeded()
        return cache[tokenKey, default: nil]
    }

    static func setToken(_ token: String) throws {
        try keychain.set(token, key: tokenKey)
        cache[tokenKey] = token
    }

    static func deleteToken() throws {
        try keychain.remove(tokenKey)
        cache[tokenKey] = nil as String?
    }

    // MARK: - OAuth Token

    static func getOAuthToken() -> String? {
        loadCacheIfNeeded()
        return cache[oauthTokenKey, default: nil]
    }

    static func setOAuthToken(_ token: String) throws {
        try keychain.set(token, key: oauthTokenKey)
        cache[oauthTokenKey] = token
    }

    static func deleteOAuthToken() throws {
        try keychain.remove(oauthTokenKey)
        cache[oauthTokenKey] = nil as String?
    }

    // MARK: - Active Token (based on auth method stored in UserDefaults)

    static func getActiveToken() -> String? {
        let method = UserDefaults.standard.string(forKey: "authMethod") ?? ""
        switch method {
        case "oauth":
            return getOAuthToken()
        case "pat":
            return getToken()
        default:
            // Fallback: try OAuth first, then PAT
            return getOAuthToken() ?? getToken()
        }
    }
}
