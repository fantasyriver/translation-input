#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_APP="$PROJECT_DIR/dist/UIReview.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS"
swiftc -swift-version 5 -parse-as-library \
 "$PROJECT_DIR/macos/Sources/TranslationInput/DesignSystem.swift" \
 "$PROJECT_DIR/macos/Sources/TranslationInput/Panel.swift" \
 "$PROJECT_DIR/macos/Sources/TranslationInput/Result.swift" \
 "$PROJECT_DIR/macos/Tests/UIReview/Preview.swift" \
 -o "$PREVIEW_APP/Contents/MacOS/UIReview"
cat > "$PREVIEW_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.translationinput.ui-review</string>
<key>CFBundleExecutable</key><string>UIReview</string>
<key>CFBundleName</key><string>UIReview</string>
<key>CFBundleDisplayName</key><string>译入 UI 预览</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$PREVIEW_APP"
printf 'Built: %s\n' "$PREVIEW_APP"
