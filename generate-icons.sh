#!/bin/bash

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo "ImageMagick is not installed. Please install it first:"
    echo "brew install imagemagick"
    exit 1
fi

# Check if input files exist
if [ ! -f "icon.png" ]; then
    echo "Please place your colored icon.png file in the project root directory"
    echo "Recommended size: 1024x1024 pixels"
    exit 1
fi

if [ ! -f "icon-bw.png" ]; then
    echo "Please place your black and white icon-bw.png file in the project root directory"
    echo "Recommended size: 1024x1024 pixels"
    exit 1
fi

# Create required directories
mkdir -p build/icon.iconset
mkdir -p assets

# Generate app icons
echo "Generating app icons..."
sizes=(
    "16x16"
    "32x32"
    "64x64"
    "128x128"
    "256x256"
    "512x512"
    "1024x1024"
)

# Generate each size
for size in "${sizes[@]}"; do
    echo "Generating $size icon..."
    magick -background none icon.png -resize $size -gravity center -extent $size "build/icon.iconset/icon_${size}.png"
done

# Generate @2x versions
magick -background none icon.png -resize 32x32 -gravity center -extent 32x32 "build/icon.iconset/icon_16x16@2x.png"
magick -background none icon.png -resize 64x64 -gravity center -extent 64x64 "build/icon.iconset/icon_32x32@2x.png"
magick -background none icon.png -resize 256x256 -gravity center -extent 256x256 "build/icon.iconset/icon_128x128@2x.png"
magick -background none icon.png -resize 512x512 -gravity center -extent 512x512 "build/icon.iconset/icon_256x256@2x.png"
magick -background none icon.png -resize 1024x1024 -gravity center -extent 1024x1024 "build/icon.iconset/icon_512x512@2x.png"

# Generate menubar icons
echo "Generating menubar icons..."
magick -background none icon-bw.png -resize 18x18 -gravity center -extent 18x18 "assets/tray-icon-template.png"
magick -background none icon-bw.png -resize 36x36 -gravity center -extent 36x36 "assets/tray-icon-template@2x.png"
magick -background none icon-bw.png -resize 54x54 -gravity center -extent 54x54 "assets/tray-icon-template@3x.png"

# Verify that files were created
if [ ! -f "build/icon.iconset/icon_16x16.png" ]; then
    echo "Error: Failed to generate app icons. Please check your PNG file."
    exit 1
fi

if [ ! -f "assets/tray-icon-template.png" ]; then
    echo "Error: Failed to generate menubar icons. Please check your PNG file."
    exit 1
fi

# Convert to icns
echo "Converting to ICNS..."
iconutil -c icns build/icon.iconset -o build/icon.icns

echo "Done! All icons have been generated:"
echo "- App icon: build/icon.icns"
echo "- Menubar icons: assets/tray-icon-template.png (and @2x, @3x)" 