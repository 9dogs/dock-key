#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/DockKey.app"
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
codesign --force --sign - "$APP"
echo "Built $APP"
