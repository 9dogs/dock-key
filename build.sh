#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/DockKey.app"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "APP_VERSION must be MAJOR.MINOR.PATCH and BUILD_NUMBER must be numeric." >&2
    exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "${TMPDIR:-/tmp}/dockkey-module-cache" Source/Dock.swift Source/main.swift -o "$APP/Contents/MacOS/DockKey" -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DockKey</string>
<key>CFBundleIdentifier</key><string>local.dockkey.app</string>
<key>CFBundleName</key><string>DockKey</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
