# Testing Error Handling in PR Notifier

## Test Scenarios

### 1. Test Invalid GitHub Token
1. Open the app settings
2. Enter an invalid GitHub token (e.g., "invalid-token-123")
3. Add a valid repository (e.g., "facebook/react")
4. Click "Check Now"
5. **Expected**: 
   - Error notification appears: "GitHub authentication failed. Please check your token."
   - Tray icon shows "⚠️ Error" 
   - Context menu shows error details
   - UI shows error banner with "Go to Settings" link

### 2. Test Network Connection Error
1. Disconnect from the internet or block GitHub API access
2. Click "Check Now"
3. **Expected**:
   - Error notification: "Network error: Unable to connect to GitHub. Please check your internet connection."
   - Tray icon shows "⚠️ Error"
   - UI shows network error banner

### 3. Test Invalid Repository
1. Add a non-existent repository (e.g., "fake-user/fake-repo")
2. Click "Check Now"
3. **Expected**:
   - Error shown for the specific repository: "Repository fake-user/fake-repo not found or you don't have access."
   - Other valid repositories should still be checked

### 4. Test Missing Configuration
1. Clear all settings (remove token, username, and repositories)
2. Restart the app
3. **Expected**:
   - Error notification: "Please configure your GitHub settings"
   - Tray shows "Setup needed!"
   - UI prompts to configure settings

### 5. Test Error Recovery
1. Cause an error (e.g., invalid token)
2. Fix the issue (enter valid token)
3. Click "Check Now"
4. **Expected**:
   - Error state clears
   - Tray icon returns to normal state
   - UI error banner disappears
   - PRs are displayed normally

## Manual Testing Steps

To manually test these scenarios:

1. **Build and run the app in development mode**:
   ```bash
   npm run dev
   ```

2. **For invalid token test**:
   - Go to Settings
   - Enter: `ghp_invalidtoken123456789`
   - Add your username
   - Add a real repository like `facebook/react`
   - Click "Check Now"

3. **For network error test**:
   - Turn off WiFi or disconnect ethernet
   - Click "Check Now"

4. **Monitor the console** for error logs that show the error handling in action

## Automated Test Considerations

The existing Playwright tests can be extended to cover error scenarios by:
1. Mocking GitHub API responses to return errors
2. Checking for error UI elements
3. Verifying error notifications appear