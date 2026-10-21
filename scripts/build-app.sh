#!/bin/bash
# Builds Catification.app into ./build, ad-hoc signed.
#
#   scripts/build-app.sh [--universal] [--version X.Y.Z] [--debug]
#
#   --universal   arm64 + x86_64 binary (needs Xcode, not just Command Line Tools)
#   --version     version shown in Finder/About (default 0.0.0-dev; CI passes the tag)
#   --debug       debug configuration instead of release
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=release
UNIVERSAL=0
VERSION="0.0.0-dev"
while [ $# -gt 0 ]; do
    case "$1" in
        --universal) UNIVERSAL=1 ;;
        --version) VERSION="$2"; shift ;;
        --debug) CONFIG=debug ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

ARCH_FLAGS=()
if [ "$UNIVERSAL" = 1 ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
BIN="$BIN_DIR/Catification"

APP="build/Catification.app"
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Catification"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

"$BIN" --render-icon build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# CFBundleVersion must be plain numbers, so drop any "-rc.1"-style suffix.
BUILD_NUMBER="${VERSION%%-*}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Catification</string>
    <key>CFBundleDisplayName</key>
    <string>Catification</string>
    <key>CFBundleIdentifier</key>
    <string>dev.catification.app</string>
    <key>CFBundleExecutable</key>
    <string>Catification</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.entertainment</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP ($VERSION, $CONFIG$([ "$UNIVERSAL" = 1 ] && echo ", universal"))"
