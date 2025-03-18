/**
 * This file contains mock implementations for GitHub API responses
 * used during testing.
 */

export const mockPullRequests = [
  {
    id: 1,
    number: 101,
    title: 'Add new feature',
    html_url: 'https://github.com/test-org/test-repo/pull/101',
    repo: 'test-org/test-repo'
  },
  {
    id: 2,
    number: 102,
    title: 'Fix bug in login flow',
    html_url: 'https://github.com/test-org/test-repo/pull/102',
    repo: 'test-org/test-repo'
  }
];