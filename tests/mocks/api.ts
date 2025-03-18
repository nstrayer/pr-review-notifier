import { ipcMain } from 'electron';
import { mockPullRequests } from './github';

// Mock IPC handlers for tests
export function setupMockIpcHandlers() {
  // Clear any existing handlers
  ipcMain.removeHandler('get-settings');
  ipcMain.removeHandler('check-now');
  ipcMain.removeHandler('dismiss-pr');
  ipcMain.removeHandler('undismiss-pr');
  
  // Mock settings
  ipcMain.handle('get-settings', () => {
    return {
      token: 'test-token',
      username: 'test-user',
      repos: ['test-org/test-repo'],
      showNotifications: true,
      lastQueryTime: Date.now(),
      pendingPRs: mockPullRequests,
      dismissedPRs: []
    };
  });

  // Mock check-now handler
  ipcMain.handle('check-now', () => {
    return {
      activePRs: mockPullRequests,
      dismissedPRs: []
    };
  });

  // Mock dismiss-pr handler
  let dismissedPRIds: number[] = [];
  ipcMain.handle('dismiss-pr', (event, prId) => {
    dismissedPRIds.push(prId);
    return true;
  });

  // Mock undismiss-pr handler
  ipcMain.handle('undismiss-pr', (event, prId) => {
    dismissedPRIds = dismissedPRIds.filter(id => id !== prId);
    return true;
  });
}