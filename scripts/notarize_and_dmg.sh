#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# MoveClipBoard — Notarize & DMG Builder
#
# Prerequisites:
#   1. "Developer ID Application" certificate installed in Keychain
#   2. App-specific password saved in Keychain:
#      xcrun notarytool store-credentials "MoveClipBoard-Notary" \
#        --apple-id "your@email.com" \
#        --team-id YXAC437M3K \
#        --password "xxxx-xxxx-xxxx-xxxx"
#   3. `create-dmg` installed: brew install create-dmg
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="MoveClipBoard"
BUNDLE_ID="com.erkamkucet.MoveClipBoard"
TEAM_ID="YXAC437M3K"
SIGN_IDENTITY="Developer ID Application: $TEAM_ID"
NOTARY_PROFILE="MoveClipBoard-Notary"          # keychain profile name (see above)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/build"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DMG_DIR="$PROJECT_DIR/dist"
DMG_PATH="$DMG_DIR/$APP_NAME.dmg"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "\033[34m▸ $*\033[0m"; }
success() { echo "\033[32m✓ $*\033[0m"; }
fail()    { echo "\033[31m✗ $*\033[0m" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
info "Checking prerequisites…"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || fail "No 'Developer ID Application' certificate found in Keychain.\nSee README for setup instructions."

command -v create-dmg &>/dev/null \
  || fail "'create-dmg' not found. Install with: brew install create-dmg"

mkdir -p "$DMG_DIR"

# ── 1. Build (Release) ────────────────────────────────────────────────────────
info "Building Release…"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  clean build 2>&1 | tail -5

[[ -d "$APP_PATH" ]] || fail "Build failed — $APP_PATH not found."
success "Build complete: $APP_PATH"

# ── 2. Sign ───────────────────────────────────────────────────────────────────
info "Signing with hardened runtime…"
codesign \
  --force \
  --deep \
  --sign "Developer ID Application" \
  --options runtime \
  --timestamp \
  --entitlements "$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements" \
  "$APP_PATH" 2>/dev/null || \
codesign \
  --force \
  --deep \
  --sign "Developer ID Application" \
  --options runtime \
  --timestamp \
  "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"
success "Code signing verified."

# ── 3. Create DMG ─────────────────────────────────────────────────────────────
info "Creating DMG…"
[[ -f "$DMG_PATH" ]] && rm "$DMG_PATH"

create-dmg \
  --volname "$APP_NAME" \
  --volicon "$PROJECT_DIR/$APP_NAME/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 560 400 \
  --icon-size 120 \
  --icon "$APP_NAME.app" 160 185 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 400 185 \
  "$DMG_PATH" \
  "$APP_PATH" 2>&1 | tail -3 || \
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

success "DMG created: $DMG_PATH"

# ── 4. Sign DMG ───────────────────────────────────────────────────────────────
info "Signing DMG…"
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"
success "DMG signed."

# ── 5. Notarize ───────────────────────────────────────────────────────────────
info "Submitting to Apple Notary Service (this may take 1–5 minutes)…"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --timeout 300

success "Notarization complete."

# ── 6. Staple ─────────────────────────────────────────────────────────────────
info "Stapling notarization ticket…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
success "Stapled and validated."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "  ✓ Ready to upload: $DMG_PATH"
echo "  Upload to GitHub Release:"
echo "  gh release create v1.0.0 \"$DMG_PATH\" --title \"v1.0.0\" --notes \"Initial release\""
