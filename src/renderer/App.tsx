import React, { useState, useEffect } from 'react';
import { ipcRenderer } from 'electron';
import Settings from './Settings';
import PRList from './PRList';

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
}

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'prs' | 'settings'>('prs');
  const [pendingPRs, setPendingPRs] = useState<PR[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);

  useEffect(() => {
    // Load pending PRs from store on startup
    const loadPendingPRs = async () => {
      try {
        const settings = await ipcRenderer.invoke('get-settings');
        if (settings && settings.pendingPRs) {
          setPendingPRs(settings.pendingPRs);
        }
      } catch (error) {
        console.error('Error loading PRs:', error);
      }
    };
    
    loadPendingPRs();
    // Check for PRs
    handleRefresh();
    
    // Listen for 'show-settings' event from main process
    ipcRenderer.on('show-settings', () => {
      setActiveTab('settings');
    });
    
    return () => {
      ipcRenderer.removeAllListeners('show-settings');
    };
  }, []);

  const handleRefresh = async () => {
    setIsLoading(true);
    try {
      const prs = await ipcRenderer.invoke('check-now');
      setPendingPRs(prs);
    } catch (error) {
      console.error('Error refreshing PRs:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const styles = {
    container: {
      display: 'flex',
      flexDirection: 'column' as const,
      height: '100%',
      borderRadius: '8px',
      overflow: 'hidden',
      boxShadow: '0 2px 10px rgba(0, 0, 0, 0.2)',
    },
    header: {
      padding: '10px',
      borderBottom: '1px solid #eaeaea',
      display: 'flex',
      justifyContent: 'space-between',
      backgroundColor: '#f5f5f5',
    },
    title: {
      margin: 0,
      fontSize: '16px',
      fontWeight: 'bold' as const,
    },
    tabs: {
      display: 'flex',
      borderBottom: '1px solid #eaeaea',
    },
    tab: {
      padding: '8px 16px',
      cursor: 'pointer',
      backgroundColor: 'transparent',
      border: 'none',
      borderBottom: '2px solid transparent',
    },
    activeTab: {
      borderBottom: '2px solid #0366d6',
      fontWeight: 'bold' as const,
    },
    content: {
      flex: 1,
      padding: '16px',
      overflow: 'auto',
    },
    refreshButton: {
      padding: '4px 8px',
      fontSize: '12px',
      backgroundColor: '#0366d6',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      cursor: 'pointer',
    },
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>PR Notifier</h1>
        {activeTab === 'prs' && (
          <button 
            style={styles.refreshButton} 
            onClick={handleRefresh}
            disabled={isLoading}
          >
            {isLoading ? 'Checking...' : 'Check Now'}
          </button>
        )}
      </div>
      
      <div style={styles.tabs}>
        <button 
          style={{
            ...styles.tab,
            ...(activeTab === 'prs' ? styles.activeTab : {})
          }} 
          onClick={() => setActiveTab('prs')}
        >
          Pull Requests {pendingPRs.length > 0 && `(${pendingPRs.length})`}
        </button>
        <button 
          style={{
            ...styles.tab,
            ...(activeTab === 'settings' ? styles.activeTab : {})
          }} 
          onClick={() => setActiveTab('settings')}
        >
          Settings
        </button>
      </div>
      
      <div style={styles.content}>
        {activeTab === 'prs' ? (
          <PRList prs={pendingPRs} />
        ) : (
          <Settings onSave={handleRefresh} />
        )}
      </div>
    </div>
  );
};

export default App;