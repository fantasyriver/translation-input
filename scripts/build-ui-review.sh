#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_APP="$PROJECT_DIR/dist/UIReview.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS"
REVIEW_BUILD="$PROJECT_DIR/dist/ui-review-build"
mkdir -p "$REVIEW_BUILD"
# Build the core module separately; the preview links the same delivery coordinator.
swiftc -swift-version 5 -parse-as-library -emit-module -emit-library -static -module-name TranslationCore \
 "$PROJECT_DIR"/macos/Sources/TranslationCore/*.swift \
 -emit-module-path "$REVIEW_BUILD/TranslationCore.swiftmodule" -o "$REVIEW_BUILD/libTranslationCore.a"
sed '/^@main struct TranslationInputMain/,$d' "$PROJECT_DIR/macos/Sources/TranslationInput/App.swift" > "$REVIEW_BUILD/ReviewApp.swift"
cat "$PROJECT_DIR/macos/Tests/UIReview/Preview.swift" >> "$REVIEW_BUILD/ReviewApp.swift"
SOURCES=()
for SOURCE in "$PROJECT_DIR"/macos/Sources/TranslationInput/*.swift; do
 case "$(basename "$SOURCE")" in App.swift|Credentials.swift) ;; *) SOURCES+=("$SOURCE") ;; esac
done
swiftc -swift-version 5 -parse-as-library -I "$REVIEW_BUILD" -L "$REVIEW_BUILD" -lTranslationCore \
 "${SOURCES[@]}" "$REVIEW_BUILD/ReviewApp.swift" -o "$PREVIEW_APP/Contents/MacOS/UIReview"
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
