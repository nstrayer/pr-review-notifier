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
// When using --config flag, electron-builder expects just the configuration object, not wrapped in "build" property
const githubBuildConfig = {
  appId: packageJson.build.appId,
  productName: packageJson.build.productName,
  asar: packageJson.build.asar,
  afterSign: "./notarize.js",
  files: packageJson.build.files,
  mac: {
    category: packageJson.build.mac.category,
    target: packageJson.build.mac.target,
    icon: packageJson.build.mac.icon,
    darkModeSupport: packageJson.build.mac.darkModeSupport,
    hardenedRuntime: true,
    gatekeeperAssess: false,
    entitlements: "build/entitlements.github.plist",
    entitlementsInherit: "build/entitlements.github.plist",
    notarize: true
  },
  directories: packageJson.build.directories
};

// Write the configuration file
fs.writeFileSync(
  path.join(__dirname, 'electron-builder.json'), 
  JSON.stringify(githubBuildConfig, null, 2)
);

console.log('✅ Created GitHub-specific build configuration in electron-builder.json');

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