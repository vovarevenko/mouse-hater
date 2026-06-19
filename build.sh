#!/usr/bin/env bash
# Copyright © 2026 Vova Revenko
#
# Builds MouseHater and assembles a runnable .app bundle under ./build.
# Usage: ./build.sh [debug|release]   (default: release)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/MouseHater.app"

echo "==> swift build -c $CONFIG"
swift build --package-path "$ROOT" -c "$CONFIG"

BIN_DIR="$(swift build --package-path "$ROOT" -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/MouseHater"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MouseHater"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

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

if [ "$SIGN_IDENTITY" != "-" ] && ! security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "==> Signing identity '$SIGN_IDENTITY' not found — falling back to ad-hoc"
  echo "    (Accessibility permission will reset on each rebuild.)"
  SIGN_IDENTITY="-"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "==> Ad-hoc code signing"
else
  echo "==> Code signing with stable identity ($SIGN_IDENTITY)"
fi
codesign --force --sign "$SIGN_IDENTITY" --identifier org.revenko.mouse-hater "$APP"

echo "==> Done: $APP"
echo "    Run with:  open \"$APP\""
