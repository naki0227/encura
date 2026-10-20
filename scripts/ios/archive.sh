#!/usr/bin/env bash
# Build an iOS archive (and optionally upload it to TestFlight).
#
#   scripts/ios/archive.sh <config.json> <output-dir> [build-number]
#
# Signed + upload when ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID are set
# (App Store Connect API key, cloud-managed signing). Without them it makes an
# unsigned archive, which is what CI uses to prove the release build compiles.
set -euo pipefail

CONFIG=$1
OUT=$2
BUILD_NUMBER=${3:-}
ARCHIVE="$OUT/Runner.xcarchive"
mkdir -p "$OUT"

flutter_args=(--release --config-only "--dart-define-from-file=$CONFIG")
if [[ -n "$BUILD_NUMBER" ]]; then
  flutter_args+=("--build-number=$BUILD_NUMBER")
fi

xcode_args=(
  -workspace ios/Runner.xcworkspace
  -scheme Runner
  -configuration Release
  -destination "generic/platform=iOS"
)

if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  auth_args=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
  flutter build ios "${flutter_args[@]}"
  xcodebuild archive "${xcode_args[@]}" -archivePath "$ARCHIVE" "${auth_args[@]}"

  cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
  # destination=upload sends the build straight to App Store Connect / TestFlight.
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" "${auth_args[@]}"
else
  echo "No App Store Connect key: building an unsigned archive only."
  flutter build ios "${flutter_args[@]}" --no-codesign
  xcodebuild archive "${xcode_args[@]}" -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
