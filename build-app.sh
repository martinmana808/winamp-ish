#!/bin/bash
# Builds Winamp-ish.app (universal) into ./build, plus a zip for distribution.
# Pass --install to also copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64

APP=build/Winamp-ish.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/Winamp "$APP/Contents/MacOS/Winamp"

# Icon
SRC=Sources/Winamp/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -s format png -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -s format png -z $((s * 2)) $((s * 2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Winamp-ish</string>
  <key>CFBundleDisplayName</key><string>Winamp-ish</string>
  <key>CFBundleIdentifier</key><string>com.martinmana.winamp</string>
  <key>CFBundleExecutable</key><string>Winamp</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Audio</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.audio</string>
        <string>public.m3u-playlist</string>
        <string>public.folder</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Winamp-ish.zip
echo "Built $APP and build/Winamp-ish.zip"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Winamp.app /Applications/Winamp-ish.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Winamp-ish.app"
fi
