import Foundation
import KeychainAccess

enum KeychainService {
    private static let keychain = Keychain(service: "com.nickstrayer.prnotifier")
    private static let tokenKey = "github-token"

    static func getToken() -> String? {
        try? keychain.get(tokenKey)
    }

    static func setToken(_ token: String) throws {
        try keychain.set(token, key: tokenKey)
    }

    static func deleteToken() throws {
        try keychain.remove(tokenKey)
    }
}
