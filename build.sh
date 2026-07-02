#!/usr/bin/env bash
# Copyright © 2026 Vova Revenko
#
# Builds Mouse Hater and assembles a runnable .app bundle under ./build.
# Usage: ./build.sh [debug|release]   (default: release)
#
# For a Mac App Store sandbox smoke test:
#   SANDBOX=1 ./build.sh release
#
# Mouse Hater is released for Apple Silicon Macs only:
#   ARCHS=arm64 ./build.sh release
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
ARCHS="${ARCHS:-arm64}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-13.0}"
APP="$ROOT/build/Mouse Hater.app"
LEGACY_APP="$ROOT/build/MouseHater.app"
INFO_PLIST="$ROOT/Resources/Info.plist"
ICON_FILE="$ROOT/Resources/MouseHater.icns"
PRIVACY_INFO="$ROOT/Resources/PrivacyInfo.xcprivacy"
ENTITLEMENTS="$ROOT/Resources/MouseHater.entitlements"
USE_SANDBOX=false

case "$CONFIG" in
  debug|release) ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

case "${SANDBOX:-0}" in
  1|true|TRUE|yes|YES) USE_SANDBOX=true ;;
  0|false|FALSE|no|NO) ;;
  *)
    echo "SANDBOX must be 0 or 1" >&2
    exit 64
    ;;
esac

ARCH_LIST=()
if [ -n "$ARCHS" ]; then
  for arch in ${ARCHS//,/ }; do
    case "$arch" in
      arm64) ARCH_LIST+=("$arch") ;;
      *)
        echo "Unsupported ARCHS value '$arch' (Mouse Hater release builds support arm64 only)" >&2
        exit 64
        ;;
    esac
  done
fi

echo "==> swift build -c $CONFIG"
BINARIES=()
for arch in "${ARCH_LIST[@]}"; do
  triple="$arch-apple-macosx$MACOS_DEPLOYMENT_TARGET"
  scratch="$ROOT/.build/$CONFIG-$arch"

  echo "==> swift build -c $CONFIG --triple $triple"
  BIN_DIR="$(swift build --package-path "$ROOT" -c "$CONFIG" --triple "$triple" --scratch-path "$scratch" --show-bin-path)"
  swift build --package-path "$ROOT" -c "$CONFIG" --triple "$triple" --scratch-path "$scratch"

  BIN="$BIN_DIR/MouseHater"
  if [ ! -x "$BIN" ]; then
    echo "Built executable not found: $BIN" >&2
    exit 1
  fi
  BINARIES+=("$BIN")
done

echo "==> Validating Info.plist"
plutil -lint "$INFO_PLIST" >/dev/null
plutil -lint "$PRIVACY_INFO" >/dev/null
if [ ! -f "$ICON_FILE" ]; then
  echo "App icon not found: $ICON_FILE" >&2
  exit 1
fi
if $USE_SANDBOX; then
  echo "==> Validating sandbox entitlements"
  plutil -lint "$ENTITLEMENTS" >/dev/null
fi

echo "==> Assembling $APP"
rm -rf "$APP"
if [ "$LEGACY_APP" != "$APP" ]; then
  rm -rf "$LEGACY_APP"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "${BINARIES[0]}" "$APP/Contents/MacOS/MouseHater"
cp "$INFO_PLIST" "$APP/Contents/Info.plist"
cp "$ICON_FILE" "$APP/Contents/Resources/MouseHater.icns"
cp "$PRIVACY_INFO" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"

# Code signing. The default is ad-hoc. A stable signing identity keeps the macOS
# Accessibility grant from resetting on every rebuild (TCC tracks the identity,
# not the changing cdhash) — to use one, either export SIGN_IDENTITY, or put
#   SIGN_IDENTITY=<hash-or-name>
# in an (untracked) .signing.local next to this script.
if [ -z "${SIGN_IDENTITY:-}" ] && [ -f "$ROOT/.signing.local" ]; then
  # shellcheck disable=SC1091
  source "$ROOT/.signing.local"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [ "$SIGN_IDENTITY" != "-" ] && ! security find-identity -p codesigning 2>/dev/null | grep -Fq -- "$SIGN_IDENTITY"; then
  echo "==> Signing identity '$SIGN_IDENTITY' not found — falling back to ad-hoc"
  echo "    (Accessibility permission will reset on each rebuild.)"
  SIGN_IDENTITY="-"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "==> Ad-hoc code signing"
else
  echo "==> Code signing with stable identity ($SIGN_IDENTITY)"
fi
codesign_args=(--force --sign "$SIGN_IDENTITY" --identifier org.revenko.mouse-hater)
if $USE_SANDBOX; then
  echo "==> Applying sandbox entitlements"
  codesign_args+=(--entitlements "$ENTITLEMENTS")
fi
codesign "${codesign_args[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
echo "    Run with:  open \"$APP\""
