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

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlURL = "html_url"
        case repo, authorLogin, reviews, isAuthored
    }
}
