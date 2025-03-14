import React from 'react';
import { shell } from 'electron';

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
}

interface PRListProps {
  prs: PR[];
}

const PRList: React.FC<PRListProps> = ({ prs }) => {
  const handleOpenPR = (url: string) => {
    shell.openExternal(url);
  };
  
  const styles = {
    emptyState: {
      textAlign: 'center' as const,
      padding: '40px 0',
      color: '#586069',
    },
    list: {
      listStyle: 'none',
      padding: 0,
      margin: 0,
    },
    item: {
      borderBottom: '1px solid #eee',
      padding: '12px 8px',
      cursor: 'pointer',
      transition: 'background-color 0.2s',
      ':hover': {
        backgroundColor: '#f6f8fa',
      },
    },
    title: {
      fontSize: '16px',
      fontWeight: 'bold' as const,
      margin: '0 0 6px 0',
    },
    meta: {
      fontSize: '14px',
      color: '#586069',
    },
  };
  
  if (prs.length === 0) {
    return (
      <div style={styles.emptyState}>
        <h3>No pull requests waiting for your review</h3>
        <p>When someone requests your review, they'll appear here.</p>
      </div>
    );
  }
  
  return (
    <ul style={styles.list}>
      {prs.map((pr) => (
        <li 
          key={pr.id} 
          style={styles.item}
          onClick={() => handleOpenPR(pr.html_url)}
        >
          <h3 style={styles.title}>{pr.title}</h3>
          <div style={styles.meta}>
            <span>{pr.repo} #{pr.number}</span>
          </div>
        </li>
      ))}
    </ul>
  );
};

export default PRList;