#!/bin/bash
set -e  # Exit immediately if any command fails

# Make sure the app is built
echo "Building app..."
npm run build

# Make sure dist exists
if [ ! -f "dist/main/index.js" ]; then
  echo "ERROR: App build failed. dist/main/index.js not found."
  exit 1
fi

# Setup test environment
echo "Setting up test environment..."
mkdir -p tests/tmp

# Create test store with initial data
echo '{
  "token": "test-token",
  "username": "test-user",
  "repos": ["test-org/test-repo"],
  "showNotifications": true,
  "lastQueryTime": 1710861988000,
  "pendingPRs": [
    {
      "id": 1,
      "number": 101,
      "title": "Add new feature",
      "html_url": "https://github.com/test-org/test-repo/pull/101",
      "repo": "test-org/test-repo"
    },
    {
      "id": 2,
      "number": 102,
      "title": "Fix bug in login flow",
      "html_url": "https://github.com/test-org/test-repo/pull/102",
      "repo": "test-org/test-repo"
    }
  ],
  "dismissedPRs": []
}' > tests/tmp/test-store.json

# Run the tests with proper environment variables
echo "Running Playwright electron tests..."
NODE_ENV=test ELECTRON_STORE_PATH="$(pwd)/tests/tmp/test-store.json" npx playwright test "$@"