import { _electron as electron } from '@playwright/test';
import type { ElectronApplication, Page, ElementHandle } from '@playwright/test';
import path from 'path';
import * as fs from 'fs';

export class AppHelper {
  private app: ElectronApplication | null = null;
  
  async launch(): Promise<ElectronApplication> {
    // Get absolute path to the Electron app
    const appPath = path.resolve(process.cwd());
    
    // Launch Electron app based on Playwright docs
    console.log(`Launching electron from directory: ${appPath}`);
    
    try {
      // Launch method directly from Playwright docs
      this.app = await electron.launch({
        args: ['dist/main/index.js'],
        env: {
          ...process.env,
          NODE_ENV: 'test',
          ELECTRON_STORE_PATH: path.join(process.cwd(), 'tests/tmp/test-store.json'),
        },
        timeout: 30000 // 30 seconds timeout
      });
    } catch (error) {
      console.error('Failed to launch electron app:', error);
      throw error;
    }
    
    return this.app;
  }
  
  async getMainWindow(): Promise<Page> {
    if (!this.app) {
      throw new Error('App not launched. Call launch() first.');
    }
    
    try {
      // Wait for the first window to be created with timeout
      const window = await this.app.firstWindow({ timeout: 15000 });
      
      // Ensure window is loaded
      await window.waitForLoadState('domcontentloaded', { timeout: 15000 });
      
      // Add small delay to ensure React has time to render
      await window.waitForTimeout(1000);
      
      return window;
    } catch (error) {
      console.error('Failed to get main window:', error);
      throw error;
    }
  }
  
  async close(): Promise<void> {
    if (this.app) {
      await this.app.close();
      this.app = null;
    }
  }
}