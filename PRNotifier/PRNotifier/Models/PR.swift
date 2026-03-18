import Foundation

struct PR: Codable, Equatable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let htmlURL: String
    let repo: String
    let authorLogin: String?
    var reviews: [ReviewInfo]?
    var isAuthored: Bool?
    var ciInfo: CIInfo?

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlURL = "html_url"
        case repo, authorLogin, reviews, isAuthored, ciInfo
    }

    var isReadyToMerge: Bool {
        guard let ci = ciInfo, ci.overallStatus == .passing else { return false }
        guard let reviews = reviews else { return false }
        return reviews.contains { $0.state == .approved }
    }
}
