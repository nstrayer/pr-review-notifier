import Foundation

enum ErrorType: String, Codable, Equatable {
    case auth
    case network
    case repoAccess = "repo_access"
    case rateLimit = "rate_limit"
    case unknown
}

struct CheckError: Codable, Equatable {
    let type: ErrorType
    let message: String
    var repoName: String?
    var details: String?
}
