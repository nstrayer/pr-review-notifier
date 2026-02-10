# Migration Plan: PR Notifier -- Electron to Swift/SwiftUI

## Current App Summary

The Electron app is a macOS menu bar utility (~900 lines main process, ~550 lines GitHub service, ~375 lines React UI) that:

- Lives in the system tray with a dynamic PR count badge
- Polls GitHub API on a configurable interval (default 15 min) for PRs where you're a requested reviewer
- Shows a 400x500px frameless dropdown panel with tabs for PR list and settings
- Supports dismissing/restoring PRs, authored PR review status tracking, and desktop notifications
- Uses 13 IPC channels between main/renderer, electron-store for persistence, Octokit for GitHub API
- Has comprehensive input validation, auto-launch, notarization/code signing

## Proposed Swift/SwiftUI Architecture

```
PRNotifier/
  PRNotifierApp.swift          -- @main, MenuBarExtra with .window style
  Models/
    PR.swift                   -- Codable PR model (id, number, title, html_url, repo, reviews)
    AppSettings.swift          -- @AppStorage-backed settings
    ReviewInfo.swift           -- Review state enum + reviewer info
    CheckError.swift           -- Typed error model (auth, network, rate_limit, repo_access)
  Services/
    GitHubService.swift        -- URLSession + Codable (or Octokit.swift)
    NotificationService.swift  -- UNUserNotificationCenter wrapper
    KeychainService.swift      -- KeychainAccess wrapper for token
  ViewModels/
    PRViewModel.swift          -- @Observable, owns polling timer + all state
  Views/
    ContentView.swift          -- Segmented picker tab container
    PRListView.swift           -- Collapsible DisclosureGroup sections
    PRCardView.swift           -- Individual PR row with actions
    ReviewBadgeView.swift      -- Colored capsule per review state
    SettingsView.swift         -- Form with grouped sections
  Resources/
    Assets.xcassets            -- App icon, menu bar template image
```

## Technology Mapping

| Electron Concept | Swift/SwiftUI Equivalent |
|---|---|
| `Tray` + `BrowserWindow` | `MenuBarExtra` with `.window` style |
| `electron-store` (JSON) | `@AppStorage` for settings; Codable JSON file for PR cache |
| 13 `ipcMain`/`ipcRenderer` channels | Not needed -- single process, `@Observable` ViewModel |
| `@octokit/rest` | `Octokit.swift` via SPM, or thin URLSession + Codable wrapper |
| `node-notifier` + `Electron.Notification` | `UNUserNotificationCenter` |
| Token in plaintext JSON | **Keychain** via `KeychainAccess` |
| `setTimeout` recursive polling | `Timer.publish` or `Task { while !Task.isCancelled { ... } }` |
| Tailwind CSS | SwiftUI modifiers + `Form` + `.formStyle(.grouped)` |
| `electron-builder` + `notarize.js` | Xcode archive + `xcrun notarytool` |
| `shell.openExternal(url)` | `NSWorkspace.shared.open(url)` |
| Login items (auto-launch) | `SMAppService.mainApp.register()` (macOS 13+) |
| React state + useEffect | `@State`, `@Observable`, `.task {}`, `.onAppear` |

## SPM Dependencies

| Package | Purpose |
|---|---|
| [OctoKit.swift](https://github.com/nerdishbynature/octokit.swift) | GitHub REST API (or skip and use URLSession directly) |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure token storage |
| (Optional) [Sparkle](https://github.com/sparkle-project/Sparkle) | Auto-updates outside App Store |

Everything else (Timer, UNUserNotificationCenter, Codable, URLSession) is built into Foundation/SwiftUI.

## Phased Implementation

### Phase 1: Skeleton + Menu Bar

- Create Xcode project (macOS App, SwiftUI lifecycle, `LSUIElement = YES`)
- `MenuBarExtra` with `.window` style for the popover panel
- Template tray icon from existing assets (convert PNG to Asset Catalog)
- Quit menu item
- **Validates**: App appears in menu bar, panel shows/hides

### Phase 2: Data Models + Persistence

- `PR`, `ReviewInfo`, `CheckError` as `Codable` structs
- `@AppStorage` for settings (repos, username, interval, notifications, autoLaunch, settingsPrompted)
- `KeychainAccess` for GitHub token (replaces plaintext storage)
- JSON file in Application Support for PR cache, dismissed IDs, notified PR IDs, last query time, and error state
- **Validates**: Settings persist across restarts, token stored securely

### Phase 3: GitHub API

- `GitHubService` with async/await using URLSession + Codable
- `fetchPRsForReview(token:repos:username:)` -- maps to current `checkForPRs()`
- `fetchReviewsForAuthoredPRs()` -- review state per authored PR
- Input validation (token format, repo format, username)
- Typed error handling (auth, network, rate limit, repo access)
- Rate limit strategy: read `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers; when remaining is 0 or a 403/429 is received, skip the current check and surface an error in the menu bar. Resume normal polling on the next interval after the reset time has passed. No automatic retry/backoff within a single check cycle -- the regular polling interval serves as the retry mechanism.
- **Validates**: Real PR data from GitHub API

### Phase 4: Polling + State Management

- `PRViewModel` as `@Observable` class with `activePRs`, `dismissedPRs`, `authoredPRs`, `isLoading`, `lastCheckTime`, `errors`
- Single-flight polling: use an async `Task` loop that awaits each check before sleeping, ensuring no overlapping API calls (mirrors current Electron behavior where the next check is scheduled only after the current one completes)
- Cancel and restart the polling task when the check interval changes
- Dismiss/undismiss with persisted ID tracking
- Manual "Check Now" trigger (skips if a check is already in flight)
- **Validates**: PRs refresh on interval, dismiss/restore works, no overlapping polls

### Phase 5: UI -- PR List

- `ContentView` with segmented `Picker` for tabs
- `PRListView` with `DisclosureGroup` collapsible sections (active, dismissed, authored)
- `PRCardView` with clickable title, repo label, PR number, action buttons
- `ReviewBadgeView` capsule with SF Symbol icon + state-based color
- Click opens in browser via `NSWorkspace`
- **Validates**: PR list matches current Electron UI functionality

### Phase 6: UI -- Settings

- SwiftUI `Form` with `Section` groups
- `SecureField` for token, `TextField` for username
- Dynamic list for repos with add (Enter key) / remove
- `Stepper` for check interval (1-60 min)
- `Toggle` for notifications and auto-launch
- Inline validation error display
- **Validates**: All settings functional

### Phase 7: Notifications

- Request permission on first launch
- `UNUserNotificationCenter` for new PR alerts with click-to-open
- Track notified PR IDs to avoid duplicates
- Summary notification for pending count
- **Validates**: Notifications fire for new PRs

### Phase 8: System Integration

- Auto-launch via `SMAppService`
- Dynamic menu bar title showing PR count (or error indicator)
- `NSApp.dockTile.badgeLabel` for dock badge if desired
- **Validates**: Behaves as proper menu bar utility

### Phase 9: Distribution

- Developer ID signing + notarization
- DMG packaging
- Optional: Sparkle for auto-updates
- **Validates**: Clean install on fresh Mac

## Key Benefits

| Metric | Electron (current) | Swift/SwiftUI (target) |
|---|---|---|
| Memory | ~150-300 MB | ~15-30 MB |
| App bundle size | ~150+ MB | ~5-10 MB |
| Battery impact | Chromium overhead | Minimal native process |
| Token security | Plaintext JSON file | macOS Keychain |
| IPC complexity | 13 channels, 2 processes | Single process, direct bindings |
| macOS integration | Electron shims | Native APIs |

## Risks and Considerations

- **Octokit.swift coverage**: The JS Octokit is more mature. Your API surface is small (list PRs, list reviews, check repo access), so a thin URLSession wrapper may be simpler and more reliable than depending on Octokit.swift.
- **MenuBarExtra quirks**: The `.window` style can have sizing/animation issues. Fallback: `NSStatusItem` + `NSPopover` via AppKit interop.
- **Minimum macOS version**: Targeting macOS 14 (Sonoma) lets you use `@Observable` and all modern APIs. macOS 13 is possible but requires `ObservableObject` instead.
- **Existing native artifacts**: Check for any existing Swift project artifacts in the repo before scaffolding to avoid conflicts or duplication.
- **Testing**: XCTest + XCUITest replace Playwright. SwiftUI previews help with UI iteration.

## Current Codebase Reference

### Source Files

| File | Lines | Purpose |
|---|---|---|
| `src/main/main.ts` | ~900 | Electron main process: window, tray, IPC, polling |
| `src/utils/github.ts` | ~543 | GitHub API: PR fetching, notifications, error handling |
| `src/utils/inputValidator.ts` | ~465 | Input validation for token, repo, username, URL |
| `src/renderer/App.tsx` | ~375 | Root React component: tabs, state, IPC listeners |
| `src/renderer/Settings.tsx` | ~350 | Settings form with validation |
| `src/renderer/PRList.tsx` | ~144 | PR card list with dismiss/restore |
| `src/renderer/ReviewStatusBadge.tsx` | ~63 | Review state badge component |
| `src/preload.ts` | ~37 | Window drag region setup |

### IPC Channels (all eliminated in Swift version)

| Channel | Direction | Purpose |
|---|---|---|
| `save-settings` | Renderer -> Main | Validate and save config |
| `get-settings` | Renderer -> Main | Load all settings |
| `check-now` | Renderer -> Main | Trigger immediate PR check |
| `dismiss-pr` | Renderer -> Main | Add PR to dismissed list |
| `undismiss-pr` | Renderer -> Main | Remove PR from dismissed list |
| `hide-window` | Renderer -> Main | Close dropdown |
| `toggle-auto-launch` | Renderer -> Main | Set login item |
| `get-auto-launch` | Renderer -> Main | Get login item status |
| `save-dev-settings` | Renderer -> Main | Toggle sample PR mode |
| `get-dismissed-prs` | Renderer -> Main | Get dismissed PR IDs |
| `show-settings` | Main -> Renderer | Switch to settings tab |
| `window-shown` | Main -> Renderer | Window became visible |
| `settings-updated` | Main -> Renderer | Settings changed externally |

### Store Schema (maps to @AppStorage + Keychain + JSON file)

| Key | Type | Swift Storage |
|---|---|---|
| `token` | string | Keychain |
| `repos` | string[] | @AppStorage (JSON-encoded) |
| `username` | string | @AppStorage |
| `checkInterval` | number | @AppStorage |
| `enableNotifications` | boolean | @AppStorage |
| `autoLaunch` | boolean | @AppStorage |
| `devShowSamplePRs` | boolean | @AppStorage |
| `pendingPRs` | PR[] | JSON file |
| `authoredPRs` | PR[] | JSON file |
| `notifiedPRs` | number[] | JSON file |
| `dismissedPRs` | number[] | JSON file |
| `lastQueryTime` | number | JSON file |
| `lastCheckHadErrors` | boolean | JSON file |
| `lastCheckErrors` | CheckError[] | JSON file |
| `settingsPrompted` | boolean | @AppStorage |
