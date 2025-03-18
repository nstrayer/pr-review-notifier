import { Octokit } from '@octokit/rest';
import { Notification, shell } from 'electron';
import Store from 'electron-store';
import notifier from 'node-notifier';
import path from 'path';
import fs from 'fs';

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
  dismissedPRs: number[];
  enableNotifications: boolean;
  devShowSamplePRs: boolean; // For development mode only
}

const store = new Store<StoreSchema>();

// Type for PR checking results, includes active and dismissed PRs
export interface PRCheckResult {
  activePRs: PR[];
  dismissedPRs: PR[];
}

export async function checkForPRs(): Promise<PRCheckResult> {
  const token = store.get('token', '');
  const repos = store.get('repos', []);
  const username = store.get('username', '');
  const dismissedPRIds = store.get('dismissedPRs', []);
  
  console.log(`Running checkForPRs with ${dismissedPRIds.length} dismissed PRs`);
  
  // Sample PRs for development mode
  const showSamplePRs = store.get('devShowSamplePRs', false);
  
  // If in sample mode, return mocked data
  if (showSamplePRs) {
    console.log('Returning sample PRs from github.ts');
    
    // Create sample PRs
    const sampleActivePRs: PR[] = [
      {
        id: 9876543210,
        number: 123,
        title: "[SAMPLE] Add new dashboard feature",
        html_url: "https://github.com/sample/repo/pull/123",
        repo: "sample/repo"
      },
      {
        id: 9876543211,
        number: 456,
        title: "[SAMPLE] Fix login bug on Safari",
        html_url: "https://github.com/sample/repo/pull/456",
        repo: "another/project"
      },
      {
        id: 9876543212,
        number: 789,
        title: "[SAMPLE] Update README with new installation instructions",
        html_url: "https://github.com/sample/repo/pull/789",
        repo: "docs/documentation"
      }
    ];
    
    // Sample PRs that are always shown as dismissed
    const sampleAlwaysDismissedPRs: PR[] = [
      {
        id: 9876543213,
        number: 101,
        title: "[SAMPLE-DISMISSED] Improve test coverage",
        html_url: "https://github.com/sample/repo/pull/101",
        repo: "sample/repo"
      },
      {
        id: 9876543214,
        number: 202,
        title: "[SAMPLE-DISMISSED] Update API documentation",
        html_url: "https://github.com/sample/repo/pull/202",
        repo: "docs/api-docs"
      }
    ];
    
    // Check which of the active sample PRs are in the dismissed list
    const actualActivePRs = sampleActivePRs.filter(pr => !dismissedPRIds.includes(pr.id));
    
    // Find dismissed PRs: combine always-dismissed samples with any dismissed active samples
    const dismissedActivePRs = sampleActivePRs.filter(pr => dismissedPRIds.includes(pr.id));
    
    // Final dismissed list includes both always-dismissed and user-dismissed PRs
    const dismissedPRs = [...sampleAlwaysDismissedPRs, ...dismissedActivePRs];
    
    // Store the active PRs in the store
    store.set('pendingPRs', actualActivePRs);
    
    return {
      activePRs: actualActivePRs,
      dismissedPRs: dismissedPRs
    };
  }
  
  if (!token || !username || repos.length === 0) {
    // Log missing settings to console for debugging
    console.log('Missing settings, cannot check for PRs', { 
      hasToken: !!token, 
      hasUsername: !!username, 
      reposCount: repos.length 
    });
    return { activePRs: [], dismissedPRs: [] };
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
        
        if (isRequested && !dismissedPRIds.includes(pr.id)) {
          const newPR = {
            id: pr.id,
            number: pr.number,
            title: pr.title,
            html_url: pr.html_url,
            repo: repoFullName,
          };
          
          pendingPRs.push(newPR);
          
          // Check if we've already notified for this PR and if notifications are enabled
          const notifiedPRs = store.get('notifiedPRs', []);
          const enableNotifications = store.get('enableNotifications', true);
          
          if (!notifiedPRs.includes(pr.id) && enableNotifications) {
            // Send notification using system notifications
            const iconPath = path.join(__dirname, '../../assets/icon.svg');
            let notificationOptions: any = {
              title: `PR Review Requested: ${repoFullName}`,
              message: pr.title,
            };
            
            try {
              if (fs.existsSync(iconPath)) {
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
  
  // Separate active and dismissed PRs
  const activePRs: PR[] = [];
  const dismissedPRs: PR[] = [];
  
  // Sort PRs into active and dismissed categories
  pendingPRs.forEach(pr => {
    if (dismissedPRIds.includes(pr.id)) {
      dismissedPRs.push(pr);
    } else {
      activePRs.push(pr);
    }
  });
  
  console.log(`After filtering: ${activePRs.length} active PRs, ${dismissedPRs.length} dismissed PRs`);
  
  // Update pendingPRs in store - only active PRs count as pending
  store.set('pendingPRs', activePRs);
  
  // Update the badge count on the application icon
  const enableNotifications = store.get('enableNotifications', true);
  if (activePRs.length > 0 && enableNotifications) {
    new Notification({
      title: 'PR Reviews Pending',
      body: `You have ${activePRs.length} pull request${activePRs.length === 1 ? '' : 's'} waiting for your review.`,
      silent: true,
    }).show();
  }
  
  // The main process will handle updating the tray menu after receiving the results
  
  console.log(`checkForPRs returning ${activePRs.length} active PRs and ${dismissedPRs.length} dismissed PRs`);
  return { activePRs, dismissedPRs };
}

export async function openPR(url: string): Promise<void> {
  await shell.openExternal(url);
}