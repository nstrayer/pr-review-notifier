#!/usr/bin/env node

/**
 * This script checks if the environment variables needed for notarization 
 * are loaded correctly from the .env file
 */

require('dotenv').config();
console.log('Environment variables check:');
console.log('------------------------');
console.log(`APPLE_ID: ${process.env.APPLE_ID || 'Not set'}`);
console.log(`APPLE_APP_SPECIFIC_PASSWORD: ${process.env.APPLE_APP_SPECIFIC_PASSWORD ? 'Set (value hidden)' : 'Not set'}`);
console.log(`APPLE_TEAM_ID: ${process.env.APPLE_TEAM_ID || 'Not set'}`);
console.log('------------------------');

if (!process.env.APPLE_ID || !process.env.APPLE_APP_SPECIFIC_PASSWORD || !process.env.APPLE_TEAM_ID) {
  console.error('❌ One or more required environment variables are missing.');
  console.error('Make sure your .env file is in the root directory and contains all required variables.');
} else {
  console.log('✅ All required environment variables are set.');
} 