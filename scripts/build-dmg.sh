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

# Create compressed DMG directly from staging folder
DMG_PATH="$BUILD_DIR/$DMG_NAME-$VERSION.dmg"
rm -f "$DMG_PATH"

echo "Creating DMG..."

hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "Done: $DMG_PATH ($DMG_SIZE)"
