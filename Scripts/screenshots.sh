#!/bin/bash
# Capture the 5 App Store screenshots against the RUNNING Twin app.
# Requires: System Settings > Privacy & Security > Screen Recording
# granted to your terminal (the agent session lacks this TCC grant).
# Usage: ./Scripts/build.sh && open <built TwinApp.app> && ./Scripts/screenshots.sh
set -e
cd "$(dirname "$0")/.."
OUT="Docs/screenshots"
mkdir -p "$OUT"

WIN_ID=$(swift -e '
import Cocoa
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String ?? "").contains("Twin") {
    print(w[kCGWindowNumber as String] ?? ""); break
}')
if [[ -z "$WIN_ID" ]]; then
  echo "Twin window not found — launch the app first." >&2
  exit 1
fi
echo "Twin window: $WIN_ID"

capture() {
  local file="$1" instruction="$2"
  echo ""
  echo ">> $instruction"
  read -r -p "   Arrange the app, then press Enter to capture $file ... " _
  screencapture -l "$WIN_ID" -x "$OUT/$file"
  echo "   Saved $OUT/$file"
}

capture "01-dual-pane.png"    "Motif 1/5 Dual-pane: home left, Documents right, list view."
capture "02-drag-drop.png"    "Motif 2/5 Drag-and-drop: start a drag toward the other pane (hold it), then capture."
capture "03-icon-quicklook.png" "Motif 3/5 Icon view + Quick Look: icon grid, select a file, press Space."
capture "04-search.png"       "Motif 4/5 Search: type a filter in one pane's filter field."
capture "05-finder.png"       "Motif 5/5 Finder: open Finder, show Twin View toolbar / Open in Twin menu, capture full screen next."
screencapture -x "$OUT/05-finder-full.png"
echo ""
echo "Done. Review sizes (App Store Mac: 1280x800 or 2880x1800) before submit."
