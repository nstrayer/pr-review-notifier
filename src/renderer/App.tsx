import React, { useState, useEffect } from 'react';
import { ipcRenderer } from 'electron';
import Settings from './Settings';
import PRList from './PRList';
import { formatDistanceToNow } from 'date-fns';

interface ReviewInfo {
  reviewerLogin: string;
  reviewerName: string | null;
  state: 'APPROVED' | 'CHANGES_REQUESTED' | 'COMMENTED' | 'PENDING';
}

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
  reviews?: ReviewInfo[];
  isAuthored?: boolean;
}

interface CheckError {
  type: 'auth' | 'network' | 'repo_access' | 'rate_limit' | 'unknown';
  message: string;
  repoName?: string;
  details?: string;
}

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'prs' | 'settings'>('prs');
  const [activePRs, setActivePRs] = useState<PR[]>([]);
  const [dismissedPRs, setDismissedPRs] = useState<PR[]>([]);
  const [authoredPRs, setAuthoredPRs] = useState<PR[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [lastQueryTime, setLastQueryTime] = useState<number>(0);
  const [checkErrors, setCheckErrors] = useState<CheckError[]>([]);

  useEffect(() => {
    // Load PRs from store on startup
    const loadPRs = async () => {
      try {
        const settings = await ipcRenderer.invoke('get-settings');

        // Load pending PRs from store
        if (settings && settings.pendingPRs) {
          setActivePRs(settings.pendingPRs);
        }

        // Load authored PRs from store
        if (settings && settings.authoredPRs) {
          setAuthoredPRs(settings.authoredPRs);
        }

        // Load last query time
        if (settings && settings.lastQueryTime) {
          setLastQueryTime(settings.lastQueryTime);
        }

        // Load any stored errors
        if (settings && settings.lastCheckHadErrors && settings.lastCheckErrors) {
          setCheckErrors(settings.lastCheckErrors);
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

    // Listen for 'window-shown' event to refresh data from store when window opens
    ipcRenderer.on('window-shown', () => {
      console.log('Window shown, refreshing from store...');
      loadPRs();
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
      ipcRenderer.removeAllListeners('window-shown');
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
      
      // Set the active, dismissed, and authored PRs in local state
      console.log(`Received ${result.activePRs.length} active PRs, ${result.dismissedPRs.length} dismissed PRs, and ${result.authoredPRs?.length || 0} authored PRs${result.hasErrors ? ' with errors' : ''}`);
      setActivePRs(result.activePRs);
      setDismissedPRs(result.dismissedPRs);
      setAuthoredPRs(result.authoredPRs || []);

      // Set errors if any
      if (result.errors) {
        setCheckErrors(result.errors);
      } else {
        setCheckErrors([]);
      }
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
            {/* Error Banner */}
            {checkErrors.length > 0 && (
              <div className="mb-4 bg-red-50 border border-red-200 rounded-md p-3">
                <div className="flex items-start">
                  <div className="flex-shrink-0">
                    <svg className="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <h3 className="text-sm font-medium text-red-800">
                      Error checking pull requests
                    </h3>
                    <div className="mt-2 text-sm text-red-700">
                      {checkErrors.map((error, index) => (
                        <div key={index} className="mb-3">
                          <div className="font-medium">
                            {error.repoName && <span>{error.repoName}: </span>}
                            {error.message}
                          </div>
                          {error.details && (
                            <div className="mt-1 text-xs text-red-600">
                              {error.details}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                    {checkErrors.some(e => e.type === 'auth') && (
                      <button
                        className="mt-2 text-sm text-red-600 underline cursor-pointer bg-transparent border-none p-0"
                        onClick={() => setActiveTab('settings')}
                      >
                        Go to Settings
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )}
            
            {/* Last Query Indicator */}
            {lastQueryTime > 0 && (
              <div className="mb-4 text-xs text-gray-500 italic text-right">
                Last checked: {formatDistanceToNow(lastQueryTime, { addSuffix: true })}
              </div>
            )}
            
            {/* Active PRs - Reviews requested of you */}
            {activePRs.length === 0 && dismissedPRs.length === 0 && authoredPRs.length === 0 ? (
              <div className="text-center py-12 text-gray-500">
                <h3 className="text-lg font-medium mb-2 text-gray-700">No pull requests</h3>
                <p className="text-sm m-0 text-gray-500">When you have PRs to review or PRs you've created, they'll appear here.</p>
              </div>
            ) : (
              <>
                <PRList
                  prs={activePRs}
                  title="Reviews Requested"
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

                {activePRs.length === 0 && (
                  <div className="text-center py-8 text-gray-400 text-sm mb-6">
                    No PRs waiting for your review
                  </div>
                )}

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

                {/* Your PRs - Split into awaiting reviews and reviewed */}
                {(() => {
                  // Split authored PRs into those awaiting reviews and those that have received reviews
                  const awaitingReviews = authoredPRs.filter(pr =>
                    !pr.reviews || pr.reviews.length === 0 || pr.reviews.every(r => r.state === 'PENDING')
                  );
                  const receivedReviews = authoredPRs.filter(pr =>
                    pr.reviews && pr.reviews.some(r => r.state !== 'PENDING')
                  );

                  return (
                    <>
                      {/* Awaiting Reviews */}
                      {awaitingReviews.length > 0 && (
                        <PRList
                          prs={awaitingReviews}
                          title="Your PRs - Awaiting Reviews"
                          showReviewStatus={true}
                          collapsible={false}
                        />
                      )}

                      {authoredPRs.length > 0 && awaitingReviews.length === 0 && receivedReviews.length === 0 && (
                        <div className="text-center py-8 text-gray-400 text-sm mb-6">
                          No PRs awaiting reviews
                        </div>
                      )}

                      {/* Received Reviews */}
                      {receivedReviews.length > 0 && (
                        <PRList
                          prs={receivedReviews}
                          title="Your PRs - Reviews Received"
                          showReviewStatus={true}
                          collapsible={false}
                        />
                      )}
                    </>
                  );
                })()}
              </>
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