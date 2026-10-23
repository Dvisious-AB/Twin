# Twin - Dual Pane Finder for Mac

Zed/VSCode first, App Store compliant.

## Quick Start (Zed)

1. `brew install xcodegen`
2. `zed .` öppna mappen
3. `./Scripts/generate.sh` -> skapar Twin.xcodeproj
4. `./Scripts/build.sh` -> bygger med xcodebuild

Struktur:
- `project.yml` = source of truth, committa denna
- `Twin.xcodeproj` genereras, commita ALDRIG (gitignore)
- `Sources/TwinApp` - UI, DualPaneView
- `Sources/TwinCore` - Logik, bookmarks
- `Sources/FinderSync` - Finder Sync Extension

Pris: Lite gratis, Pro 249kr $24.99 one-time

## Muse Team
Använd master-prompten jag gav dig. Första task: @BuildEngineer genererar project.yml (klart).
Nästa: FileSystemEngineer + PaneUIEngineer
