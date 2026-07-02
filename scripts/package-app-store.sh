#!/usr/bin/env bash
# Copyright © 2026 Vova Revenko
#
# Builds a sandboxed Mac App Store package from the SwiftPM app bundle.
#
# Required environment:
#   APP_SIGN_IDENTITY       App signing certificate name/hash
#   INSTALLER_SIGN_IDENTITY Installer/package signing certificate name/hash
#   TEAM_ID                 Apple Developer Team ID
#   PROVISIONING_PROFILE    Mac App Store provisioning profile path
#
# Optional environment:
#   ARCHS                   Defaults to arm64; x86_64/Intel is not supported
#   PKG_PATH                Defaults to build/Mouse Hater.pkg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/Mouse Hater.app"
PKG_PATH="${PKG_PATH:-$ROOT/build/Mouse Hater.pkg}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-${SIGN_IDENTITY:-}}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"
ARCHS="${ARCHS:-arm64}"
APP_STORE_ENTITLEMENTS="$ROOT/build/MouseHater.AppStore.entitlements"

if [ -z "$APP_SIGN_IDENTITY" ]; then
  echo "APP_SIGN_IDENTITY is required (for example: Apple Distribution: Your Name (TEAMID))" >&2
  exit 64
fi

if [ -z "$INSTALLER_SIGN_IDENTITY" ]; then
  echo "INSTALLER_SIGN_IDENTITY is required (for example: 3rd Party Mac Developer Installer: Your Name (TEAMID))" >&2
  exit 64
fi

if [ -z "$TEAM_ID" ]; then
  echo "TEAM_ID is required (for example: S4J844GX39)" >&2
  exit 64
fi

if [ -z "$PROVISIONING_PROFILE" ] || [ ! -f "$PROVISIONING_PROFILE" ]; then
  echo "PROVISIONING_PROFILE is required and must point to a Mac App Store provisioning profile" >&2
  exit 64
fi

mkdir -p "$ROOT/build"
cat >"$APP_STORE_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.application-identifier</key>
	<string>$TEAM_ID.org.revenko.mouse-hater</string>
	<key>com.apple.developer.team-identifier</key>
	<string>$TEAM_ID</string>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>
PLIST

echo "==> Building sandboxed app bundle for App Store"
ARCHS="$ARCHS" \
SANDBOX=1 \
SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
ENTITLEMENTS="$APP_STORE_ENTITLEMENTS" \
PROVISIONING_PROFILE="$PROVISIONING_PROFILE" \
"$ROOT/build.sh" "$CONFIG"

echo "==> Verifying app bundle"
codesign --verify --strict --verbose=2 "$APP"
if ! codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox"; then
  echo "Missing com.apple.security.app-sandbox entitlement in $APP" >&2
  exit 1
fi
if ! codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.application-identifier"; then
  echo "Missing com.apple.application-identifier entitlement in $APP" >&2
  exit 1
fi
if [ ! -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" ]; then
  echo "Missing PrivacyInfo.xcprivacy in $APP" >&2
  exit 1
fi
if [ ! -f "$APP/Contents/embedded.provisionprofile" ]; then
  echo "Missing embedded provisioning profile in $APP" >&2
  exit 1
fi

echo "==> Bundle architectures"
lipo -archs "$APP/Contents/MacOS/MouseHater"

echo "==> Building signed App Store package"
rm -f "$PKG_PATH"
productbuild \
  --component "$APP" /Applications \
  --sign "$INSTALLER_SIGN_IDENTITY" \
  --timestamp \
  "$PKG_PATH"

echo "==> Verifying package signature"
pkgutil --check-signature "$PKG_PATH"
if spctl --assess --type install "$PKG_PATH" >/dev/null 2>&1; then
  echo "==> Package passes local install assessment"
else
  echo "==> Package did not pass local spctl install assessment; App Store upload may still provide more specific validation"
fi

echo "==> Done: $PKG_PATH"
echo "    Upload this package with Transporter or App Store Connect tooling."
