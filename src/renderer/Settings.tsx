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
  
  useEffect(() => {
    loadSettings();
  }, []);
  
  const loadSettings = async () => {
    try {
      const settings = await ipcRenderer.invoke('get-settings');
      setToken(settings.token || '');
      setUsername(settings.username || '');
      setRepos(settings.repos || []);
      setCheckInterval(settings.checkInterval || 15);
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
      });
      
      onSave();
    } catch (error) {
      console.error('Error saving settings:', error);
    } finally {
      setIsSaving(false);
    }
  };
  
  const styles = {
    section: {
      marginBottom: '24px',
    },
    label: {
      display: 'block',
      marginBottom: '6px',
      fontWeight: 'bold' as const,
    },
    input: {
      width: '100%',
      padding: '8px',
      borderRadius: '4px',
      border: '1px solid #ddd',
      marginBottom: '12px',
    },
    repoContainer: {
      display: 'flex',
      gap: '8px',
      marginBottom: '8px',
    },
    addButton: {
      padding: '8px 12px',
      backgroundColor: '#0366d6',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      cursor: 'pointer',
    },
    removeButton: {
      padding: '2px 6px',
      backgroundColor: '#e36209',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      cursor: 'pointer',
      fontSize: '12px',
    },
    repoList: {
      maxHeight: '150px',
      overflowY: 'auto' as const,
      border: '1px solid #eee',
      padding: '8px',
      marginTop: '8px',
      borderRadius: '4px',
    },
    repoItem: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: '6px',
      borderBottom: '1px solid #eee',
    },
    saveButton: {
      padding: '10px 16px',
      backgroundColor: '#2ea44f',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      cursor: 'pointer',
      fontWeight: 'bold' as const,
      marginTop: '12px',
    },
  };
  
  return (
    <div>
      <h2>Settings</h2>
      
      <div style={styles.section}>
        <label style={styles.label} htmlFor="token">GitHub Personal Access Token</label>
        <input
          id="token"
          type="password"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="ghp_xxxxxxxxxxxx"
          style={styles.input}
        />
        <p>Create a token with 'repo' scope at GitHub Developer Settings</p>
      </div>
      
      <div style={styles.section}>
        <label style={styles.label} htmlFor="username">GitHub Username</label>
        <input
          id="username"
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Your GitHub username"
          style={styles.input}
        />
      </div>
      
      <div style={styles.section}>
        <label style={styles.label}>Repositories to Monitor</label>
        <div style={styles.repoContainer}>
          <input
            type="text"
            value={newRepo}
            onChange={(e) => setNewRepo(e.target.value)}
            placeholder="owner/repo (e.g. facebook/react)"
            style={{ ...styles.input, marginBottom: 0, flex: 1 }}
          />
          <button style={styles.addButton} onClick={handleAddRepo}>Add</button>
        </div>
        
        <div style={styles.repoList}>
          {repos.length === 0 ? (
            <p>No repositories added yet</p>
          ) : (
            repos.map((repo) => (
              <div key={repo} style={styles.repoItem}>
                <span>{repo}</span>
                <button style={styles.removeButton} onClick={() => handleRemoveRepo(repo)}>
                  Remove
                </button>
              </div>
            ))
          )}
        </div>
      </div>
      
      <div style={styles.section}>
        <label style={styles.label} htmlFor="interval">Check Interval (minutes)</label>
        <input
          id="interval"
          type="number"
          min="1"
          max="60"
          value={checkInterval}
          onChange={(e) => setCheckInterval(parseInt(e.target.value, 10))}
          style={{ ...styles.input, width: '100px' }}
        />
      </div>
      
      <button 
        style={styles.saveButton} 
        onClick={handleSave}
        disabled={isSaving}
      >
        {isSaving ? 'Saving...' : 'Save Settings'}
      </button>
    </div>
  );
};

export default Settings;