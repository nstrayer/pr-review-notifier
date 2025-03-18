/*---------------------------------------------------------------------------------------------
 *  Copyright (C) 2024 Posit Software, PBC. All rights reserved.
 *  Licensed under the Elastic License 2.0. See LICENSE.txt for license information.
 *--------------------------------------------------------------------------------------------*/

/**
 * This script optimizes the build before packaging by removing unnecessary files
 * to reduce the final app size
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Directories to clean up
const foldersToRemove = [
  'node_modules/electron/dist/chrome-sandbox',
  'node_modules/electron/dist/Electron.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libEGL.dylib',
  'node_modules/electron/dist/Electron.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libGLESv2.dylib',
  'node_modules/electron/dist/Electron.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/v8_context_snapshot_data',
  'node_modules/electron/dist/Electron.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/icudtl.dat',
  'node_modules/electron/dist/ffmpeg',
  'node_modules/@octokit/rest/node_modules',
  'node_modules/.cache'
];

// Extensions of files to remove
const extensionsToRemove = [
  '.md', '.markdown', '.ts', '.map', '.flow', '.jst', '.coffee', '.patch', 
  '.jake', '.jsm', '.sjs', '.uncompressed.js', '.hard', '.gyp', '.c', '.h', '.cc', '.cpp'
];

// Run npm prune to remove dev dependencies
console.log('🧹 Removing dev dependencies...');
execSync('npm prune --production', { stdio: 'inherit' });

// Remove specific folders
console.log('🗑️ Removing unnecessary folders...');
foldersToRemove.forEach(folder => {
  const folderPath = path.join(process.cwd(), folder);
  if (fs.existsSync(folderPath)) {
    console.log(`  Removing: ${folder}`);
    try {
      if (fs.lstatSync(folderPath).isDirectory()) {
        fs.rmSync(folderPath, { recursive: true, force: true });
      } else {
        fs.unlinkSync(folderPath);
      }
    } catch (err) {
      console.error(`  Error removing ${folder}:`, err.message);
    }
  }
});

console.log('✅ Build optimization complete!'); 