# PR Notifier for macOS

A lightweight macOS menubar application that monitors GitHub repositories and notifies you when you're tagged as a reviewer on pull requests. Designed specifically for Apple Silicon Macs.

<img src="icon.png" alt="PR Notifier Screenshot" width="200" />

## Features

- Lives in your macOS menubar
- Periodically checks for PRs that need your review
- Sends desktop notifications when new review requests come in
- Dismissible PR cards to help organize your review workflow
- Configurable check interval to control API usage
- Optimized for Apple Silicon with Metal GPU acceleration
- Low memory footprint and battery impact

## Installation

### From Release

Download the latest release from the [Releases page](https://github.com/yourusername/pr-notifier-app/releases).

### Build from Source

1. Clone the repository
2. Install dependencies: `npm install`
3. Build the app: `npm run build`
4. Create a distributable: `npm run dist`
5. The DMG installer will be available in the `release` folder

## Configuration

On first launch, you'll need to configure:

1. Your GitHub personal access token (with `repo` scope)
2. Your GitHub username
3. Repositories to monitor (in the format `owner/repo`)
4. Check interval (in minutes)
5. Notification preferences

## Development

- Run `npm run dev` to build and start the app in development mode
- Use `npm run pack` to create an unpacked version of the app
- Run `npm start-dev` to launch with development tools

## Architecture

PR Notifier is built with modern web technologies and optimized for macOS:

### Application Structure

- **Main Process**: Manages system integration through the Electron main process
  - Tray and menu management
  - Window creation and positioning
  - Scheduled PR checking
  - Notification handling
  - Persistent storage via electron-store

- **Renderer Process**: Provides the user interface using React
  - Tab-based UI for PR list and settings
  - Real-time list updates
  - Dismissible PR cards
  - Settings configuration

- **GitHub Integration**: 
  - Octokit REST client for GitHub API communication
  - Token-based authentication
  - Repository-specific PR queries
  - Rate limit consideration

### Key Technical Components

- **Electron**: Cross-platform desktop framework (optimized for macOS)
- **React & TypeScript**: Type-safe, component-based UI
- **TailwindCSS**: Utility-first styling
- **Electron Store**: Persistent local storage
- **Metal Acceleration**: Hardware-accelerated rendering on Apple Silicon

### Data Flow

1. Main process schedules periodic checks based on user configuration
2. GitHub API is queried for repositories where user is requested as reviewer
3. Results are processed, filtered against dismissed PRs, and stored
4. UI is updated to reflect current PR state
5. Notifications are triggered for new PR requests

## Future Enhancements

- Enhanced PR filtering capabilities
- Support for additional GitHub notification types
- PR metadata display (age, size, CI status)
- Custom notification sounds
- Team-based monitoring
- Windows/Linux support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the ISC License - see the LICENSE file for details.

## Technologies Used

- Electron 25.0.0
- React 19.0.0
- TypeScript 5.8.2
- Octokit REST 19.0.13
- electron-store 8.1.0
- TailwindCSS 3.3.5
- Webpack 5.98.0