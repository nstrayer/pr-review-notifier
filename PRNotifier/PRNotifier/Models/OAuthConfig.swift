import Foundation

enum OAuthConfig {
    static let clientID = "YOUR_CLIENT_ID" // Replace with registered OAuth App client ID
    static let scope = "repo"
    static let deviceCodeURL = "https://github.com/login/device/code"
    static let accessTokenURL = "https://github.com/login/oauth/access_token"
    static let userURL = "https://api.github.com/user"
}
