# CI Status Tracking + Ready to Merge -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CI status tracking to authored PRs and alert the user when a PR is approved with all CI checks passing ("ready to merge").

**Architecture:** Extend the existing MVVM architecture. New `CIInfo` model types, new `fetchCIStatus` methods in `GitHubService`, new `CIStatusView` SwiftUI component, updates to `PRViewModel` for menu bar priority and notifications, and `PersistenceManager` for cache compatibility and notification tracking.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14.0+, GitHub REST API v3, XcodeGen

**Spec:** `docs/superpowers/specs/2026-03-18-ci-status-tracking-design.md`

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `PRNotifier/PRNotifier/Models/CIInfo.swift` | Create | `CheckRunStatus`, `CIStatus`, `CheckRunInfo`, `CIInfo` types |
| `PRNotifier/PRNotifier/Models/PR.swift` | Modify | Add `ciInfo: CIInfo?`, `isReadyToMerge` computed property |
| `PRNotifier/PRNotifier/Services/GitHubService.swift` | Modify | Add `GitHubHead` decodable, `fetchCIStatus`/`fetchCheckRuns`/`fetchCommitStatuses` methods, integrate into `checkForPRs` |
| `PRNotifier/PRNotifier/Services/PersistenceManager.swift` | Modify | Add `readyMergeNotifiedPRIDs` to `CacheData`, custom `init(from:)`, getter/setter |
| `PRNotifier/PRNotifier/Services/NotificationService.swift` | Modify | Add `sendReadyToMergeNotification(pr:)` |
| `PRNotifier/PRNotifier/ViewModels/PRViewModel.swift` | Modify | Add `readyToMergePRs`, update `menuBarTitle`, update `checkNow()` for ready-merge notifications, update sample PRs |
| `PRNotifier/PRNotifier/Views/CIStatusView.swift` | Create | Expandable CI status summary + per-check detail list |
| `PRNotifier/PRNotifier/Views/PRCardView.swift` | Modify | Integrate `CIStatusView`, add green border + "READY TO MERGE" badge |

Note: `project.yml` uses `sources: - PRNotifier` which auto-includes all `.swift` files. No `project.yml` changes needed.

---

### Task 1: Add CIInfo model types

**Files:**
- Create: `PRNotifier/PRNotifier/Models/CIInfo.swift`

- [ ] **Step 1: Create CIInfo.swift with all CI model types**

```swift
import Foundation

enum CheckRunStatus: String, Codable, Equatable {
    case passing, failing, pending
}

enum CIStatus: String, Codable, Equatable {
    case passing, failing, pending, none
}

struct CheckRunInfo: Codable, Equatable {
    let name: String
    let status: CheckRunStatus
}

struct CIInfo: Codable, Equatable {
    let checks: [CheckRunInfo]
    let overallStatus: CIStatus
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PRNotifier/PRNotifier/Models/CIInfo.swift
git commit -m "feat: add CIInfo model types for CI status tracking"
```

---

### Task 2: Add ciInfo and isReadyToMerge to PR model

**Files:**
- Modify: `PRNotifier/PRNotifier/Models/PR.swift`

- [ ] **Step 1: Add ciInfo property, update CodingKeys, and add isReadyToMerge**

Add `var ciInfo: CIInfo?` after `var isAuthored: Bool?`. Update CodingKeys to include it:

```swift
enum CodingKeys: String, CodingKey {
    case id, number, title
    case htmlURL = "html_url"
    case repo, authorLogin, reviews, isAuthored, ciInfo
}
```

Add computed property after the struct's stored properties:

```swift
var isReadyToMerge: Bool {
    guard let ci = ciInfo, ci.overallStatus == .passing else { return false }
    guard let reviews = reviews else { return false }
    return reviews.contains { $0.state == .approved }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **` -- existing call sites still work because `ciInfo` has a default of `nil` in the memberwise init.

- [ ] **Step 3: Commit**

```bash
git add PRNotifier/PRNotifier/Models/PR.swift
git commit -m "feat: add ciInfo and isReadyToMerge to PR model"
```

---

### Task 3: Add PersistenceManager support for readyMergeNotifiedPRIDs

**Files:**
- Modify: `PRNotifier/PRNotifier/Services/PersistenceManager.swift`

- [ ] **Step 1: Add readyMergeNotifiedPRIDs to CacheData and add custom init(from:)**

Add to `CacheData` struct:
```swift
var readyMergeNotifiedPRIDs: Set<Int> = []
```

Add custom `init(from:)` to `CacheData` that uses `decodeIfPresent` for ALL fields. This prevents cache wipe on upgrade when existing cache files are missing the new key. The synthesized `CodingKeys` enum works here since `CacheData` has no custom key mappings.

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

- [ ] **Step 2: Add getter/setter methods**

Add after the existing `addNotifiedPRID` method:

```swift
func getReadyMergeNotifiedPRIDs() -> Set<Int> { cache.readyMergeNotifiedPRIDs }
func setReadyMergeNotifiedPRIDs(_ ids: Set<Int>) { cache.readyMergeNotifiedPRIDs = ids; save() }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PRNotifier/PRNotifier/Services/PersistenceManager.swift
git commit -m "feat: add readyMergeNotifiedPRIDs persistence with backwards-compatible decoding"
```

---

### Task 4: Add CI status fetching to GitHubService

**Files:**
- Modify: `PRNotifier/PRNotifier/Services/GitHubService.swift`

This is the largest task. It adds API response structs, three new methods, and integrates CI fetching into `checkForPRs`.

- [ ] **Step 1: Add GitHubHead to GitHubPullRequest and new API response structs**

Add `GitHubHead` struct and update `GitHubPullRequest`:

```swift
private struct GitHubHead: Decodable {
    let sha: String
}
```

Add `let head: GitHubHead` to the existing `GitHubPullRequest` struct.

Add check run and commit status response structs:

```swift
private struct GitHubCheckRun: Decodable {
    let name: String
    let status: String      // "queued", "in_progress", "completed"
    let conclusion: String? // "success", "failure", "neutral", "cancelled", "skipped", "timed_out", "action_required"
}

private struct GitHubCheckRunsResponse: Decodable {
    let checkRuns: [GitHubCheckRun]
}

private struct GitHubCommitStatus: Decodable {
    let context: String
    let state: String // "error", "failure", "pending", "success"
}

private struct GitHubCombinedStatus: Decodable {
    let statuses: [GitHubCommitStatus]
}
```

- [ ] **Step 2: Add fetchCheckRuns method (with pagination)**

Add after the existing `listReviews` method. Paginates with `per_page=100`, same pattern as `listReviews`:

```swift
private func fetchCheckRuns(
    token: String, owner: String, repo: String, sha: String
) async throws -> [CheckRunInfo] {
    var allRuns: [GitHubCheckRun] = []
    var page = 1
    let maxPages = 20

    while page <= maxPages {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)/check-runs?per_page=100&page=\(page)")!
        let data = try await request(url: url, token: token)
        let response = try Self.snakeCaseDecoder.decode(GitHubCheckRunsResponse.self, from: data)
        allRuns.append(contentsOf: response.checkRuns)

        if response.checkRuns.count < 100 { break }
        page += 1
    }

    return allRuns.map { run in
        let status: CheckRunStatus
        if run.status != "completed" {
            status = .pending
        } else {
            switch run.conclusion {
            case "success", "neutral", "skipped":
                status = .passing
            case "failure", "cancelled", "timed_out", "action_required":
                status = .failing
            default:
                status = .pending
            }
        }
        return CheckRunInfo(name: run.name, status: status)
    }
}
```

- [ ] **Step 3: Add fetchCommitStatuses method**

```swift
private func fetchCommitStatuses(
    token: String, owner: String, repo: String, sha: String
) async throws -> [CheckRunInfo] {
    let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)/status")!
    let data = try await request(url: url, token: token)
    let response = try Self.snakeCaseDecoder.decode(GitHubCombinedStatus.self, from: data)

    return response.statuses.map { s in
        let status: CheckRunStatus
        switch s.state {
        case "success":
            status = .passing
        case "failure", "error":
            status = .failing
        default:
            status = .pending
        }
        return CheckRunInfo(name: s.context, status: status)
    }
}
```

- [ ] **Step 4: Add fetchCIStatus method with deduplication**

```swift
private func fetchCIStatus(
    token: String, owner: String, repo: String, sha: String
) async throws -> CIInfo {
    let checkRuns = try await fetchCheckRuns(token: token, owner: owner, repo: repo, sha: sha)
    let commitStatuses = try await fetchCommitStatuses(token: token, owner: owner, repo: repo, sha: sha)

    // Deduplicate: check runs take priority over commit statuses (richer data)
    var checksByName: [String: CheckRunInfo] = [:]
    for run in checkRuns {
        checksByName[run.name.lowercased()] = run
    }
    for status in commitStatuses {
        let key = status.name.lowercased()
        if checksByName[key] == nil {
            checksByName[key] = status
        }
    }

    let checks = Array(checksByName.values)

    let overallStatus: CIStatus
    if checks.isEmpty {
        overallStatus = .none
    } else if checks.contains(where: { $0.status == .failing }) {
        overallStatus = .failing
    } else if checks.contains(where: { $0.status == .pending }) {
        overallStatus = .pending
    } else {
        overallStatus = .passing
    }

    return CIInfo(checks: checks, overallStatus: overallStatus)
}
```

- [ ] **Step 5: Integrate fetchCIStatus into checkForPRs**

In the `if isAuthor` block (around line 120), after `buildReviewInfos`, add CI fetching before creating the `authoredPR`. Replace the existing authored PR construction with:

```swift
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
```

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add PRNotifier/PRNotifier/Services/GitHubService.swift
git commit -m "feat: add CI status fetching from GitHub check runs and commit statuses"
```

---

### Task 5: Add ready-to-merge notification to NotificationService

**Files:**
- Modify: `PRNotifier/PRNotifier/Services/NotificationService.swift`

- [ ] **Step 1: Add sendReadyToMergeNotification method**

Add after the existing `sendSummaryNotification` method:

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

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PRNotifier/PRNotifier/Services/NotificationService.swift
git commit -m "feat: add ready-to-merge notification"
```

---

### Task 6: Update PRViewModel -- menu bar title, notifications, sample PRs

**Files:**
- Modify: `PRNotifier/PRNotifier/ViewModels/PRViewModel.swift`

- [ ] **Step 1: Add readyToMergePRs computed property**

Add after `authoredReceivedReview`:

```swift
var readyToMergePRs: [PR] {
    authoredPRs.filter { $0.isReadyToMerge }
}
```

- [ ] **Step 2: Update menuBarTitle**

Insert the ready-to-merge check after the `isConfigured` check and before the `activePRs` check:

```swift
let readyCount = readyToMergePRs.count
if readyCount > 0 {
    return "\(readyCount) ready to merge"
}
```

- [ ] **Step 3: Add ready-to-merge notification logic to checkNow()**

After the existing notification block (around line 191, after `await persistence.setNotifiedPRIDs(updatedNotifiedIDs)`), add:

```swift
// Send ready-to-merge notifications
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
    .intersection(authoredPRIDs)
await persistence.setReadyMergeNotifiedPRIDs(updatedReadyIDs)
```

- [ ] **Step 4: Update sample authored PRs with ciInfo**

In `loadSamplePRs()`, update the three sample authored PRs:

First PR (ready to merge -- approved + CI passing):
```swift
PR(id: 9876543220, number: 301, title: "[SAMPLE-AUTHORED] Implement user profile page",
   htmlURL: "https://github.com/sample/repo/pull/301", repo: "sample/repo",
   authorLogin: "you", reviews: [
       ReviewInfo(reviewerLogin: "reviewer1", reviewerName: "Alice Smith", state: .approved),
       ReviewInfo(reviewerLogin: "reviewer2", reviewerName: "Bob Johnson", state: .pending),
   ], isAuthored: true, ciInfo: CIInfo(checks: [
       CheckRunInfo(name: "build", status: .passing),
       CheckRunInfo(name: "test-suite", status: .passing),
       CheckRunInfo(name: "lint", status: .passing),
   ], overallStatus: .passing))
```

Second PR (failing CI + changes requested):
```swift
PR(id: 9876543221, number: 302, title: "[SAMPLE-AUTHORED] Fix navigation bug",
   htmlURL: "https://github.com/sample/repo/pull/302", repo: "another/project",
   authorLogin: "you", reviews: [
       ReviewInfo(reviewerLogin: "reviewer3", reviewerName: "Charlie Davis", state: .changesRequested),
   ], isAuthored: true, ciInfo: CIInfo(checks: [
       CheckRunInfo(name: "build", status: .passing),
       CheckRunInfo(name: "test-suite", status: .failing),
       CheckRunInfo(name: "lint", status: .passing),
   ], overallStatus: .failing))
```

Third PR (no checks + no reviews -- leave ciInfo as nil, which is the default).

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add PRNotifier/PRNotifier/ViewModels/PRViewModel.swift
git commit -m "feat: add ready-to-merge menu bar priority, notifications, and sample data"
```

---

### Task 7: Create CIStatusView

**Files:**
- Create: `PRNotifier/PRNotifier/Views/CIStatusView.swift`

- [ ] **Step 1: Create CIStatusView with expandable check list**

```swift
import SwiftUI

struct CIStatusView: View {
    let ciInfo: CIInfo

    @State private var isExpanded = false

    private var passingCount: Int {
        ciInfo.checks.filter { $0.status == .passing }.count
    }

    private var summaryColor: Color {
        switch ciInfo.overallStatus {
        case .passing: .green
        case .failing: .red
        case .pending: .orange
        case .none: .gray
        }
    }

    private var sortedChecks: [CheckRunInfo] {
        ciInfo.checks.sorted { a, b in
            let order: [CheckRunStatus: Int] = [.failing: 0, .pending: 1, .passing: 2]
            return (order[a.status] ?? 3) < (order[b.status] ?? 3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                        .foregroundStyle(summaryColor)
                    Text("CI: \(passingCount)/\(ciInfo.checks.count) checks passing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedChecks, id: \.name) { check in
                        HStack(spacing: 6) {
                            Image(systemName: checkIcon(for: check.status))
                                .font(.system(size: 9))
                                .foregroundStyle(checkColor(for: check.status))
                                .frame(width: 12)
                            Text(check.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(check.status.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private var statusIcon: String {
        switch ciInfo.overallStatus {
        case .passing: "checkmark.circle.fill"
        case .failing: "xmark.circle.fill"
        case .pending: "clock.fill"
        case .none: "minus.circle"
        }
    }

    private func checkIcon(for status: CheckRunStatus) -> String {
        switch status {
        case .passing: "checkmark.circle.fill"
        case .failing: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }

    private func checkColor(for status: CheckRunStatus) -> Color {
        switch status {
        case .passing: .green
        case .failing: .red
        case .pending: .orange
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PRNotifier/PRNotifier/Views/CIStatusView.swift
git commit -m "feat: add CIStatusView with expandable check list"
```

---

### Task 8: Integrate CIStatusView and ready-to-merge highlight into PRCardView

**Files:**
- Modify: `PRNotifier/PRNotifier/Views/PRCardView.swift`

- [ ] **Step 1: Add CIStatusView below review badges**

After the review badges block (after the closing `}` of `if showReviewStatus, let reviews = pr.reviews { ... }`), add:

```swift
// CI status (authored PRs with checks)
if showReviewStatus,
   let ciInfo = pr.ciInfo,
   !ciInfo.checks.isEmpty {
    CIStatusView(ciInfo: ciInfo)
}
```

- [ ] **Step 2: Add ready-to-merge badge**

At the top of the VStack (before the title Button), add a conditional "READY TO MERGE" badge:

```swift
if pr.isReadyToMerge {
    HStack {
        Spacer()
        Text("READY TO MERGE")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.13))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
            )
    }
}
```

- [ ] **Step 3: Add green border for ready-to-merge PRs**

After the existing `.clipShape(RoundedRectangle(cornerRadius: 8))` modifier on the outer VStack, add a conditional overlay using `@ViewBuilder` syntax (avoids type-erasure issues with ternary):

```swift
.overlay {
    if pr.isReadyToMerge {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
    }
}
```

Keep the existing `.background`, `.clipShape`, and `.shadow` modifiers as-is. This adds the overlay after `.clipShape` and before `.shadow`.

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PRNotifier/PRNotifier/Views/PRCardView.swift
git commit -m "feat: integrate CI status display and ready-to-merge highlight into PR cards"
```

---

### Task 9: Regenerate Xcode project and do final build verification

- [ ] **Step 1: Regenerate the Xcode project**

Run: `cd PRNotifier && xcodegen generate`

Expected: `Generated PRNotifier project` (or similar success message). This ensures the new files are properly included.

- [ ] **Step 2: Full clean build**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug clean build 2>&1 | tail -10`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit any project file changes**

```bash
git add PRNotifier/PRNotifier.xcodeproj
git commit -m "chore: regenerate Xcode project with CI status tracking files"
```

---

### Task 10: Manual smoke test with sample PRs

- [ ] **Step 1: Enable sample PR mode**

Launch the app. In Settings, enable "Show Sample PRs" (the `devShowSamplePRs` toggle).

- [ ] **Step 2: Verify menu bar shows "1 ready to merge"**

The first sample authored PR has approved review + all CI passing, so the menu bar should display "1 ready to merge".

- [ ] **Step 3: Verify PR card UI**

Open the popover. Navigate to the "Reviewed" tab. Verify:
- First authored PR shows green border, "READY TO MERGE" badge, CI line "CI: 3/3 checks passing" with expandable detail
- Second authored PR shows red CI line "CI: 2/3 checks passing" with expandable detail showing test-suite failing
- Third authored PR shows no CI line (no checks)

- [ ] **Step 4: Verify CI expand/collapse**

Click the disclosure chevron on a CI status line. Verify individual checks are listed, sorted failures first.

- [ ] **Step 5: Bump version and commit**

```bash
# Update MARKETING_VERSION in project.yml from "2.4.0" to "2.5.0"
# Then regenerate
cd PRNotifier && xcodegen generate
git add -A
git commit -m "chore: bump version to 2.5.0"
```
