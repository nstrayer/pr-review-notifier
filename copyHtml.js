const fs = require('fs');
const path = require('path');

// Create dist/renderer directory if it doesn't exist
const distRendererDir = path.join(__dirname, 'dist', 'renderer');
if (!fs.existsSync(distRendererDir)) {
  fs.mkdirSync(distRendererDir, { recursive: true });
}

// Copy HTML file to dist folder
const srcHtmlPath = path.join(__dirname, 'src', 'renderer', 'index.html');
const destHtmlPath = path.join(distRendererDir, 'index.html');

fs.copyFileSync(srcHtmlPath, destHtmlPath);
console.log(`Copied HTML file to ${destHtmlPath}`);