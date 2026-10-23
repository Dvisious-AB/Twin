#!/bin/bash
set -e
if ! command -v xcodegen &> /dev/null; then
  echo "Installing xcodegen..."
  brew install xcodegen
fi
xcodegen generate
echo "Done. Open in Zed: zed . | Build: ./Scripts/build.sh"
echo "Xcode (only for archive): open Twin.xcodeproj"
