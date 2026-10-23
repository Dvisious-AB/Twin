#!/bin/bash
# Twin release archive — Xcode is used ONLY here (archive / App Store upload).
# Local validation: ./Scripts/archive.sh --unsigned
# App Store:         ./Scripts/archive.sh   (requires Apple Developer signing)
set -e
cd "$(dirname "$0")/.."

ARCHIVE_PATH="build/Twin.xcarchive"
SIGN_ARGS=()
if [[ "$1" == "--unsigned" ]]; then
  SIGN_ARGS=("CODE_SIGNING_ALLOWED=NO")
  echo "Unsigned validation archive (no hardened-runtime signing)."
else
  echo "Signed archive. Requires an active Apple Developer Program membership."
fi

./Scripts/generate.sh
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -scheme Twin \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  "${SIGN_ARGS[@]}"

echo "Archive ready: $ARCHIVE_PATH"
echo "Upload (manual, release only): Xcode Organizer or xcrun altool — see Docs/QA-Checklist.md"
