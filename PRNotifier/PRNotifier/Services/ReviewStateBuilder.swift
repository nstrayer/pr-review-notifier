import Foundation

struct ReviewInput {
    let login: String?
    let name: String?
    let state: String
}

struct ReviewerInput {
    let login: String
    let name: String?
}

enum ReviewStateBuilder {

    static func build(reviews: [ReviewInput], requestedReviewers: [ReviewerInput]) -> [ReviewInfo] {
        var reviewerMap: [String: ReviewInfo] = [:]

        for review in reviews {
            guard let login = review.login else { continue }

            let state: ReviewState
            switch review.state {
            case "APPROVED": state = .approved
            case "CHANGES_REQUESTED": state = .changesRequested
            case "COMMENTED": state = .commented
            default: state = .pending
            }

            if state == .commented,
               let existing = reviewerMap[login],
               existing.state == .approved || existing.state == .changesRequested {
                continue
            }

            reviewerMap[login] = ReviewInfo(
                reviewerLogin: login,
                reviewerName: review.name,
                state: state
            )
        }

        for reviewer in requestedReviewers {
            reviewerMap[reviewer.login] = ReviewInfo(
                reviewerLogin: reviewer.login,
                reviewerName: reviewer.name,
                state: .pending
            )
        }

        return Array(reviewerMap.values)
    }
}
