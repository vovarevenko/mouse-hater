# Mouse Hater App Store Release Checklist

This project is a SwiftPM-built macOS menu-bar app assembled into
`build/Mouse Hater.app` by `build.sh`.

## Current Release Shape

- Bundle ID: `org.revenko.mouse-hater`
- App name: `Mouse Hater`
- App category: `public.app-category.utilities`
- Minimum macOS: `13.0`
- Architecture: `arm64` Apple Silicon only
- Version: `1.0`
- Build: `1`
- App icon: `Resources/MouseHater.icns`
- Sandbox entitlements: `Resources/MouseHater.entitlements`
- Privacy manifest: `Resources/PrivacyInfo.xcprivacy`
- App Store package helper: `scripts/package-app-store.sh`

## Local Preflight

Run before packaging:

```sh
swift test
SANDBOX=1 ./build.sh release
codesign --verify --strict --verbose=2 "build/Mouse Hater.app"
plutil -lint Resources/Info.plist Resources/MouseHater.entitlements Resources/PrivacyInfo.xcprivacy
```

The release build is Apple Silicon only. Verify the binary architecture with:

```sh
lipo -archs "build/Mouse Hater.app/Contents/MacOS/MouseHater"
```

Expected output:

```text
arm64
```

## App Store Package

Install or create the needed signing certificates in Xcode / Apple Developer
before running this. Certificate display names vary by account age; App Store
macOS builds commonly use an app-signing identity such as `Apple Distribution`
or `3rd Party Mac Developer Application`, and a package-signing identity such as
`3rd Party Mac Developer Installer` / Mac installer distribution.

You also need a Mac App Store provisioning profile for bundle ID
`org.revenko.mouse-hater`. Download it from the Apple Developer portal and keep
it outside the repository, for example in `~/Downloads/MouseHater.provisionprofile`.

List identities:

```sh
security find-identity -p codesigning -v
security find-certificate -a -p | openssl x509 -noout -subject | grep -E "Apple Distribution|3rd Party Mac Developer|Installer"
```

Build the uploadable package:

```sh
APP_SIGN_IDENTITY="Apple Distribution: YOUR NAME (TEAMID)" \
INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: YOUR NAME (TEAMID)" \
TEAM_ID="TEAMID" \
PROVISIONING_PROFILE="$HOME/Downloads/MouseHater.provisionprofile" \
./scripts/package-app-store.sh
```

The output package is:

```text
build/Mouse Hater.pkg
```

## App Store Connect Metadata Draft

Use this as a starting point, then adjust wording before submission.

Name:

```text
Mouse Hater
```

Subtitle:

```text
Keyboard mouse control
```

Primary category:

```text
Utilities
```

Short promotional text:

```text
Click anywhere on your Mac using only the keyboard.
```

Description:

```text
Mouse Hater is a macOS menu-bar utility for controlling the mouse from the
keyboard on Apple Silicon Macs.

Tap Command to open a labeled grid over the screen, type a short key sequence to
narrow the target, and click without reaching for a mouse or trackpad. For small
targets, hold the final key to nudge the click point before release.

Mouse Hater is designed to stay out of the way: it has no Dock icon, lives in
the menu bar, and can launch at login so it is ready when you start your Mac.

Features:
- Keyboard-driven left and right clicks
- Fast grid-based targeting
- Fine nudge mode for precise clicks
- Single-tap or double-tap Command trigger
- Menu-bar status and keyboard guide
- Local-only preferences, no accounts, no analytics, no tracking

Mouse Hater requires macOS Accessibility permission so it can detect the global
keyboard trigger and synthesize clicks.
```

Keywords draft (keep within App Store Connect's limit):

```text
mouse,keyboard,click,cursor,accessibility,utility,productivity
```

Copyright:

```text
Copyright © 2026 Vova Revenko
```

Support URL:

```text
TODO: publish support page URL
```

Privacy Policy URL:

```text
TODO: publish PRIVACY.md somewhere public and use that URL
```

## App Privacy Answers

Based on the current code:

- Tracking: No
- Data collection: No data collected
- Third-party SDKs: None
- Analytics: None
- Advertising: None
- Accounts/login: None
- Network features: None

The app stores local preferences with UserDefaults only. This is declared in
`Resources/PrivacyInfo.xcprivacy` under
`NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.

## Review Notes Draft

Paste into App Review notes and adjust if needed:

```text
Mouse Hater is a macOS menu-bar accessibility utility for keyboard-driven mouse
clicking.

The app requires Accessibility permission to detect the global Command-key
trigger and to synthesize mouse clicks. It does not collect data, does not use
networking, does not include analytics or ads, and does not track users.

The app has no Dock icon because it is an LSUIElement menu-bar utility. After
launch, use the cursor icon in the menu bar. On first launch it registers as
Open at Login once because the utility is intended to be available whenever the
user starts the Mac. Users can disable or re-enable Open at Login from the
status-bar menu or System Settings.

Test steps:
1. Launch Mouse Hater.
2. Grant Accessibility permission in System Settings when prompted.
3. Tap Command to show the grid overlay.
4. Type a column key, row key, and final target key to click.
5. Use the menu-bar icon to open the keyboard guide, change trigger mode, or quit.
```

## Screenshot Plan

App Store Connect will require macOS screenshots. Capture clean screenshots on a
Mac after a release build:

1. Menu-bar menu open, showing Trigger, Open at Login, Keyboard guide,
   Accessibility, and Quit.
2. Grid overlay visible on a normal desktop/app window.
3. Keyboard guide dialog.
4. Optional: nudge/crosshair mode if it is visually clear.

Avoid screenshots that show private files, accounts, notifications, or unrelated
apps. Use a plain desktop or a neutral test window behind the overlay.

## Upload And Submit

1. Create the app record in App Store Connect for macOS with bundle ID
   `org.revenko.mouse-hater`.
2. Fill app information, pricing/availability, privacy answers, age rating,
   support URL, privacy policy URL, screenshots, and review notes.
3. Build `build/Mouse Hater.pkg` with `scripts/package-app-store.sh`.
4. Upload the package with Transporter.
5. Wait for App Store Connect processing to finish.
6. Select the processed build/package on the app version page.
7. Submit for review.

Keep `CFBundleShortVersionString` and `CFBundleVersion` increasing for every
submitted build.
