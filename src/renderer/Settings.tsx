import React, { useState, useEffect } from 'react';
import { ipcRenderer } from 'electron';

interface SettingsProps {
  onSave: () => void;
}

const Settings: React.FC<SettingsProps> = ({ onSave }) => {
  const [token, setToken] = useState('');
  const [username, setUsername] = useState('');
  const [repos, setRepos] = useState<string[]>([]);
  const [newRepo, setNewRepo] = useState('');
  const [checkInterval, setCheckInterval] = useState(15);
  const [isSaving, setIsSaving] = useState(false);
  const [missingSettings, setMissingSettings] = useState(false);
  const [autoLaunch, setAutoLaunch] = useState(true);
  const [enableNotifications, setEnableNotifications] = useState(true);
  const [showDevOptions, setShowDevOptions] = useState(false);
  const [showSamplePRs, setShowSamplePRs] = useState(false);
  const isDev = process.env.NODE_ENV === 'development' || true; // Force true for demo purposes
  
  useEffect(() => {
    loadSettings();
    
    // Check if we should show sample PRs based on stored setting
    if (isDev) {
      setShowDevOptions(true);
      // We'll load the actual value from settings below
    }
  }, []);
  
  const loadSettings = async () => {
    try {
      const settings = await ipcRenderer.invoke('get-settings');
      const token = settings.token || '';
      const username = settings.username || '';
      const repoList = settings.repos || [];
      const autoLaunchSetting = settings.autoLaunch !== undefined ? settings.autoLaunch : true;
      const enableNotificationsSetting = settings.enableNotifications !== undefined ? settings.enableNotifications : true;
      const devShowSamplePRsSetting = settings.devShowSamplePRs !== undefined ? settings.devShowSamplePRs : false;
      
      setToken(token);
      setUsername(username);
      setRepos(repoList);
      setCheckInterval(settings.checkInterval || 15);
      setAutoLaunch(autoLaunchSetting);
      setEnableNotifications(enableNotificationsSetting);
      setShowSamplePRs(devShowSamplePRsSetting);
      
      // Check if settings are missing
      const missing = !token || !username || repoList.length === 0;
      setMissingSettings(missing);
    } catch (error) {
      console.error('Error loading settings:', error);
    }
  };
  
  const handleAddRepo = () => {
    if (newRepo && !repos.includes(newRepo)) {
      setRepos([...repos, newRepo]);
      setNewRepo('');
    }
  };
  
  const handleRemoveRepo = (repo: string) => {
    setRepos(repos.filter(r => r !== repo));
  };
  
  const handleSave = async () => {
    setIsSaving(true);
    try {
      await ipcRenderer.invoke('save-settings', {
        token,
        username,
        repos,
        checkInterval,
        autoLaunch,
        enableNotifications,
      });
      
      // Update missing settings status
      const missing = !token || !username || repos.length === 0;
      setMissingSettings(missing);
      
      // Update auto launch setting
      await ipcRenderer.invoke('toggle-auto-launch', autoLaunch);
      
      // For development mode, save the sample PRs setting
      if (isDev) {
        await ipcRenderer.invoke('save-dev-settings', {
          devShowSamplePRs: showSamplePRs
        });
        console.log(`Set devShowSamplePRs to ${showSamplePRs}`);
      }
      
      onSave();
    } catch (error) {
      console.error('Error saving settings:', error);
    } finally {
      setIsSaving(false);
    }
  };
  
  return (
    <div>
      <h2 className="text-xl font-bold mb-6">Settings</h2>
      
      {missingSettings && (
        <div className="mb-6 p-4 bg-yellow-50 border border-yellow-200 rounded-md">
          <p className="text-yellow-700 font-medium">⚠️ Setup required</p>
          <p className="text-sm text-yellow-600 mt-1">Please configure your GitHub settings to start monitoring pull requests.</p>
        </div>
      )}
      
      <div className="mb-7">
        <label className="block mb-2 font-semibold text-sm text-gray-700" htmlFor="token">
          GitHub Personal Access Token
        </label>
        <input
          id="token"
          type="password"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="ghp_xxxxxxxxxxxx"
          className="w-full px-3 py-2.5 rounded-md border border-gray-200 mb-3 text-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none bg-gray-50"
        />
        <p className="text-xs text-gray-500">Create a token with 'repo' scope at GitHub Developer Settings</p>
      </div>
      
      <div className="mb-7">
        <label className="block mb-2 font-semibold text-sm text-gray-700" htmlFor="username">
          GitHub Username
        </label>
        <input
          id="username"
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Your GitHub username"
          className="w-full px-3 py-2.5 rounded-md border border-gray-200 mb-3 text-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none bg-gray-50"
        />
      </div>
      
      <div className="mb-7">
        <label className="block mb-2 font-semibold text-sm text-gray-700">
          Repositories to Monitor
        </label>
        <div className="flex gap-2 mb-3">
          <input
            type="text"
            value={newRepo}
            onChange={(e) => setNewRepo(e.target.value)}
            placeholder="owner/repo (e.g. facebook/react)"
            className="flex-1 px-3 py-2.5 rounded-md border border-gray-200 text-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none bg-gray-50"
          />
          <button 
            className="px-4 py-2 bg-blue-500 hover:bg-blue-600 active:bg-blue-700 text-white border-none rounded-md cursor-pointer font-medium transition-colors"
            onClick={handleAddRepo}
          >
            Add
          </button>
        </div>
        
        <div className="max-h-44 overflow-y-auto border border-gray-200 p-3 mt-3 rounded-md bg-gray-50">
          {repos.length === 0 ? (
            <p className="text-center py-5 text-gray-500 italic">No repositories added yet</p>
          ) : (
            repos.map((repo) => (
              <div key={repo} className="flex justify-between items-center px-3 py-2.5 border-b border-gray-200 rounded mb-2 bg-white hover:bg-blue-50 transition-colors">
                <span className="text-sm">{repo}</span>
                <button 
                  className="px-2 py-1 bg-red-400 hover:bg-red-500 text-white border-none rounded-md cursor-pointer text-xs transition-colors"
                  onClick={() => handleRemoveRepo(repo)}
                >
                  Remove
                </button>
              </div>
            ))
          )}
        </div>
      </div>
      
      <div className="mb-7">
        <label className="block mb-2 font-semibold text-sm text-gray-700" htmlFor="interval">
          Check Interval (minutes)
        </label>
        <input
          id="interval"
          type="number"
          min="1"
          max="60"
          value={checkInterval}
          onChange={(e) => setCheckInterval(parseInt(e.target.value, 10))}
          className="w-24 px-3 py-2.5 rounded-md border border-gray-200 text-sm bg-gray-50"
        />
      </div>
      
      <div className="mb-7">
        <div className="flex items-center">
          <input
            id="enableNotifications"
            type="checkbox"
            checked={enableNotifications}
            onChange={(e) => setEnableNotifications(e.target.checked)}
            className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
          />
          <label htmlFor="enableNotifications" className="ml-2 text-sm font-medium text-gray-700">
            Enable notifications for new PRs
          </label>
        </div>
      </div>
      
      {/* Development options */}
      {showDevOptions && (
        <div className="mb-7 p-4 bg-gray-100 border border-gray-200 rounded-md">
          <h3 className="text-md font-semibold mb-3 text-gray-700">Developer Options</h3>
          <div className="flex items-center">
            <input
              id="showSamplePRs"
              type="checkbox"
              checked={showSamplePRs}
              onChange={async (e) => {
                const newValue = e.target.checked;
                setShowSamplePRs(newValue);
                
                // Save the setting immediately and refresh
                try {
                  await ipcRenderer.invoke('save-dev-settings', {
                    devShowSamplePRs: newValue
                  });
                  
                  console.log(`Set devShowSamplePRs to ${newValue} and refreshing...`);
                  
                  // Trigger a refresh immediately
                  onSave();
                } catch (error) {
                  console.error('Error updating sample PR mode:', error);
                }
              }}
              className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
            />
            <label htmlFor="showSamplePRs" className="ml-2 text-sm font-medium text-gray-700">
              Show sample PRs (for UI testing)
            </label>
          </div>
          {showSamplePRs && (
            <div className="mt-3 p-2 bg-blue-50 border border-blue-100 rounded text-sm text-blue-700">
              <p className="font-medium">Sample PR mode is active</p>
              <p className="text-xs mt-1">Real GitHub PRs will not be checked. Changes take effect immediately.</p>
            </div>
          )}
        </div>
      )}
      
      <button 
        className={`px-5 py-3 mt-5 bg-green-600 text-white border-none rounded-md cursor-pointer font-semibold text-base transition-all hover:bg-green-700 active:scale-98 ${
          isSaving ? 'bg-green-300 cursor-not-allowed' : ''
        }`}
        onClick={handleSave}
        disabled={isSaving}
      >
        {isSaving ? 'Saving...' : 'Save Settings'}
      </button>
    </div>
  );
};

export default Settings;