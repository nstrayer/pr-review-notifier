import Foundation

enum ReviewState: String, Codable, Equatable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case pending = "PENDING"
}

struct ReviewInfo: Codable, Equatable {
    let reviewerLogin: String
    let reviewerName: String?
    let state: ReviewState
}
