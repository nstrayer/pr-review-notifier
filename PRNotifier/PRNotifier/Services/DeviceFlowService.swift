import Foundation

// MARK: - Response Models

struct DeviceCodeResponse {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int
}

// MARK: - Errors

enum DeviceFlowError: LocalizedError {
    case networkError(String)
    case invalidResponse
    case expired
    case accessDenied
    case cancelled

    var errorDescription: String? {
        switch self {
        case .networkError(let message): return message
        case .invalidResponse: return "Invalid response from GitHub."
        case .expired: return "Authorization request expired. Please try again."
        case .accessDenied: return "Authorization was denied."
        case .cancelled: return "Authorization was cancelled."
        }
    }
}

// MARK: - Service

enum DeviceFlowService {

    private static let session = URLSession.shared

    /// Request a device code from GitHub to begin the device flow.
    static func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: URL(string: OAuthConfig.deviceCodeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(OAuthConfig.clientID)&scope=\(OAuthConfig.scope)"
        request.httpBody = body.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeviceFlowError.networkError("Failed to connect to GitHub: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DeviceFlowError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String,
              let expiresIn = json["expires_in"] as? Int,
              let interval = json["interval"] as? Int else {
            throw DeviceFlowError.invalidResponse
        }

        return DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURI: verificationURI,
            expiresIn: expiresIn,
            interval: interval
        )
    }

    /// Poll GitHub for the access token after the user has entered the device code.
    static func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        var currentInterval = interval

        while true {
            try? await Task.sleep(for: .seconds(currentInterval))

            if Task.isCancelled { throw DeviceFlowError.cancelled }

            var request = URLRequest(url: URL(string: OAuthConfig.accessTokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(OAuthConfig.clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = body.data(using: .utf8)

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw DeviceFlowError.networkError("Failed to connect to GitHub: \(error.localizedDescription)")
            }

            guard let http = response as? HTTPURLResponse else {
                throw DeviceFlowError.invalidResponse
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DeviceFlowError.invalidResponse
            }

            // Check for access token (success)
            if let accessToken = json["access_token"] as? String {
                return accessToken
            }

            // Check for error states
            guard let error = json["error"] as? String else {
                throw DeviceFlowError.invalidResponse
            }

            switch error {
            case "authorization_pending":
                // User hasn't entered the code yet -- keep polling
                continue
            case "slow_down":
                // GitHub wants us to increase the interval
                currentInterval += 5
                continue
            case "expired_token":
                throw DeviceFlowError.expired
            case "access_denied":
                throw DeviceFlowError.accessDenied
            default:
                // 200 with unrecognized error -- treat as transient for now
                if http.statusCode >= 400 {
                    throw DeviceFlowError.invalidResponse
                }
                continue
            }
        }
    }

    /// Fetch the authenticated user's login name using the provided token.
    static func fetchUsername(token: String) async throws -> String {
        var request = URLRequest(url: URL(string: OAuthConfig.userURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("PRNotifier/2.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw DeviceFlowError.networkError("Failed to fetch user info: \(error.localizedDescription)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let login = json["login"] as? String else {
            throw DeviceFlowError.invalidResponse
        }

        return login
    }
}
