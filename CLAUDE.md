# PR Notifier App Development Guide

## Build & Test Commands
- Build: `npm run build` - Compile TypeScript, run webpack, copy HTML/assets
- Dev: `npm run dev` - Build and start with development environment
- Distribution: `npm run dist` - Build optimized app for macOS arm64
- Clean: `rm -rf dist/* node_modules/.cache` - Clear build artifacts if needed

## App Architecture
- **Main Process** (src/main/): Electron's main process with system tray integration
- **Renderer Process** (src/renderer/): React UI components for the app window
- **IPC Communication**: Communication between main and renderer processes
- **Store**: electron-store for persistent data storage
- **GitHub API**: @octokit/rest for PR data fetching

### App Components
- **PRList.tsx**: Displays pending pull requests to review
- **Settings.tsx**: Configure GitHub token, repos, and notification settings
- **TrayIcon**: System tray icon showing app status

## Testing Architecture

### Testing Commands
- Run all tests: `npm test` - Builds app and runs all Playwright tests
- Run specific test: `npm run test:single` - Runs PR list test with Playwright
- Run direct test: `npm run test:pr-list` - Alternative implementation using direct Node.js approach
- Debug tests: `npm run test:debug` - Runs tests in debug mode with UI
- Install dependencies: `npm run playwright:install` - Install required Playwright browsers

### Key Test Files
- `playwright.config.ts` - Configures test timeouts, workers, and reporters
- `tests/e2e/pr-list.spec.ts` - Tests PR list UI functionality
- `tests/helpers/app.ts` - Helper for launching Electron app in tests
- `tests/helpers/store.ts` - Test store initialization functions
- `tests/mocks/github.ts` - Mock PR data for tests
- `tests/run-tests.sh` - Script to build app and run tests with proper environment

### Testing Details
- Tests use a test-specific store located at `tests/tmp/test-store.json`
- Test environment automatically sets up mock PR data via the run-tests.sh script
- Set NODE_ENV=test for proper test environment configuration
- Use ELECTRON_STORE_PATH environment variable to specify test store location
- Add data-testid attributes to components for reliable test selectors
- The Playwright tests check that the app correctly:
  - Displays PRs waiting for review
  - Shows PR titles and repository information
  - Allows dismissing and restoring PRs
  - Updates when clicking the "Check Now" button

### Playwright Test Requirements
- Playwright requires specific Electron version (v25.0.0)
- Use a single worker (workers: 1) to prevent conflicts
- Use increased timeouts for Electron window startup (60000ms)
- Ensure electron app is properly closed after each test

### Troubleshooting Tests
If you encounter issues with Electron testing:
1. Try reinstalling Electron: `npm install electron@25.0.0 --force`
2. Rebuild dependencies: `npx electron-builder install-app-deps`
3. Update Playwright: `npm install @playwright/test@latest`
4. Make sure app is built: `npm run build`
5. Check test store path is correct: `echo $ELECTRON_STORE_PATH`
6. If all else fails, try the standalone test: `node pr-list-test.js`

## Code Style Guidelines
- TypeScript with strict type checking
- 2-space indentation
- React functional components with hooks
- Define interfaces for props and state
- Use camelCase for variables/functions, PascalCase for components/types
- Error handling: try/catch with console.error logging
- Imports order: React, external libraries, local components, utils, styles
- Tailwind CSS for styling
- Use async/await for asynchronous operations
- Handle cleanup in useEffect return functions
- Use explicit typing for useState hooks
- IPC communication between Electron main and renderer processes