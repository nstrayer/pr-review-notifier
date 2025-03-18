import React, { useState, useEffect } from 'react';
import { ipcRenderer } from 'electron';
import Settings from './Settings';
import PRList from './PRList';
import { formatDistanceToNow } from 'date-fns';

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
}

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'prs' | 'settings'>('prs');
  const [activePRs, setActivePRs] = useState<PR[]>([]);
  const [dismissedPRs, setDismissedPRs] = useState<PR[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [lastQueryTime, setLastQueryTime] = useState<number>(0);

  useEffect(() => {
    // Load PRs from store on startup
    const loadPRs = async () => {
      try {
        const settings = await ipcRenderer.invoke('get-settings');
        
        // Load pending PRs from store
        if (settings && settings.pendingPRs) {
          setActivePRs(settings.pendingPRs);
        }
        
        // Load last query time
        if (settings && settings.lastQueryTime) {
          setLastQueryTime(settings.lastQueryTime);
        }
        
        // Check if settings are incomplete and switch to settings tab if needed
        const missingSettings = !settings.token || !settings.username || settings.repos.length === 0;
        if (missingSettings) {
          setActiveTab('settings');
        }
      } catch (error) {
        console.error('Error loading PRs:', error);
      }
    };
    
    loadPRs();
    // Check for PRs
    handleRefresh();
    
    // Set up a listener for settings changes
    ipcRenderer.on('settings-updated', () => {
      console.log('Settings updated, refreshing...');
      handleRefresh();
    });
    
    // Listen for 'show-settings' event from main process
    ipcRenderer.on('show-settings', () => {
      setActiveTab('settings');
    });
    
    // Add Escape key handler to prevent beep and close window
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault(); // Prevent default browser beep
        ipcRenderer.send('hide-window');
      }
    };
    
    window.addEventListener('keydown', handleKeyDown);
    
    return () => {
      ipcRenderer.removeAllListeners('show-settings');
      ipcRenderer.removeAllListeners('settings-updated');
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

  const handleRefresh = async () => {
    setIsLoading(true);
    try {
      // Get settings first to check if they're configured
      const settings = await ipcRenderer.invoke('get-settings');
      const missingSettings = !settings.token || !settings.username || settings.repos.length === 0;
      
      // If settings are missing, switch to settings tab
      if (missingSettings) {
        setActiveTab('settings');
      }
      
      // Get PRs from GitHub (or mocked PRs in dev mode)
      const result = await ipcRenderer.invoke('check-now');
      
      // Update last query time
      const updatedSettings = await ipcRenderer.invoke('get-settings');
      setLastQueryTime(updatedSettings.lastQueryTime);
      
      // Set the active and dismissed PRs in local state
      console.log(`Received ${result.activePRs.length} active PRs and ${result.dismissedPRs.length} dismissed PRs`);
      setActivePRs(result.activePRs);
      setDismissedPRs(result.dismissedPRs);
    } catch (error) {
      console.error('Error refreshing PRs:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full rounded-xl overflow-hidden shadow-lg bg-white">
      <header className="px-4 py-4 border-b border-gray-200 flex justify-between items-center bg-white">
        <div className="flex items-center">
          <h1 className="m-0 text-lg font-bold text-gray-800">PR Notifier</h1>
        </div>
        <div className="flex items-center gap-2">
          {activeTab === 'prs' && (
            <button 
              className={`px-3 py-1.5 text-sm bg-blue-500 hover:bg-blue-600 text-white border-none rounded-md cursor-pointer font-medium transition-colors ${isLoading ? 'bg-gray-500 cursor-not-allowed' : ''}`}
              onClick={handleRefresh}
              disabled={isLoading}
            >
              {isLoading ? 'Checking...' : 'Check Now'}
            </button>
          )}
          <button 
            className="p-1.5 text-gray-400 hover:text-gray-600 bg-transparent border-none rounded-md cursor-pointer transition-colors"
            onClick={() => ipcRenderer.send('hide-window')}
            title="Close"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      </header>
      
      <div className="flex border-b border-gray-200 bg-white">
        <button 
          className={`px-4 py-3 cursor-pointer bg-transparent border-none border-b-2 text-sm transition-all ${
            activeTab === 'prs' 
              ? 'border-blue-500 font-semibold text-gray-800' 
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => setActiveTab('prs')}
        >
          Pull Requests {activePRs.length > 0 && `(${activePRs.length})`}
        </button>
        <button 
          className={`px-4 py-3 cursor-pointer bg-transparent border-none border-b-2 text-sm transition-all ${
            activeTab === 'settings' 
              ? 'border-blue-500 font-semibold text-gray-800' 
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
          onClick={() => setActiveTab('settings')}
        >
          Settings
        </button>
      </div>
      
      <div className="flex-1 p-5 overflow-auto bg-white" id="scrollable-content">
        {activeTab === 'prs' ? (
          <div>
            {/* Last Query Indicator */}
            {lastQueryTime > 0 && (
              <div className="mb-4 text-xs text-gray-500 italic text-right">
                Last checked: {formatDistanceToNow(lastQueryTime, { addSuffix: true })}
              </div>
            )}
            
            {/* Active PRs */}
            <PRList 
              prs={activePRs} 
              title="PRs Waiting for Review"
              onDismiss={async (prId) => {
                try {
                  console.log(`Dismissing PR with ID: ${prId}`);
                  const success = await ipcRenderer.invoke('dismiss-pr', prId);
                  
                  if (success) {
                    console.log('PR dismissed successfully');
                    
                    // Update local state
                    const prToDismiss = activePRs.find(pr => pr.id === prId);
                    
                    // Move PR from active to dismissed
                    if (prToDismiss) {
                      setActivePRs(prevPRs => prevPRs.filter(pr => pr.id !== prId));
                      setDismissedPRs(prevDismissed => [...prevDismissed, prToDismiss]);
                    }
                  }
                } catch (error) {
                  console.error('Error dismissing PR:', error);
                }
              }}
            />
            
            {/* Dismissed PRs */}
            {dismissedPRs.length > 0 && (
              <PRList 
                prs={dismissedPRs}
                title="Dismissed PRs"
                isDismissed={true}
                collapsible={true}
                onUndismiss={async (prId) => {
                  try {
                    console.log(`Undismissing PR with ID: ${prId}`);
                    const success = await ipcRenderer.invoke('undismiss-pr', prId);
                    
                    if (success) {
                      console.log('PR undismissed successfully');
                      
                      // Update local state
                      const prToUndismiss = dismissedPRs.find(pr => pr.id === prId);
                      
                      // Move PR from dismissed to active
                      if (prToUndismiss) {
                        setDismissedPRs(prevDismissed => prevDismissed.filter(pr => pr.id !== prId));
                        setActivePRs(prevActive => [...prevActive, prToUndismiss]);
                      }
                    }
                  } catch (error) {
                    console.error('Error undismissing PR:', error);
                  }
                }}
              />
            )}
          </div>
        ) : (
          <Settings onSave={handleRefresh} />
        )}
      </div>
    </div>
  );
};

export default App;