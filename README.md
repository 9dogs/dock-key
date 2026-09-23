# DockKey

A small native Apple Silicon macOS app that launches or focuses applications with keyboard shortcuts. Requires macOS 13 or later. Built in Swift using AppKit and SwiftUI; no third-party dependencies.

![DockKey automatic shortcuts and settings](docs/screenshot.png)

## Features

- Launch or focus pinned Dock applications with Option+1–9 and Option+0.
- Follow Dock order automatically, skipping Finder and spacers.
- Choose your modifier keys or record custom shortcuts for individual applications.
- Start at login and optionally hide the menu bar icon.

## Install and use

1. Build the app using the instructions below. Quit Snap or any other app using the same shortcuts.
2. Copy the generated `DockKey.app` to Applications (or your personal Applications folder).
3. Open DockKey. Option+1 opens the first pinned Dock app, Option+2 the second, and so on. Option+0 opens the tenth.
4. Choose any combination of Control, Option, Shift and Command in Automatic settings.
5. Optionally enable “Start DockKey at login” after moving the app to its permanent location. macOS may require approval in System Settings → General → Login Items.

Closing the settings window leaves shortcuts active. The menu bar icon opens settings and offers Quit. If you hide the icon, open the application again to show settings.

## Manual shortcuts

Choose Manual → Add Application, select an app, and press a shortcut including Control, Option or Command. Click an existing shortcut to record a replacement; Escape cancels recording. The minus button removes an entry. Manual shortcuts work alongside automatic shortcuts. Registration conflicts appear in the settings window.

## Scope and limitations

- Automatic mode follows the first ten pinned applications in the Dock. Finder, spacers, folders and documents are skipped. Temporary unpinned running apps and the Dock’s recent-apps section are not included.
- Dock order refreshes every two seconds and immediately when a numbered shortcut is used. Dock preferences are a macOS implementation detail, so future macOS changes may require an update to the reader.
- Numbered shortcuts use physical number-row key positions (1–0 on a US layout). Other layouts may show different key legends.
- Global shortcuts use RegisterEventHotKey; the application does not request Accessibility or Input Monitoring access. Shortcuts may be unavailable while macOS Secure Input is active or when reserved by another app/system feature.
- This local build has an ad-hoc code signature. It is not Developer ID signed or notarized for public distribution. No network requests, analytics, or updater are included.
- Login launch uses Apple’s SMAppService: https://developer.apple.com/documentation/servicemanagement/smappservice

## Verification

- Compiles for `arm64-apple-macosx13.0`; executable architecture and code signature checked.
- Tests cover Dock ordering, Finder exclusion, spacers, invalid entries, non-file URLs, percent-encoded paths, duplicate entries, empty Dock and reordered Dock.
- Live Dock output matched the local pinned app order.
- Both settings screens visually inspected. Adding an application, recording Control+Option+T, and removing the temporary manual entry were verified through the UI.
- Global shortcut registration reported no conflicts during the UI check. Foreground activation still requires a manual keyboard check.
- Launch at login has not been tested through a logout/login cycle.

## Build and test

On an Apple Silicon Mac, install Xcode or Apple Command Line Tools, then run:

```sh
git clone https://github.com/9dogs/dock-key.git
cd dock-key
./build.sh
./test.sh
./DockKey.app/Contents/MacOS/DockKey --check-dock
```

`build.sh` creates an Apple Silicon application bundle and signs it locally. The source, tests and build scripts are included so the app can be maintained without an external package service.
