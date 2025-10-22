import { Octokit } from '@octokit/rest';
import { Notification, shell } from 'electron';
import Store from 'electron-store';
import notifier from 'node-notifier';
import path from 'path';
import fs from 'fs';

export interface ReviewInfo {
  reviewerLogin: string;
  reviewerName: string | null;
  state: 'APPROVED' | 'CHANGES_REQUESTED' | 'COMMENTED' | 'PENDING';
}

export interface PR {
  id: number;
  number: number;
  title: string;
  html_url: string;
  repo: string;
  reviews?: ReviewInfo[];
  isAuthored?: boolean;
}

interface StoreSchema {
  token: string;
  repos: string[];
  username: string;
  checkInterval: number;
  pendingPRs: PR[];
  authoredPRs: PR[];
  notifiedPRs: number[];
  dismissedPRs: number[];
  enableNotifications: boolean;
  devShowSamplePRs: boolean; // For development mode only
}

// Configure store path for tests if environment variable is set
const store = new Store<StoreSchema>({
  cwd: process.env.ELECTRON_STORE_PATH ? path.dirname(process.env.ELECTRON_STORE_PATH) : undefined,
  name: process.env.ELECTRON_STORE_PATH ? path.basename(process.env.ELECTRON_STORE_PATH, '.json') : undefined
});

// Helper function to parse GitHub API errors and provide detailed messages
function parseGitHubError(error: any, context: string = ''): { type: 'auth' | 'network' | 'repo_access' | 'rate_limit' | 'unknown'; message: string; details?: string } {
  const status = error.status || error.response?.status;
  const responseData = error.response?.data;
  const gitHubMessage = responseData?.message || '';
  const documentationUrl = responseData?.documentation_url;
  
  // Network errors
  if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
    return {
      type: 'network',
      message: 'Unable to connect to GitHub',
      details: 'Check your internet connection and try again.'
    };
  }
  
  // Authentication errors (401)
  if (status === 401) {
    let message = 'GitHub authentication failed';
    let details = 'Your token may be expired, invalid, or revoked.';
    
    if (gitHubMessage.toLowerCase().includes('bad credentials')) {
      message = 'Invalid GitHub token';
      details = 'The token appears to be malformed or incorrect. Generate a new personal access token.';
    } else if (gitHubMessage.toLowerCase().includes('token expired')) {
      message = 'GitHub token has expired';
      details = 'Please generate a new personal access token with the same permissions.';
    } else if (gitHubMessage.toLowerCase().includes('revoked')) {
      message = 'GitHub token has been revoked';
      details = 'The token was revoked. Generate a new personal access token.';
    }
    
    return { type: 'auth', message, details };
  }
  
  // Permission/scope errors (403)
  if (status === 403) {
    // Rate limiting
    if (error.response?.headers?.['x-ratelimit-remaining'] === '0') {
      const resetTime = error.response?.headers?.['x-ratelimit-reset'];
      let resetDetails = '';
      if (resetTime) {
        const resetDate = new Date(parseInt(resetTime) * 1000);
        resetDetails = ` Rate limit resets at ${resetDate.toLocaleTimeString()}.`;
      }
      
      return {
        type: 'rate_limit',
        message: 'GitHub API rate limit exceeded',
        details: `You've made too many requests.${resetDetails} Consider using a personal access token for higher limits.`
      };
    }
    
    // Permission issues
    if (gitHubMessage.toLowerCase().includes('scopes') || gitHubMessage.toLowerCase().includes('permission')) {
      return {
        type: 'auth',
        message: 'Insufficient token permissions',
        details: `Your token needs additional scopes. ${gitHubMessage} Make sure your token has 'repo' scope for private repos or 'public_repo' for public repos.`
      };
    }
    
    return {
      type: 'auth',
      message: 'Access forbidden',
      details: gitHubMessage || 'Your token may not have the required permissions.'
    };
  }
  
  // Repository not found (404)
  if (status === 404) {
    return {
      type: 'repo_access',
      message: `Repository ${context} not found`,
      details: 'The repository may be private, deleted, or the name is incorrect.'
    };
  }
  
  // Other errors
  return {
    type: 'unknown',
    message: gitHubMessage || `GitHub API error${context ? ` for ${context}` : ''}`,
    details: documentationUrl ? `See: ${documentationUrl}` : 'An unexpected error occurred.'
  };
}

// Type for PR checking results, includes active and dismissed PRs
export interface PRCheckResult {
  activePRs: PR[];
  dismissedPRs: PR[];
  authoredPRs: PR[];
  errors?: {
    type: 'auth' | 'network' | 'repo_access' | 'rate_limit' | 'unknown';
    message: string;
    repoName?: string;
    details?: string;
  }[];
  hasErrors?: boolean;
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
    
    // Create sample PRs - these represent all valid PRs
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
    
    // Get all valid PR IDs in the sample data
    const validPRIds = [...sampleActivePRs, ...sampleAlwaysDismissedPRs].map(pr => pr.id);
    
    // Filter dismissed PRs to only those that are still valid
    const updatedDismissedPRIds = dismissedPRIds.filter(id => validPRIds.includes(id));
    
    // If some dismissed PRs were removed, update the store
    if (updatedDismissedPRIds.length !== dismissedPRIds.length) {
      console.log(`[Sample Mode] Removing ${dismissedPRIds.length - updatedDismissedPRIds.length} dismissed PRs that no longer exist`);
      store.set('dismissedPRs', updatedDismissedPRIds);
    }
    
    // Check which of the active sample PRs are in the dismissed list
    const actualActivePRs = sampleActivePRs.filter(pr => !updatedDismissedPRIds.includes(pr.id));
    
    // Find dismissed PRs: combine always-dismissed samples with any dismissed active samples
    const dismissedActivePRs = sampleActivePRs.filter(pr => updatedDismissedPRIds.includes(pr.id));
    
    // Final dismissed list includes both always-dismissed and user-dismissed PRs
    const dismissedPRs = [...sampleAlwaysDismissedPRs, ...dismissedActivePRs];
    
    // Sample authored PRs with review status
    const sampleAuthoredPRs: PR[] = [
      {
        id: 9876543220,
        number: 301,
        title: "[SAMPLE-AUTHORED] Implement user profile page",
        html_url: "https://github.com/sample/repo/pull/301",
        repo: "sample/repo",
        isAuthored: true,
        reviews: [
          {
            reviewerLogin: "reviewer1",
            reviewerName: "Alice Smith",
            state: 'APPROVED'
          },
          {
            reviewerLogin: "reviewer2",
            reviewerName: "Bob Johnson",
            state: 'PENDING'
          }
        ]
      },
      {
        id: 9876543221,
        number: 302,
        title: "[SAMPLE-AUTHORED] Fix navigation bug",
        html_url: "https://github.com/sample/repo/pull/302",
        repo: "another/project",
        isAuthored: true,
        reviews: [
          {
            reviewerLogin: "reviewer3",
            reviewerName: "Charlie Davis",
            state: 'CHANGES_REQUESTED'
          }
        ]
      },
      {
        id: 9876543222,
        number: 303,
        title: "[SAMPLE-AUTHORED] Add API documentation",
        html_url: "https://github.com/sample/repo/pull/303",
        repo: "docs/documentation",
        isAuthored: true,
        reviews: []
      }
    ];

    // Store the active PRs in the store
    store.set('pendingPRs', actualActivePRs);
    store.set('authoredPRs', sampleAuthoredPRs);

    return {
      activePRs: actualActivePRs,
      dismissedPRs: dismissedPRs,
      authoredPRs: sampleAuthoredPRs
    };
  }
  
  if (!token || !username || repos.length === 0) {
    // Log missing settings to console for debugging
    console.log('Missing settings, cannot check for PRs', { 
      hasToken: !!token, 
      hasUsername: !!username, 
      reposCount: repos.length 
    });
    
    const errors = [];
    if (!token) {
      errors.push({
        type: 'auth' as const,
        message: 'GitHub token not configured. Please add your token in settings.'
      });
    }
    if (!username) {
      errors.push({
        type: 'auth' as const,
        message: 'GitHub username not configured. Please add your username in settings.'
      });
    }
    if (repos.length === 0) {
      errors.push({
        type: 'auth' as const,
        message: 'No repositories configured. Please add repositories to monitor in settings.'
      });
    }
    
    return {
      activePRs: [],
      dismissedPRs: [],
      authoredPRs: [],
      errors,
      hasErrors: true
    };
  }
  
  const octokit = new Octokit({ auth: token });
  const pendingPRs: PR[] = [];
  const authoredPRs: PR[] = [];
  const errors: Array<{ type: 'auth' | 'network' | 'repo_access' | 'rate_limit' | 'unknown'; message: string; repoName?: string; details?: string }> = [];

  // Track all valid PR IDs that currently exist in GitHub
  const validPRIds: number[] = [];
  // Store all valid PRs by their ID for quick lookup
  const validPRsById: Record<number, PR> = {};
  
  try {
    for (const repoFullName of repos) {
      const [owner, repo] = repoFullName.split('/');
      
      // Check if the repository exists and is accessible
      try {
        await octokit.repos.get({ owner, repo });
      } catch (error: any) {
        console.error(`Repository ${repoFullName} not found or not accessible:`, error);
        
        const parsedError = parseGitHubError(error, repoFullName);
        
        errors.push({
          type: parsedError.type,
          message: parsedError.message,
          details: parsedError.details,
          repoName: repoFullName
        });
        
        continue;
      }
      
      // Get open PRs for the repo
      const { data: openPRs } = await octokit.pulls.list({
        owner,
        repo,
        state: 'open',
        per_page: 100,
      });
      
      // Check each PR to see if user is requested as reviewer or is the author
      for (const pr of openPRs) {
        const { data: reviewRequests } = await octokit.pulls.listRequestedReviewers({
          owner,
          repo,
          pull_number: pr.number,
        });

        const isRequested = reviewRequests.users.some(user => user.login === username);
        const isAuthor = pr.user?.login === username;

        // Track this PR ID as valid regardless of whether it's dismissed or not
        if (isRequested) {
          validPRIds.push(pr.id);

          // Create PR object
          const newPR = {
            id: pr.id,
            number: pr.number,
            title: pr.title,
            html_url: pr.html_url,
            repo: repoFullName,
          };

          // Store in lookup map for use with dismissed PRs
          validPRsById[pr.id] = newPR;

          // Only add to pending PRs if not dismissed
          if (!dismissedPRIds.includes(pr.id)) {
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

        // Check if user is the author of this PR
        if (isAuthor) {
          // Get all reviews for this PR
          const { data: reviews } = await octokit.pulls.listReviews({
            owner,
            repo,
            pull_number: pr.number,
          });

          // Get unique reviewers and their latest review state
          const reviewerMap = new Map<string, ReviewInfo>();

          // Process reviews in chronological order (they come sorted newest first by default)
          reviews.reverse().forEach(review => {
            if (review.user && review.state !== 'COMMENTED') {
              reviewerMap.set(review.user.login, {
                reviewerLogin: review.user.login,
                reviewerName: review.user.name || null,
                state: review.state as 'APPROVED' | 'CHANGES_REQUESTED' | 'PENDING'
              });
            }
          });

          // Add pending reviewers who haven't submitted a review yet
          reviewRequests.users.forEach(user => {
            if (!reviewerMap.has(user.login)) {
              reviewerMap.set(user.login, {
                reviewerLogin: user.login,
                reviewerName: user.name || null,
                state: 'PENDING'
              });
            }
          });

          const reviewsArray = Array.from(reviewerMap.values());

          authoredPRs.push({
            id: pr.id,
            number: pr.number,
            title: pr.title,
            html_url: pr.html_url,
            repo: repoFullName,
            isAuthored: true,
            reviews: reviewsArray
          });
        }
      }
    }
  } catch (error: any) {
    console.error('Error checking PRs:', error);
    
    const parsedError = parseGitHubError(error);
    
    errors.push({
      type: parsedError.type,
      message: parsedError.message,
      details: parsedError.details
    });
  }
  
  // Filter the dismissed PR IDs to only include valid ones
  const updatedDismissedPRIds = dismissedPRIds.filter(id => validPRIds.includes(id));
  
  // If some dismissed PRs were removed, update the store
  if (updatedDismissedPRIds.length !== dismissedPRIds.length) {
    console.log(`Removing ${dismissedPRIds.length - updatedDismissedPRIds.length} dismissed PRs that no longer exist`);
    store.set('dismissedPRs', updatedDismissedPRIds);
  }
  
  // Separate active and dismissed PRs
  const activePRs: PR[] = [];
  const dismissedPRs: PR[] = [];
  
  // Add active PRs
  pendingPRs.forEach(pr => {
    if (!updatedDismissedPRIds.includes(pr.id)) {
      activePRs.push(pr);
    }
  });
  
  // Add dismissed PRs with full details from the valid PRs map
  updatedDismissedPRIds.forEach(id => {
    if (validPRsById[id]) {
      dismissedPRs.push(validPRsById[id]);
    }
  });
  
  console.log(`After filtering: ${activePRs.length} active PRs, ${dismissedPRs.length} dismissed PRs, ${authoredPRs.length} authored PRs`);

  // Update pendingPRs and authoredPRs in store
  store.set('pendingPRs', activePRs);
  store.set('authoredPRs', authoredPRs);

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

  console.log(`checkForPRs returning ${activePRs.length} active PRs, ${dismissedPRs.length} dismissed PRs, and ${authoredPRs.length} authored PRs${errors.length > 0 ? ` with ${errors.length} errors` : ''}`);
  return {
    activePRs,
    dismissedPRs,
    authoredPRs,
    errors: errors.length > 0 ? errors : undefined,
    hasErrors: errors.length > 0
  };
}

export async function openPR(url: string): Promise<void> {
  await shell.openExternal(url);
}