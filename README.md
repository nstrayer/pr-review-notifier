# PR Notifier for macOS

A lightweight native macOS menu bar app that monitors GitHub repositories and notifies you when you're tagged as a reviewer on pull requests.

## Features

- Lives in your macOS menu bar with a PR count badge
- Periodically checks for PRs that need your review
- Desktop notifications for new review requests
- Dismissible PR cards to organize your review workflow
- Tracks your authored PRs and their review status
- Secure token storage in macOS Keychain
- Configurable check interval
- Launch at login support

## Requirements

- macOS 14.0 (Sonoma) or later

## Installation

### Build from Source

1. Clone the repository
2. Open `PRNotifier/PRNotifier.xcodeproj` in Xcode
3. Build and run (Cmd+R)

Or from the command line:

```bash
xcodebuild -project PRNotifier/PRNotifier.xcodeproj -scheme PRNotifier -configuration Release build
```

## Configuration

On first launch, open Settings to configure:

1. **GitHub token** -- personal access token with `repo` scope (stored securely in Keychain)
2. **GitHub username**
3. **Repositories** to monitor (format: `owner/repo`)
4. **Check interval** in minutes
5. **Notification preferences**

## Architecture

Built with Swift 5.9 and SwiftUI using MVVM architecture:

- **Models** -- PR data, settings, review state, error types
- **ViewModels** -- PR state management, polling, dismiss/restore
- **Views** -- SwiftUI menu bar UI with tabs for PR list and settings
- **Services** -- GitHub API (URLSession), Keychain, notifications, persistence

## License

ISC License -- see LICENSE for details.
