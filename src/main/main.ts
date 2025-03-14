import { app, BrowserWindow, Menu, Tray, nativeImage, ipcMain } from 'electron';
import path from 'path';
import { checkForPRs } from '../utils/github';
import Store from 'electron-store';

interface StoreSchema {
  token: string;
  repos: string[];
  username: string;
  checkInterval: number;
  pendingPRs: any[];
  notifiedPRs: number[];
  autoLaunch: boolean;
}

const store = new Store<StoreSchema>();

const schema: StoreSchema = {
  token: '',
  repos: [],
  username: '',
  checkInterval: 15,
  pendingPRs: [],
  notifiedPRs: [],
  autoLaunch: true,
};

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
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
    },
    // Make it a proper menu bar dropdown window
    titleBarStyle: process.platform === 'darwin' ? 'customButtonsOnHover' : 'hidden',
    resizable: false,
    skipTaskbar: true,
    frame: false,
    transparent: false,
    backgroundColor: '#FFFFFF',
    // Critical for menubar apps - this ensures the window will stay above other windows
    alwaysOnTop: true,
    // Hide from dock and task switcher
    type: 'panel', // Important for macOS to keep it from showing in the dock
    // Add shadow for better visibility
    hasShadow: true,
  });

  const htmlPath = path.join(__dirname, '../renderer/index.html');
  console.log('Loading HTML from:', htmlPath);
  
  // Add error handler
  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
    console.error('Failed to load:', errorCode, errorDescription);
  });
  
  mainWindow.loadFile(htmlPath);
  
  // Handle window load completion
  mainWindow.webContents.on('did-finish-load', () => {
    console.log('Window content loaded successfully');
    
    // Only open DevTools in development
    if (process.env.NODE_ENV === 'development') {
      mainWindow?.webContents.openDevTools({ mode: 'detach' });
    }
    
    // Add Escape key handler to close the window
    if (mainWindow) {
      mainWindow.webContents.on('before-input-event', (event, input) => {
        if (input.type === 'keyDown' && input.key === 'Escape') {
          console.log('Escape key pressed, hiding window');
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

  // Hide the window when it loses focus
  mainWindow.on('blur', () => {
    if (!mainWindow?.webContents.isDevToolsOpened()) {
      mainWindow?.hide();
    }
  });
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
    tray = new Tray(path.join(__dirname, "./assets/tray-icon-template.png"));
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

  // Create the context menu but don't set it as the default
  updateTrayMenu();
  
  // Important: Set the context menu to null to prevent automatic popup
  // This ensures only explicit right-clicks will show the menu
  tray.setContextMenu(null);
  
  // Restore original behavior: Show/hide window when clicking the tray icon
  if (process.platform === 'darwin') {
    // On macOS, left click should toggle the window
    tray.on('click', (event, bounds) => {
      console.log('Tray icon clicked, toggling window');
      toggleWindow(bounds);
    });
  } else {
    // Windows and Linux might behave differently, but we'll use the same behavior
    tray.on('click', (event, bounds) => {
      console.log('Tray icon clicked, toggling window');
      toggleWindow(bounds);
    });
  }
  
  // Right click still shows context menu on all platforms
  tray.on('right-click', (event, bounds) => {
    console.log('Tray icon right-clicked, showing context menu');
    const contextMenu = buildContextMenu();
    tray?.popUpContextMenu(contextMenu);
  });
}

// Separate function to build the context menu
function buildContextMenu() {
  const pendingPRs = store.get('pendingPRs', []);
  return Menu.buildFromTemplate([
    { 
      label: `PR Notifier${pendingPRs.length > 0 ? ` (${pendingPRs.length})` : ''}`, 
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
  ]);
}

function updateTrayMenu() {
  // Update the tray title/tooltip, but don't set the context menu
  // This prevents the menu from showing automatically
  const pendingPRs = store.get('pendingPRs', []);
  
  // Update the icon badge on macOS
  if (process.platform === 'darwin') {
    // Set a visible text label in the menu bar for macOS - this ensures something is visible
    if (pendingPRs.length > 0) {
      // Show count with PR prefix
      tray?.setTitle(`PR: ${pendingPRs.length}`);
    } else {
      // Show a short text instead of an empty string to ensure visibility
      tray?.setTitle('PR');
    }
  } else {
    // On Windows/Linux we might update the icon or tooltip instead
    tray?.setToolTip(`PR Notifier${pendingPRs.length > 0 ? ` (${pendingPRs.length} pending)` : ''}`);
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
  const { screen } = require('electron');
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
  mainWindow.focus();
  
  // Reset workspaces setting after showing
  if (process.platform === 'darwin') {
    setTimeout(() => {
      try {
        if (mainWindow) {
          mainWindow.setVisibleOnAllWorkspaces(false);
        }
      } catch (e) {
        console.error('Error resetting visible on all workspaces:', e);
      }
    }, 100); // Short delay to ensure window is visible before changing setting
  }
}

async function startPRChecking() {
  let interval = store.get('checkInterval', DEFAULT_CHECK_INTERVAL);
  
  // First check immediately on startup
  const prs = await checkForPRs();
  updateTrayMenu();
  
  // Then check periodically
  setInterval(async () => {
    await checkForPRs();
    updateTrayMenu();
  }, interval * 60 * 1000);
}

app.whenReady().then(() => {
  console.log('App is ready, initializing...');
  
  // For macOS menu bar apps, we need to hide from the dock
  if (process.platform === 'darwin') {
    app.dock.hide();
  }
  
  // Setup auto-launch for startup
  setupAutoLaunch();
  
  createWindow();
  createTray();
  startPRChecking();
  
  // Force a window show during development to make debugging easier
  if (process.env.NODE_ENV === 'development') {
    setTimeout(() => {
      if (mainWindow) {
        console.log('Showing window for development mode');
        mainWindow.webContents.openDevTools({ mode: 'detach' });
        // Note: We're not showing the window by default anymore, even in dev mode
        // To see it, you'll need to click the tray icon
      }
    }, 1000);
  }
  
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
  return true;
});

ipcMain.handle('get-settings', () => {
  return {
    token: store.get('token', ''),
    repos: store.get('repos', []),
    username: store.get('username', ''),
    checkInterval: store.get('checkInterval', DEFAULT_CHECK_INTERVAL),
    pendingPRs: store.get('pendingPRs', []),
    autoLaunch: store.get('autoLaunch', true),
  };
});

ipcMain.handle('check-now', async () => {
  const prs = await checkForPRs();
  updateTrayMenu(); // Update the tray menu to reflect new PR count
  return prs;
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