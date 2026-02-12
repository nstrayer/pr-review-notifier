import Foundation

// MARK: - API Response Models (private, snake_case auto-decoded)

private struct GitHubRepository: Decodable {
    let id: Int
    let fullName: String
}

private struct GitHubUser: Decodable {
    let login: String
    let name: String?
}

private struct GitHubPullRequest: Decodable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let user: GitHubUser?
}

private struct ReviewersResponse: Decodable {
    let users: [GitHubUser]
}

private struct GitHubReview: Decodable {
    let user: GitHubUser?
    let state: String
}

// MARK: - Result

struct PRCheckResult {
    var activePRs: [PR]
    var dismissedPRs: [PR]
    var authoredPRs: [PR]
    var validPRIDs: Set<Int>
    var errors: [CheckError]
    var hasErrors: Bool
}

// MARK: - Service

struct GitHubService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Main entry point

    func checkForPRs(
        token: String,
        repos: [String],
        username: String,
        dismissedIDs: Set<Int>
    ) async throws -> PRCheckResult {
        var pendingPRs: [PR] = []
        var authoredPRs: [PR] = []
        var errors: [CheckError] = []
        var validPRIDs: Set<Int> = []
        var validPRsByID: [Int: PR] = [:]

        for repoFullName in repos {
            let parts = repoFullName.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repo = String(parts[1])

            // Validate repo access
            do {
                try await validateRepoAccess(token: token, owner: owner, repo: repo)
            } catch let error as APIError {
                errors.append(parseAPIError(error, context: repoFullName))
                continue
            }

            // List open PRs
            let openPRs: [GitHubPullRequest]
            do {
                openPRs = try await listOpenPRs(token: token, owner: owner, repo: repo)
            } catch let error as APIError {
                errors.append(parseAPIError(error, context: repoFullName))
                continue
            }

            for ghPR in openPRs {
                // Check if user is requested reviewer
                let reviewers: ReviewersResponse
                do {
                    reviewers = try await listRequestedReviewers(
                        token: token, owner: owner, repo: repo, pullNumber: ghPR.number
                    )
                } catch {
                    continue
                }

                let isRequested = reviewers.users.contains { $0.login == username }
                let isAuthor = ghPR.user?.login == username

                if isRequested {
                    validPRIDs.insert(ghPR.id)

                    let pr = PR(
                        id: ghPR.id,
                        number: ghPR.number,
                        title: ghPR.title,
                        htmlURL: ghPR.htmlUrl,
                        repo: repoFullName,
                        authorLogin: ghPR.user?.login
                    )
                    validPRsByID[ghPR.id] = pr

                    pendingPRs.append(pr)
                }

                if isAuthor {
                    let reviews: [GitHubReview]
                    do {
                        reviews = try await listReviews(
                            token: token, owner: owner, repo: repo, pullNumber: ghPR.number
                        )
                    } catch {
                        reviews = []
                    }

                    let reviewInfos = buildReviewInfos(
                        reviews: reviews,
                        requestedReviewers: reviewers.users
                    )

                    let authoredPR = PR(
                        id: ghPR.id,
                        number: ghPR.number,
                        title: ghPR.title,
                        htmlURL: ghPR.htmlUrl,
                        repo: repoFullName,
                        authorLogin: ghPR.user?.login,
                        reviews: reviewInfos,
                        isAuthored: true
                    )
                    authoredPRs.append(authoredPR)
                }
            }
        }

        // Clean dismissed IDs to only those still valid
        let activeDismissedIDs = dismissedIDs.intersection(validPRIDs)

        // Build active and dismissed lists
        let activePRs = pendingPRs.filter { !activeDismissedIDs.contains($0.id) }
        let dismissedPRs = activeDismissedIDs.compactMap { validPRsByID[$0] }

        return PRCheckResult(
            activePRs: activePRs,
            dismissedPRs: dismissedPRs,
            authoredPRs: authoredPRs,
            validPRIDs: validPRIDs,
            errors: errors,
            hasErrors: !errors.isEmpty
        )
    }

    // MARK: - API Calls

    private func validateRepoAccess(token: String, owner: String, repo: String) async throws {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        let _ = try await request(url: url, token: token)
    }

    private func listOpenPRs(
        token: String, owner: String, repo: String
    ) async throws -> [GitHubPullRequest] {
        var allPRs: [GitHubPullRequest] = []
        var page = 1
        let maxPages = 50

        while page <= maxPages {
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pulls?state=open&per_page=100&page=\(page)")!
            let data = try await request(url: url, token: token)
            let prs = try Self.snakeCaseDecoder.decode([GitHubPullRequest].self, from: data)
            allPRs.append(contentsOf: prs)

            if prs.count < 100 { break }
            page += 1
        }

        return allPRs
    }

    private func listRequestedReviewers(
        token: String, owner: String, repo: String, pullNumber: Int
    ) async throws -> ReviewersResponse {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(pullNumber)/requested_reviewers")!
        let data = try await request(url: url, token: token)
        return try Self.snakeCaseDecoder.decode(ReviewersResponse.self, from: data)
    }

    private func listReviews(
        token: String, owner: String, repo: String, pullNumber: Int
    ) async throws -> [GitHubReview] {
        var allReviews: [GitHubReview] = []
        var page = 1
        let maxPages = 20

        while page <= maxPages {
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews?per_page=100&page=\(page)")!
            let data = try await request(url: url, token: token)
            let reviews = try Self.snakeCaseDecoder.decode([GitHubReview].self, from: data)
            allReviews.append(contentsOf: reviews)

            if reviews.count < 100 { break }
            page += 1
        }

        return allReviews
    }

    // MARK: - HTTP

    private func request(url: URL, token: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("PRNotifier/2.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError(statusCode: nil, rateLimitRemaining: nil, message: error.localizedDescription, isNetworkError: true)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(statusCode: nil, rateLimitRemaining: nil, message: "Invalid response", isNetworkError: false)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = body?["message"] as? String ?? ""
            let rateLimitRemaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining")
            throw APIError(
                statusCode: http.statusCode,
                rateLimitRemaining: rateLimitRemaining,
                message: msg,
                isNetworkError: false
            )
        }

        return data
    }

    private nonisolated(unsafe) static let snakeCaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Error types

    private struct APIError: Error {
        let statusCode: Int?
        let rateLimitRemaining: String?
        let message: String
        let isNetworkError: Bool
    }

    // MARK: - Error parsing (matches parseGitHubError in github.ts)

    private func parseAPIError(_ error: APIError, context: String) -> CheckError {
        if error.isNetworkError {
            return CheckError(
                type: .network,
                message: "Unable to connect to GitHub",
                repoName: context,
                details: "Check your internet connection and try again."
            )
        }

        guard let status = error.statusCode else {
            return CheckError(
                type: .unknown,
                message: error.message.isEmpty ? "GitHub API error for \(context)" : error.message,
                repoName: context,
                details: "An unexpected error occurred."
            )
        }

        switch status {
        case 401:
            let lower = error.message.lowercased()
            if lower.contains("bad credentials") {
                return CheckError(
                    type: .auth,
                    message: "Invalid GitHub token",
                    repoName: context,
                    details: "The token appears to be malformed or incorrect. Generate a new personal access token."
                )
            } else if lower.contains("token expired") {
                return CheckError(
                    type: .auth,
                    message: "GitHub token has expired",
                    repoName: context,
                    details: "Please generate a new personal access token with the same permissions."
                )
            }
            return CheckError(
                type: .auth,
                message: "GitHub authentication failed",
                repoName: context,
                details: "Your authentication may be expired, invalid, or revoked. Try signing in again or updating your token in settings."
            )

        case 403:
            if error.rateLimitRemaining == "0" {
                return CheckError(
                    type: .rateLimit,
                    message: "GitHub API rate limit exceeded",
                    repoName: context,
                    details: "You've made too many requests. Consider increasing your check interval."
                )
            }
            let lower = error.message.lowercased()
            if lower.contains("saml") || lower.contains("sso") {
                // Extract org name from context (owner/repo -> owner)
                let org = context.split(separator: "/").first.map(String.init) ?? context
                return CheckError(
                    type: .auth,
                    message: "SSO authorization required for \(org)",
                    repoName: context,
                    details: "This organization requires SSO. Open github.com/orgs/\(org)/sso in your browser to authorize, then try again."
                )
            }
            return CheckError(
                type: .auth,
                message: "Access forbidden",
                repoName: context,
                details: error.message.isEmpty ? "Your token may not have the required permissions." : error.message
            )

        case 404:
            return CheckError(
                type: .repoAccess,
                message: "Repository \(context) not found",
                repoName: context,
                details: "The repository may be private, deleted, or the name is incorrect."
            )

        default:
            return CheckError(
                type: .unknown,
                message: error.message.isEmpty ? "GitHub API error for \(context)" : error.message,
                repoName: context,
                details: "An unexpected error occurred."
            )
        }
    }

    // MARK: - Review processing (matches github.ts:440-464)

    private func buildReviewInfos(
        reviews: [GitHubReview],
        requestedReviewers: [GitHubUser]
    ) -> [ReviewInfo] {
        var reviewerMap: [String: ReviewInfo] = [:]

        // Process reviews -- latest review wins (API returns chronological order)
        for review in reviews {
            guard let user = review.user else { continue }
            // Skip COMMENTED state per Electron logic
            guard review.state != "COMMENTED" else { continue }

            let state: ReviewState
            switch review.state {
            case "APPROVED": state = .approved
            case "CHANGES_REQUESTED": state = .changesRequested
            default: state = .pending
            }

            reviewerMap[user.login] = ReviewInfo(
                reviewerLogin: user.login,
                reviewerName: user.name,
                state: state
            )
        }

        // Requested reviewers override any prior review state -- being in this
        // list means the review was dismissed or re-requested, so treat as pending.
        for user in requestedReviewers {
            reviewerMap[user.login] = ReviewInfo(
                reviewerLogin: user.login,
                reviewerName: user.name,
                state: .pending
            )
        }

        return Array(reviewerMap.values)
    }
}
