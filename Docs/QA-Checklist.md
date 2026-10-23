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

## Kvar före submit

- [x] `Scripts/archive.sh --unsigned` — `ARCHIVE SUCCEEDED` lokalt. Signerad arkivering + hardened runtime kräver aktivt Apple Developer-konto (#7)
- [ ] App Store Connect: produkt `se.dvisious.twin.pro`, pris 249 kr (launch 149 kr)
- [ ] Screenshots enligt README-sektionen "Screenshots"
