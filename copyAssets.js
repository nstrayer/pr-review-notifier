const fs = require('fs');
const path = require('path');

// Create dist/assets directory if it doesn't exist
const distAssetsDir = path.join(__dirname, 'dist', 'assets');
if (!fs.existsSync(distAssetsDir)) {
  fs.mkdirSync(distAssetsDir, { recursive: true });
}

// Copy assets files to dist folder
const srcAssetsPath = path.join(__dirname, 'assets');
fs.readdirSync(srcAssetsPath).forEach(file => {
  if (file !== '.DS_Store') { // Skip .DS_Store files
    fs.copyFileSync(
      path.join(srcAssetsPath, file),
      path.join(distAssetsDir, file)
    );
    console.log(`Copied asset: ${file}`);
  }
});

// Also copy the SVG icon from the root if it exists
const svgIconPath = path.join(__dirname, 'simple-icon-template.svg');
if (fs.existsSync(svgIconPath)) {
  fs.copyFileSync(
    svgIconPath,
    path.join(distAssetsDir, 'simple-icon-template.svg')
  );
  console.log('Copied SVG icon from root');
}

// Also copy our newly created SVG icon
const newSvgIconPath = path.join(__dirname, 'assets', 'tray-icon-template.svg');
if (fs.existsSync(newSvgIconPath)) {
  fs.copyFileSync(
    newSvgIconPath,
    path.join(distAssetsDir, 'tray-icon-template.svg')
  );
  console.log('Copied tray icon SVG');
}

console.log(`Copied assets to ${distAssetsDir}`);