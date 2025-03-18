import { test, expect, _electron as electron } from '@playwright/test';
import path from 'path';
import fs from 'fs';

// Store setup for tests
const setupTestStore = () => {
  // Make sure the tmp directory exists
  const storeDir = path.join(process.cwd(), 'tests/tmp');
  if (!fs.existsSync(storeDir)) {
    fs.mkdirSync(storeDir, { recursive: true });
  }
  
  // Write test data
  const testData = {
    token: 'test-token',
    username: 'test-user',
    repos: ['test-org/test-repo'],
    showNotifications: true,
    lastQueryTime: Date.now(),
    pendingPRs: [
      {
        id: 1,
        number: 101,
        title: 'Add new feature',
        html_url: 'https://github.com/test-org/test-repo/pull/101',
        repo: 'test-org/test-repo'
      },
      {
        id: 2,
        number: 102,
        title: 'Fix bug in login flow',
        html_url: 'https://github.com/test-org/test-repo/pull/102',
        repo: 'test-org/test-repo'
      }
    ],
    dismissedPRs: []
  };
  
  // Write to file
  const storePath = path.join(storeDir, 'test-store.json');
  fs.writeFileSync(storePath, JSON.stringify(testData, null, 2));
  
  return storePath;
};

// Using Playwright's Electron testing (no fixture injection)
test.describe('PR List Screen', () => {
  let electronApp;
  let storePath;
  
  test.beforeAll(async () => {
    // Setup test store
    storePath = setupTestStore();
    console.log(`Test store created at: ${storePath}`);
  });
  
  test.beforeEach(async () => {
    // Launch Electron app directly using Playwright's API
    console.log('Launching Electron app...');
    
    // Directly follows Playwright's Electron testing docs
    electronApp = await electron.launch({
      args: ['dist/main/index.js'],
      env: {
        NODE_ENV: 'test',
        ELECTRON_STORE_PATH: storePath
      }
    });
  });
  
  test.afterEach(async () => {
    // Close app after each test
    if (electronApp) {
      await electronApp.close();
    }
  });
  
  test('should display PRs that need review', async () => {
    // Get the first window that the app opens
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    
    console.log('Window loaded, looking for PR list elements');
    
    // Wait for the PR list to load with longer timeout
    await window.waitForSelector('text=PRs Waiting for Review', { timeout: 15000 });
    
    // Check that our test PR data is displayed
    await expect(window.locator('text=Add new feature')).toBeVisible({ timeout: 10000 });
    await expect(window.locator('text=Fix bug in login flow')).toBeVisible({ timeout: 10000 });
    
    // Check for repository name
    await expect(window.locator('text=test-org/test-repo')).toBeVisible();
    
    // Check for action buttons
    await expect(window.locator('button:has-text("View on GitHub")')).toBeVisible();
    await expect(window.locator('button:has-text("Dismiss")')).toBeVisible();
  });
});