require('dotenv').config();
const { notarize } = require('electron-notarize');
const path = require('path');

exports.default = async function notarizing(context) {
  // Log all context properties to help debug
  console.log('Notarization context:', {
    electronPlatformName: context.electronPlatformName,
    appOutDir: context.appOutDir,
    packager: {
      platform: context.packager.platform,
      platformName: context.packager.platformName,
      config: context.packager.config ? 'Exists' : 'Missing',
      appInfo: context.packager.appInfo ? {
        productFilename: context.packager.appInfo.productFilename,
        productName: context.packager.appInfo.productName,
      } : 'Missing'
    }
  });

  const { electronPlatformName, appOutDir } = context;  
  if (electronPlatformName !== 'darwin') {
    console.log('Skipping notarization: Not macOS platform');
    return;
  }

  console.log('Notarizing app...');
  console.log('Environment variables status:',
    `APPLE_ID: ${process.env.APPLE_ID ? 'Set' : 'Not set'}`,
    `APPLE_APP_SPECIFIC_PASSWORD: ${process.env.APPLE_APP_SPECIFIC_PASSWORD ? 'Set' : 'Not set'}`,
    `APPLE_TEAM_ID: ${process.env.APPLE_TEAM_ID ? 'Set' : 'Not set'}`
  );
  
  if (!context.packager || !context.packager.appInfo) {
    console.error('Missing packager or appInfo in context. Cannot proceed with notarization.');
    return;
  }

  const appName = context.packager.appInfo.productFilename;
  if (!appName) {
    console.error('Missing productFilename in appInfo. Cannot proceed with notarization.');
    return;
  }

  const appPath = path.join(appOutDir, `${appName}.app`);
  console.log(`App path for notarization: ${appPath}`);
  
  if (!process.env.APPLE_ID || !process.env.APPLE_APP_SPECIFIC_PASSWORD || !process.env.APPLE_TEAM_ID) {
    console.error('Required environment variables for notarization are missing. Skipping notarization.');
    console.error('APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID must be set in your .env file.');
    return;
  }

  try {
    console.log('Starting notarization process...');
    await notarize({
      tool: 'notarytool',
      appPath,
      appleId: process.env.APPLE_ID,
      appleIdPassword: process.env.APPLE_APP_SPECIFIC_PASSWORD,
      teamId: process.env.APPLE_TEAM_ID,
    });
    console.log('Notarization complete!');
  } catch (error) {
    console.error('Notarization failed:', error);
    throw error;
  }
}; 