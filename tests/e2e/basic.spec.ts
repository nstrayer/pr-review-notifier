import { test, expect, _electron as electron } from '@playwright/test';
import path from 'path';
import fs from 'fs';

test('can launch app', async () => {
  // Setup custom app location
  const appPath = path.join(process.cwd(), 'dist/main/index.js');
  console.log(`App path: ${appPath}`);
  
  // Check if file exists
  if (!fs.existsSync(appPath)) {
    throw new Error(`App path does not exist: ${appPath}`);
  }
  
  // Launch Electron app
  const electronApp = await electron.launch({
    args: [appPath]
  });
  
  // Verify app is running
  const isPackaged = await electronApp.evaluate(async ({ app }) => {
    return app.isPackaged;
  });
  
  console.log(`App isPackaged: ${isPackaged}`);
  
  // Get app window count
  const windowCount = electronApp.windows().length;
  console.log(`App window count: ${windowCount}`);
  
  // Close the app
  await electronApp.close();
  
  // Verification
  expect(windowCount).toBeGreaterThan(0);
});