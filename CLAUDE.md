# PR Notifier App Development Guide

## Build Commands
- **Build (Xcode)**: Open `PRNotifier/PRNotifier.xcodeproj`, Cmd+B
- **Build (CLI)**: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Debug build`
- **Release build**: `xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Release build`
- **Regenerate project**: `cd PRNotifier && xcodegen generate` (requires `brew install xcodegen`)

## App Architecture
Native macOS menu bar app built with Swift 5.9 and SwiftUI, targeting macOS 14.0+.

- **Entry point**: `PRNotifier/PRNotifierApp.swift` -- @main struct using MenuBarExtra scene
- **MVVM pattern**: Views -> ViewModels -> Models/Services

### Models (`PRNotifier/Models/`)
- `PR.swift` -- Codable PR model
- `AppSettings.swift` -- @Observable settings backed by UserDefaults
- `ReviewInfo.swift` -- Review state enum and reviewer data
- `CheckError.swift` -- Typed error model for API failures
- `InputValidation.swift` -- Token, repo name, username validation

### ViewModels (`PRNotifier/ViewModels/`)
- `PRViewModel.swift` -- @Observable @MainActor: PR state, polling, dismiss/restore logic

### Views (`PRNotifier/Views/`)
- `ContentView.swift` -- Tab container (PRs / Settings) with header and "Check Now"
- `PRListView.swift` -- Collapsible sections for active, dismissed, and authored PRs
- `PRCardView.swift` -- Individual PR card
- `ReviewBadgeView.swift` -- Review state badge
- `SettingsView.swift` -- Settings form
- `ErrorBannerView.swift` -- Error display banner

### Services (`PRNotifier/Services/`)
- `GitHubService.swift` -- GitHub API via URLSession with pagination and rate limiting
- `KeychainService.swift` -- Secure token storage in macOS Keychain
- `NotificationService.swift` -- UNUserNotificationCenter integration
- `PersistenceManager.swift` -- Actor-based JSON cache in ~/Library/Application Support/PRNotifier

### Key Dependencies (SPM)
- `KeychainAccess` 4.2.2 -- Keychain wrapper

## Code Style
- Swift 5.9 with SwiftUI
- MVVM architecture with @Observable
- Actor pattern for thread-safe persistence
- camelCase for variables/functions, PascalCase for types
- async/await for asynchronous operations
- Early returns, explicit error handling
