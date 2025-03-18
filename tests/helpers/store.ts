import path from 'path';
import fs from 'fs';
import os from 'os';

export const testSettings = {
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

export class StoreHelper {
  private storePath: string;
  private storeDir: string;
  
  constructor() {
    // Create a test-specific store path 
    this.storeDir = path.join(process.cwd(), 'tests/tmp');
    this.storePath = path.join(this.storeDir, 'test-store.json');
  }
  
  initStore(): void {
    // Create the directory if it doesn't exist
    if (!fs.existsSync(this.storeDir)) {
      fs.mkdirSync(this.storeDir, { recursive: true });
    }
    
    // Write test settings to the store file
    fs.writeFileSync(this.storePath, JSON.stringify(testSettings, null, 2));
    
    // Set environment variables to point electron-store to our test store
    process.env.ELECTRON_STORE_PATH = this.storePath;
    console.log(`Initialized test store at ${this.storePath}`);
  }
  
  cleanStore(): void {
    // Clean up after tests
    if (fs.existsSync(this.storePath)) {
      fs.unlinkSync(this.storePath);
      console.log(`Cleaned up test store at ${this.storePath}`);
    }
  }
}