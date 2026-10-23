#!/bin/bash
# Build and launch Twin locally for manual testing. No Developer account needed.
set -e
cd "$(dirname "$0")/.."

./Scripts/build.sh

APP_PATH=$(xcodebuild -scheme Twin -configuration Debug -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
  | awk -F'= ' '/ BUILT_PRODUCTS_DIR =/ {print $2 "/TwinApp.app"}' | head -n 1)

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found (looked for: $APP_PATH)" >&2
  exit 1
fi

echo "Launching: $APP_PATH"
open "$APP_PATH"
echo "Twin is running. Test: navigate both panes, filter, Space = Quick Look, Tab/Cmd+1/Cmd+2 switches pane, drag files between panes."
