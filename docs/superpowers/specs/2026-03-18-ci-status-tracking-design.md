# CI Status Tracking + Ready to Merge

## Problem

The user often merges PRs before CI finishes because waiting is tedious. The app should alert when an authored PR has both approval and passing CI, signaling it's safe to merge.

## Overview

Add CI status tracking for authored PRs. When an authored PR has at least one approval and all CI checks passing, it becomes "ready to merge" -- triggering a notification and taking over the menu bar display.

## Data Model

### New types in `Models/`

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

Add `var ciInfo: CIInfo?` to the `PR` struct. Add corresponding `CodingKey`.

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

2. **Combined Commit Status** (legacy CI -- CircleCI, Jenkins, etc.):
   `GET /repos/{owner}/{repo}/commits/{sha}/status`
   - Returns individual statuses with `context` (name) and `state` ("error"/"failure"/"pending"/"success")

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

### Scope

CI status is fetched only for authored PRs to minimize API usage. This adds ~2 API calls per authored PR per poll cycle (check-runs + status).

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

### New GitHubService methods

```swift
func fetchCIStatus(token: String, owner: String, repo: String, sha: String) async throws -> CIInfo
```

Called from within `checkForPRs` after building each authored PR. The `CIInfo` is set on the PR before appending to `authoredPRs`.

## Menu Bar

### Priority order (highest first)

1. Errors: `"!"`
2. Ready to merge: `"N ready to merge"` (new)
3. Reviews needed: `"N reviews"`
4. PRs reviewed: `"N reviewed"`
5. Nothing: `"No reviews!"`

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

When an authored PR transitions to ready-to-merge (approved + CI passing) and hasn't been notified yet.

### Tracking

Add `readyMergeNotifiedPRIDs: Set<Int>` to `PersistenceManager`, following the same pattern as `notifiedPRIDs`.

### Content

- Title: `"Ready to Merge: {repo}"`
- Body: `"{PR title}"`
- Clicking opens the PR on GitHub (same as existing notifications)

### Implementation

In `PRViewModel.checkNow()`, after fetching results:

```swift
let readyMergeNotifiedIDs = await persistence.getReadyMergeNotifiedPRIDs()
let newlyReady = readyToMergePRs.filter { !readyMergeNotifiedIDs.contains($0.id) }

if settings.enableNotifications && !newlyReady.isEmpty {
    for pr in newlyReady {
        await NotificationService.shared.sendReadyToMergeNotification(pr: pr)
    }
}

let updatedReadyIDs = readyMergeNotifiedIDs
    .union(Set(newlyReady.map(\.id)))
    .intersection(result.validPRIDs)  // clean stale
await persistence.setReadyMergeNotifiedPRIDs(updatedReadyIDs)
```

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

If `ciInfo` is nil or has no checks, show nothing (don't show "CI: no checks").

### Ready to Merge highlight (Reviewed tab)

PRs that are ready to merge get:
- A green left border (3px) on the card
- A "READY TO MERGE" badge/label at the top-right of the card

### New view: `CIStatusView`

A new SwiftUI view in `Views/` that handles the summary line, disclosure toggle, and individual check list. Used by `PRCardView` when `showReviewStatus` is true and `ciInfo` is non-nil.

## Persistence

### Cached data

`ciInfo` is already part of the `PR` struct, so it gets cached automatically when `authoredPRs` are persisted via `PersistenceManager.setAuthoredPRs()`.

### New persisted set

`readyMergeNotifiedPRIDs: Set<Int>` -- tracks which PRs have already triggered a ready-to-merge notification. Follows the same file-based JSON pattern as `notifiedPRIDs` and `dismissedPRIDs`.

## Sample PRs

Update `loadSamplePRs()` in `PRViewModel` to include `ciInfo` on sample authored PRs:
- One PR with all checks passing + approved (ready to merge)
- One PR with a failing check + changes requested
- One PR with no checks + no reviews

## Files Changed

| File | Change |
|------|--------|
| `Models/CIInfo.swift` | New file: `CheckRunStatus`, `CIStatus`, `CheckRunInfo`, `CIInfo` |
| `Models/PR.swift` | Add `ciInfo: CIInfo?`, `isReadyToMerge` computed property |
| `Services/GitHubService.swift` | Add `fetchCIStatus()`, new Decodable structs (`GitHubHead`, `GitHubCheckRunsResponse`, `GitHubCombinedStatus`), call from `checkForPRs` for authored PRs |
| `Services/NotificationService.swift` | Add `sendReadyToMergeNotification(pr:)` |
| `Services/PersistenceManager.swift` | Add `readyMergeNotifiedPRIDs` get/set |
| `ViewModels/PRViewModel.swift` | Add `readyToMergePRs`, update `menuBarTitle`, update `checkNow()` for ready-merge notifications, update sample PRs |
| `Views/CIStatusView.swift` | New file: expandable CI status display |
| `Views/PRCardView.swift` | Integrate `CIStatusView`, add green border for ready-to-merge PRs |
| `project.yml` | Add new source files |
