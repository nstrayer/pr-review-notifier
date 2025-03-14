import { Octokit } from '@octokit/rest';
import { Notification } from 'electron';
import Store from 'electron-store';
import notifier from 'node-notifier';
import path from 'path';

interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
}

interface StoreSchema {
  token: string;
  repos: string[];
  username: string;
  checkInterval: number;
  pendingPRs: PR[];
  notifiedPRs: number[];
}

const store = new Store<StoreSchema>();

export async function checkForPRs(): Promise<PR[]> {
  const token = store.get('token', '');
  const repos = store.get('repos', []);
  const username = store.get('username', '');
  
  if (!token || !username || repos.length === 0) {
    return [];
  }
  
  const octokit = new Octokit({ auth: token });
  const pendingPRs: PR[] = [];
  
  try {
    for (const repoFullName of repos) {
      const [owner, repo] = repoFullName.split('/');
      
      // Check if the repository exists and is accessible
      try {
        await octokit.repos.get({ owner, repo });
      } catch (error) {
        console.error(`Repository ${repoFullName} not found or not accessible:`, error);
        continue;
      }
      
      // Get open PRs for the repo
      const { data: openPRs } = await octokit.pulls.list({
        owner,
        repo,
        state: 'open',
        per_page: 100,
      });
      
      // Check each PR to see if user is requested as reviewer
      for (const pr of openPRs) {
        const { data: reviewRequests } = await octokit.pulls.listRequestedReviewers({
          owner,
          repo,
          pull_number: pr.number,
        });
        
        const isRequested = reviewRequests.users.some(user => user.login === username);
        
        if (isRequested) {
          const newPR = {
            id: pr.id,
            number: pr.number,
            title: pr.title,
            html_url: pr.html_url,
            repo: repoFullName,
          };
          
          pendingPRs.push(newPR);
          
          // Check if we've already notified for this PR
          const notifiedPRs = store.get('notifiedPRs', []);
          
          if (!notifiedPRs.includes(pr.id)) {
            // Send notification using system notifications
            const iconPath = path.join(__dirname, '../../assets/icon.svg');
            let notificationOptions: any = {
              title: `PR Review Requested: ${repoFullName}`,
              message: pr.title,
            };
            
            try {
              if (require('fs').existsSync(iconPath)) {
                notificationOptions.icon = iconPath;
              }
            } catch (error) {
              console.log('Icon not found, using default system icon');
            }
            
            notifier.notify(notificationOptions);
            
            // Also open an Electron notification that when clicked will open the PR
            const notification = new Notification({
              title: `PR Review Requested: ${repoFullName}`,
              body: pr.title,
            });
            
            notification.on('click', () => {
              openPR(pr.html_url);
            });
            
            notification.show();
            
            // Mark as notified
            store.set('notifiedPRs', [...notifiedPRs, pr.id]);
          }
        }
      }
    }
  } catch (error) {
    console.error('Error checking PRs:', error);
  }
  
  // Update pendingPRs in store
  store.set('pendingPRs', pendingPRs);
  
  // Update the badge count on the application icon
  if (pendingPRs.length > 0) {
    new Notification({
      title: 'PR Reviews Pending',
      body: `You have ${pendingPRs.length} pull request${pendingPRs.length === 1 ? '' : 's'} waiting for your review.`,
      silent: true,
    }).show();
  }
  
  return pendingPRs;
}

export async function openPR(url: string): Promise<void> {
  const { shell } = require('electron');
  await shell.openExternal(url);
}