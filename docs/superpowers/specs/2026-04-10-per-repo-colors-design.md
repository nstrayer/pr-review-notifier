# Per-Repo Color Design

Each monitored repository gets its own color so users can visually distinguish repos when scanning PR cards.

## Color Palette

8 preset colors based on standard macOS system colors, assigned in this order:

1. Blue (`#007AFF`)
2. Green (`#34C759`)
3. Orange (`#FF9500`)
4. Red (`#FF3B30`)
5. Purple (`#AF52DE`)
6. Pink (`#FF2D55`)
7. Teal (`#5AC8FA`)
8. Yellow (`#FFCC00`)

If all 8 are in use, assignment cycles from the beginning.

## Data Model

### `RepoColor` enum (new file: `Models/RepoColor.swift`)

```swift
enum RepoColor: String, Codable, CaseIterable {
    case blue, green, orange, red, purple, pink, teal, yellow

    var swiftUIColor: Color { ... }
}
```

Maps each case to its corresponding SwiftUI `Color` value.

### `AppSettings` changes

New stored property:

```swift
var repoColors: [String: RepoColor]  // persisted in UserDefaults as JSON
```

New helper method:

```swift
func colorForRepo(_ repo: String) -> RepoColor
```

Returns the stored color for a repo. If none is stored, auto-assigns the first palette color not already in use (by iterating `RepoColor.allCases` and checking which are absent from the current `repoColors` values). Persists the assignment immediately. If all colors are taken, cycles from the beginning.

Also cleans up stale entries: when `repos` is set, any `repoColors` keys not in the new repo list are removed.

## UI Changes

### PR Card (`PRCardView.swift`)

The repo badge (lines 52-59) currently uses `Color.accentColor` for background and foreground. Change to use the repo's assigned color:

- Background: `repoColor.opacity(0.1)` (unchanged pattern, new color source)
- Foreground: `repoColor` (unchanged pattern, new color source)
- Dismissed state remains gray (unchanged)

The view needs access to `AppSettings` via `@Environment(AppSettings.self)`. This is a new dependency for `PRCardView` -- `AppSettings` is already injected into the environment at the app level, so no changes needed to parent views.

### Settings (`SettingsView.swift`)

Each repo row in the Repositories section gains a color indicator dot (20x20 circle) to the left of the repo name. Tapping the dot opens a popover containing the 8 palette swatches. Tapping a swatch updates the color and dismisses the popover.

The color dot reflects the current assignment. New repos get auto-assigned on add.

## Auto-Assignment Behavior

When a repo is added (via `addRepo()` in settings), `colorForRepo()` is called to assign a color before the save. This ensures every repo in the list always has a visible color dot.

## Testing

Verify with the existing "Show sample PRs" developer toggle -- sample PRs use repos like `[SAMPLE]` prefixed names. Each should get a distinct color.
