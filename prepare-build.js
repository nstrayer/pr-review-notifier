#!/usr/bin/env node

/**
 * This script prepares a tailored electron-builder configuration for GitHub Actions
 * It creates a simplified version that is more compatible with the GitHub Actions environment
 */

const fs = require('fs');
const path = require('path');

// Read the original package.json
const packageJsonPath = path.join(__dirname, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

// Create a simplified build configuration for GitHub Actions
const githubBuildConfig = {
  ...packageJson.build,
  mac: {
    ...packageJson.build.mac,
    hardenedRuntime: true,
    gatekeeperAssess: false,
    entitlements: "build/entitlements.github.plist",
    entitlementsInherit: "build/entitlements.github.plist",
    notarize: true
  }
};

// Update the package.json with the GitHub-specific configuration
packageJson.build = githubBuildConfig;

// Write the updated package.json
fs.writeFileSync(
  path.join(__dirname, 'package.github.json'), 
  JSON.stringify(packageJson, null, 2)
);

console.log('✅ Created GitHub-specific build configuration in package.github.json');

// Also create a simplified entitlements file if it doesn't exist
const githubEntitlementsPath = path.join(__dirname, 'build', 'entitlements.github.plist');
if (!fs.existsSync(githubEntitlementsPath)) {
  const entitlements = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <true/>
  <key>com.apple.security.cs.debugger</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.network.server</key>
  <true/>
  <key>com.apple.security.automation.apple-events</key>
  <true/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
  <key>com.apple.security.cs.allow-dyld-environment-variables</key>
  <true/>
</dict>
</plist>`;
  fs.writeFileSync(githubEntitlementsPath, entitlements);
  console.log('✅ Created GitHub-specific entitlements file');
} 