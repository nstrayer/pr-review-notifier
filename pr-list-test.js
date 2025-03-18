// Direct Electron test launcher for PR list
const { _electron: electron } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

async function setupTestStore() {
  // Make sure the tmp directory exists
  const storeDir = path.join(process.cwd(), 'tests/tmp');
  if (!fs.existsSync(storeDir)) {
    fs.mkdirSync(storeDir, { recursive: true });
  }
  
  // Create test data
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
  
  // Write to test store file
  const storePath = path.join(storeDir, 'test-store.json');
  fs.writeFileSync(storePath, JSON.stringify(testData, null, 2));
  
  return storePath;
}

async function testPRList() {
  try {
    console.log('Starting PR list test');
    
    // Setup test store
    const storePath = await setupTestStore();
    console.log(`Created test store at: ${storePath}`);
    
    // Get app path
    const appPath = path.join(process.cwd(), 'dist/main/index.js');
    console.log(`App path: ${appPath}`);
    
    if (!fs.existsSync(appPath)) {
      console.error(`App entry point not found: ${appPath}`);
      console.log('Did you run npm run build?');
      return { success: false, error: 'App not built' };
    }
    
    // Launch the app
    console.log('Launching Electron app...');
    const electronApp = await electron.launch({
      args: [appPath],
      env: {
        NODE_ENV: 'test',
        ELECTRON_IS_DEV: '1',
        ELECTRON_STORE_PATH: storePath
      },
      timeout: 30000 // 30 seconds timeout
    });
    
    console.log('App launched, waiting for window...');
    
    // Wait for the window to appear
    const window = await electronApp.firstWindow({ timeout: 10000 });
    console.log('Window appeared, waiting for it to load...');
    
    // Wait for the window to load
    await window.waitForLoadState('domcontentloaded', { timeout: 10000 });
    console.log('Window loaded, checking for PR list...');
    
    // Look for the PR list heading
    try {
      // Try to find the PR list heading
      const prListSelector = 'text=PRs Waiting for Review';
      console.log(`Looking for selector: ${prListSelector}`);
      
      // Wait for the selector to appear
      await window.waitForSelector(prListSelector, { timeout: 15000 });
      console.log('Found PR list heading!');
      
      // Check for PR titles
      const featurePR = await window.locator('text=Add new feature').isVisible();
      const bugPR = await window.locator('text=Fix bug in login flow').isVisible();
      
      console.log('PR "Add new feature" visible:', featurePR);
      console.log('PR "Fix bug in login flow" visible:', bugPR);
      
      const success = featurePR && bugPR;
      
      // Take a screenshot if the elements are visible
      if (success) {
        const screenshotPath = path.join(process.cwd(), 'tests/tmp/pr-list-test.png');
        await window.screenshot({ path: screenshotPath });
        console.log(`Screenshot saved to: ${screenshotPath}`);
      }
      
      // Close the app
      await electronApp.close();
      console.log('App closed');
      
      return { success, prListFound: true };
    } catch (error) {
      console.error('Error finding PR list elements:', error);
      
      // Try to take a screenshot anyway
      try {
        const screenshotPath = path.join(process.cwd(), 'tests/tmp/pr-list-error.png');
        await window.screenshot({ path: screenshotPath });
        console.log(`Error screenshot saved to: ${screenshotPath}`);
      } catch (screenshotError) {
        console.error('Could not take screenshot:', screenshotError);
      }
      
      // Close the app
      await electronApp.close();
      console.log('App closed after error');
      
      return { success: false, prListFound: false, error };
    }
  } catch (error) {
    console.error('Test failed with error:', error);
    return { success: false, error };
  }
}

// Run the test
testPRList()
  .then(result => {
    console.log('\n--- Test Results ---');
    console.log('Success:', result.success);
    if (result.prListFound) {
      console.log('PR list found and displayed correctly.');
    }
    
    if (!result.success && result.error) {
      console.log('Error details:', result.error.message || result.error);
    }
    
    process.exit(result.success ? 0 : 1);
  })
  .catch(err => {
    console.error('Unexpected error running test:', err);
    process.exit(1);
  });