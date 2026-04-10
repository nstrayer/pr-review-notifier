# Per-Repo Colors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each monitored repository its own color in the PR card repo badge and let users configure it in settings.

**Architecture:** A `RepoColor` enum defines 8 preset colors. `AppSettings` stores a `[String: RepoColor]` mapping in UserDefaults and provides a `colorForRepo(_:)` helper that auto-assigns colors. `PRCardView` reads the color from settings. `SettingsView` adds an inline color picker popover per repo row.

**Tech Stack:** Swift 5.9, SwiftUI, UserDefaults

---

### Task 1: Add `RepoColor` enum

**Files:**
- Create: `PRNotifier/PRNotifier/Models/RepoColor.swift`

- [ ] **Step 1: Create `RepoColor.swift`**

Create `PRNotifier/PRNotifier/Models/RepoColor.swift`:

```swift
import SwiftUI

enum RepoColor: String, Codable, CaseIterable {
    case blue, green, orange, red, purple, pink, teal, yellow

    var swiftUIColor: Color {
        switch self {
        case .blue: Color(red: 0.0, green: 0.478, blue: 1.0)
        case .green: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .orange: Color(red: 1.0, green: 0.584, blue: 0.0)
        case .red: Color(red: 1.0, green: 0.231, blue: 0.188)
        case .purple: Color(red: 0.686, green: 0.322, blue: 0.871)
        case .pink: Color(red: 1.0, green: 0.176, blue: 0.333)
        case .teal: Color(red: 0.353, green: 0.784, blue: 0.980)
        case .yellow: Color(red: 1.0, green: 0.8, blue: 0.0)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Regenerate Xcode project**

XcodeGen auto-discovers source files, so the new file needs a project regenerate:

Run: `cd PRNotifier && xcodegen generate`
Expected: `Generated PRNotifier project`

- [ ] **Step 4: Build again after regeneration**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PRNotifier/PRNotifier/Models/RepoColor.swift PRNotifier/PRNotifier.xcodeproj
git commit -m "feat: add RepoColor enum with 8 preset palette colors"
```

---

### Task 2: Add color storage and auto-assignment to `AppSettings`

**Files:**
- Modify: `PRNotifier/PRNotifier/Models/AppSettings.swift`

- [ ] **Step 1: Add `repoColors` key and stored property**

In `AppSettings.swift`, add to the `Keys` enum:

```swift
static let repoColors = "repoColors"
```

Add a new stored property after `oauthUsername`:

```swift
var repoColors: [String: RepoColor] {
    didSet {
        if let data = try? JSONEncoder().encode(repoColors) {
            defaults.set(data, forKey: Keys.repoColors)
        }
    }
}
```

- [ ] **Step 2: Load `repoColors` in `init()`**

In `init()`, after the line `self.oauthUsername = defaults.string(forKey: Keys.oauthUsername) ?? ""`, add:

```swift
if let data = defaults.data(forKey: Keys.repoColors),
   let decoded = try? JSONDecoder().decode([String: RepoColor].self, from: data) {
    self.repoColors = decoded
} else {
    self.repoColors = [:]
}
```

- [ ] **Step 3: Add `colorForRepo(_:)` method**

Add this method after the `isConfigured` computed property:

```swift
func colorForRepo(_ repo: String) -> RepoColor {
    if let existing = repoColors[repo] {
        return existing
    }

    let usedColors = Set(repoColors.values)
    let assigned = RepoColor.allCases.first { !usedColors.contains($0) }
        ?? RepoColor.allCases[repoColors.count % RepoColor.allCases.count]

    repoColors[repo] = assigned
    return assigned
}
```

- [ ] **Step 4: Clean up stale colors when repos change**

In the `repos` property's `didSet`, after the existing `defaults.set(data, ...)` call, add cleanup logic. Replace the entire `repos` didSet:

```swift
var repos: [String] {
    didSet {
        if let data = try? JSONEncoder().encode(repos) {
            defaults.set(data, forKey: Keys.repos)
        }
        // Remove color entries for repos no longer in the list
        let repoSet = Set(repos)
        repoColors = repoColors.filter { repoSet.contains($0.key) }
    }
}
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add PRNotifier/PRNotifier/Models/AppSettings.swift
git commit -m "feat: add repoColors storage and auto-assignment to AppSettings"
```

---

### Task 3: Use repo color in `PRCardView`

**Files:**
- Modify: `PRNotifier/PRNotifier/Views/PRCardView.swift`

- [ ] **Step 1: Add `AppSettings` environment dependency**

At the top of `PRCardView`, after the existing properties (line 4-8), add:

```swift
@Environment(AppSettings.self) private var settings
```

- [ ] **Step 2: Replace accent color with repo color in the badge**

Replace the repo badge block (lines 52-59) from:

```swift
Text(pr.repo)
    .font(.caption)
    .fontWeight(.medium)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(isDismissed ? Color.gray.opacity(0.1) : Color.accentColor.opacity(0.1))
    .foregroundStyle(isDismissed ? Color.secondary : Color.accentColor)
    .clipShape(Capsule())
```

to:

```swift
Text(pr.repo)
    .font(.caption)
    .fontWeight(.medium)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(isDismissed ? Color.gray.opacity(0.1) : settings.colorForRepo(pr.repo).swiftUIColor.opacity(0.1))
    .foregroundStyle(isDismissed ? Color.secondary : settings.colorForRepo(pr.repo).swiftUIColor)
    .clipShape(Capsule())
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual test with sample PRs**

Launch the app, enable "Show sample PRs" in Developer Options. Verify:
- Each repo (`sample/repo`, `another/project`, `docs/documentation`, `docs/api-docs`) has a distinct colored badge
- Dismissed PRs still show gray badges
- Colors are consistent across tabs (same repo = same color)

- [ ] **Step 5: Commit**

```bash
git add PRNotifier/PRNotifier/Views/PRCardView.swift
git commit -m "feat: use per-repo colors in PR card badges"
```

---

### Task 4: Add inline color picker to `SettingsView`

**Files:**
- Modify: `PRNotifier/PRNotifier/Views/SettingsView.swift`

- [ ] **Step 1: Add local state for the color picker popover**

In `SettingsView`, after the existing `@State` properties (around line 23), add:

```swift
@State private var colorPickerRepo: String?
```

- [ ] **Step 2: Replace the repo row with a color-picker-enabled version**

Replace the `ForEach(repos, id: \.self)` block (lines 53-68) with:

```swift
ForEach(repos, id: \.self) { repo in
    HStack(spacing: 10) {
        Circle()
            .fill(settings.colorForRepo(repo).swiftUIColor)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .onTapGesture {
                colorPickerRepo = colorPickerRepo == repo ? nil : repo
            }
            .popover(isPresented: Binding(
                get: { colorPickerRepo == repo },
                set: { if !$0 { colorPickerRepo = nil } }
            )) {
                repoColorPicker(for: repo)
            }

        Text(repo)
            .font(.body)
        Spacer()
        Button {
            if let index = repos.firstIndex(of: repo) {
                repos.remove(at: index)
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Add the `repoColorPicker` helper view**

Add this private method at the bottom of `SettingsView`, before the closing `}` of the struct (but after `updateAutoLaunch`):

```swift
private func repoColorPicker(for repo: String) -> some View {
    let columns = Array(repeating: GridItem(.fixed(28), spacing: 8), count: 4)

    return LazyVGrid(columns: columns, spacing: 8) {
        ForEach(RepoColor.allCases, id: \.self) { color in
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(
                            settings.repoColors[repo] == color ? 0.6 : 0.15
                        ), lineWidth: settings.repoColors[repo] == color ? 2 : 1)
                )
                .onTapGesture {
                    settings.repoColors[repo] = color
                    colorPickerRepo = nil
                }
        }
    }
    .padding(12)
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Manual test**

Launch the app, go to Settings > Repositories. Verify:
- Each repo has a colored circle to its left
- Tapping the circle opens a popover with 8 color swatches
- Tapping a swatch changes the repo's color and closes the popover
- The color change is reflected immediately in the PR list
- Adding a new repo auto-assigns a color and shows the dot

- [ ] **Step 6: Commit**

```bash
git add PRNotifier/PRNotifier/Views/SettingsView.swift
git commit -m "feat: add inline repo color picker to settings"
```

---

### Task 5: Regenerate Xcode project and final verification

**Files:**
- Modify: `PRNotifier/PRNotifier.xcodeproj` (regenerated)

- [ ] **Step 1: Regenerate Xcode project**

Run: `cd PRNotifier && xcodegen generate`
Expected: `Generated PRNotifier project`

- [ ] **Step 2: Clean build**

Run: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug clean build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit if project file changed**

```bash
git add PRNotifier/PRNotifier.xcodeproj
git commit -m "chore: regenerate Xcode project with RepoColor model"
```
