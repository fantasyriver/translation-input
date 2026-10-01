#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_BIN="${SWIFT_BIN:-swift}"
"$SWIFT_BIN" build --package-path "$PROJECT_DIR/macos" -c release --product TranslationInput
BIN_DIR="$("$SWIFT_BIN" build --package-path "$PROJECT_DIR/macos" -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/TranslationInput.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/TranslationInput" "$APP_DIR/Contents/MacOS/TranslationInput"
cp "$PROJECT_DIR/macos/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
 codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
 codesign --force --sign - "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
