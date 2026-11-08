#!/bin/sh
set -e
APP=Junkdrawer
ID=junkdrawer.junkdrawer
VERSION=0.1.0
BUILD=1
# A stable identity keeps the Accessibility grant across builds. Create it once
# in Keychain Access: Certificate Assistant, Create a Certificate, Code Signing.
SIGN_ID="${SIGN_ID:-junkdrawer local}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/junkdrawer"

OUT="build/$APP.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP"
if [ -f Resources/symbols.tsv ]; then cp Resources/symbols.tsv "$OUT/Contents/Resources/"; fi

cat > "$OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>Copyright (c) junkdrawer Contributors, MIT License</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning | grep -q "\"$SIGN_ID\""; then
   codesign --force --sign "$SIGN_ID" "$OUT"
else
   echo "warning: no code-signing identity \"$SIGN_ID\", signing ad hoc; the Accessibility grant will reset on every build" >&2
   codesign --force --sign - "$OUT"
fi
echo "Built $OUT"
