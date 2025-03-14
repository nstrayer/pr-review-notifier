# PR Notifier for macOS

A simple macOS menubar application that notifies you when you're tagged as a reviewer on GitHub pull requests.

## Features

- Lives in your macOS menubar
- Periodically checks for PRs that need your review
- Sends desktop notifications when new review requests come in
- Configurable check interval
- Easy access to the PRs that need your attention

## Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Build the app: `npm run build`
4. Start the app: `npm start`

## Development

- Run `npm run dev` to build and start the app in development mode
- Use `npm run pack` to create an unpacked version of the app
- Create a distributable with `npm run dist`

## Configuration

On first launch, you'll need to configure:

1. Your GitHub personal access token (with `repo` scope)
2. Your GitHub username
3. Repositories to monitor (in the format `owner/repo`)
4. Check interval (in minutes)

## Build from Source

To build a distributable version:

```bash
npm run dist
```

This will create a DMG installer in the `dist` folder.

## Technologies Used

- Electron
- React
- TypeScript
- Octokit (GitHub API)
- electron-store for configuration storage