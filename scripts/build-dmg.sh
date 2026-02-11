#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../PRNotifier"
BUILD_DIR="$SCRIPT_DIR/../build"
APP_NAME="PRNotifier"
DMG_NAME="PRNotifier"

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
if [ -z "$VERSION" ]; then
    VERSION="0.0.0"
fi

echo "Building $APP_NAME v$VERSION..."

# Clean previous build artifacts
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -arch arm64 \
    -arch x86_64 \
    clean build \
    | tail -5

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_NAME.app not found at $APP_PATH"
    exit 1
fi

echo "App built at $APP_PATH"

# Create DMG staging area
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -a "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
DMG_PATH="$BUILD_DIR/$DMG_NAME-$VERSION.dmg"
DMG_TEMP="$BUILD_DIR/$DMG_NAME-temp.dmg"
rm -f "$DMG_PATH" "$DMG_TEMP"

echo "Creating DMG..."

# Create a temporary read-write DMG
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size 200m \
    "$DMG_TEMP" \
    -quiet

# Mount the temporary DMG
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify -quiet | grep '/Volumes/' | awk '{print $3}')

# Set Finder window layout via AppleScript
# This configures the drag-to-Applications layout users expect
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 640, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "$APP_NAME.app" of container window to {130, 150}
        set position of item "Applications" of container window to {410, 150}
        close
    end tell
end tell
APPLESCRIPT

# Let Finder finish writing .DS_Store
sync
sleep 1

# Unmount
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet
rm -f "$DMG_TEMP"

# Clean up staging
rm -rf "$STAGING_DIR"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "Done: $DMG_PATH ($DMG_SIZE)"
