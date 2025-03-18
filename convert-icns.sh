#!/bin/bash

# Create iconset directory
mkdir -p build/icon.iconset

# Copy your PNG files to the iconset directory with the correct names
# Replace these with your actual icon files
cp icon_16x16.png build/icon.iconset/icon_16x16.png
cp icon_32x32.png build/icon.iconset/icon_16x16@2x.png
cp icon_32x32.png build/icon.iconset/icon_32x32.png
cp icon_64x64.png build/icon.iconset/icon_32x32@2x.png
cp icon_128x128.png build/icon.iconset/icon_128x128.png
cp icon_256x256.png build/icon.iconset/icon_128x128@2x.png
cp icon_256x256.png build/icon.iconset/icon_256x256.png
cp icon_512x512.png build/icon.iconset/icon_256x256@2x.png
cp icon_512x512.png build/icon.iconset/icon_512x512.png
cp icon_1024x1024.png build/icon.iconset/icon_512x512@2x.png

# Convert to icns
iconutil -c icns build/icon.iconset -o build/icon.icns 