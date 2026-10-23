# Twin - Dual Pane Finder for Mac

Finder som det borde vara: dual-pane i samma fönster, Cinnamon-style drag-and-drop.
Zed/VSCode first, App Store compliant. Xcode endast för arkivering/upload.

## Quick Start (Zed / VSCode)

1. `brew install xcodegen`
2. `zed .` (eller `code .`) — öppna mappen, tasks finns i `.zed/tasks.json` / `.vscode/tasks.json`
3. `./Scripts/generate.sh` -> skapar Twin.xcodeproj (committas ALDRIG)
4. `./Scripts/build.sh` -> bygger med xcodebuild

## Funktioner

Lite (gratis): dual-pane med två oberoende NavigationStacks, drag-and-drop
(NSFilePromise), tabs/panelväxling Cmd+1/Cmd+2, Quick Look på Space,
instant search per panel, breadcrumbs.

Pro ($24.99 / 249 kr one-time, launch 149 kr): Workspaces, Folder Sync,
Batch Rename, Git badges. StoreKit 2, se `Configuration.storekit`.

## Screenshots (beskrivning för App Store)

1. **Dual-pane översikt** — två paneler sida vid sida, vänster ~/ och höger
   ~/Documents, breadcrumbs och listvy synliga, aktiv panel markerad.
2. **Drag-and-drop** — fil dras från vänster till höger panel, drop-highlight
   i accentfärg, progressbar "Copying 1 item(s)… 50%" i panelens fot.
3. **Icon view + Quick Look** — ikonrutnät i ena panelen, Quick Look-preview
   öppen över vald fil (Space).
4. **Search** — filterfältet aktivt med "report" ifyllt, träfflistan filtrerad
   i båda vyerna.
5. **Finder-integration** — Finder med "Twin View" i toolbaren och
   "Open in Twin" i högerklicksmenyn.

## Struktur

- `project.yml` = source of truth, committa denna
- `Package.swift` = TwinCore som Swift Package (`swift build`)
- `Sources/TwinApp` - UI, DualPaneView, Search
- `Sources/TwinCore` - FileSystem (NSFileCoordinator), security-scoped bookmarks
- `Sources/FinderSync` - Finder Sync Extension (toolbar + context menu, twin://)
- `Sources/TwinLite` / `Sources/TwinPro` - edition + StoreKit 2
- `Docs/UX-Spec.md` - UX-spec (LeadUX), `Docs/QA-Checklist.md` - App Store-check (LeadQA)
