# Twin — App Store QA-checklista (LeadQA)

[LeadQA -> ProductOwner]: Check inför arkivering. Uppdateras av @QAEngineer.

## Bygg & verktyg

- [x] `./Scripts/generate.sh` grön (XcodeGen från project.yml)
- [x] `./Scripts/build.sh` — `BUILD SUCCEEDED` (scheme Twin, macOS)
- [x] `swift build` grön (TwinCore Swift Package)
- [x] SwiftLint 0.65.1 — `swiftlint lint --strict` 0 violations (17 filer), körs även i CI
- [x] Ingen `*.xcodeproj` trackad i git (`git ls-files | grep xcodeproj` tom)
- [x] CI: `.github/workflows/build.yml` (lint, generate, build, swift test på macos-14)

## Sandbox & entitlements

- [x] `com.apple.security.app-sandbox` på (TwinApp + FinderSyncExtension)
- [x] Endast App Store-kompatibla nycklar: `files.user-selected.read-write`,
      `files.bookmarks.app-scope`, `files.bookmarks.document-scope`
- [x] Inga privata entitlements

## Privacy & metadata

- [x] `Sources/TwinApp/PrivacyInfo.xcprivacy` — ingen tracking, inga insamlade
      datatyper, UserDefaults (CA92.1) + FileTimestamp (C617.1) deklarerade
- [x] `twin://` URL-scheme registrerad via project.yml (överlever generate.sh)
- [x] StoreKit: `Configuration.storekit` med `se.dvisious.twin.pro`

## Feltillstånd & återhämtning (tillagt efter pilotfynd 2026-10-24)

Pilotanvändaren landade i "Can't Read Folder" utan väg vidare —
testerna körde bara i läsbara mappar. Kontrollera varje release:

- [ ] Starta med en sparad session som pekar på en mapp utan
      behörighet (t.ex. /Users utan bokmärke): feltillståndet ska
      erbjuda Grant Access / Choose Another Folder / Go Up — aldrig
      bara Try Again.
- [ ] Grant Access från feltillståndet ska ladda mappen efter val.
- [ ] Pil-navigation (↑/↓) direkt efter start, utan föregående klick
      (täckt av `testArrowKeysMoveSelection`).
- [ ] Första start utan bokmärken: Welcome-grant visas, panelerna
      står i hem/Desktop — aldrig i sandbox-containern.

## Viewers, editors & filtypskopplingar (2026-10-24)

- [x] F3 Viewer: text/kod med radnummer, Markdown renderad (+ Raw),
      bild med zoom, PDF, media, hex för binärt — `testF3OpensBuiltinViewer`
- [x] Guide: Files ▸ File Type Handlers… — välj filtyp, visare (F3),
      editor (F4/Enter åsidosätter macOS standard i Twin), egen
      handler (app eller kommando med {file}) — `testFileTypeHandlersGuideOpens`
- [x] Högerklick ▸ Open With: Twin Viewer/Editor, installerade appar,
      egna handlers, macOS standardapp
- [ ] Manuellt: sätt .log → extern editor i guiden, verifiera att
      Enter öppnar dit och att valet överlever omstart
- [ ] Manuellt: egen kommando-handler (t.ex. xxd {file}) körs från
      Open With utan fel i statusraden

## Rekursiv sökning (2026-10-24)

- [x] Cmd+Shift+F Find Files: namn + text i filer, rekursivt under
      aktiv panel, resultat med Show in Pane/Open —
      `testFindFilesRecursiveSearch`, enhetstester i TwinCore
- [ ] Manuellt: sök i en stor riktig mapp (10k+ filer) och avbryt
      med Stop mitt i — appen ska svara direkt

## Kvar före submit

- [x] `Scripts/archive.sh --unsigned` — `ARCHIVE SUCCEEDED` lokalt. Signerad arkivering + hardened runtime kräver aktivt Apple Developer-konto (#7)
- [ ] App Store Connect: produkt `se.dvisious.twin.pro`, pris 249 kr (launch 149 kr)
- [ ] Screenshots enligt README-sektionen "Screenshots"
