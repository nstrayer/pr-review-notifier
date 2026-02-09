/**
 * inputValidator.test.ts
 *
 * Comprehensive security-focused test suite for input validation
 *
 * This test suite verifies that:
 * 1. All malicious inputs are rejected (security requirement)
 * 2. All valid inputs are accepted (functionality requirement)
 * 3. Edge cases are handled correctly
 * 4. No false positives or false negatives exist
 *
 * Test Coverage:
 * - Command injection attempts
 * - Path traversal attacks
 * - SQL injection patterns
 * - URL injection
 * - Null byte injection
 * - Unicode/homograph attacks
 * - Control character injection
 * - Length boundary conditions
 *
 * Run with: npm test -- inputValidator.test.ts
 */

import {
  validateGitHubToken,
  validateRepository,
  validateUsername,
  validateGitHubURL,
  validateCheckInterval,
  MALICIOUS_TEST_CASES,
  VALID_TEST_CASES,
} from './inputValidator';

describe('GitHub Token Validation', () => {
  describe('Valid tokens should pass', () => {
    test.each(VALID_TEST_CASES.tokens)('accepts valid token: %s', (token) => {
      expect(validateGitHubToken(token)).toBe(true);
    });

    test('accepts ghp_ prefix (Personal Access Token)', () => {
      expect(validateGitHubToken('ghp_' + 'A'.repeat(36))).toBe(true);
    });

    test('accepts gho_ prefix (OAuth token)', () => {
      expect(validateGitHubToken('gho_' + 'A'.repeat(36))).toBe(true);
    });

    test('accepts ghs_ prefix (Server token)', () => {
      expect(validateGitHubToken('ghs_' + 'A'.repeat(36))).toBe(true);
    });

    test('accepts tokens with mixed case', () => {
      expect(validateGitHubToken('ghp_AbCdEf1234567890ABCDEFabcdefghijklmn')).toBe(true);
    });

    test('accepts tokens with numbers', () => {
      expect(validateGitHubToken('ghp_1234567890123456789012345678901234567890')).toBe(true);
    });

    test('accepts maximum reasonable length (300 chars)', () => {
      expect(validateGitHubToken('ghp_' + 'A'.repeat(296))).toBe(true);
    });
  });

  describe('Invalid tokens should fail', () => {
    test.each(MALICIOUS_TEST_CASES.tokens)('rejects malicious token: %s', (token) => {
      expect(validateGitHubToken(token)).toBe(false);
    });

    test('rejects empty string', () => {
      expect(validateGitHubToken('')).toBe(false);
    });

    test('rejects whitespace-only string', () => {
      expect(validateGitHubToken('   ')).toBe(false);
    });

    test('rejects token with leading whitespace', () => {
      expect(validateGitHubToken(' ghp_' + 'A'.repeat(36))).toBe(false);
    });

    test('rejects token with trailing whitespace', () => {
      expect(validateGitHubToken('ghp_' + 'A'.repeat(36) + ' ')).toBe(false);
    });

    test('rejects token too short (< 40 chars)', () => {
      expect(validateGitHubToken('ghp_ABC123')).toBe(false);
    });

    test('rejects token too long (> 300 chars)', () => {
      expect(validateGitHubToken('ghp_' + 'A'.repeat(297))).toBe(false);
    });

    test('rejects invalid prefix', () => {
      expect(validateGitHubToken('invalid_' + 'A'.repeat(36))).toBe(false);
    });

    test('rejects token with special characters', () => {
      expect(validateGitHubToken('ghp_ABC123!@#$%^&*()' + 'A'.repeat(20))).toBe(false);
    });

    test('rejects token with spaces', () => {
      expect(validateGitHubToken('ghp_ABC 123 DEF' + 'A'.repeat(25))).toBe(false);
    });

    test('rejects token with null byte', () => {
      expect(validateGitHubToken('ghp_' + 'A'.repeat(20) + '\0' + 'A'.repeat(16))).toBe(false);
    });

    test('rejects token with command injection attempt', () => {
      expect(validateGitHubToken('ghp_$(whoami)' + 'A'.repeat(27))).toBe(false);
    });

    test('rejects token with semicolon (command separator)', () => {
      expect(validateGitHubToken('ghp_ABC123;rm -rf /' + 'A'.repeat(18))).toBe(false);
    });

    test('rejects null input', () => {
      expect(validateGitHubToken(null as any)).toBe(false);
    });

    test('rejects undefined input', () => {
      expect(validateGitHubToken(undefined as any)).toBe(false);
    });

    test('rejects non-string input', () => {
      expect(validateGitHubToken(123 as any)).toBe(false);
      expect(validateGitHubToken({} as any)).toBe(false);
      expect(validateGitHubToken([] as any)).toBe(false);
    });
  });
});

describe('Repository Name Validation', () => {
  describe('Valid repositories should pass', () => {
    test.each(VALID_TEST_CASES.repositories)('accepts valid repo: %s', (repo) => {
      expect(validateRepository(repo)).toBe(true);
    });

    test('accepts repo with dots in name', () => {
      expect(validateRepository('owner/repo.name.test')).toBe(true);
    });

    test('accepts repo with underscores', () => {
      expect(validateRepository('owner_name/repo_name')).toBe(true);
    });

    test('accepts repo with hyphens', () => {
      expect(validateRepository('my-org/my-repo')).toBe(true);
    });

    test('accepts maximum length owner (39 chars)', () => {
      expect(validateRepository('a'.repeat(39) + '/repo')).toBe(true);
    });

    test('accepts maximum length repo (100 chars)', () => {
      expect(validateRepository('owner/' + 'a'.repeat(100))).toBe(true);
    });

    test('accepts mixed case', () => {
      expect(validateRepository('MyOrg/MyRepo')).toBe(true);
    });
  });

  describe('Invalid repositories should fail', () => {
    test.each(MALICIOUS_TEST_CASES.repositories)('rejects malicious repo: %s', (repo) => {
      expect(validateRepository(repo)).toBe(false);
    });

    test('rejects empty string', () => {
      expect(validateRepository('')).toBe(false);
    });

    test('rejects whitespace-only string', () => {
      expect(validateRepository('   ')).toBe(false);
    });

    test('rejects repo with leading whitespace', () => {
      expect(validateRepository(' owner/repo')).toBe(false);
    });

    test('rejects repo with trailing whitespace', () => {
      expect(validateRepository('owner/repo ')).toBe(false);
    });

    test('rejects repo too short (< 3 chars)', () => {
      expect(validateRepository('a/b')).toBe(true); // This is actually valid
      expect(validateRepository('a/')).toBe(false);
      expect(validateRepository('/b')).toBe(false);
    });

    test('rejects repo too long (> 140 chars)', () => {
      expect(validateRepository('a'.repeat(70) + '/' + 'b'.repeat(71))).toBe(false);
    });

    test('rejects repo without slash', () => {
      expect(validateRepository('invalid-repo')).toBe(false);
    });

    test('rejects repo with multiple slashes', () => {
      expect(validateRepository('owner/repo/extra')).toBe(false);
    });

    test('rejects path traversal: ../', () => {
      expect(validateRepository('../owner/repo')).toBe(false);
      expect(validateRepository('owner/../repo')).toBe(false);
      expect(validateRepository('../../etc/passwd')).toBe(false);
    });

    test('rejects path traversal: ./', () => {
      expect(validateRepository('./owner/repo')).toBe(false);
    });

    test('rejects double slash', () => {
      expect(validateRepository('owner//repo')).toBe(false);
      expect(validateRepository('//owner/repo')).toBe(false);
    });

    test('rejects http:// URL scheme', () => {
      expect(validateRepository('http://github.com/owner/repo')).toBe(false);
    });

    test('rejects https:// URL scheme', () => {
      expect(validateRepository('https://github.com/owner/repo')).toBe(false);
    });

    test('rejects file:// URL scheme', () => {
      expect(validateRepository('file:///etc/passwd')).toBe(false);
    });

    test('rejects javascript: scheme', () => {
      expect(validateRepository('javascript:alert(1)')).toBe(false);
    });

    test('rejects semicolon (command injection)', () => {
      expect(validateRepository('owner/repo; rm -rf /')).toBe(false);
    });

    test('rejects ampersand (command injection)', () => {
      expect(validateRepository('owner/repo && curl evil.com')).toBe(false);
      expect(validateRepository('owner/repo & background')).toBe(false);
    });

    test('rejects pipe (command injection)', () => {
      expect(validateRepository('owner/repo | cat /etc/passwd')).toBe(false);
    });

    test('rejects backtick (command substitution)', () => {
      expect(validateRepository('owner/repo`whoami`')).toBe(false);
    });

    test('rejects dollar sign (variable expansion)', () => {
      expect(validateRepository('owner/repo$(whoami)')).toBe(false);
      expect(validateRepository('owner/repo$HOME')).toBe(false);
    });

    test('rejects SQL injection: single quote', () => {
      expect(validateRepository("owner/repo' OR '1'='1")).toBe(false);
    });

    test('rejects SQL injection: double dash', () => {
      expect(validateRepository('owner/repo--')).toBe(false);
    });

    test('rejects SQL injection: comment', () => {
      expect(validateRepository('owner/repo/*comment*/')).toBe(false);
    });

    test('rejects null byte', () => {
      expect(validateRepository('owner/repo\0')).toBe(false);
    });

    test('rejects control characters', () => {
      expect(validateRepository('owner/repo\n')).toBe(false);
      expect(validateRepository('owner/repo\r')).toBe(false);
      expect(validateRepository('owner/repo\t')).toBe(false);
    });

    test('rejects newline (command injection)', () => {
      expect(validateRepository('owner/repo\nrm -rf /')).toBe(false);
    });

    test('rejects owner starting with hyphen', () => {
      expect(validateRepository('-owner/repo')).toBe(false);
    });

    test('rejects owner ending with hyphen', () => {
      expect(validateRepository('owner-/repo')).toBe(false);
    });

    test('rejects repo that is just dots', () => {
      expect(validateRepository('owner/.')).toBe(false);
      expect(validateRepository('owner/..')).toBe(false);
      expect(validateRepository('owner/...')).toBe(false);
    });

    test('rejects null input', () => {
      expect(validateRepository(null as any)).toBe(false);
    });

    test('rejects undefined input', () => {
      expect(validateRepository(undefined as any)).toBe(false);
    });

    test('rejects non-string input', () => {
      expect(validateRepository(123 as any)).toBe(false);
      expect(validateRepository({} as any)).toBe(false);
    });
  });
});

describe('Username Validation', () => {
  describe('Valid usernames should pass', () => {
    test.each(VALID_TEST_CASES.usernames)('accepts valid username: %s', (username) => {
      expect(validateUsername(username)).toBe(true);
    });

    test('accepts minimum length (1 char)', () => {
      expect(validateUsername('a')).toBe(true);
      expect(validateUsername('A')).toBe(true);
      expect(validateUsername('1')).toBe(true);
    });

    test('accepts maximum length (39 chars)', () => {
      expect(validateUsername('a'.repeat(39))).toBe(true);
    });

    test('accepts hyphens in middle', () => {
      expect(validateUsername('user-name')).toBe(true);
      expect(validateUsername('a-b-c-d')).toBe(true);
    });

    test('accepts numbers', () => {
      expect(validateUsername('user123')).toBe(true);
      expect(validateUsername('123user')).toBe(true);
    });

    test('accepts mixed case', () => {
      expect(validateUsername('UserName')).toBe(true);
      expect(validateUsername('uSeRnAmE')).toBe(true);
    });
  });

  describe('Invalid usernames should fail', () => {
    test.each(MALICIOUS_TEST_CASES.usernames)('rejects malicious username: %s', (username) => {
      expect(validateUsername(username)).toBe(false);
    });

    test('rejects empty string', () => {
      expect(validateUsername('')).toBe(false);
    });

    test('rejects whitespace-only string', () => {
      expect(validateUsername('   ')).toBe(false);
    });

    test('rejects username with leading whitespace', () => {
      expect(validateUsername(' username')).toBe(false);
    });

    test('rejects username with trailing whitespace', () => {
      expect(validateUsername('username ')).toBe(false);
    });

    test('rejects username too long (> 39 chars)', () => {
      expect(validateUsername('a'.repeat(40))).toBe(false);
      expect(validateUsername('a'.repeat(100))).toBe(false);
    });

    test('rejects username starting with hyphen', () => {
      expect(validateUsername('-username')).toBe(false);
      expect(validateUsername('-')).toBe(false);
    });

    test('rejects username ending with hyphen', () => {
      expect(validateUsername('username-')).toBe(false);
    });

    test('rejects consecutive hyphens', () => {
      expect(validateUsername('user--name')).toBe(false);
      expect(validateUsername('a--b')).toBe(false);
    });

    test('rejects special characters', () => {
      expect(validateUsername('user@example.com')).toBe(false);
      expect(validateUsername('user.name')).toBe(false);
      expect(validateUsername('user_name')).toBe(false);
      expect(validateUsername('user!name')).toBe(false);
    });

    test('rejects spaces', () => {
      expect(validateUsername('user name')).toBe(false);
    });

    test('rejects semicolon (command injection)', () => {
      expect(validateUsername('user; curl evil.com')).toBe(false);
    });

    test('rejects ampersand (command injection)', () => {
      expect(validateUsername('user && whoami')).toBe(false);
    });

    test('rejects pipe (command injection)', () => {
      expect(validateUsername('user | cat /etc/passwd')).toBe(false);
    });

    test('rejects null byte', () => {
      expect(validateUsername('user\0name')).toBe(false);
    });

    test('rejects control characters', () => {
      expect(validateUsername('user\nname')).toBe(false);
      expect(validateUsername('user\rname')).toBe(false);
      expect(validateUsername('user\tname')).toBe(false);
    });

    test('rejects path traversal', () => {
      expect(validateUsername('../../../etc')).toBe(false);
    });

    test('rejects Unicode characters (homograph attack)', () => {
      expect(validateUsername('usеr')).toBe(false); // Cyrillic 'е'
    });

    test('rejects non-ASCII characters', () => {
      expect(validateUsername('user™')).toBe(false);
      expect(validateUsername('user©')).toBe(false);
    });

    test('rejects null input', () => {
      expect(validateUsername(null as any)).toBe(false);
    });

    test('rejects undefined input', () => {
      expect(validateUsername(undefined as any)).toBe(false);
    });

    test('rejects non-string input', () => {
      expect(validateUsername(123 as any)).toBe(false);
      expect(validateUsername({} as any)).toBe(false);
    });
  });
});

describe('GitHub URL Validation', () => {
  describe('Valid URLs should pass', () => {
    test('accepts github.com PR URL', () => {
      expect(validateGitHubURL('https://github.com/facebook/react/pull/123')).toBe(true);
    });

    test('accepts github.com issue URL', () => {
      expect(validateGitHubURL('https://github.com/owner/repo/issues/456')).toBe(true);
    });

    test('accepts github.com repo URL', () => {
      expect(validateGitHubURL('https://github.com/owner/repo')).toBe(true);
    });

    test('accepts www.github.com URLs', () => {
      expect(validateGitHubURL('https://www.github.com/owner/repo')).toBe(true);
    });
  });

  describe('Invalid URLs should fail', () => {
    test('rejects empty string', () => {
      expect(validateGitHubURL('')).toBe(false);
    });

    test('rejects non-GitHub domain', () => {
      expect(validateGitHubURL('https://evil.com/owner/repo')).toBe(false);
    });

    test('rejects http:// (not HTTPS)', () => {
      expect(validateGitHubURL('http://github.com/owner/repo')).toBe(false);
    });

    test('rejects file:// protocol', () => {
      expect(validateGitHubURL('file:///etc/passwd')).toBe(false);
    });

    test('rejects javascript: protocol', () => {
      expect(validateGitHubURL('javascript:alert(1)')).toBe(false);
    });

    test('rejects data: protocol', () => {
      expect(validateGitHubURL('data:text/html,<script>alert(1)</script>')).toBe(false);
    });

    test('rejects GitHub subdomain (not github.com)', () => {
      expect(validateGitHubURL('https://api.github.com/repos/owner/repo')).toBe(false);
    });

    test('rejects path traversal', () => {
      expect(validateGitHubURL('https://github.com/../../etc/passwd')).toBe(false);
    });

    test('rejects null byte', () => {
      expect(validateGitHubURL('https://github.com/owner/repo\0')).toBe(false);
    });

    test('rejects malformed URL', () => {
      expect(validateGitHubURL('not a url')).toBe(false);
    });

    test('rejects null input', () => {
      expect(validateGitHubURL(null as any)).toBe(false);
    });
  });
});

describe('Check Interval Validation', () => {
  test('accepts valid intervals', () => {
    expect(validateCheckInterval(1)).toBe(true);
    expect(validateCheckInterval(15)).toBe(true);
    expect(validateCheckInterval(60)).toBe(true);
    expect(validateCheckInterval(1440)).toBe(true);
  });

  test('rejects zero', () => {
    expect(validateCheckInterval(0)).toBe(false);
  });

  test('rejects negative numbers', () => {
    expect(validateCheckInterval(-1)).toBe(false);
    expect(validateCheckInterval(-100)).toBe(false);
  });

  test('rejects too large', () => {
    expect(validateCheckInterval(1441)).toBe(false);
    expect(validateCheckInterval(10000)).toBe(false);
  });

  test('rejects floats', () => {
    expect(validateCheckInterval(15.5)).toBe(false);
  });

  test('rejects non-numbers', () => {
    expect(validateCheckInterval('15' as any)).toBe(false);
    expect(validateCheckInterval(NaN)).toBe(false);
  });
});
