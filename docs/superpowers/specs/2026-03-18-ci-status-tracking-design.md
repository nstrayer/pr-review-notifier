# CI Status Tracking + Ready to Merge

## Problem

The user often merges PRs before CI finishes because waiting is tedious. The app should alert when an authored PR has both approval and passing CI, signaling it's safe to merge.

## Overview

Add CI status tracking for authored PRs. When an authored PR has at least one approval and all CI checks passing, it becomes "ready to merge" -- triggering a notification and taking over the menu bar display.

## Data Model

### New types in `Models/CIInfo.swift`

```swift
enum CheckRunStatus: String, Codable, Equatable {
    case passing, failing, pending
}

enum CIStatus: String, Codable, Equatable {
    case passing, failing, pending, none
}

struct CheckRunInfo: Codable, Equatable {
    let name: String           // e.g. "test-suite", "build", "lint"
    let status: CheckRunStatus
}

struct CIInfo: Codable, Equatable {
    let checks: [CheckRunInfo]
    let overallStatus: CIStatus
}
```

### PR model changes

Add `var ciInfo: CIInfo?` to the `PR` struct with a default of `nil`. Add corresponding `CodingKey`. Since `ciInfo` is optional with a default, the memberwise initializer remains backwards-compatible -- existing call sites do not need changes.

### Computed property on PR

```swift
var isReadyToMerge: Bool {
    guard let ci = ciInfo, ci.overallStatus == .passing else { return false }
    guard let reviews = reviews else { return false }
    return reviews.contains { $0.state == .approved }
}
```

## GitHub API

### Fetching CI status

For each authored PR, fetch the HEAD commit's check status using two endpoints:

1. **Check Runs** (GitHub Actions, modern CI):
   `GET /repos/{owner}/{repo}/commits/{sha}/check-runs`
   - Returns individual check runs with `name`, `status` ("queued"/"in_progress"/"completed"), and `conclusion` ("success"/"failure"/"neutral"/"cancelled"/"skipped"/"timed_out"/"action_required")
   - Paginated (default 30, max 100). Must paginate to handle repos with many checks (matrix builds, monorepos).

2. **Combined Commit Status** (legacy CI -- CircleCI, Jenkins, etc.):
   `GET /repos/{owner}/{repo}/commits/{sha}/status`
   - Returns individual statuses with `context` (name) and `state` ("error"/"failure"/"pending"/"success")
   - Returns all statuses in a single response (no pagination needed).

### Getting the HEAD SHA

The existing `GitHubPullRequest` Decodable struct needs a `head` field added:

```swift
private struct GitHubPullRequest: Decodable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let user: GitHubUser?
    let head: GitHubHead  // NEW
}

private struct GitHubHead: Decodable {
    let sha: String
}
```

The SHA is available on `ghPR.head.sha` inside the `checkForPRs` loop and does not need to be persisted on the `PR` model. It is only needed transiently to make the CI API calls.

### Scope

CI status is fetched only for authored PRs to minimize API usage. This adds ~2 API calls per authored PR per poll cycle (check-runs + status).

### Deduplication

Check runs and commit statuses can overlap (same CI system posting to both). Deduplicate by name: if a check run and a commit status share the same name/context, keep the check run (it has richer data). Use case-insensitive name matching.

### Mapping to CheckRunInfo

- Check runs with `status == "completed"` and `conclusion == "success"`: `.passing`
- Check runs with `status == "completed"` and `conclusion` in `["failure", "cancelled", "timed_out", "action_required"]`: `.failing`
- Check runs with `status != "completed"` (queued/in_progress): `.pending`
- Check runs with `conclusion` in `["neutral", "skipped"]`: `.passing` (not blocking)
- Commit statuses: `"success"` -> `.passing`, `"failure"`/`"error"` -> `.failing`, `"pending"` -> `.pending`

### Overall CIStatus derivation

- No checks at all: `.none`
- Any check `.failing`: `.failing`
- Any check `.pending` (and none failing): `.pending`
- All checks `.passing`: `.passing`

### Integration into checkForPRs

The `fetchCIStatus` call happens inside the `for ghPR in openPRs` loop, in the `if isAuthor` block, after building review infos. The SHA comes from `ghPR.head.sha`:

```swift
if isAuthor {
    let reviews: [GitHubReview] = // ... existing code ...
    let reviewInfos = buildReviewInfos(reviews: reviews, requestedReviewers: reviewers.users)

    // Fetch CI status -- fail silently, leave ciInfo as nil
    let ciInfo: CIInfo?
    do {
        ciInfo = try await fetchCIStatus(
            token: token, owner: owner, repo: repo, sha: ghPR.head.sha
        )
    } catch {
        ciInfo = nil
    }

    let authoredPR = PR(
        id: ghPR.id,
        number: ghPR.number,
        title: ghPR.title,
        htmlURL: ghPR.htmlUrl,
        repo: repoFullName,
        authorLogin: ghPR.user?.login,
        reviews: reviewInfos,
        isAuthored: true,
        ciInfo: ciInfo
    )
    authoredPRs.append(authoredPR)
}
```

**Error handling:** If `fetchCIStatus` throws (network error, rate limit, etc.), `ciInfo` is set to `nil`. The PR card will show no CI information. This is intentional -- CI status is supplementary and should not block the core PR tracking functionality. Errors are not surfaced to the user's error banner.

### New GitHubService methods

```swift
private func fetchCIStatus(token: String, owner: String, repo: String, sha: String) async throws -> CIInfo
private func fetchCheckRuns(token: String, owner: String, repo: String, sha: String) async throws -> [CheckRunInfo]
private func fetchCommitStatuses(token: String, owner: String, repo: String, sha: String) async throws -> [CheckRunInfo]
```

`fetchCIStatus` calls `fetchCheckRuns` and `fetchCommitStatuses`, deduplicates, and derives `overallStatus`. `fetchCheckRuns` paginates (per_page=100, same pattern as existing `listReviews`).

## Menu Bar

### Priority order (highest first)

1. Errors: `"!"`
2. Not configured: `"Setup"`
3. Ready to merge: `"N ready to merge"` (new)
4. Reviews needed: `"N reviews"`
5. PRs reviewed: `"N reviewed"`
6. Nothing: `"No reviews!"`

### Implementation

Add a computed property to `PRViewModel`:

```swift
var readyToMergePRs: [PR] {
    authoredPRs.filter { $0.isReadyToMerge }
}
```

Update `menuBarTitle`:

```swift
var menuBarTitle: String {
    if hasErrors { return "!" }
    if !settings.isConfigured && !settings.devShowSamplePRs { return "Setup" }
    let readyCount = readyToMergePRs.count
    if readyCount > 0 {
        return "\(readyCount) ready to merge"
    }
    if !activePRs.isEmpty {
        return "\(activePRs.count) \(activePRs.count == 1 ? "review" : "reviews")"
    }
    let reviewedCount = authoredReceivedReview.count
    if reviewedCount > 0 {
        return "\(reviewedCount) reviewed"
    }
    return "No reviews!"
}
```

## Notifications

### Trigger

When an authored PR transitions to ready-to-merge (approved + CI passing) and hasn't been notified yet. Uses the existing `enableNotifications` setting -- no separate toggle.

### Tracking

Add `readyMergeNotifiedPRIDs: Set<Int>` to `PersistenceManager`, following the same pattern as `notifiedPRIDs`.

### Content

- Title: `"Ready to Merge: {repo}"`
- Body: `"{PR title}"`
- Clicking opens the PR on GitHub via `userInfo["url"]`
- Sound: `.default`

### NotificationService method

```swift
func sendReadyToMergeNotification(pr: PR) async {
    let content = UNMutableNotificationContent()
    content.title = "Ready to Merge: \(pr.repo)"
    content.body = pr.title
    content.sound = .default
    content.userInfo = ["url": pr.htmlURL]

    let request = UNNotificationRequest(
        identifier: "pr-ready-\(pr.id)",
        content: content,
        trigger: nil
    )

    do {
        try await UNUserNotificationCenter.current().add(request)
    } catch {
        print("Failed to schedule ready-to-merge notification: \(error.localizedDescription)")
    }
}
```

### Stale ID cleanup

Clean `readyMergeNotifiedPRIDs` against authored PR IDs (not `validPRIDs`, since authored PRs may not be in `validPRIDs` when the user is not also a reviewer):

```swift
let readyMergeNotifiedIDs = await persistence.getReadyMergeNotifiedPRIDs()
let newlyReady = readyToMergePRs.filter { !readyMergeNotifiedIDs.contains($0.id) }

if settings.enableNotifications && !newlyReady.isEmpty {
    for pr in newlyReady {
        await NotificationService.shared.sendReadyToMergeNotification(pr: pr)
    }
}

let authoredPRIDs = Set(result.authoredPRs.map(\.id))
let updatedReadyIDs = readyMergeNotifiedIDs
    .union(Set(newlyReady.map(\.id)))
    .intersection(authoredPRIDs)  // clean stale against authored PRs
await persistence.setReadyMergeNotifiedPRIDs(updatedReadyIDs)
```

### Re-notification behavior

If a PR transitions from ready -> not ready (new commit resets CI) -> ready again, it will NOT be re-notified because its ID is already in `readyMergeNotifiedPRIDs`. This is intentional -- the user has already been alerted and can check the app for current status.

## PR Card UI

### CI Status Line (authored PRs only)

Below the review badges, show a CI status summary line with an expandable disclosure for individual checks.

#### Collapsed state

```
CI: 3/3 checks passing       [v]
```

Color-coded: green for all passing, red if any failing, orange if pending.

#### Expanded state

```
CI: 2/3 checks passing       [^]
  x  test-suite               failing
  v  build                    passing
  v  lint                     passing
```

Sorted: failures first, then pending, then passing.

#### No checks

If `ciInfo` is nil, has no checks, or has `overallStatus == .none`, show nothing.

### Ready to Merge highlight

The green border and "READY TO MERGE" badge apply wherever the PR card appears (Reviewed tab, Awaiting tab, or any other context where authored PRs are displayed). The styling is driven by `pr.isReadyToMerge` on the card itself, not the containing tab.

PRs that are ready to merge get:
- A green border overlay on the card (1.5px, rounded corners matching the card)
- A "READY TO MERGE" badge/label at the top-right of the card

### New view: `CIStatusView`

A new SwiftUI view in `Views/` that handles the summary line, disclosure toggle, and individual check list. Used by `PRCardView` when `showReviewStatus` is true and `ciInfo` is non-nil with at least one check.

## Persistence

### Cached data

`ciInfo` is already part of the `PR` struct, so it gets cached automatically when `authoredPRs` are persisted via `PersistenceManager.setAuthoredPRs()`.

### Cache backwards compatibility

Swift's synthesized `Decodable` does NOT use property defaults for missing keys -- it throws `keyNotFound` even when a default is provided. The existing code falls back to `CacheData()` on decode failure, which would wipe all cached state (dismissed PRs, notification tracking, etc.) on upgrade.

To avoid this, add a custom `init(from:)` to `CacheData` that uses `decodeIfPresent` with a fallback for the new field:

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    pendingPRs = try container.decodeIfPresent([PR].self, forKey: .pendingPRs) ?? []
    authoredPRs = try container.decodeIfPresent([PR].self, forKey: .authoredPRs) ?? []
    notifiedPRIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .notifiedPRIDs) ?? []
    dismissedPRIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .dismissedPRIDs) ?? []
    lastQueryTime = try container.decodeIfPresent(Date.self, forKey: .lastQueryTime)
    lastCheckHadErrors = try container.decodeIfPresent(Bool.self, forKey: .lastCheckHadErrors) ?? false
    lastCheckErrors = try container.decodeIfPresent([CheckError].self, forKey: .lastCheckErrors) ?? []
    readyMergeNotifiedPRIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .readyMergeNotifiedPRIDs) ?? []
}
```

This makes ALL fields resilient to missing keys, not just the new one. This also retroactively fixes the same latent issue for any future field additions.

### New persisted set

`readyMergeNotifiedPRIDs: Set<Int> = []` -- tracks which PRs have already triggered a ready-to-merge notification. Follows the same file-based JSON pattern as `notifiedPRIDs` and `dismissedPRIDs`.

Add corresponding getter/setter:
```swift
func getReadyMergeNotifiedPRIDs() -> Set<Int> { cache.readyMergeNotifiedPRIDs }
func setReadyMergeNotifiedPRIDs(_ ids: Set<Int>) { cache.readyMergeNotifiedPRIDs = ids; save() }
```

## Sample PRs

Update `loadSamplePRs()` in `PRViewModel` to include `ciInfo` on sample authored PRs:
- One PR with all checks passing + approved (ready to merge)
- One PR with a failing check + changes requested
- One PR with no checks + no reviews

## Known Limitations

- **Not GitHub's "ready to merge":** This feature checks for at least one approval + all CI passing. It does not account for branch protection rules (required reviewer count, required specific checks, merge conflicts). A PR may show as "ready to merge" here but still be blocked on GitHub.
- **Stale CI between polls:** CI status reflects the HEAD SHA at last poll time. If a new commit is pushed between polls, the cached status is for the old commit until the next poll cycle. This is consistent with how the rest of the app works.
- **No concurrent CI fetches:** CI status is fetched sequentially per authored PR within the existing `for ghPR in openPRs` loop. For users with many authored PRs, this could be optimized with `TaskGroup` in a future iteration.

## Files Changed

| File | Change |
|------|--------|
| `Models/CIInfo.swift` | New file: `CheckRunStatus`, `CIStatus`, `CheckRunInfo`, `CIInfo` |
| `Models/PR.swift` | Add `ciInfo: CIInfo?` (default nil), `isReadyToMerge` computed property |
| `Services/GitHubService.swift` | Add `fetchCIStatus()`, `fetchCheckRuns()`, `fetchCommitStatuses()`, new Decodable structs (`GitHubHead`, `GitHubCheckRun`, `GitHubCheckRunsResponse`, `GitHubCombinedStatus`, `GitHubCommitStatus`), call from `checkForPRs` for authored PRs, add deduplication logic |
| `Services/NotificationService.swift` | Add `sendReadyToMergeNotification(pr:)` |
| `Services/PersistenceManager.swift` | Add `readyMergeNotifiedPRIDs` to `CacheData`, add get/set methods |
| `ViewModels/PRViewModel.swift` | Add `readyToMergePRs`, update `menuBarTitle`, update `checkNow()` for ready-merge notifications, update sample PRs |
| `Views/CIStatusView.swift` | New file: expandable CI status display with summary + per-check detail |
| `Views/PRCardView.swift` | Integrate `CIStatusView`, add green border + "READY TO MERGE" badge for ready PRs |

Note: `project.yml` uses `sources: - PRNotifier` which auto-includes all `.swift` files. No `project.yml` changes needed.
