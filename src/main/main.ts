import { 
  app, 
  BrowserWindow, 
  Menu, 
  Tray, 
  nativeImage, 
  ipcMain, 
  Notification, 
  MenuItemConstructorOptions,
  screen,
  shell 
} from 'electron';
import path from 'path';
import fs from 'fs';
import { checkForPRs } from '../utils/github';
import Store from 'electron-store';

interface StoreSchema {
  token: string;
  repos: string[];
  username: string;
  checkInterval: number;
  pendingPRs: any[];
  notifiedPRs: number[];
  dismissedPRs: number[];
  autoLaunch: boolean;
  settingsPrompted: boolean;
  enableNotifications: boolean;
  devShowSamplePRs: boolean; // For development mode only
  lastQueryTime: number; // Timestamp of the last GitHub API query
}

// Configure store path for tests if environment variable is set
const store = new Store<StoreSchema>({
  cwd: process.env.ELECTRON_STORE_PATH ? path.dirname(process.env.ELECTRON_STORE_PATH) : undefined,
  name: process.env.ELECTRON_STORE_PATH ? path.basename(process.env.ELECTRON_STORE_PATH, '.json') : undefined
});

const schema: StoreSchema = {
  token: '',
  repos: [],
  username: '',
  checkInterval: 15,
  pendingPRs: [],
  notifiedPRs: [],
  dismissedPRs: [],
  autoLaunch: true,
  settingsPrompted: false,
  enableNotifications: true,
  devShowSamplePRs: false, // For development mode only
  lastQueryTime: 0, // Default to 0 (no queries yet)
};

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let trayContextMenu: Menu | null = null;
let isQuitting = false;

// Check interval in minutes
const DEFAULT_CHECK_INTERVAL = 15;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 400,
    height: 500,
    show: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      // Enable smooth scrolling
      enableBlinkFeatures: 'SmoothScrolling',
      // Use frame rate divisor for better performance on Apple Silicon
      backgroundThrottling: false,
    },
    // Make it a proper menu bar dropdown window
    titleBarStyle: process.platform === 'darwin' ? 'customButtonsOnHover' : 'hidden',
    // Enable resize for better scrolling behavior
    resizable: true,
    skipTaskbar: true,
    frame: false,
    transparent: false,
    backgroundColor: '#FFFFFF',
    // Critical for menubar apps - this ensures the window will stay above other windows
    alwaysOnTop: true,
    // Hide from dock and task switcher
    type: process.platform === 'darwin' ? 'panel' : undefined, // Panel only on macOS to prevent scrolling issues
    // Add shadow for better visibility
    hasShadow: true,
    // Add these settings for better menubar app behavior
    fullscreenable: false,
    minimizable: false,
    maximizable: false,
    // This is critical for menubar apps
    focusable: true,
  });

  const htmlPath = path.join(__dirname, '../renderer/index.html');
  console.log('Loading HTML from:', htmlPath);
  
  // Set the preload script
  mainWindow?.webContents.once('dom-ready', () => {
    // Inject custom CSS to fix scrolling issues
    mainWindow?.webContents.insertCSS(`
      ::-webkit-scrollbar {
        width: 10px !important;
        height: 10px !important;
      }
      ::-webkit-scrollbar-thumb {
        background: #888 !important;
        border-radius: 5px !important;
      }
      #scrollable-content {
        -webkit-app-region: no-drag !important;
      }
      .overflow-auto, .overflow-y-auto {
        -webkit-app-region: no-drag !important;
      }
    `);
  });
  
  // Add error handler
  mainWindow?.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
    console.error('Failed to load:', errorCode, errorDescription);
  });
  
  mainWindow?.loadFile(htmlPath);
  
  // Handle window load completion
  mainWindow?.webContents.on('did-finish-load', () => {
    console.log('Window content loaded successfully');
    
    // Only open DevTools in development and not in test mode
    if (process.env.NODE_ENV === 'development' ) {
      mainWindow?.webContents.openDevTools({ mode: 'detach' });
    }
    
    // Add Escape key handler to close the window without beep sound
    if (mainWindow) {
      mainWindow.webContents.on('before-input-event', (event, input) => {
        if (input.type === 'keyDown' && input.key === 'Escape') {
          console.log('Escape key pressed, hiding window');
          event.preventDefault(); // Prevent default behavior (beep sound)
          mainWindow?.hide();
        }
      });
    }
  });
  
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow?.hide();
      return false;
    }
    return true;
  });

  // // Hide the window when it loses focus
  // mainWindow.on('blur', () => {
  //   if (!mainWindow?.webContents.isDevToolsOpened()) {
  //     // Add a small delay to prevent immediate hiding when clicking
  //     setTimeout(() => {
  //       if (mainWindow && mainWindow.isVisible()) {
  //         mainWindow.hide();
  //       }
  //     }, 100);
  //   }
  // });
}

function createTray() {
  console.log('Creating tray icon...');
  
  // Debug path resolution
  console.log('Current __dirname:', __dirname);
  console.log('Current working directory:', process.cwd());
  
  // Instead of a subtle circle, use a more distinct icon with thicker lines
  // This PR icon is more likely to be visible
  const iconData = `
    <svg width="22" height="22" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22">
      <path d="M7,4 L7,14 M7,10 L4,10 L4,14 L7,14 M15,4 L15,14 M15,10 L18,10 L18,14 L15,14 M7,10 L15,10" 
        stroke="black" 
        stroke-width="2.5" 
        fill="none" 
        stroke-linecap="round" 
        stroke-linejoin="round"/>
    </svg>
  `;
  
  const regularIcon = nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(iconData).toString('base64')}`);
  
  // Create a backup icon that will be visible regardless
  const backupIcon = nativeImage.createFromDataURL(`data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAeGVYSWZNTQAqAAAACAAFARIAAwAAAAEAAQAAARoABQAAAAEAAABKARsABQAAAAEAAABSASgAAwAAAAEAAgAAh2kABAAAAAEAAABaAAAAAAAAAEgAAAABAAAASAAAAAEAAqACAAQAAAABAAAAFKADAAQAAAABAAAAFAAAAAAh/bHvAAAACXBIWXMAAAsTAAALEwEAmpwYAAACZmlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyIKICAgICAgICAgICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICAgICA8dGlmZjpSZXNvbHV0aW9uVW5pdD4yPC90aWZmOlJlc29sdXRpb25Vbml0PgogICAgICAgICA8ZXhpZjpQaXhlbFlEaW1lbnNpb24+MjA8L2V4aWY6UGl4ZWxZRGltZW5zaW9uPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MjA8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KFcjjjAAAAmNJREFUOBGtlM9rE1EQx2d3X9LdJE1ME0xJSGnaVNOixYJUC1JQwYMnT+JV/AO86cWTf4AXT568+AdUFCyiVVQQf9BomlTTpNFqmjZtkm6y2d3nfLdpaFbowQeP2feYz3dmvjPvEbXrjV4/tGWATRiOVYoSdbMQPbkNXCNMwKrGcc01HCfqhu3aCbZt18zIWGRra2uLer0ekhRVYrvdiouA53lRo9GIzpVGNP20W6LbH2JMuYPFw01ywjQrqVRK8X3faTQaQSKRIEmSSJIkCgKRHO5AxbFEKkpEJxcK1Fey6dnp9/uUzWa7pmlOYxX/GcNCoRBzHKdDuVxOLhaLe+l0mmRZptXVVYIzfzAwiUK5XKZkMhljUCqVYvCl+Xw+n06n1XQ6TaZpKu1Wmywrpq7W4DKpSH0ZTn9HIR6PO0yPK4oStG3b9TzPsW1bW19fd4vFoiNOULerqioBQQ4byvnM+qNbj1fKLyRPjTGuNZu8BxKa7r/gFUTNJYpQ5YahE+i1mvNzc0/mb86fnfvw7vOlXO78G1WNXzlRoDEE1kZbKNrFJxV+/cYXS03I1Waw++bz+Yvnrn38XNl1oXzx/KjFjC0+3LwXuL7FXdnwADfk7lL/5t70zNT45M25K7MfHz4a7+3tHZyf/zb/9dv3Ry/frlx9+r46Ynd9lkrq4ZcXDwTQ3/Ua2uBxg3jYOD+0BwcH1G639+w3Ht5s4IUmHNR9hg/jEX/SxT6m7EzJYfjvIbPZ+YcSDDjEzb7DwSH+PmRY6P+Hwd/4FWAAoOQ0DBU9VNQAAAAASUVORK5CYII=`);
  
  // For macOS - Template icon (black/transparent only)
  let icon = regularIcon;
  
  if (process.platform === 'darwin') {
    // Set as template image
    icon.setTemplateImage(true);
    console.log('Set as template image');
  }
  
  // Log icon details for debugging
  const size = icon.getSize();
  console.log(`Icon created with size: ${size.width}x${size.height}`);
  
  // Create the tray with our icon
  try {
    // Path to assets relative to the app root, not the build directory
    const iconPath = path.join(__dirname, '../assets', 'tray-icon-template.png');
    console.log('Trying to load icon from:', iconPath);
    
    // Load the PNG file as a native image
    const trayIcon = nativeImage.createFromPath(iconPath);
    
    // Set as template image for macOS
    if (process.platform === 'darwin') {
      trayIcon.setTemplateImage(true);
    }
    
    tray = new Tray(trayIcon);
    console.log('Created tray with regular icon');
  } catch (e) {
    console.error('Failed to create tray with regular icon:', e);
    // If that fails, try with the backup icon
    try {
      tray = new Tray(backupIcon);
      console.log('Created tray with backup icon');
    } catch (e2) {
      console.error('Failed to create tray with backup icon:', e2);
      // Last resort - use a text title as the "icon"
      tray = new Tray(nativeImage.createEmpty());
      tray.setTitle('PR');
      console.log('Created tray with text title fallback');
    }
  }
  
  tray.setToolTip('PR Notifier');
  console.log('Tray icon created successfully!');

  // Initialize the context menu
  updateTrayMenu();
  
  // Restore original behavior: Show/hide window when clicking the tray icon
  // On macOS, left click should toggle the window
  tray.on('click', (event, bounds) => {
    console.log('Tray icon clicked, toggling window');
    toggleWindow(bounds);
  });
  
  // Right click shows the context menu
  tray.on('right-click', (event, bounds) => {
    console.log('Tray icon right-clicked, showing context menu');
    if (trayContextMenu) {
      tray?.popUpContextMenu(trayContextMenu);
    }
  });
}

// Separate function to build the context menu
function buildContextMenu() {
  const pendingPRs = store.get('pendingPRs', []);
  const token = store.get('token', '');
  const repos = store.get('repos', []);
  const username = store.get('username', '');
  const missingSettings = !token || !username || repos.length === 0;
  const showSamplePRs = store.get('devShowSamplePRs', false);
  
  // Log the pending PRs count for debugging
  console.log(`Building context menu with ${pendingPRs.length} pending PRs`);
  
  let menuLabel = '';
  
  if (missingSettings && !showSamplePRs) {
    menuLabel = 'PR Notifier (Setup Required)';
  } else {
    menuLabel = `PR Notifier${pendingPRs.length > 0 ? ` (${pendingPRs.length})` : ''}`;
  }
  
  const template = [
    { 
      label: menuLabel, 
      enabled: false 
    },
    { type: 'separator' },
    { label: 'Open', click: () => {
      // Ensure the window is visible and focused
      if (!mainWindow?.isVisible()) {
        // Get tray bounds for proper positioning
        const trayBounds = tray?.getBounds();
        console.log('Opening window with tray bounds:', trayBounds);
        showWindow(trayBounds);
      } else {
        mainWindow?.focus();
      }
    }},
    { label: 'Check Now', click: async () => {
      const prs = await checkForPRs();
      updateTrayMenu();
    }},
    { type: 'separator' },
    { label: 'Settings', click: () => {
      // Show the window if not already visible
      if (!mainWindow?.isVisible()) {
        // Get tray bounds for proper positioning
        const trayBounds = tray?.getBounds();
        console.log('Opening settings with tray bounds:', trayBounds);
        showWindow(trayBounds);
      }
      // Send message to renderer to show settings tab
      mainWindow?.webContents.send('show-settings');
      mainWindow?.focus();
    }},
    { type: 'separator' },
    { label: 'Quit', click: () => { isQuitting = true; app.quit(); } }
  ];
  
  // Add indicator if in sample mode
  if (showSamplePRs) {
    // Insert after "Check Now"
    template.splice(4, 0, {
      label: '📝 Sample PR Mode Active',
      enabled: false
    });
  }
  
  return Menu.buildFromTemplate(template as MenuItemConstructorOptions[]);
}

export function updateTrayMenu() {
  // Update the tray title/tooltip and rebuild the context menu
  const pendingPRs = store.get('pendingPRs', []);
  const token = store.get('token', '');
  const repos = store.get('repos', []);
  const username = store.get('username', '');
  const missingSettings = !token || !username || repos.length === 0;
  const showSamplePRs = store.get('devShowSamplePRs', false);
  
  // Log current PR count for debugging
  console.log(`Updating tray menu with ${pendingPRs.length} pending PRs`);
  
  // Update the icon badge on macOS
  if (process.platform === 'darwin') {
    if (missingSettings && !showSamplePRs) {
      tray?.setTitle('Setup needed!'); 
    } else if (pendingPRs.length > 0) {
      tray?.setTitle(`${pendingPRs.length} reviews`);
    } else {
      tray?.setTitle('No reviews!');
    }
  } else {
    // On Windows/Linux we might update the icon or tooltip instead
    if (missingSettings && !showSamplePRs) {
      tray?.setToolTip('PR Notifier - Setup needed!');
    } else {
      tray?.setToolTip(`PR Notifier${pendingPRs.length > 0 ? ` (${pendingPRs.length} pending)` : ''}`);
    }
  }
  
  // Rebuild the context menu but don't set it as the default click action
  // This will only be shown on right-click
  if (tray) {
    // Create the context menu with updated counts
    const contextMenu = buildContextMenu();
    
    // Just update the instance variable - we'll use it in the right-click handler
    trayContextMenu = contextMenu;
  }
}

function toggleWindow(trayBounds?: Electron.Rectangle) {
  if (mainWindow?.isVisible()) {
    mainWindow.hide();
  } else {
    showWindow(trayBounds);
  }
}

function showWindow(trayBounds?: Electron.Rectangle) {
  if (!mainWindow) {
    console.error('Cannot show window: mainWindow is null');
    return;
  }
  
  // If no tray bounds provided or they're invalid, try to get them directly
  if (!trayBounds || !trayBounds.width || !trayBounds.height) {
    console.log('No valid tray bounds provided, attempting to get them directly');
    if (tray) {
      trayBounds = tray.getBounds();
      console.log('Retrieved tray bounds directly:', trayBounds);
    }
    
    // If still no valid bounds, center the window
    if (!trayBounds || !trayBounds.width || !trayBounds.height) {
      console.log('Could not get valid tray bounds, centering window');
      mainWindow.center();
      mainWindow.show();
      mainWindow.focus();
      return;
    }
  }
  
  // Position window above the tray icon
  const windowBounds = mainWindow.getBounds();
  
  // Get display that contains the tray icon
  const display = screen.getDisplayNearestPoint({
    x: trayBounds.x,
    y: trayBounds.y
  });
  
  let x = 0;
  let y = 0;
  
  // Platform-specific positioning
  if (process.platform === 'darwin') {
    // macOS: Position window so it appears to drop down from the menu bar
    x = Math.round(trayBounds.x + (trayBounds.width / 2) - (windowBounds.width / 2));
    y = Math.round(trayBounds.y + trayBounds.height);
  } else {
    // Windows/Linux: Position window below the tray icon
    x = Math.round(trayBounds.x + (trayBounds.width / 2) - (windowBounds.width / 2));
    y = Math.round(trayBounds.y + trayBounds.height + 4); // 4px padding
  }
  
  // Correct position if it would go off screen
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  if (x + windowBounds.width > display.bounds.width) {
    x = display.bounds.width - windowBounds.width;
  }
  
  // For macOS menu bar apps
  if (process.platform === 'darwin') {
    // Show the window on the current space without switching spaces
    try {
      mainWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
    } catch (e) {
      console.error('Error setting visible on all workspaces:', e);
    }
  }
  
  console.log(`Showing window at position x:${x}, y:${y}`);
  mainWindow.setPosition(x, y, false);
  mainWindow.show();

  // // Reset workspaces setting after showing
  // if (process.platform === 'darwin') {
  //   setTimeout(() => {
  //     try {
  //       if (mainWindow) {
  //         mainWindow.setVisibleOnAllWorkspaces(false);
  //       }
  //     } catch (e) {
  //       console.error('Error resetting visible on all workspaces:', e);
  //     }
  //   }, 100);
  // }
}

async function startPRChecking() {
  // First check immediately on startup
  checkSettingsAndPRs();
  
  // Setup a function to reschedule the check based on the current interval setting
  const scheduleNextCheck = () => {
    // Get the current interval from settings (might have changed)
    const interval = store.get('checkInterval', DEFAULT_CHECK_INTERVAL);
    console.log(`Scheduling next PR check in ${interval} minutes`);
    
    // Schedule the next check
    setTimeout(() => {
      checkSettingsAndPRs().then(() => {
        // Schedule the next check after this one completes
        scheduleNextCheck();
      });
    }, interval * 60 * 1000);
  };
  
  // Start the scheduling chain
  scheduleNextCheck();
}

async function checkSettingsAndPRs() {
  const token = store.get('token', '');
  const repos = store.get('repos', []);
  const username = store.get('username', '');
  const dismissedPRs = store.get('dismissedPRs', []);
  const devShowSamplePRs = store.get('devShowSamplePRs', false);
  const missingSettings = !token || !username || repos.length === 0;
  
  console.log(`checkSettingsAndPRs called with ${dismissedPRs.length} dismissed PRs, devMode: ${devShowSamplePRs}`);
  
  // Update menu to reflect current state
  updateTrayMenu();
  
  // If in dev mode, we can proceed even with missing settings
  if (!devShowSamplePRs && missingSettings && mainWindow) {
    // Show a notification if window is not already visible
    if (!mainWindow.isVisible()) {
      const notification = new Notification({
        title: 'PR Notifier Setup Required',
        body: 'Please configure your GitHub settings to start monitoring pull requests.',
      });
      
      notification.on('click', () => {
        const trayBounds = tray?.getBounds();
        showWindow(trayBounds);
        mainWindow?.webContents.send('show-settings');
      });
      
      notification.show();
    }
    
    // If this is first run or settings were reset, automatically open settings
    const settingsPrompted = store.get('settingsPrompted', false);
    if (!settingsPrompted) {
      store.set('settingsPrompted', true);
      const trayBounds = tray?.getBounds();
      showWindow(trayBounds);
      mainWindow.webContents.send('show-settings');
    }
    
    // Return empty arrays if settings are missing
    return { activePRs: [], dismissedPRs: [] };
  }
  
  // If settings are configured or in dev mode, check PRs
  const result = await checkForPRs();
  
  // Record the timestamp of this query
  store.set('lastQueryTime', Date.now());
  
  // Make sure to update the tray menu after getting PRs
  updateTrayMenu();
  
  return result;
}

// Enable optimizations for Apple Silicon
app.commandLine.appendSwitch('js-flags', '--expose-gc');
app.commandLine.appendSwitch('enable-features', 'MetalLowPowerMode');
app.commandLine.appendSwitch('use-angle', 'metal');

app.whenReady().then(() => {
  console.log('App is ready, initializing...');
  
  // For macOS menu bar apps, we need to hide from the dock
  if (process.platform === 'darwin') {
    app.dock.hide();
  }
  
  // Set up periodic garbage collection to reduce memory usage
  setInterval(() => {
    if (global.gc) global.gc();
  }, 60000);
  
  // Setup auto-launch for startup
  setupAutoLaunch();
  
  createWindow();
  createTray();
  startPRChecking();

  
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  isQuitting = true;
});

// IPC handlers for renderer process
ipcMain.handle('save-settings', (event, settings) => {
  if (settings.token !== undefined) store.set('token', settings.token);
  if (settings.repos !== undefined) store.set('repos', settings.repos);
  if (settings.username !== undefined) store.set('username', settings.username);
  if (settings.checkInterval !== undefined) store.set('checkInterval', settings.checkInterval);
  if (settings.enableNotifications !== undefined) store.set('enableNotifications', settings.enableNotifications);
  return true;
});

// Add handler for closing/hiding the window from renderer
ipcMain.on('hide-window', () => {
  if (mainWindow?.isVisible()) {
    mainWindow.hide();
  }
});

ipcMain.handle('get-settings', () => {
  return {
    token: store.get('token', ''),
    repos: store.get('repos', []),
    username: store.get('username', ''),
    checkInterval: store.get('checkInterval', DEFAULT_CHECK_INTERVAL),
    pendingPRs: store.get('pendingPRs', []),
    autoLaunch: store.get('autoLaunch', true),
    enableNotifications: store.get('enableNotifications', true),
    devShowSamplePRs: store.get('devShowSamplePRs', false),
    lastQueryTime: store.get('lastQueryTime', 0),
  };
});

ipcMain.handle('check-now', async () => {
  const result = await checkSettingsAndPRs();
  // Make sure to update the tray menu after getting new PRs
  updateTrayMenu();
  return result;
});

// Add this function to handle auto-launch functionality
function setupAutoLaunch() {
  const autoLaunch = store.get('autoLaunch', true);
  
  // App needs to be packaged for this to work
  if (app.isPackaged) {
    app.setLoginItemSettings({
      openAtLogin: autoLaunch,
      // On macOS, this opens the app in the background
      openAsHidden: true
    });
  }
}

// Add this IPC handler for toggling auto-launch
ipcMain.handle('toggle-auto-launch', (event, enabled) => {
  store.set('autoLaunch', enabled);
  
  if (app.isPackaged) {
    app.setLoginItemSettings({
      openAtLogin: enabled,
      openAsHidden: true
    });
  }
  
  return enabled;
});

// Add this IPC handler to get auto-launch status
ipcMain.handle('get-auto-launch', () => {
  return store.get('autoLaunch', true);
});

// Add this IPC handler for dev settings
ipcMain.handle('save-dev-settings', async (event, settings) => {
  if (settings.devShowSamplePRs !== undefined) {
    const previousValue = store.get('devShowSamplePRs', false);
    const newValue = settings.devShowSamplePRs;
    
    console.log(`Changing devShowSamplePRs from ${previousValue} to ${newValue}`);
    
    // Update the setting
    store.set('devShowSamplePRs', newValue);
    
    // When toggling sample mode, we need to clear the dismiss list
    // This ensures clean state transitions between modes
    if (previousValue !== newValue) {
      console.log('Mode changed, refreshing PR data');
      
      // Check for PRs with the new setting
      await checkSettingsAndPRs();
    }
    
    // Immediately update the tray menu to reflect sample mode
    updateTrayMenu();
    
    // Notify the renderer process that settings have changed
    if (mainWindow) {
      mainWindow.webContents.send('settings-updated');
    }
  }
  return true;
});

// Add handler for dismissing a PR
ipcMain.handle('dismiss-pr', (event, prId) => {
  try {
    console.log(`Dismissing PR with ID: ${prId}`);
    
    // Make sure dismissed PR list exists
    const dismissedPRs = store.get('dismissedPRs', []);
    if (!dismissedPRs.includes(prId)) {
      // Add PR to the dismissed list
      store.set('dismissedPRs', [...dismissedPRs, prId]);
      console.log(`Added PR ${prId} to dismissed list, now contains ${dismissedPRs.length + 1} PRs`);
    }
    
    // Get current pending PRs and update them
    const pendingPRs = store.get('pendingPRs', []);
    console.log(`Current pending PRs: ${pendingPRs.length}`);
    
    // Filter out the dismissed PR
    const filteredPRs = pendingPRs.filter(pr => pr.id !== prId);
    console.log(`After filtering, pending PRs: ${filteredPRs.length}`);
    
    // Update store with filtered PRs
    store.set('pendingPRs', filteredPRs);

    // Force update the tray menu with new count
    console.log('Updating tray menu after dismissal');
    updateTrayMenu();
    
    // Reset the title to ensure the count updates on macOS
    if (process.platform === 'darwin' && tray) {
      // We need to get the current active PRs count
      const activePRs = store.get('pendingPRs', []);
      const count = activePRs.length;
      
      if (count > 0) {
        tray.setTitle(`${count} reviews`);
      } else {
        tray.setTitle('No reviews!');
      }
      console.log(`Set tray title to: ${count > 0 ? `${count} reviews` : 'No reviews!'}`);
    }
    
    return true;
  } catch (error) {
    console.error('Error dismissing PR:', error);
    return false;
  }
});

// Add handler for getting dismissed PRs
ipcMain.handle('get-dismissed-prs', () => {
  return store.get('dismissedPRs', []);
});

// Add handler for undismissing a PR
ipcMain.handle('undismiss-pr', (event, prId) => {
  try {
    console.log(`Undismissing PR with ID: ${prId}`);
    
    // Get current dismissed PRs 
    const dismissedPRs = store.get('dismissedPRs', []);
    
    // Filter out the undismissed PR
    const updatedDismissedPRs = dismissedPRs.filter(id => id !== prId);
    
    console.log(`Removed PR ${prId} from dismissed list, now contains ${updatedDismissedPRs.length} PRs (was ${dismissedPRs.length})`);
    
    // Update the store with the new list
    store.set('dismissedPRs', updatedDismissedPRs);
    
    // We need to find this PR in the result from checkForPRs and add it back to pendingPRs
    // For dev mode, this will automatically be handled on next refresh via the mock data
    // Just trigger a refresh to make sure everything is up-to-date
    checkSettingsAndPRs().then(() => {
      // Update the tray menu
      updateTrayMenu();
      
      console.log('Refreshed PRs after undismissing');
    });
    
    return true;
  } catch (error) {
    console.error('Error undismissing PR:', error);
    return false;
  }
});