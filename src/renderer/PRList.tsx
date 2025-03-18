import React, { useState } from 'react';
import { shell, ipcRenderer } from 'electron';

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
}

interface PRListProps {
  prs: PR[];
  title?: string;
  isDismissed?: boolean;
  collapsible?: boolean;
  onDismiss?: (prId: number) => void;
  onUndismiss?: (prId: number) => void;
}

const PRList: React.FC<PRListProps> = ({ 
  prs, 
  title, 
  isDismissed = false, 
  collapsible = false,
  onDismiss, 
  onUndismiss 
}) => {
  const [isCollapsed, setIsCollapsed] = useState(true);
  
  const handleOpenPR = (url: string) => {
    shell.openExternal(url);
  };
  
  const handleDismiss = (prId: number) => {
    if (onDismiss) onDismiss(prId);
  };
  
  const handleUndismiss = (prId: number) => {
    if (onUndismiss) onUndismiss(prId);
  };
  
  // If no PRs and not showing a title, show the empty state
  if (prs.length === 0 && !title) {
    return (
      <div className="text-center py-12 text-gray-500">
        <h3 className="text-lg font-medium mb-2 text-gray-700">No pull requests waiting for your review</h3>
        <p className="text-sm m-0 text-gray-500">When someone requests your review, they'll appear here.</p>
      </div>
    );
  }
  
  // If no PRs but showing a title, just return null
  if (prs.length === 0) {
    return null;
  }
  
  return (
    <div className="mb-6">
      {title && (
        <div 
          className={`flex justify-between items-center mb-3 ${collapsible ? 'cursor-pointer' : ''}`}
          onClick={collapsible ? () => setIsCollapsed(!isCollapsed) : undefined}
        >
          <h2 className="text-lg font-semibold text-gray-700 flex items-center">
            {title} <span className="ml-2 text-sm text-gray-500">({prs.length})</span>
            {collapsible && (
              <span className="ml-2 text-gray-400">
                {isCollapsed ? '▼' : '▲'}
              </span>
            )}
          </h2>
        </div>
      )}
      
      {(!collapsible || !isCollapsed) && (
        <ul className="list-none p-0 m-0">
          {prs.map((pr) => (
            <li 
              key={pr.id} 
              data-testid="pr-item"
              className={`border-b border-gray-200 p-4 cursor-default transition-all duration-200 rounded-md mb-2 shadow-sm hover:shadow-md hover:-translate-y-0.5 ${isDismissed ? 'bg-gray-50' : 'bg-white hover:bg-gray-50'}`}
            >
              <h3 className={`text-base font-semibold mb-2 ${isDismissed ? 'text-gray-600' : 'text-blue-600'}`}>
                {pr.title}
              </h3>
              <div className="text-sm text-gray-500 flex items-center mb-3">
                <span className={`inline-block py-1 px-2 text-xs font-medium rounded-full mr-2 ${isDismissed ? 'bg-gray-100 text-gray-600' : 'bg-blue-50 text-blue-600'}`}>
                  {pr.repo}
                </span>
                <span>#{pr.number}</span>
              </div>
              <div className="flex gap-2 mt-3 pt-2 border-t border-gray-100">
                <button
                  className="flex-1 px-3 py-1.5 bg-blue-500 text-white hover:bg-blue-600 rounded text-xs font-medium transition-colors"
                  onClick={() => handleOpenPR(pr.html_url)}
                >
                  View on GitHub
                </button>
                {isDismissed ? (
                  <button
                    className="flex-1 px-3 py-1.5 bg-green-500 text-white hover:bg-green-600 rounded text-xs font-medium transition-colors"
                    onClick={() => handleUndismiss(pr.id)}
                  >
                    Restore
                  </button>
                ) : (
                  <button
                    className="flex-1 px-3 py-1.5 bg-gray-200 text-gray-700 hover:bg-gray-300 rounded text-xs font-medium transition-colors"
                    onClick={() => handleDismiss(pr.id)}
                  >
                    Dismiss
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default PRList;