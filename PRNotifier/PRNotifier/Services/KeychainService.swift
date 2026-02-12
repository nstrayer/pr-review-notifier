import Foundation
import KeychainAccess

enum KeychainService {
    private static let keychain = Keychain(service: "com.nickstrayer.prnotifier")
    private static let tokenKey = "github-token"
    private static let oauthTokenKey = "github-oauth-token"

    // MARK: - PAT (existing)

    static func getToken() -> String? {
        try? keychain.get(tokenKey)
    }

    static func setToken(_ token: String) throws {
        try keychain.set(token, key: tokenKey)
    }

    static func deleteToken() throws {
        try keychain.remove(tokenKey)
    }

    // MARK: - OAuth Token

    static func getOAuthToken() -> String? {
        try? keychain.get(oauthTokenKey)
    }

    static func setOAuthToken(_ token: String) throws {
        try keychain.set(token, key: oauthTokenKey)
    }

    static func deleteOAuthToken() throws {
        try keychain.remove(oauthTokenKey)
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
