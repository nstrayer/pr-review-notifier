import Foundation

enum InputValidation {

    // MARK: - GitHub Token

    static func validateGitHubToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed == token else { return false }
        guard token.count >= 40, token.count <= 300 else { return false }

        // Only alphanumeric + underscore allowed
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard token.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

        // Classic tokens: ghp_, gho_, ghs_ followed by 36-255 alphanumeric chars
        // Fine-grained tokens: github_pat_ followed by alphanumeric/underscore chars
        let pattern = "^(gh[ops]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{20,255})$"
        return token.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Repository

    static func validateRepository(_ repo: String) -> Bool {
        let trimmed = repo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed == repo else { return false }
        guard repo.count >= 3, repo.count <= 140 else { return false }

        // Path traversal
        if repo.contains("../") || repo.contains("./") || repo.contains("//") {
            return false
        }

        // URL schemes
        let schemes = ["http://", "https://", "file://", "ftp://", "data:", "javascript:"]
        let lower = repo.lowercased()
        if schemes.contains(where: { lower.contains($0) }) { return false }

        // Shell metacharacters
        let shellMeta = CharacterSet(charactersIn: ";&|$`<>\n\r\t\\")
        if repo.unicodeScalars.contains(where: { shellMeta.contains($0) }) { return false }

        // Control characters
        if repo.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            return false
        }

        // SQL injection patterns
        if repo.contains("'") || repo.contains("\"") || repo.contains("--")
            || repo.contains("/*") || repo.contains("*/") {
            return false
        }

        // Must have exactly one slash
        let parts = repo.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }

        let owner = String(parts[0])
        let repoName = String(parts[1])

        // Owner: 1-39 chars, alphanumeric + hyphens + underscores, no leading/trailing hyphen
        guard owner.count >= 1, owner.count <= 39 else { return false }
        let ownerPattern = "^[a-zA-Z0-9_-]+$"
        guard owner.range(of: ownerPattern, options: .regularExpression) != nil else { return false }
        if owner.hasPrefix("-") || owner.hasSuffix("-") { return false }

        // Repo: 1-100 chars, alphanumeric + dots + hyphens + underscores
        guard repoName.count >= 1, repoName.count <= 100 else { return false }
        let repoPattern = "^[a-zA-Z0-9._-]+$"
        guard repoName.range(of: repoPattern, options: .regularExpression) != nil else { return false }

        // Reject repos that are just dots
        if repoName.allSatisfy({ $0 == "." }) { return false }

        return true
    }

    // MARK: - Username

    static func validateUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed == username else { return false }
        guard username.count >= 1, username.count <= 39 else { return false }

        // Only alphanumeric + hyphen
        let pattern = "^[a-zA-Z0-9-]+$"
        guard username.range(of: pattern, options: .regularExpression) != nil else { return false }

        // No leading/trailing/consecutive hyphens
        if username.hasPrefix("-") || username.hasSuffix("-") || username.contains("--") {
            return false
        }

        // ASCII only
        guard username.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value <= 0x7E }) else {
            return false
        }

        return true
    }

    // MARK: - Check Interval

    static func validateCheckInterval(_ interval: Int) -> Bool {
        interval >= 1 && interval <= 1440
    }

    // MARK: - GitHub URL

    static func validateGitHubURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        guard url.hasPrefix("https://github.com/") else { return false }

        // Reject dangerous patterns
        let dangerous = ["../", "./", "javascript:", "data:", "file:", "vbscript:", "about:", "\0"]
        for pattern in dangerous {
            if url.contains(pattern) { return false }
        }

        // Check for double-slash after protocol
        let afterProtocol = String(url.dropFirst("https://".count))
        if afterProtocol.contains("//") { return false }

        // Parse and validate
        guard let parsed = URL(string: url),
              let host = parsed.host else { return false }

        guard host == "github.com" || host == "www.github.com" else { return false }
        guard parsed.scheme == "https" else { return false }

        // Path pattern: /owner/repo or /owner/repo/type/number
        let pathPattern = "^/[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+(/[a-z]+/[0-9]+)?$"
        guard parsed.path.range(of: pathPattern, options: .regularExpression) != nil else {
            return false
        }

        return true
    }
}
