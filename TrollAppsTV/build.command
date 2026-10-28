#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
WORKING_LOCATION="$PWD"
APPLICATION_NAME=TrollAppsTV
BUILD_LOCATION="$WORKING_LOCATION/build"
command -v ldid >/dev/null || { echo 'Install ldid first: brew install ldid' >&2; exit 1; }
mkdir -p "$BUILD_LOCATION"
swiftc "$WORKING_LOCATION/../scripts/PrepareAssets.swift" -parse-as-library -o "$BUILD_LOCATION/prepare-assets"
"$BUILD_LOCATION/prepare-assets" "$WORKING_LOCATION/TrollAppsTV/Assets.xcassets"
xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
  -scheme "$APPLICATION_NAME" -configuration Release \
  -derivedDataPath "$BUILD_LOCATION/DerivedDataApp" \
  -destination 'generic/platform=tvOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" ONLY_ACTIVE_ARCH=NO clean build
APP_PATH="$BUILD_LOCATION/DerivedDataApp/Build/Products/Release-appletvos/$APPLICATION_NAME.app"
# Refuse to package a partial build.
test -x "$APP_PATH/$APPLICATION_NAME"
python3 - "$APP_PATH/Info.plist" <<'PYBUILD'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleShortVersionString') != '0.92.2':
    raise SystemExit('Build identity mismatch: expected Lite Fix 2 / 0.92.2. Replace the complete source package.')
info['TALiteFixBuild'] = 'Lite Fix 2'
with open(sys.argv[1], 'wb') as stream:
    plistlib.dump(info, stream)
print('Verified built app identity: Lite Fix 2 / 0.92.2')
PYBUILD
STAGING_LOCATION="$(mktemp -d "$BUILD_LOCATION/package.XXXXXX")"
trap 'rm -rf "$STAGING_LOCATION"' EXIT
mkdir "$STAGING_LOCATION/Payload"
cp -R "$APP_PATH" "$STAGING_LOCATION/Payload/"
TARGET_APP="$STAGING_LOCATION/Payload/$APPLICATION_NAME.app"
if codesign -d "$TARGET_APP" >/dev/null 2>&1; then codesign --remove-signature "$TARGET_APP"; fi
rm -rf "$TARGET_APP/_CodeSignature"
rm -f "$TARGET_APP/embedded.mobileprovision"
# Preserve the entitlements required for file access and root-helper spawning.
ldid -S"$WORKING_LOCATION/entitlements.plist" "$TARGET_APP/$APPLICATION_NAME"
ldid -e "$TARGET_APP/$APPLICATION_NAME" > "$STAGING_LOCATION/signed-entitlements.plist"
python3 - "$STAGING_LOCATION/signed-entitlements.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    entitlements = plistlib.load(stream)
for key in ('com.apple.private.security.no-sandbox', 'com.apple.private.persona-mgmt'):
    if entitlements.get(key) is not True:
        raise SystemExit('Missing required entitlement: ' + key)
PY
rm -f "$BUILD_LOCATION/$APPLICATION_NAME.ipa" "$BUILD_LOCATION/$APPLICATION_NAME.tipa"
(cd "$STAGING_LOCATION" && COPYFILE_DISABLE=1 zip -qr "$BUILD_LOCATION/$APPLICATION_NAME.ipa" Payload)
cp "$BUILD_LOCATION/$APPLICATION_NAME.ipa" "$BUILD_LOCATION/$APPLICATION_NAME.tipa"
(cd "$BUILD_LOCATION" && shasum -a 256 "$APPLICATION_NAME.ipa" "$APPLICATION_NAME.tipa" > SHA256SUMS)
echo "Built $BUILD_LOCATION/$APPLICATION_NAME.ipa"
